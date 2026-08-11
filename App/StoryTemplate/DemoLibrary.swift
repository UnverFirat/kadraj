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
    /// kategori adı ve etiketi, şablonun kendi varsayılan metinleri.
    ///
    /// İki dil birden taranıyor çünkü kullanıcı Türkçe arayüzde "recipe" ya da
    /// İngilizce arayüzde "tarif" yazabiliyor; ayrıca şablonun demo metinleri
    /// ("YAZ İNDİRİMİ") kullanıcının aklındaki kelimeye adından daha yakın.
    var searchTerms: [String] {
        var terms = Array(template.name.values.values)
        terms.append(template.category)
        terms += TemplateCategory.label(template.category).values.values
        terms += texts.values
        return terms
    }

    func matches(_ query: String) -> Bool {
        let needle = query.searchNormalized
        guard !needle.isEmpty else { return true }
        return searchTerms.contains { $0.searchNormalized.contains(needle) }
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
    private static func subtitle(for template: Template) -> String {
        let slots = template.mediaSlots
        let count = max(slots.count, 1)
        let seconds = Int(template.totalDuration.rounded())
        if !slots.isEmpty, slots.allSatisfy({ !$0.allowsVideo }) {
            return String(localized: "\(count) fotoğraf · \(seconds) sn",
                          comment: "Galeri kartı alt satırı: yalnız fotoğraf alan şablon")
        }
        if template.scenes?.isEmpty == false {
            return String(localized: "\(count) klip · \(seconds) sn",
                          comment: "Galeri kartı alt satırı: çok sahneli şablon")
        }
        return String(localized: "\(count) medya · \(seconds) sn",
                      comment: "Galeri kartı alt satırı: tek sahneli şablon")
    }
}
