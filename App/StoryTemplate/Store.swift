import Foundation
import SwiftUI
import TemplateKit

/// Abonelik durumunun UI tarafındaki sahibi. Mağaza işini `EntitlementProvider`
/// yapar; bu sınıf yalnız durumu yayınlar ve kilit kurallarını (`Entitlements`)
/// sunar. Hangi sağlayıcının takılı olduğunu UI hiç bilmez.
///
/// Sağlayıcı seçimi `--billing` bayrağıyla yapılır (bkz. `BillingBackend`):
/// varsayılan `local` (mağazasız demo), `storekit` gerçek App Store.
///
/// Screenshot otomasyonu: `--pro` Pro başlatır, `--free` aboneliği sıfırlar
/// (yalnız yerel sağlayıcıda geçerli — gerçek mağazada hak uydurulmaz).
@MainActor
final class Store: ObservableObject {
    @Published private(set) var status: EntitlementStatus = .free
    @Published var isPurchasing = false
    /// Paywall'ı tetikleyen bağlam (başlıkta gösterilir).
    @Published var paywallReason: String?
    /// Mağazadan gelen ürünler. Gerçek mağazada ilk anda BOŞ olabilir —
    /// paywall bu durumda fiyat yerine yükleniyor gösterir.
    @Published private(set) var products: [SubscriptionProduct] = []

    let backend: BillingBackend
    private let provider: EntitlementProvider
    /// Yerel sağlayıcı takılıysa demo bayraklarını (`--pro`) uygulayabilmek için.
    private let local: LocalEntitlementProvider?

    init(backend: BillingBackend = .resolved) {
        self.backend = backend
        let arguments = ProcessInfo.processInfo.arguments
        switch backend {
        case .storeKit:
            local = nil
            provider = StoreKitEntitlementProvider()
        case .local:
            let localProvider = LocalEntitlementProvider()
            #if DEBUG
            // Demo/screenshot bayrakları YALNIZ debug derlemede: yayınlanan
            // uygulamada bir başlatma argümanı Pro açamamalı.
            if arguments.contains("--free") { localProvider.reset() }
            if arguments.contains("--pro") {
                // Mağazadan geçmeden Pro başlat. Senkron — hemen başlayan
                // otomatik export doğru durumu görsün.
                localProvider.grant(localProvider.products[1])
            }
            #endif
            local = localProvider
            provider = localProvider
        }
        status = provider.status
        products = provider.products
    }

    /// Gerçek mağazada ürünleri ve hakları çeker (yerel sağlayıcıda anında
    /// döner). Açılışta bir kez çağrılır.
    func start() async {
        guard let storeKit = provider as? StoreKitEntitlementProvider else { return }
        status = await storeKit.start()
        products = storeKit.products
    }

    var entitlements: Entitlements { Entitlements(status: status) }

    func showPaywall(reason: String) {
        paywallReason = reason
        Analytics.shared.log(.paywallShown(reason: reason))
    }

    func purchase(_ product: SubscriptionProduct) async {
        isPurchasing = true
        defer { isPurchasing = false }
        if local != nil {
            // Gerçek mağaza akışının gecikmesini taklit et (buton durumları görünsün).
            Analytics.shared.log(.purchaseStarted(productID: product.id))
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        do {
            status = try await provider.purchase(product)
            if local != nil {
                Analytics.shared.log(.purchaseCompleted(productID: product.id,
                                                        plan: product.plan.rawValue,
                                                        trial: status.inTrial))
            }
            paywallReason = nil
        } catch {
            // Gerçek sağlayıcı olayı kendi kaydeder (iptal/doğrulanamadı ayrımı
            // orada bilinir); burada yalnız UI durumu geri alınır.
            if local != nil {
                Analytics.shared.log(.purchaseFailed(productID: product.id, reason: "local"))
            }
        }
    }

    func restore() async -> Bool {
        guard let restored = try? await provider.restore() else {
            if local != nil { Analytics.shared.log(.restoreCompleted(success: false)) }
            return false
        }
        status = restored
        paywallReason = nil
        if local != nil { Analytics.shared.log(.restoreCompleted(success: true)) }
        return true
    }
}

/// Hangi ödeme arka ucunun kullanılacağı.
///
/// MVP'de varsayılan `local`: App Store Connect'te ürünler tanımlanana kadar
/// gerçek satın alma denemesi her cihazda hata verir, demo ve screenshot akışı
/// da kırılır. Ürünler yayına girince buradaki varsayılan `storeKit` yapılır —
/// uygulamanın başka hiçbir yeri değişmez.
///
/// RevenueCat: `RevenueCatEntitlementProvider` TemplateKit'te hazır ve testli,
/// yalnız `PurchasesBridge`'i uygulayan SDK adaptörü eksik (SDK bağımlılığı
/// bilinçli olarak henüz eklenmedi). Bridge yazıldığında buraya üçüncü bir
/// seçenek olarak girer.
enum BillingBackend: String {
    case local
    case storeKit = "storekit"

    /// `--billing storekit` / `--billing local`; verilmezse varsayılan.
    static var resolved: BillingBackend {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--billing"), index + 1 < arguments.count,
           let backend = BillingBackend(rawValue: arguments[index + 1].lowercased()) {
            return backend
        }
        return .local
    }
}
