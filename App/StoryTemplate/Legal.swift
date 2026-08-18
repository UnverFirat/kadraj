import Foundation
import TemplateKit

/// Uygulamanın kimliği ve yasal bağlantıları — TEK yerde.
///
/// App Store incelemesinin (Guideline 3.1.2) satın alma ekranında aradıkları:
/// abonelik adı, süresi, fiyatı, otomatik yenilendiği bilgisi, iptal yolu,
/// **Kullanım Koşulları (EULA) ve Gizlilik Politikası bağlantıları**. Bunlar
/// eksikse uygulama ret alır; metinleri ekranlara dağıtmak yerine burada
/// topladık ki paywall, ayarlar ve mağaza açıklaması aynı şeyi söylesin.
enum AppInfo {
    /// Kullanıcıya görünen ad. Filigran ve arayüz bunu kullanır.
    /// `CFBundleDisplayName` ile aynı kalmalı; bundle id (`com.fireflysoftware.kadraj`)
    /// ise mağazaya bağlı olduğu için marka adından bağımsız duruyor.
    static let displayName = "Kadraj"

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}

enum Legal {
    /// Kendi kullanım koşullarımız (`docs/kosullar.html`); sayfa Apple'ın
    /// standart EULA'sına da bağlanıyor, App Store Connect'te "standart EULA"
    /// seçili kalabilir. Guideline 3.1.2 satın alma ekranında bu bağlantıyı
    /// arıyor.
    static let termsURL = page("kosullar.html")

    /// Gizlilik politikası — kaynağı `docs/gizlilik.html`, GitHub Pages'ten
    /// yayınlanıyor. App Store Connect bu URL'i ayrı bir alan olarak da istiyor
    /// ve erişilemezse uygulama reddediliyor.
    /// (Kendi alan adı alınırsa üç URL birlikte değişir.)
    static let privacyPolicyURL = page("gizlilik.html")

    /// Destek sayfası — kaynağı `docs/destek.html`.
    static let supportURL = page("destek.html")


    /// Yasal sayfalar TEK dosyada iki dilli: önce Türkçe, `<hr id="english">`
    /// ayracından sonra İngilizce. İki ayrı dosya tutmuyoruz — hukuk metni
    /// çoğaltmak, zamanla iki sürümün ayrışması demek; App Store'a verilen
    /// gizlilik URL'i de tek kalsın.
    ///
    /// Türkçe olmayan cihazda `#english` çapasıyla açılır, yani kullanıcı
    /// Türkçe metni kaydırmak zorunda kalmaz. ASC'ye verilen URL çapasız
    /// halidir (her dilden okunabilir olmalı).
    private static func page(_ file: String) -> URL {
        let base = "https://unverfirat.github.io/kadraj/" + file
        return URL(string: AppLanguage.isTurkish ? base : base + "#english")!
    }

    /// Aboneliğini yöneten/iptal eden kullanıcı için sistem sayfası.
    static let manageSubscriptionsURL = URL(string:
        "https://apps.apple.com/account/subscriptions")!

    /// TODO (yayın öncesi): App Store Connect'te uygulama oluşturulunca
    /// `https://apps.apple.com/app/id<APP_ID>` ile değiştirilecek.
    /// "Arkadaşlarına öner" bu bağlantıyı paylaşır.
    static let appStoreURL = URL(string: "https://unverfirat.github.io/kadraj/")!

    /// Paylaş sayfasında bağlantının yanına giden kısa tanıtım cümlesi.
    static var shareMessage: String {
        String(localized: "\(AppInfo.displayName) ile hikâye videolarını dakikalar içinde hazırlıyorum:")
    }

    /// Abonelik ekranında gösterilecek zorunlu açıklama.
    /// Ürün bilgisi mağazadan geldiği için fiyat/süre metni de oradan türetilir.
    static func subscriptionDisclosure(for product: SubscriptionProduct?) -> String {
        guard let product else {
            return String(localized: "Abonelik dönem sonunda otomatik yenilenir. İptal etmezsen yenileme ücreti hesabına yansır; iptali istediğin an Ayarlar → Apple Kimliği → Abonelikler'den yapabilirsin.")
        }
        let period = product.plan == .monthly
            ? String(localized: "ay") : String(localized: "yıl")
        let trial = product.trialDays > 0
            ? String(localized: "\(product.trialDays) günlük ücretsiz deneme sonunda ")
            : ""
        return String(localized: "\(trial)\(product.priceText) / \(period). Abonelik, dönem bitiminden en az 24 saat önce iptal edilmezse otomatik yenilenir ve ücret Apple hesabına yansır. İptal: Ayarlar → Apple Kimliği → Abonelikler.")
    }
}
