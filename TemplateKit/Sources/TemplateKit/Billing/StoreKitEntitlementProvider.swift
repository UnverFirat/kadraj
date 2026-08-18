#if canImport(StoreKit)
import Foundation
import StoreKit

/// Gerçek mağaza sağlayıcısı — **StoreKit 2**, üçüncü parti SDK yok.
///
/// `EntitlementProvider`'ı uygular, yani uygulamanın geri kalanı (paywall,
/// galeri kilidi, filigran kararı) hiç değişmeden bu sağlayıcıyla çalışır;
/// `LocalEntitlementProvider` demo/test yolunda kalır.
///
/// Akış:
/// 1. `start()` — açılışta bir kez: ürünleri çeker, `Transaction.updates`
///    dinleyicisini kurar (dışarıda yapılan/yenilenen satın alımlar), mevcut
///    hakları tazeler.
/// 2. `status` her zaman SENKRON okunur (protokol sözleşmesi). Değer
///    `EntitlementCache`'ten gelir → mağaza cevabı gecikirken bile doğru.
/// 3. Doğrulama: `VerificationResult` yalnız `.verified` kabul edilir. Sunucu
///    tarafı makbuz doğrulaması MVP'de yok — StoreKit 2'nin imza doğrulaması
///    cihazda yeterli; abonelik sunucumuzda bir hesaba bağlı değil (hesapsız
///    uygulama).
@available(iOS 16.0, macOS 13.0, *)
public final class StoreKitEntitlementProvider: EntitlementProvider, @unchecked Sendable {

    /// Mağazadaki ürün kimlikleri. App Store Connect'te bu id'lerle
    /// oluşturulur; kodda başka yerde geçmez.
    public struct Configuration: Sendable {
        public var monthlyProductID: String
        public var yearlyProductID: String

        public init(monthlyProductID: String = "com.fireflysoftware.kadraj.pro.monthly",
                    yearlyProductID: String = "com.fireflysoftware.kadraj.pro.yearly") {
            self.monthlyProductID = monthlyProductID
            self.yearlyProductID = yearlyProductID
        }

        var allIDs: [String] { [monthlyProductID, yearlyProductID] }

        func plan(for productID: String) -> SubscriptionPlan? {
            if productID == monthlyProductID { return .monthly }
            if productID == yearlyProductID { return .yearly }
            return nil
        }
    }

    private let configuration: Configuration
    private let cache: EntitlementCache
    private let analytics: Analytics
    private let lock = NSLock()
    private var storeProducts: [String: Product] = [:]
    private var cachedProducts: [SubscriptionProduct] = []
    private var cachedStatus: EntitlementStatus
    private var updatesTask: Task<Void, Never>?

    public init(configuration: Configuration = Configuration(),
                cache: EntitlementCache = EntitlementCache(),
                analytics: Analytics = .shared) {
        self.configuration = configuration
        self.cache = cache
        self.analytics = analytics
        self.cachedStatus = cache.status
    }

    deinit { updatesTask?.cancel() }

    // MARK: EntitlementProvider

    public var status: EntitlementStatus {
        lock.lock(); defer { lock.unlock() }
        return cachedStatus
    }

    /// Ürünler mağazadan gelene kadar BOŞ döner — paywall bu durumda fiyat
    /// yerine yükleniyor göstermeli (fiyat uydurmak App Store kuralına aykırı).
    public var products: [SubscriptionProduct] {
        lock.lock(); defer { lock.unlock() }
        return cachedProducts
    }

    public func purchase(_ product: SubscriptionProduct) async throws -> EntitlementStatus {
        guard let storeProduct = self.storeProduct(id: product.id) else {
            throw EntitlementError.unavailable
        }
        analytics.log(.purchaseStarted(productID: product.id))
        let result: Product.PurchaseResult
        do {
            result = try await storeProduct.purchase()
        } catch {
            analytics.log(.purchaseFailed(productID: product.id, reason: "store_error"))
            throw EntitlementError.unavailable
        }
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                // İmzası doğrulanmayan işlem (jailbreak/aracı) — hak tanınmaz.
                analytics.log(.purchaseFailed(productID: product.id, reason: "unverified"))
                throw EntitlementError.unavailable
            }
            // `finish` ÇAĞRILMAZSA işlem her açılışta yeniden düşer.
            await transaction.finish()
            let new = await refreshEntitlements()
            analytics.log(.purchaseCompleted(productID: product.id,
                                             plan: product.plan.rawValue,
                                             trial: new.inTrial))
            return new
        case .userCancelled:
            analytics.log(.purchaseFailed(productID: product.id, reason: "cancelled"))
            throw EntitlementError.cancelled
        case .pending:
            // "Ask to buy" (aile onayı) — onaylanınca Transaction.updates düşer.
            analytics.log(.purchaseFailed(productID: product.id, reason: "pending"))
            throw EntitlementError.unavailable
        @unknown default:
            throw EntitlementError.unavailable
        }
    }

    /// "Satın alımları geri yükle": App Store hesabını senkronlar, sonra
    /// hakları yeniden okur. Abonelik hesapsız çalıştığı için tek yol budur.
    public func restore() async throws -> EntitlementStatus {
        try? await AppStore.sync()
        let restored = await refreshEntitlements()
        analytics.log(.restoreCompleted(success: restored.isPro))
        guard restored.isPro else { throw EntitlementError.nothingToRestore }
        return restored
    }

    // MARK: Yaşam döngüsü

    /// Açılışta bir kez çağrılır: ürünler + hak durumu + işlem dinleyicisi.
    @discardableResult
    public func start() async -> EntitlementStatus {
        startObservingTransactions()
        await loadProducts()
        return await refreshEntitlements()
    }

    /// Mağaza dışında olan değişiklikleri (yenileme, iptal, aile paylaşımı,
    /// bekleyen satın almanın onaylanması) yakalar.
    private func startObservingTransactions() {
        lock.lock()
        let alreadyRunning = updatesTask != nil
        lock.unlock()
        guard !alreadyRunning else { return }

        let task = Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                _ = await self.refreshEntitlements()
            }
        }
        lock.lock()
        updatesTask = task
        lock.unlock()
    }

    /// Ürünleri mağazadan çeker ve paywall'ın gösterdiği modele çevirir.
    /// Fiyat metni MAĞAZADAN gelir (para birimi/lokal biçim App Store'un).
    public func loadProducts() async {
        guard let fetched = try? await Product.products(for: configuration.allIDs) else { return }
        var byID: [String: Product] = [:]
        var models: [SubscriptionProduct] = []
        // Sıra: aylık, yıllık (paywall bu sırayı bekliyor).
        for id in configuration.allIDs {
            guard let product = fetched.first(where: { $0.id == id }),
                  let plan = configuration.plan(for: id) else { continue }
            byID[id] = product
            models.append(SubscriptionProduct(id: id,
                                              plan: plan,
                                              priceText: product.displayPrice,
                                              periodText: Self.periodText(for: product, plan: plan),
                                              trialDays: Self.trialDays(for: product),
                                              pricePerMonthText: Self.pricePerMonth(for: product,
                                                                                    plan: plan)))
        }
        store(products: byID, models: models)
    }

    /// Kilit alan kısım ayrı ve SENKRON: `NSLock` async bağlamda tutulamaz
    /// (askıya alma noktası kilidi başka bir iş parçacığında bırakabilir).
    private func store(products: [String: Product], models: [SubscriptionProduct]) {
        lock.lock(); defer { lock.unlock() }
        storeProducts = products
        cachedProducts = models
    }

    /// Geçerli hakları okur ve durumu (cache dahil) günceller.
    @discardableResult
    public func refreshEntitlements() async -> EntitlementStatus {
        var newStatus: EntitlementStatus = .free
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  configuration.allIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expires = transaction.expirationDate, expires < Date() { continue }
            newStatus = .pro(expires: transaction.expirationDate,
                             inTrial: Self.isIntroductoryOffer(transaction))
            break
        }
        apply(newStatus)
        return newStatus
    }

    private func apply(_ status: EntitlementStatus) {
        lock.lock()
        cachedStatus = status
        lock.unlock()
        cache.store(status)
    }

    private func storeProduct(id: String) -> Product? {
        lock.lock(); defer { lock.unlock() }
        return storeProducts[id]
    }

    // MARK: Biçimlendirme

    /// "aylık" / "yıllık · ayda ₺33" — yıllıkta aylık karşılığı, mağazanın
    /// para birimi biçimiyle hesaplanır (elle sembol yazılmaz).
    private static func periodText(for product: Product, plan: SubscriptionPlan) -> String {
        switch plan {
        case .monthly:
            return "aylık"
        case .yearly:
            let perMonth = product.price / 12
            let formatted = perMonth.formatted(product.priceFormatStyle)
            return "yıllık · ayda \(formatted)"
        }
    }

    /// Yıllık planın aylık karşılığı — para birimi/biçim mağazadan.
    private static func pricePerMonth(for product: Product, plan: SubscriptionPlan) -> String? {
        guard plan == .yearly else { return nil }
        return (product.price / 12).formatted(product.priceFormatStyle)
    }

    private static func trialDays(for product: Product) -> Int {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return 0 }
        let value = offer.period.value
        switch offer.period.unit {
        case .day:   return value
        case .week:  return value * 7
        case .month: return value * 30
        case .year:  return value * 365
        @unknown default: return value
        }
    }

    /// Deneme sürümünde mi? `Transaction.offer` yalnız iOS 17.2+'da var;
    /// eski sürümlerdeki `offerType` kullanımdan kaldırıldığı için (uyarı
    /// üretiyor) orada "deneme değil" deriz — bu yalnız paywall metnini
    /// etkiler, hakkı değil.
    private static func isIntroductoryOffer(_ transaction: StoreKit.Transaction) -> Bool {
        if #available(iOS 17.2, macOS 14.2, *) {
            return transaction.offer?.type == .introductory
        }
        return false
    }
}
#endif
