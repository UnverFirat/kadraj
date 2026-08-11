import Foundation

/// Editördeki metin alanlarının başlıkları.
///
/// Şablonlar katman id'lerini kendileri belirliyor ("kicker", "spec0",
/// "old-price"…). Bunlar motorun sözleşmesi; kullanıcıya gösterilecek bir şey
/// değil. Eskiden editör yalnız dört id tanıyor, geri kalan HER alana
/// "Metin 1", "Metin 2" diyordu — 29 şablonun çoğunda kullanıcı hangi kutunun
/// videodaki hangi yazı olduğunu ancak deneyerek buluyordu.
///
/// Burada yaygın id'ler tek bir tabloda toplanır. Tablo dışı (ör. CDN'den inen
/// yeni bir şablonun) id'ler için sıra numarasına düşülür — davranış eskisi
/// gibi güvenli kalır, yalnız kapsam genişler.
enum TextFieldLabels {
    static func label(forLayerID id: String, fallbackIndex: Int) -> String {
        if let exact = table[id] { return exact }
        if let numbered = numberedLabel(for: id) { return numbered }
        return String(localized: "Metin \(fallbackIndex + 1)")
    }

    /// "step0", "item3", "name1" gibi sıralı alanlar: kök + 1 tabanlı sıra.
    private static func numberedLabel(for id: String) -> String? {
        guard let last = id.last, let index = Int(String(last)) else { return nil }
        let root = String(id.dropLast())
        switch root {
        case "step": return String(localized: "Adım \(index + 1)")
        case "num": return String(localized: "Adım \(index + 1) numarası")
        case "item", "l", "line", "word": return String(localized: "Satır \(index + 1)")
        case "spec": return String(localized: "Özellik \(index + 1)")
        case "name": return String(localized: "\(index + 1). ürün adı")
        case "desc": return String(localized: "\(index + 1). ürün açıklaması")
        case "price": return String(localized: "\(index + 1). ürün fiyatı")
        case "cap": return String(localized: "Açıklama \(index + 1)")
        case "loc": return String(localized: "Konum \(index + 1)")
        case "lbl-", "lbl": return String(localized: "Etiket \(index + 1)")
        default: return nil
        }
    }

    private static var table: [String: String] {
        [
            // Başlıklar
            "headline": String(localized: "Ana başlık"),
            "title": String(localized: "Ana başlık"),
            "intro-title": String(localized: "Giriş başlığı"),
            "hook-title": String(localized: "Giriş başlığı"),
            "endtitle": String(localized: "Kapanış başlığı"),
            "outro-title": String(localized: "Kapanış başlığı"),
            "kicker": String(localized: "Üst yazı"),
            "subtitle": String(localized: "Alt yazı"),
            "sub": String(localized: "Alt yazı"),
            "endtext": String(localized: "Kapanış yazısı"),
            "caption": String(localized: "Açıklama"),
            "desc": String(localized: "Açıklama"),

            // Kimlik
            "handle": String(localized: "Kullanıcı adı"),
            "brand": String(localized: "Marka"),
            "logo-text": String(localized: "Marka"),
            "name": String(localized: "İsim"),
            "names": String(localized: "İsimler"),
            "author": String(localized: "Yazan"),
            "source": String(localized: "Kaynak"),
            "agent": String(localized: "Danışman"),
            "role": String(localized: "Ünvan"),
            "artist": String(localized: "Sanatçı"),
            "guest": String(localized: "Konuk"),

            // Yer / zaman
            "location": String(localized: "Konum"),
            "place": String(localized: "Mekân"),
            "date": String(localized: "Tarih"),
            "time": String(localized: "Saat"),
            "event": String(localized: "Etkinlik"),
            "episode": String(localized: "Bölüm"),

            // Ticari
            "price": String(localized: "Fiyat"),
            "old-price": String(localized: "Eski fiyat"),
            "new-price": String(localized: "Yeni fiyat"),
            "cta": String(localized: "Eylem yazısı"),
            "cta-text": String(localized: "Eylem yazısı"),
            "listen": String(localized: "Eylem yazısı"),
            "rsvp": String(localized: "Davet notu"),
            "number": String(localized: "Sayı"),
            "unit": String(localized: "Birim"),
            "footer": String(localized: "Alt bilgi"),

            // Rozet / etiket
            "badge": String(localized: "Rozet"),
            "badge-text": String(localized: "Rozet"),
            "tag": String(localized: "Etiket"),
            "stamp": String(localized: "Damga"),
            "new-text": String(localized: "Rozet"),
            "stars": String(localized: "Puan"),
            "label-top": String(localized: "Üst etiket"),
            "label-bottom": String(localized: "Alt etiket"),

            // Alıntı
            "quote": String(localized: "Alıntı"),
            "quote-mark": String(localized: "Tırnak işareti"),

            // Çıkartmalar
            "sticker-heart": String(localized: "Çıkartma 1"),
            "sticker-spark": String(localized: "Çıkartma 2"),
            "sticker-party": String(localized: "Çıkartma 3"),
            "now": String(localized: "Üst yazı")
        ]
    }
}
