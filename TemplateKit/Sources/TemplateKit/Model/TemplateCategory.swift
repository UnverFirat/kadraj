import Foundation

/// Şablon kategorileri: galeri filtresinin kaynağı.
///
/// Kategori, şablonun ve manifest girdisinin serbest metin alanıdır (sunucu yeni
/// kategori yayınlayabilsin diye enum DEĞİL). Bu tip yalnız bilinen kategorilere
/// sıra ve lokalize etiket verir; tanımadığı kategoriyi de gösterir.
public enum TemplateCategory {

    /// Galeride görünme sırası. Listede olmayan kategoriler sona alınır.
    ///
    /// Sıra ürün kararıdır: en çok kullanılan işler önde. Katalog 100 şablona
    /// çıkarken tek bir "İş" kovası yetmez oldu — esnafın aradığı şey
    /// (kuaför / spor salonu / emlak / kurs) birbirine hiç benzemiyor, hepsi
    /// aynı çipin altındayken kimse kendi şablonunu bulamıyordu.
    public static let order = ["social", "promo", "food", "travel", "business",
                               "fashion", "beauty", "fitness", "realestate",
                               "education", "music", "wedding", "holiday",
                               "minimal"]

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
