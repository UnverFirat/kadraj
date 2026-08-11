import Foundation

/// Uygulamanın o anda gösterdiği dil.
///
/// İki ayrı dil sistemi var ve ikisi de bu değerle beslenir:
/// - **Arayüz metinleri**: `Localizable.xcstrings` (kaynak dil Türkçe, anahtar
///   Türkçe cümlenin kendisi). Bunu iOS otomatik çözer.
/// - **İÇERİK metinleri**: şablon adları, kategori etiketleri, müzik parça
///   adları ve şablonların varsayılan metinleri `LocalizedText` içinde
///   (`{"tr": …, "en": …}`) gelir; motor bunları dil koduyla çözer. CDN'den
///   inen bir şablonun adını da bu çözer — yani uygulama güncellemesi
///   gerekmeden yeni içerik iki dilde görünür.
///
/// Eskiden her çağrı yerinde dil kodu "tr" olarak SABİT yazılıydı: İngilizce
/// cihazlarda arayüz İngilizce, şablon içeriği Türkçe kalıyordu.
enum AppLanguage {
    /// Bundle'ın kullanıcı için seçtiği dil ("tr" / "en"). Bilinmeyen bir dilde
    /// (uygulama o dile çevrilmemişse) iOS zaten geliştirme diline düşer.
    static var code: String {
        let preferred = Bundle.main.preferredLocalizations.first ?? "tr"
        // "en-GB" → "en"
        return String(preferred.split(separator: "-").first ?? "tr")
    }

    static var isTurkish: Bool { code == "tr" }
}
