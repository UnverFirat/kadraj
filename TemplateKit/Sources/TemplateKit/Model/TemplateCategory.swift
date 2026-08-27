import Foundation

/// Şablon kategorileri: galeri filtresinin kaynağı.
///
/// Kategori, şablonun ve manifest girdisinin serbest metin alanıdır (sunucu yeni
/// kategori yayınlayabilsin diye enum DEĞİL). Bu tip yalnız bilinen kategorilere
/// sıra ve lokalize etiket verir; tanımadığı kategoriyi de gösterir.
public enum TemplateCategory {

    /// Galeride görünme sırası. Listede olmayan kategoriler sona alınır.
    ///
    /// Sıra ürün kararıdır. Kategoriler ayrı ayrı duruyor çünkü katalog 100
    /// şablona çıkarken tek bir "İş" kovası yetmez oldu — esnafın aradığı şey
    /// (kuaför / spor salonu / emlak / kurs) birbirine hiç benzemiyor, hepsi
    /// aynı çipin altındayken kimse kendi şablonunu bulamıyordu.
    ///
    /// SIRA 2026-08-27'DE DEĞİŞTİ: önce kişisel kullanım. Uygulamanın son
    /// kullanıcısı kendi fotoğraf ve videosundan video çıkaran kişi, esnaf
    /// değil; eski sıra bunun tersini söylüyordu. `tools/audience-split.py`
    /// 127 şablonu saydı (kişisel 41 / işletme 62 / nötr 24) ve asıl kusurun
    /// sayı değil SIRA olduğunu gösterdi: kişisel yoğunluğu en yüksek iki
    /// bölüm — Kutlama (7/8) ve Özel Günler (6/6) — 14 bölümün 12. ve 13.
    /// sırasındaydı, kullanıcı Emlak'ı ve Tanıtım'ı geçmeden Doğum Günü'ne
    /// varamıyordu. Kişisel şablonların yalnız 21/41'i ilk yarıdaydı; şimdi
    /// 32/41'i ilk 61 kartta.
    ///
    /// İşletme kategorileri SİLİNMEDİ, sona alındı — 62 şablon duruyor ve
    /// kategori çipi tek dokunuşla oraya götürüyor (çip şeridi de bu diziyi
    /// kullanır). Esnafın maliyeti bir dokunuş; son kullanıcının kazancı
    /// kaydırmadan kendi şablonunu görmek.
    ///
    /// Üç kuşak: kişisel (sosyal, gezi, kutlama, özel günler) → herkese uyan
    /// biçim ve karma (minimal, spor, moda, yemek, eğitim, müzik) → saf
    /// işletme (tanıtım, güzellik, iş, emlak).
    public static let order = ["social", "travel", "wedding", "holiday",
                               "minimal", "fitness", "fashion", "food",
                               "education", "music",
                               "promo", "beauty", "business", "realestate"]

    private static let labels: [String: LocalizedText] = [
        "social":     LocalizedText(["en": "Social", "tr": "Sosyal"]),
        "promo":      LocalizedText(["en": "Promo", "tr": "Tanıtım"]),
        "food":       LocalizedText(["en": "Food", "tr": "Yemek"]),
        "travel":     LocalizedText(["en": "Travel", "tr": "Gezi"]),
        "business":   LocalizedText(["en": "Business", "tr": "İş"]),
        "fashion":    LocalizedText(["en": "Fashion", "tr": "Moda"]),
        "beauty":     LocalizedText(["en": "Beauty", "tr": "Güzellik"]),
        "fitness":    LocalizedText(["en": "Fitness", "tr": "Spor"]),
        "realestate": LocalizedText(["en": "Real Estate", "tr": "Emlak"]),
        "education":  LocalizedText(["en": "Education", "tr": "Eğitim"]),
        "music":      LocalizedText(["en": "Music", "tr": "Müzik"]),
        "wedding":    LocalizedText(["en": "Celebration", "tr": "Kutlama"]),
        "holiday":    LocalizedText(["en": "Holidays", "tr": "Özel Günler"]),
        "minimal":    LocalizedText(["en": "Minimal", "tr": "Minimal"])
    ]

    public static func label(_ category: String) -> LocalizedText {
        labels[category] ?? LocalizedText(["en": category.capitalized])
    }

    /// Verilen kategorileri galeri sırasına dizer (bilinmeyenler alfabetik, sonda).
    public static func sorted(_ categories: some Sequence<String>) -> [String] {
        let unique = Set(categories)
        let known = order.filter(unique.contains)
        let unknown = unique.subtracting(order).sorted()
        return known + unknown
    }
}
