import Foundation

// MARK: - Abonelik durumu

/// Kullanıcının erişim düzeyi. Motor bunu bilmez — export'a yalnız
/// `includeWatermark` gibi somut parametreler geçer; karar bu katmanda verilir.
public enum EntitlementStatus: Equatable, Sendable {
    case free
    /// - Parameters:
    ///   - expires: bilinmiyorsa nil (mağaza yenilemeyi kendi yönetir).
    ///   - inTrial: deneme süresi devam ediyor mu (yıllıkta 3 gün).
    case pro(expires: Date? = nil, inTrial: Bool = false)

    public var isPro: Bool {
        if case .pro = self { return true }
        return false
    }

    public var inTrial: Bool {
        if case .pro(_, let inTrial) = self { return inTrial }
        return false
    }
}

public enum SubscriptionPlan: String, Sendable, CaseIterable {
    case monthly, yearly
}

/// Paywall'da gösterilen ürün. Fiyat metni mağazadan (StoreKit/RevenueCat)
/// lokalize gelir — burada string olarak taşınır, biçimlendirme yapılmaz.
public struct SubscriptionProduct: Identifiable, Equatable, Sendable {
    public let id: String
    public let plan: SubscriptionPlan
    public let priceText: String
    /// "aylık" / "yıllık (₺33/ay)" gibi ikinci satır.
    ///
    /// NOT: bu alan artık ARAYÜZDE kullanılmıyor — metin uygulamanın dilinde
    /// kurulmalı ve motor paketinde çeviri katalogu yok. Paywall satırını
    /// `plan` + `pricePerMonthText`'ten kendisi kurar; bu alan günlük/hata
    /// ayıklama içindir.
    public let periodText: String
    /// Yıllık planın aylığa bölünmüş fiyatı, mağazanın biçimiyle ("₺33").
    /// Aylık planda nil.
    public let pricePerMonthText: String?
    /// Ücretsiz deneme günü (0 = deneme yok). Yıllıkta 3 gün.
    public let trialDays: Int

    public init(id: String, plan: SubscriptionPlan, priceText: String,
                periodText: String, trialDays: Int = 0,
                pricePerMonthText: String? = nil) {
        self.id = id
        self.plan = plan
        self.priceText = priceText
        self.periodText = periodText
        self.trialDays = trialDays
        self.pricePerMonthText = pricePerMonthText
    }
}

public enum EntitlementError: Error, Equatable {
    case cancelled
    case unavailable
    case nothingToRestore
}

/// Abonelik sağlayıcısı arayüzü.
///
/// TASARIM: uygulama RevenueCat'i (ya da StoreKit'i) DOĞRUDAN kullanmaz, bu
/// protokolü kullanır. Böylece paywall/kilit mantığı SDK olmadan test edilir ve
/// sağlayıcı değişirse tek bir adaptör yazılır (`RevenueCatEntitlementProvider`
/// ileride burada `products/purchase/restore`'u SDK'ya devreder).
public protocol EntitlementProvider: AnyObject, Sendable {
    var status: EntitlementStatus { get }
    var products: [SubscriptionProduct] { get }
    func purchase(_ product: SubscriptionProduct) async throws -> EntitlementStatus
    func restore() async throws -> EntitlementStatus
}

// MARK: - Kilit kuralları

/// "Neye erişilebilir" kuralları tek yerde. Galeri, müzik seçici ve export
/// aynı kaynaktan karar verir; kural değişince tek dosya değişir.
public struct Entitlements: Equatable, Sendable {
    public var status: EntitlementStatus

    /// Bir kerelik "ilk videon bizden" hakkı HARCANDI mı.
    ///
    /// HUNİ KARARI: eski akışta teklif değerden önce geliyordu — kullanıcı
    /// uygulamayı açıyor, ilgisini çeken ilk şablona dokunuyor ve daha tek bir
    /// video üretmeden paywall'a çarpıyordu. Kimse görmediği bir şey için ödemez.
    /// Dönüşüm, kullanıcı işi bir kez BİTİRİP sonucu sevdiğinde olur; bu yüzden
    /// ilk video filigransız veriliyor, teklif ondan sonra geliyor.
    ///
    /// Varsayılan `true` (= hak yok): bu alanı bilmeyen bir çağıran bugünkü
    /// "ücretsiz kullanıcı filigran alır" davranışını görsün. Yeni bir alan
    /// eklemek kimseye sessizce sınırsız filigransız export dağıtmamalı.
    public var didUseFirstFreeExport: Bool

    public init(status: EntitlementStatus, didUseFirstFreeExport: Bool = true) {
        self.status = status
        self.didUseFirstFreeExport = didUseFirstFreeExport
    }

    public var isPro: Bool { status.isPro }

    /// Pro şablon ücretsiz kullanıcıda kilitlidir (galeride görünür ama
    /// dokununca paywall açılır — keşif ücretsiz, kullanım Pro).
    public func isLocked(_ template: Template) -> Bool {
        template.isPro && !isPro
    }

    public func isLocked(_ track: MusicTrack) -> Bool {
        track.isPro && !isPro
    }

    /// Bir kerelik ücretsiz (filigransız) export hakkı hâlâ duruyor mu.
    ///
    /// Pro'da HER ZAMAN `false`: Pro'nun çıktısı zaten filigransız, hakkı
    /// harcamanın da anlamı yok — abonelik biterse kullanıcı bu hakkı hâlâ
    /// elinde bulmalı. Yani mekanizma Pro kullanıcıda hiç devreye girmez.
    public var hasFirstFreeExport: Bool { !isPro && !didUseFirstFreeExport }

    /// Motorun filigran hakkında bildiği TEK şey bu `Bool` — kural burada,
    /// render katmanında değil.
    ///
    /// Ücretsiz kullanıcı ilk videosunu filigransız alır (bkz.
    /// `didUseFirstFreeExport`), sonrakiler filigranlı çıkar.
    public var includeWatermark: Bool { !isPro && didUseFirstFreeExport }

    /// Kilitli parça seçiliyse ücretsiz bir alternatife düşer (export
    /// kilitliyken sessizce Pro içerik kullanılmasın).
    public func resolvedTrack(_ track: MusicTrack?) -> MusicTrack? {
        guard let track else { return nil }
        return isLocked(track) ? MusicLibrary.all.first { !$0.isPro } : track
    }
}

// MARK: - Yerel (mağazasız) sağlayıcı

/// Mağaza olmadan çalışan sağlayıcı: durumu UserDefaults'ta tutar.
/// Demo uygulaması ve testler bunu kullanır; üretimde RevenueCat adaptörü
/// aynı protokolü uygular.
public final class LocalEntitlementProvider: EntitlementProvider, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, key: String = "entitlement.pro") {
        self.defaults = defaults
        self.key = key
    }

    public var status: EntitlementStatus {
        lock.lock(); defer { lock.unlock() }
        guard let stored = defaults.dictionary(forKey: key) else { return .free }
        let expires = stored["expires"] as? Date
        // Süresi geçmiş abonelik = free (mağaza yenilemediyse).
        if let expires, expires < Date() { return .free }
        return .pro(expires: expires, inTrial: stored["trial"] as? Bool ?? false)
    }

    public var products: [SubscriptionProduct] {
        [SubscriptionProduct(id: "pro.monthly", plan: .monthly,
                             priceText: "₺79,99", periodText: "aylık"),
         SubscriptionProduct(id: "pro.yearly", plan: .yearly,
                             priceText: "₺399,99", periodText: "yıllık · ayda ₺33",
                             trialDays: 3, pricePerMonthText: "₺33")]
    }

    public func purchase(_ product: SubscriptionProduct) async throws -> EntitlementStatus {
        grant(product)
        return status
    }

    /// Mağaza akışı olmadan hakkı ANINDA tanır (demo başlatma bayrağı, testler).
    /// Senkron olması önemli: `purchase` await edilmeden export başlarsa
    /// kullanıcı Pro'yken filigran yiyor.
    public func grant(_ product: SubscriptionProduct) {
        let period: TimeInterval = product.plan == .monthly ? 30 * 86400 : 365 * 86400
        let inTrial = product.trialDays > 0
        let expires = Date().addingTimeInterval(inTrial ? Double(product.trialDays) * 86400
                                                        : period)
        lock.lock()
        defaults.set(["expires": expires, "trial": inTrial], forKey: key)
        lock.unlock()
    }

    public func restore() async throws -> EntitlementStatus {
        let current = status
        guard current.isPro else { throw EntitlementError.nothingToRestore }
        return current
    }

    /// Testler/demo için: aboneliği sıfırla.
    public func reset() {
        lock.lock()
        defaults.removeObject(forKey: key)
        lock.unlock()
    }
}
