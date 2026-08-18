import Foundation

/// Son bilinen abonelik durumunu diske yazar.
///
/// NEDEN: mağaza (StoreKit ya da RevenueCat) durumu ASENKRON verir — uygulama
/// açılışında ilk kare çizilirken cevap henüz gelmemiştir. Cache olmasa Pro
/// kullanıcı her açılışta bir an "free" görünür (paywall banner'ı yanıp söner,
/// hemen başlayan bir export filigran basar). Cache ile açılış anında doğru
/// durumla başlar, mağaza cevabı gelince üstüne yazılır.
///
/// Bu bir yetki KAYNAĞI değil, önbelleğidir: son geçerlilik tarihi geçmişse
/// `free` döner ve mağaza cevabı her zaman kazanır.
/// (`UserDefaults` kendi içinde iş parçacığı güvenli; `Sendable` işaretlemediği
/// için `@unchecked`.)
public struct EntitlementCache: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "entitlement.cache") {
        self.defaults = defaults
        self.key = key
    }

    public var status: EntitlementStatus {
        guard let stored = defaults.dictionary(forKey: key) else { return .free }
        guard stored["pro"] as? Bool == true else { return .free }
        let expires = stored["expires"] as? Date
        if let expires, expires < Date() { return .free }
        return .pro(expires: expires, inTrial: stored["trial"] as? Bool ?? false)
    }

    public func store(_ status: EntitlementStatus) {
        switch status {
        case .free:
            defaults.removeObject(forKey: key)
        case .pro(let expires, let inTrial):
            var value: [String: Any] = ["pro": true, "trial": inTrial]
            if let expires { value["expires"] = expires }
            defaults.set(value, forKey: key)
        }
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - İlk ücretsiz export hakkı

/// Bir kerelik "ilk videon bizden" hakkının defteri (bkz.
/// `Entitlements.hasFirstFreeExport`).
///
/// NEDEN ABONELİK ÖNBELLEĞİNDEN AYRI: `EntitlementCache` mağazadan gelen
/// bilginin kopyasıdır ve mağaza cevabı geldiğinde ÜSTÜNE YAZILIR. Bu hak ise
/// tamamen yereldir ve tek yönlüdür — bir kez harcanınca uygulama silinene
/// kadar geri gelmez. İkisini aynı sözlükte tutmak, ilk mağaza cevabında hakkın
/// sessizce sıfırlanması (yani sonsuz filigransız export) riskini doğururdu.
public struct FirstFreeExportLedger: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard,
                key: String = "export.firstFreeUsed") {
        self.defaults = defaults
        self.key = key
    }

    /// Kayıt yokken `false` döner — yeni kurulumda hak duruyor demektir.
    public var isUsed: Bool { defaults.bool(forKey: key) }

    /// Hak tüketildi. YALNIZ export başarıyla bittiğinde çağrılmalı: render
    /// yarıda patlarsa ya da kullanıcı iptal ederse hakkını kaybetmemeli.
    public func markUsed() {
        defaults.set(true, forKey: key)
    }

    /// Testler ve demo/ekran görüntüsü akışı için (temiz kurulum taklidi).
    public func reset() {
        defaults.removeObject(forKey: key)
    }
}
