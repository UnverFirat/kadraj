import Foundation

// MARK: - Ağ soyutlaması

public enum FetchOutcome: Sendable {
    case notModified
    case data(Data, etag: String?)
}

/// Katalogun ağ ihtiyacı. Testler (ve çevrimdışı senaryolar) bunu taklit eder;
/// üretimde `URLSessionFetcher` kullanılır.
public protocol TemplateFetching: Sendable {
    func fetch(_ url: URL, etag: String?) async throws -> FetchOutcome
}

public struct URLSessionFetcher: TemplateFetching {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(_ url: URL, etag: String?) async throws -> FetchOutcome {
        // file:// URL'lerde (paket içi "CDN" simülasyonu, testler) HTTP başlığı
        // yok; doğrudan oku.
        guard url.isFileURL == false else {
            return .data(try Data(contentsOf: url), etag: nil)
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return .data(data, etag: nil) }
        if http.statusCode == 304 { return .notModified }
        guard (200..<300).contains(http.statusCode) else {
            throw TemplateCatalogError.httpStatus(http.statusCode)
        }
        return .data(data, etag: http.value(forHTTPHeaderField: "ETag"))
    }
}

public enum TemplateCatalogError: Error, Equatable {
    case noManifestAvailable
    case httpStatus(Int)
    case templateUnavailable(String)
    case notConfigured
}

// MARK: - Katalog

/// Şablon kataloğu: manifest indirme, disk cache, sürümleme, çevrimdışı geri
/// düşüş. Galeri bu katmandan beslenir.
///
/// Öncelik sırası (hep bu sırada):
///   1. cache (indirilmiş manifest/şablon)  → uygulama anında açılır,
///   2. seed (uygulamayla gelen şablonlar)  → ilk açılış/çevrimdışı,
///   3. ağ (refresh)                        → arka planda tazeler.
///
/// İndirilen her şablon `TemplateValidator`'dan geçmeden cache'e YAZILMAZ —
/// bozuk bir yayın kullanıcıyı kilitlemesin.
public actor TemplateCatalog {

    /// Listenin nereden geldiği (galeri "çevrimdışı" rozetini buradan basar).
    public enum Origin: Sendable, Equatable {
        case seed, cache, network
    }

    public struct Snapshot: Sendable, Equatable {
        public var entries: [TemplateManifest.Entry]
        public var origin: Origin
    }

    private let baseURL: URL?
    private let appVersion: String
    private let cacheDirectory: URL
    /// Uygulamayla gelen şablonların bulunduğu klasör (ilk açılış / çevrimdışı).
    private let seedDirectory: URL?
    private let fetcher: TemplateFetching
    private let fileManager = FileManager.default

    public init(baseURL: URL?,
                appVersion: String,
                cacheDirectory: URL,
                seedDirectory: URL?,
                fetcher: TemplateFetching = URLSessionFetcher()) {
        self.baseURL = baseURL
        self.appVersion = appVersion
        self.cacheDirectory = cacheDirectory
        self.seedDirectory = seedDirectory
        self.fetcher = fetcher
    }

    // MARK: Manifest

    /// Ağa çıkmadan elde olan liste: cache ile seed'in YENİ olanı.
    ///
    /// Sıra körlemesine "cache → seed" DEĞİLDİR. Uygulama güncellendiğinde yeni
    /// şablonlar paketle (seed) gelir, ama diskte eski bir CDN indirmesi
    /// duruyorsa o eskisi kazanıyordu: mevcut kullanıcı, paket 127 şablon
    /// içerirken galeride 100 görüyordu ve eksik şablonlar aramada da derin
    /// bağlantıda da "bulunamadı" veriyordu (CDN yapılandırılmamışsa kalıcı
    /// olarak). Karar `revision`'a bakar; eşitlikte cache kazanır (CDN son
    /// sözü söyler).
    public func current() throws -> Snapshot {
        let cached = loadManifest(at: manifestCacheURL)
        let seeded = seedManifest()
        if let cached {
            if let seeded, seeded.revision > cached.revision {
                return Snapshot(entries: seeded.entries(forAppVersion: appVersion), origin: .seed)
            }
            return Snapshot(entries: cached.entries(forAppVersion: appVersion), origin: .cache)
        }
        if let seeded {
            return Snapshot(entries: seeded.entries(forAppVersion: appVersion), origin: .seed)
        }
        throw TemplateCatalogError.noManifestAvailable
    }

    /// Manifesti sunucudan tazeler. Ağ yoksa/hata varsa ÇAĞIRAN karar verir —
    /// `current()` ile eldeki listeye düşebilir.
    @discardableResult
    public func refresh() async throws -> Snapshot {
        guard let baseURL else { throw TemplateCatalogError.notConfigured }
        let url = baseURL.appendingPathComponent("manifest.json")
        switch try await fetcher.fetch(url, etag: storedETag()) {
        case .notModified:
            // Sunucu "değişmedi" dedi: cache zaten güncel.
            return try current()
        case .data(let data, let etag):
            let manifest = try JSONDecoder().decode(TemplateManifest.self, from: data)
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try data.write(to: manifestCacheURL, options: .atomic)
            if let etag { try? Data(etag.utf8).write(to: etagCacheURL, options: .atomic) }
            pruneCachedTemplates(keeping: manifest)
            // Sunucudaki yayın paketten ESKİYSE (CDN henüz güncellenmedi) taze
            // indirme de seed'i ezmemeli — `current()` ile aynı kural.
            if let seeded = seedManifest(), seeded.revision > manifest.revision {
                return Snapshot(entries: seeded.entries(forAppVersion: appVersion), origin: .seed)
            }
            return Snapshot(entries: manifest.entries(forAppVersion: appVersion), origin: .network)
        }
    }

    // MARK: Şablon

    /// Şablonu getirir: cache → (yoksa) indir + doğrula + cache'le → (o da
    /// olmazsa) seed. Sürüm artmışsa cache anahtarı değiştiği için otomatik
    /// yeniden indirilir.
    public func template(for entry: TemplateManifest.Entry) async throws -> Template {
        let cached = templateCacheURL(for: entry)
        if let template = decodeValidated(at: cached) { return template }

        if let baseURL {
            let url = baseURL.appendingPathComponent(entry.templatePath)
            if case .data(let data, _) = try? await fetcher.fetch(url, etag: nil),
               let template = decodeValidated(data: data) {
                try? fileManager.createDirectory(at: cached.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
                try? data.write(to: cached, options: .atomic)
                return template
            }
        }

        if let seedDirectory {
            let candidates = [seedDirectory.appendingPathComponent(entry.templatePath),
                              seedDirectory.appendingPathComponent("\(entry.id).json")]
            for candidate in candidates {
                if let template = decodeValidated(at: candidate) { return template }
            }
        }
        throw TemplateCatalogError.templateUnavailable(entry.id)
    }

    /// Listedeki tüm şablonları sırayla yükler; açılamayan şablon (bozuk yayın,
    /// eksik dosya) sessizce atlanır — galeri yine de açılır.
    public func loadTemplates(_ entries: [TemplateManifest.Entry]) async -> [Template] {
        var result: [Template] = []
        for entry in entries {
            if let template = try? await template(for: entry) { result.append(template) }
        }
        return result
    }

    // MARK: Galeri posteri

    /// Şablonun poster görselini (jpg/png) getirir: cache → indir + cache →
    /// seed (uygulamayla gelen). Şablonun kendisiyle AYNI öncelik sırası,
    /// aynı `id-vN` sürümlemesi.
    ///
    /// Bulunamazsa `nil` döner — galeri o kartı şablonun katmanlarından çizen
    /// `TemplatePreview`'a düşürür, yani eksik poster hiçbir zaman boş kart
    /// göstermez.
    /// - Parameter languageCode: poster şablonun METİNLERİNİ gösterdiği için
    ///   dile bağlıdır. Kaynak dilin (tr) posteri `thumbs/<id>.jpg`, diğer
    ///   diller `thumbs/<dil>/<id>.jpg`. İstenen dilin posteri yoksa sessizce
    ///   kaynak dile düşülür — yeni bir dil eklendiğinde varlıklar
    ///   üretilene kadar galeri boş kalmasın.
    public func thumbnail(for entry: TemplateManifest.Entry,
                          languageCode: String? = nil) async -> Data? {
        for path in Self.thumbnailPaths(for: entry, languageCode: languageCode) {
            if let data = await thumbnail(at: path, entry: entry) { return data }
        }
        return nil
    }

    private func thumbnail(at path: String, entry: TemplateManifest.Entry) async -> Data? {
        let cached = thumbnailCacheURL(for: entry, path: path)
        if let data = try? Data(contentsOf: cached), Self.isImage(data) { return data }

        if let baseURL {
            let url = baseURL.appendingPathComponent(path)
            if case .data(let data, _) = try? await fetcher.fetch(url, etag: nil),
               // Doğrulamadan geçmeyen indirme CACHE'LENMEZ: sunucu 404
               // yerine HTML dönerse onu poster diye saklamayalım.
               Self.isImage(data) {
                try? fileManager.createDirectory(at: cached.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
                try? data.write(to: cached, options: .atomic)
                return data
            }
        }

        if let seedDirectory,
           let data = try? Data(contentsOf: seedDirectory.appendingPathComponent(path)),
           Self.isImage(data) {
            return data
        }
        return nil
    }

    /// Denenecek poster yolları, sırayla: istenen dil → kaynak dil.
    static func thumbnailPaths(for entry: TemplateManifest.Entry,
                               languageCode: String?) -> [String] {
        let base = entry.thumbnailPath
        guard let languageCode, languageCode != sourceLanguage else { return [base] }
        let directory = (base as NSString).deletingLastPathComponent
        let file = (base as NSString).lastPathComponent
        let localized = directory.isEmpty ? "\(languageCode)/\(file)"
                                          : "\(directory)/\(languageCode)/\(file)"
        return [localized, base]
    }

    /// Şablon metinlerinin yazıldığı dil (varlık klasörünün kökü).
    public static let sourceLanguage = "tr"

    /// Sihirli baytlardan görsel kontrolü (JPEG / PNG). Görsel kodlayıcı
    /// çağırmadan, platformdan bağımsız — model katmanı saf Foundation kalır.
    static func isImage(_ data: Data) -> Bool {
        if data.count < 8 { return false }
        let bytes = [UInt8](data.prefix(8))
        let jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF
        let png = Array(bytes[0..<8]) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        return jpeg || png
    }

    // MARK: - Cache yardımcıları

    private var manifestCacheURL: URL { cacheDirectory.appendingPathComponent("manifest.json") }
    private var etagCacheURL: URL { cacheDirectory.appendingPathComponent("manifest.etag") }

    private func templateCacheURL(for entry: TemplateManifest.Entry) -> URL {
        cacheDirectory.appendingPathComponent("templates/\(entry.cacheKey).json")
    }

    /// Cache anahtarı hem sürümü hem DİLİ taşır: aynı şablonun Türkçe ve
    /// İngilizce posteri birbirini ezmemeli.
    private func thumbnailCacheURL(for entry: TemplateManifest.Entry, path: String) -> URL {
        // Uzantı manifestteki yoldan gelsin (png poster de yayınlanabilir).
        let ext = (entry.thumbnailPath as NSString).pathExtension
        let directory = (path as NSString).deletingLastPathComponent
        let language = (directory as NSString).lastPathComponent
        let suffix = (language.isEmpty || language == "thumbs") ? "" : "-\(language)"
        return cacheDirectory.appendingPathComponent(
            "thumbs/\(entry.cacheKey)\(suffix).\(ext.isEmpty ? "jpg" : ext)")
    }

    private func storedETag() -> String? {
        guard fileManager.fileExists(atPath: manifestCacheURL.path),
              let data = try? Data(contentsOf: etagCacheURL) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Uygulamayla gelen manifest (yoksa nil).
    private func seedManifest() -> TemplateManifest? {
        guard let seedDirectory else { return nil }
        return loadManifest(at: seedDirectory.appendingPathComponent("manifest.json"))
    }

    private func loadManifest(at url: URL) -> TemplateManifest? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TemplateManifest.self, from: data)
    }

    private func decodeValidated(at url: URL) -> Template? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decodeValidated(data: data)
    }

    private func decodeValidated(data: Data) -> Template? {
        guard let template = try? JSONDecoder().decode(Template.self, from: data),
              (try? TemplateValidator.validate(template)) != nil else { return nil }
        return template
    }

    /// Manifestte artık olmayan (ya da sürümü geçmiş) şablon ve poster
    /// dosyalarını siler — ikisi de aynı `id-vN` anahtarını kullanır.
    private func pruneCachedTemplates(keeping manifest: TemplateManifest) {
        let valid = Set(manifest.templates.map(\.cacheKey))
        for name in ["templates", "thumbs"] {
            let directory = cacheDirectory.appendingPathComponent(name)
            guard let files = try? fileManager.contentsOfDirectory(at: directory,
                                                                   includingPropertiesForKeys: nil)
            else { continue }
            for file in files {
                // Poster dosyaları dil ekiyle bitebilir ("quote-01-v2-en.jpg");
                // geçerlilik kararı ŞABLON anahtarına göre verilir, yoksa her
                // yenilemede İngilizce posterler siliniyordu.
                let name = file.deletingPathExtension().lastPathComponent
                let matches = valid.contains { name == $0 || name.hasPrefix("\($0)-") }
                if !matches { try? fileManager.removeItem(at: file) }
            }
        }
    }

    /// Uygulamanın varsayılan şablon cache dizini.
    public static func defaultCacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("templates", isDirectory: true)
    }
}
