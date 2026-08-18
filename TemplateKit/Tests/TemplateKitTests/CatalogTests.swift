import XCTest
@testable import TemplateKit

/// Ağı taklit eder: dosya sisteminden okur, çağrıları sayar, istenirse hata
/// (çevrimdışı) veya 304 döner.
private final class StubFetcher: TemplateFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [URL] = []
    var calls: [URL] { lock.lock(); defer { lock.unlock() }; return _calls }

    var offline = false
    var etagToReturn: String?
    var respondNotModified = false

    func fetch(_ url: URL, etag: String?) async throws -> FetchOutcome {
        lock.lock(); _calls.append(url); lock.unlock()
        if offline { throw URLError(.notConnectedToInternet) }
        if respondNotModified, etag != nil { return .notModified }
        return .data(try Data(contentsOf: url), etag: etagToReturn)
    }

    func callCount(containing fragment: String) -> Int {
        calls.filter { $0.lastPathComponent.contains(fragment) }.count
    }
}

final class TemplateCatalogTests: XCTestCase {

    private var root: URL!
    private var remote: URL!     // "CDN"
    private var cache: URL!
    private var seed: URL!

    private var repoTemplates: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("templates")
    }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("catalog-test-\(UUID().uuidString)")
        remote = root.appendingPathComponent("remote")
        cache = root.appendingPathComponent("cache")
        seed = root.appendingPathComponent("seed")
        for directory in [remote, cache, seed] {
            try FileManager.default.createDirectory(at: directory!, withIntermediateDirectories: true)
        }
        // "CDN" içeriği: gerçek depo şablonlarından ikisi.
        for id in ["minimal-fade-01", "reel-collage-01"] {
            try FileManager.default.copyItem(
                at: repoTemplates.appendingPathComponent("\(id).json"),
                to: remote.appendingPathComponent("\(id).json"))
        }
        // Seed (uygulamayla gelen) yalnız birini taşır.
        try FileManager.default.copyItem(
            at: repoTemplates.appendingPathComponent("minimal-fade-01.json"),
            to: seed.appendingPathComponent("minimal-fade-01.json"))
        try writeManifest(at: seed, entries: [entry(id: "minimal-fade-01", version: 1)])
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: Yardımcılar

    private func entry(id: String, version: Int,
                       minAppVersion: String = "1.0.0") -> TemplateManifest.Entry {
        TemplateManifest.Entry(id: id, version: version, category: "minimal",
                               minAppVersion: minAppVersion, template: "\(id).json",
                               name: LocalizedText(["en": id]))
    }

    private func writeManifest(at directory: URL, entries: [TemplateManifest.Entry],
                               revision: Int = 0) throws {
        let data = try JSONEncoder().encode(TemplateManifest(revision: revision,
                                                             templates: entries))
        try data.write(to: directory.appendingPathComponent("manifest.json"))
    }

    private func makeCatalog(fetcher: TemplateFetching,
                             appVersion: String = "1.0.0",
                             withSeed: Bool = true) -> TemplateCatalog {
        TemplateCatalog(baseURL: remote, appVersion: appVersion,
                        cacheDirectory: cache, seedDirectory: withSeed ? seed : nil,
                        fetcher: fetcher)
    }

    // MARK: Testler

    func testRefreshCachesManifestAndFiltersByAppVersion() async throws {
        try writeManifest(at: remote, entries: [
            entry(id: "minimal-fade-01", version: 1),
            entry(id: "reel-collage-01", version: 1, minAppVersion: "2.0.0")
        ])
        let fetcher = StubFetcher()
        let catalog = makeCatalog(fetcher: fetcher)

        let snapshot = try await catalog.refresh()
        XCTAssertEqual(snapshot.origin, .network)
        XCTAssertEqual(snapshot.entries.map(\.id), ["minimal-fade-01"],
                       "minAppVersion 2.0.0 olan şablon 1.0.0 uygulamada görünmemeli")

        // Manifest diske yazıldı → ağsız da aynı liste.
        let cached = try await catalog.current()
        XCTAssertEqual(cached.origin, .cache)
        XCTAssertEqual(cached.entries.map(\.id), ["minimal-fade-01"])
    }

    func testNewerAppSeesGatedTemplate() async throws {
        try writeManifest(at: remote, entries: [
            entry(id: "reel-collage-01", version: 1, minAppVersion: "1.2.0")
        ])
        let catalog = makeCatalog(fetcher: StubFetcher(), appVersion: "1.10.0")
        let snapshot = try await catalog.refresh()
        XCTAssertEqual(snapshot.entries.count, 1, "1.10.0 > 1.2.0 olmalı (metinsel değil sayısal)")
    }

    func testTemplateDownloadIsCachedAndReusedUntilVersionBump() async throws {
        try writeManifest(at: remote, entries: [entry(id: "reel-collage-01", version: 1)])
        let fetcher = StubFetcher()
        let catalog = makeCatalog(fetcher: fetcher)
        let entries = try await catalog.refresh().entries

        let first = try await catalog.template(for: entries[0])
        XCTAssertEqual(first.id, "reel-collage-01")
        XCTAssertEqual(fetcher.callCount(containing: "reel-collage"), 1)

        _ = try await catalog.template(for: entries[0])
        XCTAssertEqual(fetcher.callCount(containing: "reel-collage"), 1, "cache'ten okunmalı")

        // Sürüm artışı = yeni cache anahtarı = yeniden indirme.
        _ = try await catalog.template(for: entry(id: "reel-collage-01", version: 2))
        XCTAssertEqual(fetcher.callCount(containing: "reel-collage"), 2)
    }

    func testStaleCacheFilesArePrunedOnRefresh() async throws {
        try writeManifest(at: remote, entries: [entry(id: "reel-collage-01", version: 1)])
        let fetcher = StubFetcher()
        let catalog = makeCatalog(fetcher: fetcher)
        _ = try await catalog.template(for: try await catalog.refresh().entries[0])
        let cachedFile = cache.appendingPathComponent("templates/reel-collage-01-v1.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cachedFile.path))

        // Sunucu v2 yayınladı → v1 dosyası temizlenmeli.
        try writeManifest(at: remote, entries: [entry(id: "reel-collage-01", version: 2)])
        _ = try await catalog.refresh()
        XCTAssertFalse(FileManager.default.fileExists(atPath: cachedFile.path))
    }

    func testOfflineFallsBackToCacheThenSeed() async throws {
        try writeManifest(at: remote, entries: [entry(id: "minimal-fade-01", version: 1),
                                                entry(id: "reel-collage-01", version: 1)])
        let fetcher = StubFetcher()
        let catalog = makeCatalog(fetcher: fetcher)
        _ = try await catalog.refresh()

        // Ağ gitti: refresh patlar ama eldeki liste (cache) durur.
        fetcher.offline = true
        do {
            _ = try await catalog.refresh()
            XCTFail("çevrimdışıyken refresh hata vermeli")
        } catch {}
        let cached = try await catalog.current()
        XCTAssertEqual(cached.origin, .cache)
        XCTAssertEqual(cached.entries.count, 2)

        // Cache de yoksa uygulamayla gelen şablonlara (seed) düş.
        try FileManager.default.removeItem(at: cache)
        let fresh = makeCatalog(fetcher: fetcher)
        let seeded = try await fresh.current()
        XCTAssertEqual(seeded.origin, .seed)
        XCTAssertEqual(seeded.entries.map(\.id), ["minimal-fade-01"])

        // Seed şablonu ağsız da açılabilmeli.
        let template = try await fresh.template(for: seeded.entries[0])
        XCTAssertEqual(template.id, "minimal-fade-01")
    }

    // MARK: Cache mi seed mi (yayın numarası)

    /// Uygulama güncellendi: paket yeni şablonlar taşıyor ama diskte eski bir
    /// CDN indirmesi var. Sessiz ama ürünü bozan hata buydu — eski indirme
    /// kazanıyor, kullanıcı yeni şablonları HİÇ görmüyordu.
    func testNewerSeedBeatsStaleCachedManifest() async throws {
        try writeManifest(at: remote, entries: [entry(id: "minimal-fade-01", version: 1)],
                          revision: 1)
        let fetcher = StubFetcher()
        _ = try await makeCatalog(fetcher: fetcher).refresh()   // cache'i doldur

        // "Uygulama güncellendi": seed daha yeni bir yayın ve iki şablon taşıyor.
        try FileManager.default.copyItem(
            at: repoTemplates.appendingPathComponent("reel-collage-01.json"),
            to: seed.appendingPathComponent("reel-collage-01.json"))
        try writeManifest(at: seed, entries: [entry(id: "minimal-fade-01", version: 1),
                                              entry(id: "reel-collage-01", version: 1)],
                          revision: 2)

        fetcher.offline = true
        let snapshot = try await makeCatalog(fetcher: fetcher).current()
        XCTAssertEqual(snapshot.origin, .seed, "yeni paket bayat cache'i yenmeli")
        XCTAssertEqual(snapshot.entries.map(\.id), ["minimal-fade-01", "reel-collage-01"])
    }

    /// Alanı hiç tanımayan eski bir indirme (revision yok → 0) de seed'e kaybeder.
    func testCachedManifestWithoutRevisionLosesToSeed() async throws {
        let legacy = """
        {"manifestVersion": 1, "templates": [
          {"id": "minimal-fade-01", "version": 1, "category": "minimal",
           "template": "minimal-fade-01.json", "name": {"en": "eski"}}]}
        """
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data(legacy.utf8).write(to: cache.appendingPathComponent("manifest.json"))
        try writeManifest(at: seed, entries: [entry(id: "minimal-fade-01", version: 1),
                                              entry(id: "reel-collage-01", version: 1)],
                          revision: 1)

        let snapshot = try await makeCatalog(fetcher: StubFetcher()).current()
        XCTAssertEqual(snapshot.origin, .seed)
        XCTAssertEqual(snapshot.entries.count, 2)
    }

    /// CDN yayını paketten yeniyse (normal durum) cache kazanır — düzeltme
    /// katalogun sunucudan yönetilmesini bozmamalı.
    func testCachedManifestWinsWhenItIsTheNewerRelease() async throws {
        try writeManifest(at: seed, entries: [entry(id: "minimal-fade-01", version: 1)],
                          revision: 2)
        try writeManifest(at: remote, entries: [entry(id: "minimal-fade-01", version: 1),
                                                entry(id: "reel-collage-01", version: 1)],
                          revision: 3)
        let fetcher = StubFetcher()
        _ = try await makeCatalog(fetcher: fetcher).refresh()

        fetcher.offline = true
        let snapshot = try await makeCatalog(fetcher: fetcher).current()
        XCTAssertEqual(snapshot.origin, .cache)
        XCTAssertEqual(snapshot.entries.count, 2)
    }

    /// CDN geride kaldıysa taze indirme de seed'i ezmemeli.
    func testRefreshFallsBackToSeedWhenServerIsBehind() async throws {
        try writeManifest(at: remote, entries: [entry(id: "minimal-fade-01", version: 1)],
                          revision: 1)
        try FileManager.default.copyItem(
            at: repoTemplates.appendingPathComponent("reel-collage-01.json"),
            to: seed.appendingPathComponent("reel-collage-01.json"))
        try writeManifest(at: seed, entries: [entry(id: "minimal-fade-01", version: 1),
                                              entry(id: "reel-collage-01", version: 1)],
                          revision: 5)

        let snapshot = try await makeCatalog(fetcher: StubFetcher()).refresh()
        XCTAssertEqual(snapshot.origin, .seed)
        XCTAssertEqual(snapshot.entries.count, 2)
    }

    /// Depodaki manifest yayın numarası taşımalı — `make-manifest.py`
    /// çalıştırılmayı unutulursa güncelleyen kullanıcı yeni şablonları görmez.
    func testRepoManifestCarriesARevision() throws {
        let data = try Data(contentsOf: repoTemplates.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(TemplateManifest.self, from: data)
        XCTAssertGreaterThan(manifest.revision, 0,
                             "manifest `revision` taşımalı — `python3 tools/make-manifest.py`")
    }

    func testNotModifiedKeepsCachedList() async throws {
        try writeManifest(at: remote, entries: [entry(id: "minimal-fade-01", version: 1)])
        let fetcher = StubFetcher()
        fetcher.etagToReturn = "\"abc123\""
        let catalog = makeCatalog(fetcher: fetcher)
        _ = try await catalog.refresh()

        fetcher.respondNotModified = true
        let snapshot = try await catalog.refresh()
        XCTAssertEqual(snapshot.origin, .cache, "304'te cache listesi korunmalı")
        XCTAssertEqual(snapshot.entries.count, 1)
    }

    func testCorruptDownloadIsRejectedAndSeedWins() async throws {
        // Sunucu bozuk (validasyondan geçmeyen) bir şablon yayınladı.
        let broken = """
        {"schemaVersion": 1, "id": "minimal-fade-01", "name": {"tr": "Bozuk"},
         "category": "minimal", "duration": 5, "palette": {}, "layers": []}
        """
        try Data(broken.utf8).write(to: remote.appendingPathComponent("minimal-fade-01.json"))
        try writeManifest(at: remote, entries: [entry(id: "minimal-fade-01", version: 3)])

        let catalog = makeCatalog(fetcher: StubFetcher())
        let entries = try await catalog.refresh().entries
        let template = try await catalog.template(for: entries[0])

        XCTAssertEqual(template.name.values["en"], "Minimal Fade", "seed sürümü kullanılmalı")
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: cache.appendingPathComponent("templates/minimal-fade-01-v3.json").path),
            "doğrulamayı geçmeyen şablon cache'e yazılmamalı")
    }

    func testLoadTemplatesSkipsUnavailableEntries() async throws {
        try writeManifest(at: remote, entries: [entry(id: "minimal-fade-01", version: 1),
                                                entry(id: "yok-01", version: 1)])
        let catalog = makeCatalog(fetcher: StubFetcher())
        let entries = try await catalog.refresh().entries
        let templates = await catalog.loadTemplates(entries)
        XCTAssertEqual(templates.map(\.id), ["minimal-fade-01"])
    }

    // MARK: Galeri posteri

    /// 1x1 JPEG (SOI + APP0 + ... ) yerine sihirli baytlar yeterli: katalog
    /// görseli DECODE etmez, yalnız "bu gerçekten bir görsel mi" bakar.
    private func fakeJPEG(_ marker: UInt8 = 0x01) -> Data {
        Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, marker, 0x00])
    }

    private func thumbEntry(id: String, version: Int) -> TemplateManifest.Entry {
        TemplateManifest.Entry(id: id, version: version, category: "minimal",
                               template: "\(id).json", thumbnail: "thumbs/\(id).jpg",
                               name: LocalizedText(["en": id]))
    }

    func testThumbnailIsDownloadedOnceThenServedFromCache() async throws {
        let entries = [thumbEntry(id: "minimal-fade-01", version: 1)]
        try writeManifest(at: remote, entries: entries)
        try FileManager.default.createDirectory(at: remote.appendingPathComponent("thumbs"),
                                                withIntermediateDirectories: true)
        try fakeJPEG().write(to: remote.appendingPathComponent("thumbs/minimal-fade-01.jpg"))

        let fetcher = StubFetcher()
        let catalog = makeCatalog(fetcher: fetcher)
        let entry = try await catalog.refresh().entries[0]

        let data = await catalog.thumbnail(for: entry)
        XCTAssertEqual(data, fakeJPEG())
        XCTAssertEqual(fetcher.callCount(containing: "minimal-fade-01.jpg"), 1)

        _ = await catalog.thumbnail(for: entry)
        XCTAssertEqual(fetcher.callCount(containing: "minimal-fade-01.jpg"), 1,
                       "poster ikinci kez indirilmemeli")

        // Sürüm artışı posteri de tazeler (aynı `id-vN` anahtarı).
        _ = await catalog.thumbnail(for: thumbEntry(id: "minimal-fade-01", version: 2))
        XCTAssertEqual(fetcher.callCount(containing: "minimal-fade-01.jpg"), 2)
    }

    func testThumbnailFallsBackToSeedAndRejectsNonImages() async throws {
        // Sunucu poster yerine hata sayfası (HTML) döndürüyor.
        try FileManager.default.createDirectory(at: remote.appendingPathComponent("thumbs"),
                                                withIntermediateDirectories: true)
        try Data("<html>404</html>".utf8)
            .write(to: remote.appendingPathComponent("thumbs/minimal-fade-01.jpg"))
        // Uygulamayla gelen poster sağlam.
        try FileManager.default.createDirectory(at: seed.appendingPathComponent("thumbs"),
                                                withIntermediateDirectories: true)
        try fakeJPEG(0x02).write(to: seed.appendingPathComponent("thumbs/minimal-fade-01.jpg"))

        let catalog = makeCatalog(fetcher: StubFetcher())
        let data = await catalog.thumbnail(for: thumbEntry(id: "minimal-fade-01", version: 1))
        XCTAssertEqual(data, fakeJPEG(0x02), "görsel olmayan indirme reddedilip seed'e düşmeli")
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: cache.appendingPathComponent("thumbs/minimal-fade-01-v1.jpg").path),
            "görsel olmayan içerik cache'lenmemeli")
    }

    func testMissingThumbnailReturnsNil() async {
        let catalog = makeCatalog(fetcher: StubFetcher())
        let data = await catalog.thumbnail(for: thumbEntry(id: "yok-01", version: 1))
        XCTAssertNil(data, "poster yoksa galeri kendi çizimine düşebilmeli")
    }

    func testStaleThumbnailsArePrunedOnRefresh() async throws {
        try writeManifest(at: remote, entries: [thumbEntry(id: "minimal-fade-01", version: 1)])
        try FileManager.default.createDirectory(at: remote.appendingPathComponent("thumbs"),
                                                withIntermediateDirectories: true)
        try fakeJPEG().write(to: remote.appendingPathComponent("thumbs/minimal-fade-01.jpg"))

        let catalog = makeCatalog(fetcher: StubFetcher())
        _ = await catalog.thumbnail(for: try await catalog.refresh().entries[0])
        let cached = cache.appendingPathComponent("thumbs/minimal-fade-01-v1.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cached.path))

        try writeManifest(at: remote, entries: [thumbEntry(id: "minimal-fade-01", version: 2)])
        _ = try await catalog.refresh()
        XCTAssertFalse(FileManager.default.fileExists(atPath: cached.path),
                       "eski sürümün posteri de temizlenmeli")
    }

    /// Depodaki her manifest girdisinin posteri gerçekten var mı
    /// (`templatekit-assets` çalıştırılmayı unutulduysa CDN kırık link verir).
    func testRepoThumbnailsExistForEveryEntry() throws {
        let data = try Data(contentsOf: repoTemplates.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(TemplateManifest.self, from: data)
        for entry in manifest.templates {
            let url = repoTemplates.appendingPathComponent(entry.thumbnailPath)
            let file = try Data(contentsOf: url)
            XCTAssertTrue(TemplateCatalog.isImage(file), "\(entry.id): poster bir görsel değil")
        }
    }

    func testRepoManifestMatchesTemplateFiles() throws {
        let data = try Data(contentsOf: repoTemplates.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(TemplateManifest.self, from: data)
        let files = try FileManager.default.contentsOfDirectory(at: repoTemplates,
                                                                includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }

        XCTAssertEqual(manifest.templates.count, files.count,
                       "manifest güncel değil — `python3 tools/make-manifest.py` çalıştırın")
        for entry in manifest.templates {
            let url = repoTemplates.appendingPathComponent(entry.templatePath)
            let template = try JSONDecoder().decode(Template.self, from: Data(contentsOf: url))
            XCTAssertEqual(template.id, entry.id)
            XCTAssertEqual(template.isPro, entry.isPro, "\(entry.id): isPro manifest ile şablonda farklı")
            XCTAssertNoThrow(try TemplateValidator.validate(template))
        }
    }

    func testAppVersionComparison() {
        XCTAssertEqual(AppVersion.compare("1.2.0", "1.10.0"), .orderedAscending)
        XCTAssertEqual(AppVersion.compare("1.2", "1.2.0"), .orderedSame)
        XCTAssertEqual(AppVersion.compare("2.0.0", "1.9.9"), .orderedDescending)
        XCTAssertEqual(AppVersion.compare("1.0.0", "1.0.1"), .orderedAscending)
    }
}

final class TemplateCategoryTests: XCTestCase {

    func testCategoriesAreOrderedAndLabelled() {
        // Beklenen sıra `TemplateCategory.order`'dan türetilir; testin sabit bir
        // sıra ezberlemesi, ürün kararıyla (galeri çipi sırası) her
        // değiştiğinde testi kırıyordu. Doğrulanan davranış şu: bilinen
        // kategoriler order'daki sırayı korur, bilinmeyen sona gider.
        let input = ["minimal", "food", "travel", "kripto"]
        let sorted = TemplateCategory.sorted(input)
        let expected = TemplateCategory.order.filter(input.contains) + ["kripto"]
        XCTAssertEqual(sorted, expected,
                       "bilinen kategoriler order sırasında, bilinmeyen sonda olmalı")
        XCTAssertEqual(sorted.last, "kripto")
        XCTAssertEqual(TemplateCategory.label("food").resolved(languageCode: "tr"), "Yemek")
        XCTAssertEqual(TemplateCategory.label("kripto").resolved(languageCode: "tr"), "Kripto",
                       "tanınmayan kategori de gösterilebilmeli")
    }

    /// Her kategori hem sırada hem etiket tablosunda olmalı — yenisi
    /// eklenirken biri unutulursa galeri o çipe ham kategori adını
    /// ("realestate") basıyor.
    func testEveryOrderedCategoryHasALocalisedLabel() {
        for category in TemplateCategory.order {
            let label = TemplateCategory.label(category)
            // Tabloda olmayan kategori tek dilli bir yedeğe düşer
            // (`["en": capitalized]`); iki dil varsa gerçekten tablodadır.
            // ("Minimal" gibi etiketler büyük harfli hâliyle aynı olduğu için
            // metni karşılaştırmak yanlış alarm veriyordu.)
            XCTAssertNotNil(label.values["tr"], "\(category): Türkçe etiket yok")
            XCTAssertNotNil(label.values["en"], "\(category): İngilizce etiket yok")
        }
    }

    func testEveryCatalogCategoryHasALabel() throws {
        let templates = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("templates")
        let manifest = try JSONDecoder().decode(
            TemplateManifest.self,
            from: Data(contentsOf: templates.appendingPathComponent("manifest.json")))
        for category in Set(manifest.templates.map(\.category)) {
            XCTAssertTrue(TemplateCategory.order.contains(category),
                          "'\(category)' galeri sırasında tanımlı değil")
        }
    }
}
