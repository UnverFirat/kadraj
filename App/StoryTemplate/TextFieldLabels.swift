import Foundation

/// Editördeki metin alanlarının başlıkları.
///
/// Şablonlar katman id'lerini kendileri belirliyor ("kicker", "spec0",
/// "drink0-price"…). Bunlar motorun sözleşmesi; kullanıcıya gösterilecek bir
/// şey değil. Eskiden editör bu id'lerin ancak yarısını tanıyordu: katalogdaki
/// 746 metin alanının 418'i (127 şablonun 92'sinde) "Metin 1", "Metin 2" diye
/// görünüyordu. `travel-checklist-01` ve `city-guide-01` gibi şablonlarda
/// alanların HEPSİ isimsizdi — kullanıcı hangi kutunun videodaki hangi yazı
/// olduğunu ancak tek tek yazıp önizleyerek buluyordu.
///
/// Başlık katman id'sini DEĞİL kullanıcının işini anlatır: "Metin 3" değil
/// "1. içeceğin fiyatı".
///
/// Tablo dışı (ör. CDN'den inen yeni bir şablonun) id'ler için sıra numarasına
/// düşülür — davranış eskisi gibi güvenli kalır, yalnız kapsam genişler.
enum TextFieldLabels {
    /// Bir şablonun TÜM metin alanlarının başlıkları (katman id → başlık).
    ///
    /// NEDEN TEK SEFERDE, ALAN ALAN DEĞİL: sıralı bir alanın kaçıncı olduğu
    /// KOMŞUSUNA bağlı. Şablonların bir kısmı sıfırdan sayıyor (`line0`), bir
    /// kısmı birden (`line1`); ham rakamı kullanmak `list-five-01`'de
    /// "Satır 2 … Satır 6" diye başlayan bir liste üretiyordu. Aynı ailenin en
    /// küçük rakamı 1 sayılır, numaralar oradan yürür.
    ///
    /// `ids` editördeki alan sırasıdır; tanınmayan bir id o sıraya göre
    /// "Metin N" olur.
    static func labels(forLayerIDs ids: [String]) -> [String: String] {
        // Tablo her çağrıda yeniden kuruluyor (dil değişince başlıklar da
        // değişmeli); döngü içinde değil, BİR KEZ.
        let exactTable = table

        var base: [String: Int] = [:]
        for id in ids {
            guard let field = numberedField(id) else { continue }
            base[field.family] = min(base[field.family] ?? field.index, field.index)
        }

        var result: [String: String] = [:]
        for (order, id) in ids.enumerated() {
            if let contextual = contextualLabel(id, among: ids) {
                result[id] = contextual
            } else if let exact = exactTable[id] {
                result[id] = exact
            } else if let field = numberedField(id),
                      let numbered = familyLabel(field.family,
                                                 number: field.index - (base[field.family] ?? 0) + 1) {
                result[id] = numbered
            } else {
                result[id] = String(localized: "Metin \(order + 1)")
            }
        }
        return result
    }

    /// Aynı id'nin iki ayrı işi anlattığı tek yer.
    ///
    /// `a-label` `qa-card-01`'de "CEVAP", `beauty-before-after-01`'de "ÖNCE"
    /// demek. Id tek başına ayırt etmeye yetmiyor; ayıran şey KOMŞUSU — soru
    /// etiketi taşıyan bir şablon soru-cevap kartıdır.
    private static func contextualLabel(_ id: String, among ids: [String]) -> String? {
        guard id == "a-label" else { return nil }
        return ids.contains("q-label")
            ? String(localized: "Cevap etiketi")
            : String(localized: "Önce etiketi")
    }

    /// "drink0-price" → (aile: "drink#-price", sıra: 0).
    ///
    /// Rakam id'nin SONUNDA da ("step0") ORTASINDA da ("drink0-price")
    /// olabiliyor; aynı fikrin iki yazımı. Rakamın yerine "#" konarak ikisi tek
    /// bir aile anahtarına iner ve tablo iki kez yazılmak zorunda kalmaz.
    private static func numberedField(_ id: String) -> (family: String, index: Int)? {
        guard let first = id.firstIndex(where: { $0.isNumber }) else { return nil }
        var end = first
        while end < id.endIndex, id[end].isNumber { end = id.index(after: end) }
        guard let index = Int(id[first..<end]) else { return nil }
        return (String(id[id.startIndex..<first]) + "#" + String(id[end...]), index)
    }

    /// Sıralı alan ailelerinin başlıkları. `number` 1 tabanlıdır.
    private static func familyLabel(_ family: String, number: Int) -> String? {
        switch family {
        // Adımlar / satırlar
        case "step#": return String(localized: "Adım \(number)")
        case "num#": return String(localized: "Adım \(number) numarası")
        case "note#": return String(localized: "\(number). adımın notu")
        case "item#", "line#": return String(localized: "Satır \(number)")
        case "pl-item#": return String(localized: "\(number). madde")
        case "tick#": return String(localized: "\(number). maddenin işareti")
        case "tip#": return String(localized: "\(number). ipucu")
        case "move#": return String(localized: "\(number). hareket")
        case "word#", "b#-word": return String(localized: "\(number). kelime")
        case "b#-step": return String(localized: "\(number). kelimenin sırası")
        case "cap#": return String(localized: "Açıklama \(number)")
        case "loc#": return String(localized: "Konum \(number)")
        case "lbl#", "lbl-#": return String(localized: "Etiket \(number)")

        // Etiket / değer çiftleri
        case "label#": return String(localized: "\(number). satırın etiketi")
        case "value#": return String(localized: "\(number). satırın değeri")
        case "clabel#": return String(localized: "\(number). özelliğin etiketi")
        case "cvalue#": return String(localized: "\(number). özelliğin değeri")
        case "spec#": return String(localized: "Özellik \(number)")
        case "strip#-label": return String(localized: "\(number). parçanın etiketi")

        // Ürün / menü kalemleri
        case "name#", "row#-name": return String(localized: "\(number). ürün adı")
        case "desc#": return String(localized: "\(number). ürün açıklaması")
        case "price#", "row#-price": return String(localized: "\(number). ürün fiyatı")
        case "drink#-name": return String(localized: "\(number). içecek adı")
        case "drink#-price": return String(localized: "\(number). içeceğin fiyatı")
        case "dur#": return String(localized: "\(number). hizmetin süresi")

        // Program / takvim
        case "day#": return String(localized: "\(number). gün")
        case "topic#": return String(localized: "\(number). günün konusu")
        case "hour#": return String(localized: "\(number). dersin saati")
        case "class#": return String(localized: "\(number). dersin adı")
        case "coach#": return String(localized: "\(number). dersin eğitmeni")
        case "time#": return String(localized: "\(number). anın saati")

        // Müzik / turne
        case "song#": return String(localized: "\(number). şarkı")
        case "len#": return String(localized: "\(number). şarkının süresi")
        case "date#": return String(localized: "\(number). konserin tarihi")
        case "city#": return String(localized: "\(number). konserin şehri")

        // Soru / şık
        case "letter#": return String(localized: "\(number). şıkkın harfi")
        case "option#": return String(localized: "\(number). şık")

        // Şehir rehberi / rota durakları
        case "c#-num": return String(localized: "\(number). durağın numarası")
        case "c#-label", "r#-tag": return String(localized: "\(number). durağın etiketi")
        case "c#-place": return String(localized: "\(number). durağın adı")
        case "c#-note": return String(localized: "\(number). durağın notu")
        case "r#-cap": return String(localized: "\(number). durağın açıklaması")

        // Oda turu
        case "r#-num": return String(localized: "\(number). odanın numarası")
        case "r#-name": return String(localized: "\(number). odanın adı")
        case "r#-note": return String(localized: "\(number). odanın notu")
        case "r#-tour": return String(localized: "\(number). odanın üst yazısı")

        // Kombin / görünüm
        case "fit#-label": return String(localized: "\(number). kombinin etiketi")
        case "fit#-name": return String(localized: "\(number). kombinin adı")
        case "fit#-price": return String(localized: "\(number). kombinin fiyatı")
        case "fit#-hint": return String(localized: "\(number). kombinin sorusu")
        case "look#-num": return String(localized: "\(number). görünümün numarası")
        case "look#-label": return String(localized: "\(number). görünümün etiketi")
        case "look#-title": return String(localized: "\(number). görünümün başlığı")
        case "dotnum#": return String(localized: "\(number). ürünün numarası")
        case "dotlabel#": return String(localized: "\(number). ürün")

        // Süs katmanları
        case "sp#": return String(localized: "Işıltı \(number)")
        case "h#": return String(localized: "Kalp \(number)")

        default: return nil
        }
    }

    /// Birebir tanınan id'ler. Derleyici tek bir dev sözlük değişmezini makul
    /// sürede tip denetleyemiyor; konu konu bölünmüş hali hem hızlı derlenir
    /// hem okunur.
    ///
    /// ÖNBELLEKLİ (2026-08-27). Bu bir hesaplanan özellikti ve her çağrıda
    /// sekiz sözlüğü sıfırdan kurup 303 `String(localized:)` çözüyordu.
    /// Çağıran `EditorView.fieldLabels` → `textPanel`, yani Metin sekmesi
    /// açıkken HER `body` geçişi — pratikte her tuş vuruşu. Yazarken hissedilen
    /// takılmanın ölçülebilir bir parçası buydu.
    ///
    /// Dil anahtarı korunuyor: `String(localized:)` çıktısı dile bağlı ve
    /// uygulama içi dil değişimi (`AppLanguage`) tabloyu geçersizleştirmeli.
    private static var tableCache: [String: [String: String]] = [:]

    private static var table: [String: String] {
        let language = AppLanguage.code
        if let cached = tableCache[language] { return cached }
        var all = headings
        for group in [identity, placeAndTime, commerce, badges, questions, scenes, stickers] {
            all.merge(group) { current, _ in current }
        }
        tableCache[language] = all
        return all
    }

    // MARK: - Başlıklar ve açıklamalar

    private static var headings: [String: String] {
        [
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
            "tagline": String(localized: "Slogan"),
            "motto": String(localized: "Motto"),
            "lyric": String(localized: "Şarkı sözü"),
            "summary": String(localized: "Özet satırı"),
            "detail": String(localized: "Ayrıntı"),
            "note": String(localized: "Not"),
            "small": String(localized: "Küçük not"),
            "info": String(localized: "İlan bilgisi"),
            "extra": String(localized: "Ek bilgi"),
            "meta": String(localized: "Liste özeti"),
            "footer": String(localized: "Alt bilgi"),
            "guide-title": String(localized: "Rehber başlığı"),
            "pl-title": String(localized: "Liste başlığı"),
            "pl-sub": String(localized: "Liste alt yazısı"),
            "pl-foot": String(localized: "Liste alt bilgisi"),
        ]
    }

    // MARK: - Kimlik

    private static var identity: [String: String] {
        [
            "handle": String(localized: "Kullanıcı adı"),
            "brand": String(localized: "Marka"),
            "logo-text": String(localized: "Marka"),
            "name": String(localized: "İsim"),
            "names": String(localized: "İsimler"),
            "author": String(localized: "Yazan"),
            "source": String(localized: "Kaynak"),
            "agent": String(localized: "Danışman"),
            "agency": String(localized: "Ofis adı"),
            "role": String(localized: "Ünvan"),
            "artist": String(localized: "Sanatçı"),
            "guest": String(localized: "Konuk"),
            "band": String(localized: "Grup adı"),
            "album": String(localized: "Albüm adı"),
            "salon": String(localized: "Salon adı"),
            "school": String(localized: "Okul ve bölüm"),
            "student": String(localized: "Öğrenci adı"),
            "pet-name": String(localized: "Evcil hayvanın adı"),
            "pet-info": String(localized: "Evcil hayvan bilgisi"),
            "look-name": String(localized: "Makyajın adı"),
            "tone-name": String(localized: "Renk tonunun adı"),
            "dish": String(localized: "Yemeğin adı"),
            "course": String(localized: "Kursun adı"),
            "topic": String(localized: "Yayının konusu"),
            "movement": String(localized: "Hareketin adı"),
            "service": String(localized: "Hizmetler"),
            "material": String(localized: "Malzeme"),
            "season": String(localized: "Sezon"),
        ]
    }

    // MARK: - Yer ve zaman

    private static var placeAndTime: [String: String] {
        [
            "location": String(localized: "Konum"),
            "loc": String(localized: "Konum"),
            "place": String(localized: "Mekân"),
            "venue": String(localized: "Mekân bilgisi"),
            "address": String(localized: "Adres"),
            "where": String(localized: "Nerede"),
            "when": String(localized: "Ne zaman"),
            "date": String(localized: "Tarih"),
            "time": String(localized: "Saat"),
            "hours": String(localized: "Çalışma saatleri"),
            "event": String(localized: "Etkinlik"),
            "episode": String(localized: "Bölüm"),
            "year": String(localized: "Yıl"),
            "age": String(localized: "Yaş"),
            "days": String(localized: "Kalan gün"),
            "start": String(localized: "Başlangıç tarihi"),
            "length": String(localized: "Süre"),
            "release": String(localized: "Çıkış tarihi"),
            "datestamp": String(localized: "Tarih damgası"),
            "timecode": String(localized: "Zaman kodu"),
            "exam": String(localized: "Sınav adı ve tarihi"),
            "sun-place": String(localized: "Yer"),
            "sun-time": String(localized: "Saat"),
            "iftar-label": String(localized: "İftar etiketi"),
            "iftar-time": String(localized: "İftar saati"),
        ]
    }

    // MARK: - Ticari

    private static var commerce: [String: String] {
        [
            "price": String(localized: "Fiyat"),
            "old-price": String(localized: "Eski fiyat"),
            "new-price": String(localized: "Yeni fiyat"),
            "old-label": String(localized: "Eski fiyat etiketi"),
            "new-label": String(localized: "Yeni fiyat etiketi"),
            "percent": String(localized: "İndirim oranı"),
            "cta": String(localized: "Eylem yazısı"),
            "cta-text": String(localized: "Eylem yazısı"),
            "listen": String(localized: "Eylem yazısı"),
            "b-cta": String(localized: "Eylem yazısı"),
            "back-cta": String(localized: "Eylem yazısı"),
            "apply": String(localized: "Başvuru bilgisi"),
            "book": String(localized: "Randevu bilgisi"),
            "rsvp": String(localized: "Davet notu"),
            "invite": String(localized: "Davet yazısı"),
            "phone": String(localized: "Telefon"),
            "code": String(localized: "Kupon kodu"),
            "valid": String(localized: "Geçerlilik"),
            "terms": String(localized: "Koşullar"),
            "limit": String(localized: "Alt sınır"),
            "seats": String(localized: "Kontenjan"),
            "ticket": String(localized: "Bilet durumu"),
            "stock": String(localized: "Stok notu"),
            "speed": String(localized: "Hız notu"),
            "eta-text": String(localized: "Teslimat süresi"),
            "number": String(localized: "Sayı"),
            "unit": String(localized: "Birim"),
            "figure": String(localized: "Büyük sayı"),
            "big": String(localized: "Büyük sayı"),
            "count": String(localized: "Adet"),
            "distance": String(localized: "Mesafe"),
            "value": String(localized: "Değer"),
            "label": String(localized: "Etiket"),
            "previous": String(localized: "Önceki rekor"),
            "time-label": String(localized: "Süre etiketi"),
            "time-value": String(localized: "Süre değeri"),
            "pace-label": String(localized: "Tempo etiketi"),
            "pace-value": String(localized: "Tempo değeri"),
        ]
    }

    // MARK: - Rozet, etiket, şerit

    private static var badges: [String: String] {
        [
            "badge": String(localized: "Rozet"),
            "badge-text": String(localized: "Rozet"),
            "badge-num": String(localized: "Rozet numarası"),
            "chip-text": String(localized: "Rozet"),
            "new-text": String(localized: "Rozet"),
            "pet-badge-text": String(localized: "Rozet"),
            "tag": String(localized: "Etiket"),
            "tag-text": String(localized: "Etiket"),
            "stamp": String(localized: "Damga"),
            "stars": String(localized: "Puan"),
            "label-top": String(localized: "Üst etiket"),
            "label-bottom": String(localized: "Alt etiket"),
            "band-text": String(localized: "Şerit yazısı"),
            "banner-text": String(localized: "Şerit yazısı"),
            "ribbon-text": String(localized: "Şerit yazısı"),
            "live": String(localized: "Yayın rozeti"),
            "rec": String(localized: "Kayıt göstergesi"),
            "reel": String(localized: "Üst yazı"),
            "roll": String(localized: "Rulo bilgisi"),
            // 4 filtre kartı: her biri kendi adını taşıyor.
            "lbl-cinematic": String(localized: "Sinematik etiketi"),
            "lbl-mono": String(localized: "Mono etiketi"),
            "lbl-vintage": String(localized: "Vintage etiketi"),
            "lbl-vivid": String(localized: "Canlı etiketi"),
        ]
    }

    // MARK: - Alıntı, soru-cevap, sözlük

    private static var questions: [String: String] {
        [
            "quote": String(localized: "Alıntı"),
            "quote-mark": String(localized: "Tırnak işareti"),
            "q-label": String(localized: "Soru etiketi"),
            "question": String(localized: "Soru"),
            "answer-text": String(localized: "Cevap"),
            "ask": String(localized: "Soru yazısı"),
            "opt-a": String(localized: "1. seçenek"),
            "opt-b": String(localized: "2. seçenek"),
            "or": String(localized: "Ayraç yazısı"),
            "word": String(localized: "Kelime"),
            "pron": String(localized: "Okunuş"),
            "def-label": String(localized: "Tanım etiketi"),
            "definition": String(localized: "Tanım"),
            "ex-label": String(localized: "Örnek etiketi"),
            "example": String(localized: "Örnek cümle"),
            "tip": String(localized: "İpucu"),
            // "sign" çoğu şablonda altına atılan imza; `neon-sign-01`'de
            // tabelanın kendisi. Dördün üçü imza olduğu için başlık odur.
            "sign": String(localized: "İmza yazısı"),
        ]
    }

    // MARK: - Sahne sahne akan şablonlar (önce/sonra, tur, kapanış)

    private static var scenes: [String: String] {
        [
            "a-note": String(localized: "Önce notu"),
            "b-label": String(localized: "Sonra etiketi"),
            "b-head": String(localized: "Sonra başlığı"),
            "then-label": String(localized: "Geçmiş etiketi"),
            "then-sub": String(localized: "Geçmiş açıklaması"),
            "now": String(localized: "Üst yazı"),
            "now-label": String(localized: "Bugün etiketi"),
            "now-sub": String(localized: "Bugün açıklaması"),
            "one-title": String(localized: "1. hafta başlığı"),
            "one-note": String(localized: "1. hafta notu"),
            "eight-title": String(localized: "8. hafta başlığı"),
            "eight-note": String(localized: "8. hafta notu"),
            "end-line": String(localized: "Kapanış yazısı"),
            "end-cta": String(localized: "Kapanış eylem yazısı"),
            "hit-title": String(localized: "Vurucu başlık"),
            "hit-sub": String(localized: "Vurucu alt yazı"),
            "show-title": String(localized: "Kampanya başlığı"),
            "show-cta": String(localized: "Kampanya eylem yazısı"),
            "show-chip-text": String(localized: "Kampanya rozeti"),
            "gone-kicker": String(localized: "Tükendi üst yazısı"),
            "gone-word": String(localized: "Tükendi yazısı"),
            "gone-note": String(localized: "Tükendi notu"),
            "back-label": String(localized: "Yeniden stokta etiketi"),
            "back-name": String(localized: "Ürün adı"),
            "back-price": String(localized: "Ürün fiyatı"),
            "door-tag": String(localized: "Giriş etiketi"),
            "door-sub": String(localized: "Giriş açıklaması"),
            "table-tag": String(localized: "Masa etiketi"),
            "table-sub": String(localized: "Masa açıklaması"),
            "plate-tag": String(localized: "Tabak etiketi"),
            "plate-sub": String(localized: "Tabak açıklaması"),
            "booth-kicker": String(localized: "Stüdyo üst yazısı"),
            "booth-title": String(localized: "Stüdyo başlığı"),
            "booth-note": String(localized: "Stüdyo notu"),
            "closing-line": String(localized: "Kapanış yazısı"),
            "closing-date": String(localized: "Kapanış tarihi"),
            "closing-handle": String(localized: "Kapanış kullanıcı adı"),
            "cov-kicker": String(localized: "Kapak üst yazısı"),
            "cov-title": String(localized: "Kapak başlığı"),
            "cov-sub": String(localized: "Kapak alt yazısı"),
            "g-title": String(localized: "Orta sahne başlığı"),
            "g-note": String(localized: "Orta sahne notu"),
            "cl-title": String(localized: "Kapanış yazısı"),
            "cl-handle": String(localized: "Kapanış kullanıcı adı"),
            // `engagement-01` sahne numarasını id'ye gömüyor ama her sahnede
            // alan bir tane: sıralı aile sayılamaz, birebir yazılır.
            "s1-word": String(localized: "1. sahnenin yazısı"),
            "s1-date": String(localized: "1. sahnenin tarihi"),
            "s2-names": String(localized: "2. sahnenin isimleri"),
            "s2-sub": String(localized: "2. sahnenin alt yazısı"),
            "sun-quote": String(localized: "Gün batımı yazısı"),
            "tb-kicker": String(localized: "Üst yazı"),
            "tb-date": String(localized: "Tarih"),
            "tb-caption": String(localized: "Açıklama"),
            "dump-kicker": String(localized: "Üst yazı"),
            "dump-title": String(localized: "Başlık"),
            "dump-foot": String(localized: "Alt bilgi"),
            "bd-kicker": String(localized: "Üst yazı"),
            "bd-title": String(localized: "Ana başlık"),
            "bd-wish": String(localized: "Dilek yazısı"),
            "md-kicker": String(localized: "Üst yazı"),
            "md-title": String(localized: "Ana başlık"),
            "md-msg": String(localized: "Mesaj"),
            "md-foot": String(localized: "Alt bilgi"),
            "ny-kicker": String(localized: "Üst yazı"),
            "ny-year": String(localized: "Yıl"),
            "ny-wish": String(localized: "Dilek yazısı"),
            "ny-sign": String(localized: "İmza"),
            "tease": String(localized: "Merak yazısı"),
        ]
    }

    // MARK: - Çıkartmalar (tek emoji taşıyan katmanlar)

    private static var stickers: [String: String] {
        [
            "sticker-heart": String(localized: "Çıkartma 1"),
            "sticker-spark": String(localized: "Çıkartma 2"),
            "sticker-party": String(localized: "Çıkartma 3"),
            "spark": String(localized: "Çıkartma"),
            "end-spark": String(localized: "Kapanış çıkartması"),
            "cake": String(localized: "Pasta çıkartması"),
            "balloon": String(localized: "Balon çıkartması"),
            "confetti": String(localized: "Konfeti çıkartması"),
            "baby": String(localized: "Bebek çıkartması"),
            "cap": String(localized: "Mezuniyet çıkartması"),
            "heart": String(localized: "Kalp çıkartması"),
            "md-heart": String(localized: "Kalp çıkartması"),
            "paw": String(localized: "Pati çıkartması"),
            "star": String(localized: "Yıldız çıkartması"),
            "headphones": String(localized: "Kulaklık çıkartması"),
            "md-flower": String(localized: "Çiçek çıkartması"),
            "md-tulip": String(localized: "Lale çıkartması"),
            "s2-ring-emoji": String(localized: "Yüzük çıkartması"),
        ]
    }
}
