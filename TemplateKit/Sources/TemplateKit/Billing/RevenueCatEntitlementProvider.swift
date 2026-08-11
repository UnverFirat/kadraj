import Foundation

// MARK: - Köprü (SDK sınırı)

/// RevenueCat'ten gelen bir teklif (offering paketi).
public struct RemoteOffering: Equatable, Sendable {
    public let productID: String
    public let plan: SubscriptionPlan
    /// Mağazadan gelen lokalize fiyat metni ("₺399,99").
    public let priceText: String
    /// Aylık karşılık gibi ikinci satır; nil ise sağlayıcı varsayılanı yazar.
    public let periodText: String?
    public let trialDays: Int

    public init(productID: String, plan: SubscriptionPlan, priceText: String,
                periodText: String? = nil, trialDays: Int = 0) {
        self.productID = productID
        self.plan = plan
        self.priceText = priceText
        self.periodText = periodText
        self.trialDays = trialDays
    }
}

/// RevenueCat `CustomerInfo`'nun bizim ihtiyacımız olan kadarı.
public struct RemoteCustomerInfo: Equatable, Sendable {
    /// Aktif entitlement kimlikleri (RevenueCat panosunda tanımlı, ör. "pro").
    public let activeEntitlements: Set<String>
    public let expirationDate: Date?
    public let isInTrial: Bool

    public init(activeEntitlements: Set<String>, expirationDate: Date? = nil,
                isInTrial: Bool = false) {
        self.activeEntitlements = activeEntitlements
        self.expirationDate = expirationDate
        self.isInTrial = isInTrial
    }

    public static let none = RemoteCustomerInfo(activeEntitlements: [])
}

public enum RemotePurchaseError: Error, Equatable {
    case cancelled
    case unavailable
}

/// Uzak abonelik servisinin (RevenueCat) uygulamaya bakan yüzü.
///
/// TASARIM — neden SDK doğrudan çağrılmıyor: `Purchases` SDK'sı ağ, cihaz ve
/// App Store hesabı ister; ne testte ne CI'da koşar. Bu protokol SDK'nın
/// yüzeyini DÖRT çağrıya indirger, böylece paywall/kilit mantığının tamamı
/// SDK'sız test edilir. SDK eklendiğinde tek yapılacak, bu protokolü uygulayan
/// ~30 satırlık bir `PurchasesBridge` yazmaktır:
///
///     final class LivePurchasesBridge: PurchasesBridge {
///         func customerInfo() async throws -> RemoteCustomerInfo {
///             map(try await Purchases.shared.customerInfo())
///         }
///         ...
///     }
///
/// `TemplateKit`'in bağımlılıksız kalması da bilinçli: motor bir ödeme SDK'sına
/// bağlanmaz.
public protocol PurchasesBridge: Sendable {
    func offerings() async throws -> [RemoteOffering]
    func customerInfo() async throws -> RemoteCustomerInfo
    func purchase(productID: String) async throws -> RemoteCustomerInfo
    func restore() async throws -> RemoteCustomerInfo
}

// MARK: - Sağlayıcı

/// RevenueCat sağlayıcısı: köprüden gelen `CustomerInfo`'yu uygulamanın
/// `EntitlementStatus`'una çevirir. Hak kararının TEK kuralı:
/// `entitlementID` aktif entitlement'lar arasında mı.
public final class RevenueCatEntitlementProvider: EntitlementProvider, @unchecked Sendable {
    private let bridge: PurchasesBridge
    /// RevenueCat panosundaki entitlement kimliği (ürün kimliği DEĞİL — ürün
    /// değişse de hak aynı kalsın diye RevenueCat bu ayrımı yapar).
    private let entitlementID: String
    private let cache: EntitlementCache
    private let analytics: Analytics
    private let lock = NSLock()
    private var cachedStatus: EntitlementStatus
    private var cachedProducts: [SubscriptionProduct] = []

    public init(bridge: PurchasesBridge,
                entitlementID: String = "pro",
                cache: EntitlementCache = EntitlementCache(key: "entitlement.cache.rc"),
                analytics: Analytics = .shared) {
        self.bridge = bridge
        self.entitlementID = entitlementID
        self.cache = cache
        self.analytics = analytics
        self.cachedStatus = cache.status
    }

    public var status: EntitlementStatus {
        lock.lock(); defer { lock.unlock() }
        return cachedStatus
    }

    public var products: [SubscriptionProduct] {
        lock.lock(); defer { lock.unlock() }
        return cachedProducts
    }

    /// Açılışta bir kez: teklifler + mevcut hak.
    @discardableResult
    public func start() async -> EntitlementStatus {
        await loadOfferings()
        return await refresh()
    }

    public func loadOfferings() async {
        guard let offerings = try? await bridge.offerings() else { return }
        let models = offerings.map { offering in
            SubscriptionProduct(id: offering.productID,
                                plan: offering.plan,
                                priceText: offering.priceText,
                                periodText: offering.periodText
                                    ?? (offering.plan == .monthly ? "aylık" : "yıllık"),
                                trialDays: offering.trialDays)
        }
        store(models)
    }

    /// Kilit alan kısım ayrı ve SENKRON (async bağlamda `NSLock` tutulmaz).
    private func store(_ models: [SubscriptionProduct]) {
        lock.lock(); defer { lock.unlock() }
        cachedProducts = models
    }

    /// Uzak durumu yeniden okur (uygulama öne geldiğinde de çağrılabilir).
    @discardableResult
    public func refresh() async -> EntitlementStatus {
        guard let info = try? await bridge.customerInfo() else { return status }
        return apply(info)
    }

    public func purchase(_ product: SubscriptionProduct) async throws -> EntitlementStatus {
        analytics.log(.purchaseStarted(productID: product.id))
        do {
            let info = try await bridge.purchase(productID: product.id)
            let new = apply(info)
            guard new.isPro else {
                // Satın alma "başarılı" döndü ama hak gelmedi (yanlış
                // entitlement eşlemesi) — sessizce Pro sayma.
                analytics.log(.purchaseFailed(productID: product.id, reason: "no_entitlement"))
                throw EntitlementError.unavailable
            }
            analytics.log(.purchaseCompleted(productID: product.id,
                                             plan: product.plan.rawValue,
                                             trial: new.inTrial))
            return new
        } catch RemotePurchaseError.cancelled {
            analytics.log(.purchaseFailed(productID: product.id, reason: "cancelled"))
            throw EntitlementError.cancelled
        } catch let error as EntitlementError {
            throw error
        } catch {
            analytics.log(.purchaseFailed(productID: product.id, reason: "store_error"))
            throw EntitlementError.unavailable
        }
    }

    public func restore() async throws -> EntitlementStatus {
        let info = (try? await bridge.restore()) ?? .none
        let restored = apply(info)
        analytics.log(.restoreCompleted(success: restored.isPro))
        guard restored.isPro else { throw EntitlementError.nothingToRestore }
        return restored
    }

    @discardableResult
    private func apply(_ info: RemoteCustomerInfo) -> EntitlementStatus {
        var new: EntitlementStatus = .free
        if info.activeEntitlements.contains(entitlementID) {
            // Süresi geçmiş hak (sunucu saati ile bizimki farklı olabilir):
            // yine de kapat — hak açık kalırsa ücretsiz Pro demektir.
            if let expires = info.expirationDate, expires < Date() {
                new = .free
            } else {
                new = .pro(expires: info.expirationDate, inTrial: info.isInTrial)
            }
        }
        lock.lock()
        cachedStatus = new
        lock.unlock()
        cache.store(new)
        return new
    }
}
