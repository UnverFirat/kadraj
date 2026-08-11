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
