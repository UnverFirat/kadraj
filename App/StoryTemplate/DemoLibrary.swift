import Foundation
import SwiftUI
import AVFoundation
import CoreGraphics
import TemplateKit

/// Editörün üstünde çalıştığı proje: şablon + önceden atanmış örnek medya.
struct DemoProject: Identifiable {
    let id: String
    let template: Template
    /// Editörde düzenlenebilir metin alanları (katman id -> mevcut değer).
    var texts: [String: String]
    /// slotIndex -> örnek medya (video URL veya foto).
    let videoSlots: [Int: URL]
    let photoSlots: [Int: CGImage]
    let subtitle: String
    let accentHex: String
    let isMontage: Bool
    /// Manifestten gelen rozetler (`new` / `popular`) — tamamen sunucudan.
    let tags: [String]
    /// Bu şablonun manifest girdisi — galeri posteri (`thumbs/`) buradan
    /// çözülür. Manifestsiz bir yoldan gelen proje olursa nil.
    let entry: TemplateManifest.Entry?

    /// Galeri aramasının taradığı sözcükler: şablon adı (İKİ DİLDE de),
    /// kategori adı ve etiketi, manifest etiketleri, şablonun kendi
    /// varsayılan metinleri.
    ///
    /// İki dil birden taranıyor çünkü kullanıcı Türkçe arayüzde "recipe" ya da
    /// İngilizce arayüzde "tarif" yazabiliyor; ayrıca şablonun demo metinleri
    /// ("YAZ İNDİRİMİ") kullanıcının aklındaki kelimeye adından daha yakın.
    var searchTerms: [String] {
        var terms = Array(template.name.values.values)
        terms.append(template.category)
        terms += TemplateCategory.label(template.category).values.values
        // Manifest etiketleri ("new" / "popular") okunmuyordu: rozet olarak
        // gösterdiğimiz bir bilgi aramada yok sayılıyordu.
        terms += tags
        terms += texts.values
        return terms
    }

    /// `synonyms` sorgu başına BİR kez çözülür (bkz. `TemplateSynonyms`), her
    /// şablon için yeniden hesaplanmaz.
    func matches(_ query: String, synonyms: TemplateSynonyms.Match = .init()) -> Bool {
        let needle = query.searchNormalized
        guard !needle.isEmpty else { return true }
        if searchTerms.contains(where: { $0.searchNormalized.contains(needle) }) { return true }
        return synonyms.templateIDs.contains(id)
            || synonyms.categories.contains(template.category)
    }
}

/// Kullanıcının kelimesini katalogdaki şablonlara bağlayan eş anlamlı tablosu.
///
/// NEDEN VAR: arama yalnız şablon adını, kategoriyi ve demo metinlerini
/// tarıyordu. Katalogda "Kuaför Randevu" var ama "berber" yazan kullanıcı BOŞ
/// ekran görüyordu; "restoran", "nikah", "yılbaşı", "tatil", "evcil hayvan",
/// "black friday", "diyet", "araba", "tiktok"… hepsi aynı şekilde sıfır sonuç
/// veriyordu. Ölçüm: 52 gerçekçi sorgunun 18'i sıfır sonuçluydu ve on sekizinin
/// de karşılığı katalogda vardı — yani sorun katalogda değil, sözlükte.
///
/// Tablo iki ayrı işi yapıyor:
///  1. AYNI İŞİN farklı adı (kuaför/berber, restoran/lokanta, düğün/nikah).
///     Esnaf kendi kelimesini yazar, bizim editoryal başlığımızı değil.
///  2. Katalogda KARŞILIĞI OLMAYAN meslek/konu (doktor, avukat, araba): en
///     yakın iş akışına yönlendirilir (randevu / hizmet fiyatı / müşteri
///     yorumu / ilan künyesi). Yaklaşık sonuç, boş ekrandan her zaman iyidir.
///
/// Eşleştirme `searchNormalized`'dan geçer (Türkçe ı/i + aksan katlaması), yani
/// "kuafor", "dugun", "yilbasi" de çalışır; İngilizce anahtarlar aynı tabloda.
enum TemplateSynonyms {

    /// Bir sorgunun eş anlamlı karşılığı: doğrudan şablon id'leri ve/veya
    /// kategoriler ("tatil" → tüm Gezi kategorisi).
    struct Match {
        var templateIDs: Set<String> = []
        var categories: Set<String> = []

        init() {}

        /// Tablo hedefleri: "cat:<kategori>" kategoriyi, diğerleri şablon id'sini
        /// gösterir.
        init(targets: [String]) {
            for target in targets {
                if let category = target.dropPrefix("cat:") {
                    categories.insert(category)
                } else {
                    templateIDs.insert(target)
                }
            }
        }

        mutating func formUnion(_ other: Match) {
            templateIDs.formUnion(other.templateIDs)
            categories.formUnion(other.categories)
        }
    }

    /// Sorguya karşılık gelen şablonlar. Kısa sorgularda (tek harf) tablo
    /// devre dışı: "a" yarım katalogu getirir, kullanıcı henüz ne aradığını
    /// yazmamıştır bile.
    static func matching(_ query: String) -> Match {
        let needle = query.searchNormalized
        guard needle.count >= 2 else { return Match() }
        var result = Match()
        for entry in index where entry.keyword.contains(needle) {
            result.formUnion(entry.match)
        }
        return result
    }

    /// Tablo, tek tek anahtar kelimelere açılmış ve normalleştirilmiş hâli.
    /// Bir kez kurulur; her tuş vuruşunda 300 kelime yeniden katlanmaz.
    private static let index: [(keyword: String, match: Match)] = table.flatMap {
        keywords, targets -> [(String, Match)] in
        let match = Match(targets: targets)
        return keywords.split(separator: ",").map {
            ($0.trimmingCharacters(in: .whitespaces).searchNormalized, match)
        }
    }

    /// Anahtar kelimeler (virgülle ayrık) -> şablon id'leri / "cat:<kategori>".
    ///
    /// Anahtarlar virgülle ayrılıyor çünkü "black friday", "spor salonu" gibi
    /// iki kelimelik aramalar tek bir anahtar olmak zorunda.
    private static let table: [String: [String]] = [
        // — Esnaf: kendi kelimesiyle arıyor
        "kuaför, berber, saç kesimi, saç, boya, fön, hairdresser, barber, hair, salon":
            ["salon-booking-01", "hair-color-01", "price-list-01"],
        "güzellik, bakım, cilt, spa, estetik, makyaj, tırnak, beauty, skincare, nails":
            ["cat:beauty"],
        "restoran, lokanta, kafe, cafe, restaurant, mekan, şef, chef, bistro, garson":
            ["cat:food"],
        "spor, fitness, antrenman, egzersiz, spor salonu, koşu, yoga, pilates, gym, workout":
            ["cat:fitness"],
        "emlak, konut, daire, kiralık, satılık, ilan, real estate, property, rent, listing":
            ["cat:realestate"],
        "moda, kıyafet, giyim, butik, kombin, fashion, outfit, clothing, boutique":
            ["cat:fashion"],
        "müzik, şarkı, albüm, konser, sahne, dj, music, song, album, concert, band":
            ["cat:music"],
        "okul, öğrenci, sınav, kurs, ders, eğitmen, school, student, exam, course, lesson":
            ["cat:education"],
        // Katalogda mesleğin kendi şablonu yok; işi ne ise ona yönlendiriyoruz:
        // randevu al, hizmet fiyatını duyur, müşteri yorumunu paylaş.
        "doktor, diş, dişçi, klinik, sağlık, hastane, veteriner, doctor, dentist, clinic, health":
            ["salon-booking-01", "price-list-01", "testimonial-01",
             "testimonial-quote-01", "lesson-tips-01"],
        "avukat, hukuk, danışman, muhasebe, mali müşavir, lawyer, legal, consultant, accountant":
            ["agent-card-01", "testimonial-quote-01", "testimonial-01",
             "price-list-01", "stat-card-01"],
        "fotoğrafçı, fotoğraf, portfolyo, albüm, photographer, photography, portfolio":
            ["photo-slideshow-01", "photo-dump-01", "polaroid-01", "film-strip-01",
             "grid-four-01", "mono-frame-01", "reel-collage-01"],
        "iş ilanı, eleman, personel, kariyer, hiring, job, recruiting, vacancy":
            ["team-hiring-01"],

        // — Kampanya sözlüğü: "indirim" katalogda geçiyor, "black friday" geçmiyor
        "black friday, kara cuma, sezon sonu, outlet, indirim, kampanya, promosyon, sale, discount, deal":
            ["cat:promo", "sale-rack-01", "price-drop-01", "gym-offer-01"],
        "kupon, kod, promosyon kodu, coupon, promo code, voucher":
            ["coupon-code-01"],
        "kargo, teslimat, paket servis, gönderi, shipping, delivery, takeaway":
            ["free-shipping-01", "food-delivery-01"],

        // — Özel günler
        "düğün, nikah, gelin, damat, evlilik, wedding, bride, groom, marriage":
            ["invite-card-01", "save-the-date-01", "engagement-01", "anniversary-01",
             "shapes-trio-01", "countdown-01"],
        "yılbaşı, yeni yıl, noel, new year, christmas, nye":
            ["new-year-01", "celebrate-01", "countdown-01"],
        "doğum günü, parti, kutlama, birthday, party, celebration":
            ["birthday-wish-01", "celebrate-01", "invite-card-01"],
        "bayram, ramazan, kurban, eid, ramadan":
            ["bayram-greeting-01", "ramadan-01"],

        // — Konu sözlüğü
        "tatil, otel, seyahat, gezi, turizm, vacation, hotel, trip, tour, travel":
            ["cat:travel"],
        "evcil hayvan, evcil, hayvan, köpek, kedi, pet, dog, cat, puppy, kitten":
            ["pet-star-01"],
        "anket, oylama, oy verme, poll, vote, survey, quiz":
            ["poll-card-01", "qa-card-01", "quiz-card-01"],
        "diyet, beslenme, kalori, sağlıklı yaşam, diet, nutrition, calories, healthy":
            ["nutrition-tip-01", "workout-steps-01", "challenge-01", "recipe-quick-01"],
        "teknoloji, telefon, bilgisayar, yazılım, uygulama, tech, gadget, software, app":
            ["product-01", "new-arrival-01", "restock-01", "logo-reveal-01",
             "stat-card-01", "split-screen-01"],
        // Araç ilanı emlak ilanıyla aynı iş: künye + fiyat + "satıldı".
        "araba, oto, otomobil, araç, galeri, car, auto, vehicle, dealership":
            ["product-01", "property-specs-01", "just-sold-01", "price-drop-01",
             "new-arrival-01", "split-screen-01"],
        "tatlı, pasta, kek, fırın, dessert, cake, bakery, pastry":
            ["dessert-reveal-01", "coffee-shop-01", "daily-special-01"],
        "bebek, hamile, baby, pregnancy, newborn":
            ["baby-news-01"],
        "alıntı, söz, motivasyon, quote, motivation, saying":
            ["quote-01", "bold-statement-01", "testimonial-quote-01", "lyric-card-01"],
        "logo, marka, kurumsal, branding, brand, identity":
            ["logo-reveal-01", "cover-art-01", "mono-frame-01"],

        // — Mecra adları: kullanıcı şablonu yapacağı yere göre arıyor
        "reels, reel, tiktok, story, hikâye, instagram, shorts, sosyal medya, trend, viral":
            ["cat:social"]
    ]
}

extension String {
    /// "cat:food" -> "food"; ön ek yoksa nil.
    fileprivate func dropPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}

extension String {
    /// Arama karşılaştırması için normalleştirilmiş hâl.
    ///
    /// `localizedCaseInsensitiveContains` Türkçe'de YETMİYOR, iki ayrı sebeple:
    ///
    /// 1. Türkçe kullanıcı aksanları çoğu zaman yazmaz — "sehir", "indirim",
    ///    "urun", "gecis". Diakritik katlama bunları eşler.
    /// 2. Türkçe'nin `ı`/`i` ayrımı: `ı` aksanlı bir `i` DEĞİL, ayrı bir harf;
    ///    diakritik katlaması onu `i`'ye çevirmez. Üstelik Türkçe locale'de
    ///    "I".lowercased() → "ı" olduğu için locale'e duyarlı karşılaştırma
    ///    İngilizce şablon adlarını da bozabiliyor. Bu yüzden katlama
    ///    `en_US_POSIX` ile yapılır ve `ı` elle `i`'ye eşlenir.
    var searchNormalized: String {
        let folded = folding(options: [.caseInsensitive, .diacriticInsensitive,
                                       .widthInsensitive],
                             locale: Locale(identifier: "en_US_POSIX"))
        return folded.replacingOccurrences(of: "ı", with: "i")
    }
}

/// Galeriyi besleyen kütüphane. Şablonlar `TemplateCatalog`'tan gelir:
/// önce paketle gelen seed / önbellek gösterilir, ardından CDN'den tazelenir.
///
/// Uygulamayı `--cdn <url>` ile başlatmak CDN'i etkinleştirir (geliştirmede
/// `python3 -m http.server` ile depo `templates/` klasörünü yayınlamak yeterli).
/// Argüman yoksa uygulama tamamen paketteki şablonlarla çalışır.
@MainActor
final class DemoLibrary: ObservableObject {
    enum Status: Equatable {
        case loading
        case ready(origin: TemplateCatalog.Origin, count: Int)
        case failed(String)

        /// Galeri başlığının altındaki kaynak satırı.
        var label: String {
            switch self {
            case .loading:
                return String(localized: "Şablonlar yükleniyor…")
            case .ready(let origin, let count):
                switch origin {
                case .seed:    return String(localized: "\(count) şablon · uygulama paketi")
                case .cache:   return String(localized: "\(count) şablon · önbellek (çevrimdışı)")
                case .network: return String(localized: "\(count) şablon · güncellendi")
                }
            case .failed:
                // Teknik hata metni kullanıcıya gösterilmez (dosya yolu/alan adı
                // sızdırabiliyor); ayrıntı yalnız analitikte.
                return String(localized: "Şablonlar yüklenemedi")
            }
        }
    }

    @Published private(set) var projects: [DemoProject] = []
    @Published private(set) var status: Status = .loading

    private let catalog: TemplateCatalog
    /// Galeri posterleri aynı katalogdan beslenir (CDN → cache → paket).
    let thumbnails: ThumbnailStore
    /// O an kullanılan CDN kökü (yoksa nil). Ayarlar'ın debug bölümü gösterir —
    /// yayına CDN'siz çıkmak seed dışı şablonların posterini kalıcı olarak
    /// yer tutucuya düşürür, bu yüzden görünür olmalı.
    let cdnBase: URL?

    init() {
        let cdnURL = Self.cdnBaseURL()
        cdnBase = cdnURL
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1.0"
        catalog = TemplateCatalog(baseURL: cdnURL,
                                  appVersion: version,
                                  cacheDirectory: TemplateCatalog.defaultCacheDirectory(),
                                  seedDirectory: Bundle.main.resourceURL)
        thumbnails = ThumbnailStore(catalog: catalog)
        Task { await load() }
    }

    /// Önce eldeki listeyi (önbellek/paket) gösterir, sonra CDN'den tazeler.
    /// Böylece galeri ağ beklemeden açılır ve çevrimdışında da doludur.
    func load() async {
        if let snapshot = try? await catalog.current() {
            await apply(snapshot)
        }
        do {
            let snapshot = try await catalog.refresh()
            await apply(snapshot)
        } catch TemplateCatalogError.notConfigured {
            // CDN yapılandırılmamış (paket modunda çalışıyoruz) — normal.
        } catch {
            if projects.isEmpty { status = .failed(String(describing: error)) }
        }
    }

    private func apply(_ snapshot: TemplateCatalog.Snapshot) async {
        let templates = await catalog.loadTemplates(snapshot.entries)
        let entries = Dictionary(uniqueKeysWithValues: snapshot.entries.map { ($0.id, $0) })
        // Galeri sırası = manifest sırası (sunucudan yönetilir).
        projects = templates.compactMap { makeProject($0, entry: entries[$0.id]) }
        status = .ready(origin: snapshot.origin, count: projects.count)
        Analytics.shared.log(.catalogLoaded(origin: String(describing: snapshot.origin),
                                            count: projects.count))
    }

    func project(templateID: String) -> DemoProject? {
        projects.first { $0.id == templateID }
    }

    /// Şablon CDN'inin kökü.
    ///
    /// Sıra: `--cdn <url>` başlatma bayrağı (geliştirme) → `Info.plist`
    /// `TemplateCDNBaseURL` (ürün) → nil (yalnız paket şablonları).
    ///
    /// Neden Info.plist: eskiden CDN YALNIZCA başlatma bayrağıyla açılıyordu,
    /// yani yayınlanan uygulama hiçbir zaman ağa çıkmıyordu — katalogun
    /// tamamı uygulama paketinden gelmek zorundaydı. Katalog büyüdükçe bu
    /// sürdürülebilir değil (bkz. docs/cdn-deployment.md).
    private static func cdnBaseURL() -> URL? {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--cdn"), index + 1 < arguments.count {
            return URL(string: arguments[index + 1])
        }
        guard let configured = Bundle.main.object(forInfoDictionaryKey: "TemplateCDNBaseURL")
                as? String else { return nil }
        let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    // MARK: - Şablon -> demo projesi

    /// Şablonu editörde açılabilir bir projeye çevirir.
    ///
    /// Metinler ŞABLONUN KENDİ varsayılanlarından gelir (cihazın diliyle
    /// çözülür). Eskiden burada şablon id'sine göre elle yazılmış Türkçe demo
    /// metinleri vardı: yeni şablonlar tabloda olmadığı için farklı davranıyor,
    /// İngilizce cihazda da Türkçe metin çıkıyordu. Şablonlar zaten iki dilli
    /// varsayılan taşıyor — tek kaynak o.
    private func makeProject(_ template: Template,
                             entry: TemplateManifest.Entry?) -> DemoProject? {
        let texts = template.defaultTexts(languageCode: AppLanguage.code)
        let isMontage = template.scenes?.isEmpty == false
        return DemoProject(
            id: template.id, template: template, texts: texts,
            videoSlots: [:], photoSlots: [:],
            subtitle: Self.subtitle(for: template),
            accentHex: template.palette["accent"] ?? "#D9A441",
            isMontage: isMontage,
            tags: entry?.tags ?? [], entry: entry)
    }

    /// Galeri kartının alt satırı.
    ///
    /// Eskiden burada "Montaj • 3 sahne" / "Klasik • 2 medya" yazıyordu:
    /// "montaj", "klasik" ve "sahne" bizim iç sözlüğümüz, kullanıcıya hiçbir
    /// şey söylemiyor. Kullanıcının gerçekten merak ettiği iki şey var —
    /// KAÇ görsel hazırlaması gerektiği ve videonun NE KADAR süreceği.
    ///
    /// Sonra da aynı ızgarada "5 klip", "1 medya" ve "4 fotoğraf" yan yana
    /// düştü: üç ayrı sözcük, üstelik ayrım kullanıcının umurunda olmayan bir
    /// şeye (şablonun sahneli olup olmadığına) dayanıyordu. Artık tek kural
    /// var — satır KULLANICININ NE HAZIRLAYACAĞINI söyler:
    ///   · hiç medya slotu yoksa    → "Yalnız yazı"  (17 şablon; eskiden bu
    ///     kartlar da "1 medya" diyordu, yani olmayan bir şey istiyordu)
    ///   · slotların hepsi fotoğraf → "N fotoğraf"
    ///   · video kabul eden slot var→ "N fotoğraf/video"
    private static func subtitle(for template: Template) -> String {
        let slots = template.mediaSlots
        let seconds = Int(template.totalDuration.rounded())
        guard !slots.isEmpty else {
            return String(localized: "Yalnız yazı · \(seconds) sn",
                          comment: "Galeri kartı alt satırı: medya istemeyen şablon")
        }
        if slots.contains(where: \.allowsVideo) {
            return String(localized: "\(slots.count) fotoğraf/video · \(seconds) sn",
                          comment: "Galeri kartı alt satırı: video da kabul eden şablon")
        }
        return String(localized: "\(slots.count) fotoğraf · \(seconds) sn",
                      comment: "Galeri kartı alt satırı: yalnız fotoğraf alan şablon")
    }
}
