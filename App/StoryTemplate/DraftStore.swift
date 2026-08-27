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

    /// Disk işini ana iş parçacığından ALAN seri yazıcı.
    ///
    /// NEDEN: `save()` senkrondu ve `onDisappear` ile `scenePhase` üzerinden
    /// çağrılıyordu — yani GERİ TUŞU her fotoğrafın JPEG'e kodlanmasını ve her
    /// videonun kopyalanmasını bekliyordu. 5 klipli bir projede bu saniyeler
    /// sürüyor; kullanıcıya "geri tuşu takıldı" diye görünüyor, arka plana
    /// alınırken de watchdog riski taşıyor.
    ///
    /// Aktör olması SIRAYI garanti eder: iki kayıt aynı dosya adına aynı anda
    /// yazamaz.
    private let writer = DraftWriter()

    /// Son kaydın disk işi. Yeni kayıt bunun ARDINA zincirlenir; `settle()` de
    /// bunu bekler. Sıra hem burada hem yazıcı aktöründe garanti altında:
    /// aktör iki yazmanın çakışmasını, zincir de "hangisi önce" sorusunu çözer
    /// (bir `Task`'ın aktöre HANGİ sırayla ulaşacağı garanti değildir).
    private var lastCommit: Task<Void, Never>?

    /// Henüz diske YAZILMAMIŞ fotoğraflar (dosya adı → kare).
    ///
    /// Yazma artık eşzamansız olduğu için, kullanıcı kaydettikten hemen sonra
    /// editöre geri girerse `photo(_:)` dosyayı henüz bulamayabilir ve slot
    /// sessizce boş kalırdı. Bellekten servis edilir; yazma bitince silinir.
    /// Ek bellek maliyeti yok: bunlar editörün zaten elinde tuttuğu kareler.
    private var pendingPhotos: [String: CGImage] = [:]

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
        // Dosya ADLARI burada belirlenir (ucuz), YAZMA aşağıda yazıcıya
        // devredilir (pahalı). Böylece taslak nesnesi ve `drafts` dizisi anında
        // doğru olur; kullanıcı "Devam et" şeridini beklemeden görür.
        var photoWrites: [DraftWriter.PhotoWrite] = []
        var videoCopies: [DraftWriter.VideoCopy] = []
        for (slot, image) in photos.sorted(by: { $0.key < $1.key }) {
            // Aynı slotun fotoğrafı aynı DOSYA ADINA yazılır: dosya sayısı
            // taslak başına sabit kalır (CGImage kimliği güvenilir değil).
            let name = previous?.slots.first { $0.slot == slot && $0.kind == .photo }?.fileName
                ?? "\(UUID().uuidString).jpg"
            photoWrites.append(.init(image: image, url: fileURL(name)))
            pendingPhotos[name] = image
            slots.append(.init(slot: slot, kind: .photo, fileName: name,
                               crop: crops[slot] ?? CropTransform(),
                               start: starts[slot] ?? 0, speed: speeds[slot] ?? 1))
        }
        for (slot, url) in videos.sorted(by: { $0.key < $1.key }) {
            // Zaten taslak klasöründeyse (taslaktan devam ediliyor) kopyalama yok.
            let alreadyStored = url.deletingLastPathComponent().standardizedFileURL
                == mediaDirectory.standardizedFileURL
            let name = alreadyStored
                ? url.lastPathComponent
                : "\(UUID().uuidString).\(url.pathExtension.isEmpty ? "mov" : url.pathExtension)"
            if !alreadyStored {
                videoCopies.append(.init(source: url, destination: fileURL(name)))
            }
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
        commit(photos: photoWrites, videos: videoCopies)
        return draft
    }

    /// Bellekteki hali diske yazdırır — ANA İŞ PARÇACIĞINI BEKLETMEDEN.
    ///
    /// Sıra yazıcının içinde korunur: önce medya, sonra index, en sonda çöp
    /// toplama. Bu sıra önemli — index yazılmadan çöp toplarsak yeni dosya
    /// "sahipsiz" görünüp silinir.
    private func commit(photos: [DraftWriter.PhotoWrite] = [],
                        videos: [DraftWriter.VideoCopy] = []) {
        let index = try? JSONEncoder().encode(drafts)
        let keep = Set(drafts.flatMap { $0.slots.map(\.fileName) })
        let written = photos.map(\.url.lastPathComponent)
        let previous = lastCommit
        lastCommit = Task { [writer, indexURL, mediaDirectory] in
            await previous?.value
            await writer.commit(photos: photos, videos: videos,
                                index: index, indexURL: indexURL,
                                keep: keep, mediaDirectory: mediaDirectory)
            // Diskte artık var: bellekteki kopyayı bırak.
            for name in written { pendingPhotos[name] = nil }
        }
    }

    /// Bekleyen disk yazmaları bitene kadar bekler.
    ///
    /// NEDEN GEREKLİ: yazma eşzamansız olunca DOSYAYI OKUYAN her yol yarışa
    /// giriyor. Fotoğrafta `pendingPhotos` kurtarıyor ama VİDEO kopyası
    /// bellekte tutulamaz — kopyalanmadan önce okunursa taslak slotu sessizce
    /// düşüyordu, taslak kartının posteri de siyah kalıyordu. Diskten okuyan
    /// yollar önce burada bekler.
    func settle() async {
        await lastCommit?.value
    }

    func remove(templateID: String) {
        guard drafts.contains(where: { $0.templateID == templateID }) else { return }
        drafts.removeAll { $0.templateID == templateID }
        commit()
    }

    /// Export biten bir iş artık taslak değil — kullanıcı videosunu aldı.
    func markExported(templateID: String) {
        remove(templateID: templateID)
    }

    // MARK: - Okuma

    /// Taslağın fotoğrafını çözer (editör CGImage ile çalışıyor).
    func photo(_ slot: Draft.SlotDraft) -> CGImage? {
        guard slot.kind == .photo else { return nil }
        // Yazma eşzamansız: dosya henüz yerinde olmayabilir (bkz. pendingPhotos).
        if let pending = pendingPhotos[slot.fileName] { return pending }
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
        // Açılışta da aynı yoldan: index tazelenir ve sahipsiz medya silinir.
        // Bu iş de diskte ve açılışı bekletmesine gerek yok.
        commit()
    }

    private func evictIfNeeded() {
        guard drafts.count > capacity else { return }
        drafts = Array(drafts.prefix(capacity))
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

/// Taslakların DİSK tarafı. Ana iş parçacığından uzakta ve SERİ.
///
/// Aktör olmasının iki gerekçesi var:
///
/// 1. Ana iş parçacığını boşaltmak. JPEG kodlama ve video kopyalama
///    `onDisappear`/`scenePhase` üzerinden geri tuşuna bağlıydı.
/// 2. Sırayı garanti etmek. Aynı slotun fotoğrafı hep AYNI dosya adına
///    yazılıyor; iki kayıt paralel koşarsa aynı dosyaya aynı anda yazarlar.
private actor DraftWriter {
    struct PhotoWrite {
        let image: CGImage
        let url: URL
    }

    struct VideoCopy {
        let source: URL
        let destination: URL
    }

    /// SIRA ÖNEMLİ: önce medya, sonra index, en sonda çöp toplama. Index
    /// yazılmadan çöp toplanırsa yeni yazılan dosya "sahipsiz" görünüp silinir.
    func commit(photos: [PhotoWrite], videos: [VideoCopy],
                index: Data?, indexURL: URL,
                keep: Set<String>, mediaDirectory: URL) {
        for photo in photos { write(photo) }
        for video in videos {
            // Hedef duruyorsa (aynı kaynak iki kez kaydedildi) tekrar kopyalama.
            guard !FileManager.default.fileExists(atPath: video.destination.path) else { continue }
            try? FileManager.default.copyItem(at: video.source, to: video.destination)
        }
        if let index { try? index.write(to: indexURL, options: .atomic) }
        collectGarbage(keep: keep, in: mediaDirectory)
    }

    private func write(_ photo: PhotoWrite) {
        guard let destination = CGImageDestinationCreateWithURL(
            photo.url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, photo.image,
                                   [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        CGImageDestinationFinalize(destination)
    }

    /// Hiçbir taslağın kullanmadığı medya dosyalarını siler. Video taslakları
    /// yüzlerce MB olabiliyor; sahipsiz dosya bırakmak kabul edilemez.
    private func collectGarbage(keep: Set<String>, in mediaDirectory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: mediaDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files where !keep.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
