import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import TemplateKit

/// Yarım kalmış bir iş: hangi şablon, hangi medya, hangi metin/kadraj/hız.
///
/// NEDEN VAR: editörden çıkan kullanıcı her şeyi kaybediyordu — seçtiği 5 klip,
/// yazdığı metinler, kadrajı. Bu hem emeğin çöpe gitmesi hem de geri dönme
/// sebebinin yok olması demek. Şablon başına TEK taslak tutulur ("kaldığın
/// yerden devam et"), böylece kullanıcı "hangi taslak hangisiydi" sorusuyla
/// uğraşmaz.
struct Draft: Codable, Identifiable, Equatable {
    /// Şablon başına tek taslak: kimlik = şablon id'si.
    var id: String { templateID }
    let templateID: String
    var templateName: String
    var updatedAt: Date
    var texts: [String: String]
    var textStyles: [String: TextStyleOverride]
    var accentHex: String?
    var musicTrackID: String?
    var useOriginalAudio: Bool
    var slots: [SlotDraft]

    struct SlotDraft: Codable, Equatable {
        let slot: Int
        let kind: AssignedMediaKind
        /// Taslak klasöründeki dosya adı. Medya, seçildiği geçici klasörde
        /// BIRAKILAMAZ: iOS `tmp`'i uygun gördüğünde siliyor ve taslak boş
        /// bir kabuğa dönüşüyor.
        let fileName: String
        var crop: CropTransform
        var start: Double
        var speed: Double
    }

    /// Kullanıcıya gösterilecek özet: "3 medya · 2 dk önce".
    var mediaCount: Int { slots.count }
}

/// Taslakların diskteki hali. `ExportLibrary` ile aynı desen: küçük bir
/// `index.json` + yanında medya dosyaları.
@MainActor
final class DraftStore: ObservableObject {
    @Published private(set) var drafts: [Draft] = []

    private let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("index.json") }
    private var mediaDirectory: URL { directory.appendingPathComponent("media", isDirectory: true) }

    /// En fazla kaç taslak tutulur. Taslak medyası (videolar!) yer kapladığı
    /// için sınırsız olamaz; en eski taslak medyasıyla birlikte silinir.
    private let capacity = 12

    init(directory: URL = DraftStore.defaultDirectory()) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: mediaDirectory,
                                                 withIntermediateDirectories: true)
        load()
    }

    nonisolated static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("Drafts", isDirectory: true)
    }

    func draft(for templateID: String) -> Draft? {
        drafts.first { $0.templateID == templateID }
    }

    func fileURL(_ name: String) -> URL {
        mediaDirectory.appendingPathComponent(name)
    }

    // MARK: - Kaydetme

    /// Editörün o anki halini taslak olarak yazar.
    ///
    /// Medya taslak klasörüne KOPYALANIR (zaten oradaysa dokunulmaz): fotoğraf
    /// JPEG'e yazılır, video dosyası kopyalanır. Bu, taslağı kendi kendine
    /// yeterli yapar — kullanıcı uygulamayı kapatıp iki gün sonra dönebilir.
    @discardableResult
    func save(templateID: String, templateName: String,
              texts: [String: String],
              textStyles: [String: TextStyleOverride],
              photos: [Int: CGImage], videos: [Int: URL],
              crops: [Int: CropTransform], starts: [Int: Double],
              speeds: [Int: Double],
              accentHex: String?, musicTrackID: String?,
              useOriginalAudio: Bool,
              hasEdits: Bool = false) -> Draft? {
        // Hiç medya ve hiç değişiklik yoksa taslak yaratmak gürültüdür:
        // şablona bakıp çıkan kullanıcının galerisini taslakla doldurmayalım.
        //
        // AMA ölçüt eskiden YALNIZ medyaydı ve bu, yazı tabanlı şablonlarda
        // (menü, ders programı, valiz listesi — tam da en çok yazı yazılan
        // şablonlar) kullanıcının yazdığı her satırı geri tuşuna basınca
        // çöpe atıyordu; renk seçimi de aynı şekilde kayboluyordu. Medyası
        // olmayan bir şablonda "iş" metnin kendisidir, `hasEdits` onu söyler.
        guard !photos.isEmpty || !videos.isEmpty || hasEdits else {
            remove(templateID: templateID)
            return nil
        }

        let previous = draft(for: templateID)
        var slots: [Draft.SlotDraft] = []
        for (slot, image) in photos.sorted(by: { $0.key < $1.key }) {
            guard let name = writePhoto(image, reusing: previous, slot: slot) else { continue }
            slots.append(.init(slot: slot, kind: .photo, fileName: name,
                               crop: crops[slot] ?? CropTransform(),
                               start: starts[slot] ?? 0, speed: speeds[slot] ?? 1))
        }
        for (slot, url) in videos.sorted(by: { $0.key < $1.key }) {
            guard let name = copyVideo(url) else { continue }
            slots.append(.init(slot: slot, kind: .video, fileName: name,
                               crop: crops[slot] ?? CropTransform(),
                               start: starts[slot] ?? 0, speed: speeds[slot] ?? 1))
        }
        // Medyasız taslak SADECE bir düzenleme varsa anlamlı (yukarıdaki
        // gerekçe); medya yazılamadıysa ve ortada düzenleme de yoksa taslak
        // boş bir kabuk olur.
        guard !slots.isEmpty || hasEdits else { return nil }

        let draft = Draft(templateID: templateID, templateName: templateName,
                          updatedAt: Date(), texts: texts, textStyles: textStyles,
                          accentHex: accentHex, musicTrackID: musicTrackID,
                          useOriginalAudio: useOriginalAudio,
                          slots: slots.sorted { $0.slot < $1.slot })
        drafts.removeAll { $0.templateID == templateID }
        drafts.insert(draft, at: 0)
        evictIfNeeded()
        save()
        collectGarbage()
        return draft
    }

    func remove(templateID: String) {
        guard drafts.contains(where: { $0.templateID == templateID }) else { return }
        drafts.removeAll { $0.templateID == templateID }
        save()
        collectGarbage()
    }

    /// Export biten bir iş artık taslak değil — kullanıcı videosunu aldı.
    func markExported(templateID: String) {
        remove(templateID: templateID)
    }

    // MARK: - Okuma

    /// Taslağın fotoğrafını çözer (editör CGImage ile çalışıyor).
    func photo(_ slot: Draft.SlotDraft) -> CGImage? {
        guard slot.kind == .photo else { return nil }
        return Self.decodePhoto(at: fileURL(slot.fileName))
    }

    /// Ana iş parçacığı DIŞINDA da çağrılabilir: taslak kartları posteri
    /// (özellikle video karesi) arka planda çözüyor, ana iş parçacığında
    /// çözmek galeriyi takıyordu.
    nonisolated static func decodePhoto(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    // MARK: - Disk

    private func writePhoto(_ image: CGImage, reusing previous: Draft?,
                            slot: Int) -> String? {
        // Aynı slotun fotoğrafı değişmediyse yeniden yazmak gereksiz — ama
        // CGImage kimliği güvenilir değil, bu yüzden aynı DOSYA ADINA yazıyoruz:
        // dosya sayısı taslak başına sabit kalır.
        let name = previous?.slots.first { $0.slot == slot && $0.kind == .photo }?.fileName
            ?? "\(UUID().uuidString).jpg"
        let url = fileURL(name)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? name : nil
    }

    private func copyVideo(_ url: URL) -> String? {
        // Zaten taslak klasöründeyse (taslaktan devam ediliyor) kopyalama yok.
        if url.deletingLastPathComponent().standardizedFileURL == mediaDirectory.standardizedFileURL {
            return url.lastPathComponent
        }
        let name = "\(UUID().uuidString).\(url.pathExtension.isEmpty ? "mov" : url.pathExtension)"
        do {
            try FileManager.default.copyItem(at: url, to: fileURL(name))
        } catch {
            return nil
        }
        return name
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let stored = try? JSONDecoder().decode([Draft].self, from: data) else { return }
        // Medyası kaybolmuş taslağı gösterme (kullanıcı verisini sildi, iOS
        // temizledi): yarım bir taslak açmak hatadan kötü.
        drafts = stored.filter { draft in
            draft.slots.allSatisfy {
                FileManager.default.fileExists(atPath: fileURL($0.fileName).path)
            }
        }
        if drafts.count != stored.count { save() }
        collectGarbage()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func evictIfNeeded() {
        guard drafts.count > capacity else { return }
        drafts = Array(drafts.prefix(capacity))
    }

    /// Hiçbir taslağın kullanmadığı medya dosyalarını siler. Video taslakları
    /// yüzlerce MB olabiliyor; sahipsiz dosya bırakmak kabul edilemez.
    private func collectGarbage() {
        let used = Set(drafts.flatMap { $0.slots.map(\.fileName) })
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: mediaDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files where !used.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Taslakların toplam disk kullanımı (Ayarlar gösterir).
    var totalBytes: Int64 {
        drafts.flatMap { $0.slots }.reduce(0) { total, slot in
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: fileURL(slot.fileName).path)
            return total + Int64((attributes?[.size] as? Int) ?? 0)
        }
    }
}


/// Videonun ilk anlamlı karesi (taslak listesi ve şerit için).
enum VideoPoster {
    static func firstFrame(of url: URL) -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 560)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        return try? generator.copyCGImage(at: CMTime(seconds: 0.4, preferredTimescale: 600),
                                         actualTime: nil)
    }
}
