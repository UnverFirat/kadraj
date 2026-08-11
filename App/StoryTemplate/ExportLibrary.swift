import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import TemplateKit

/// Kullanıcının oluşturduğu bir video (kalıcı).
struct ExportItem: Identifiable, Codable, Hashable {
    let id: UUID
    let templateID: String
    let templateName: String
    let createdAt: Date
    let duration: Double

    var videoName: String { "\(id.uuidString).mp4" }
    var posterName: String { "\(id.uuidString).jpg" }
}

/// "Videolarım" sekmesinin veri kaynağı.
///
/// Export çıktısı geçici klasöre yazılır (`ExportFlow`); uygulama onu burada
/// Application Support altına taşır, poster karesini üretir ve küçük bir
/// `index.json` ile listeler. Kullanıcının emeği uygulama kapanınca kaybolmasın
/// diye bu katman var — editör tek seferlik bir önizleme ekranı değil.
@MainActor
final class ExportLibrary: ObservableObject {
    @Published private(set) var items: [ExportItem] = []

    private let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("index.json") }

    init(directory: URL = ExportLibrary.defaultDirectory()) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        load()
    }

    nonisolated static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("Exports", isDirectory: true)
    }

    func videoURL(_ item: ExportItem) -> URL {
        directory.appendingPathComponent(item.videoName)
    }

    func posterURL(_ item: ExportItem) -> URL {
        directory.appendingPathComponent(item.posterName)
    }

    /// Kütüphanenin toplam disk kullanımı. Videolar büyük; kullanıcı ne kadar
    /// yer kapladığını görebilmeli (ve gerekirse silebilmeli).
    var totalBytes: Int64 {
        items.reduce(0) { total, item in
            let attributes = try? FileManager.default.attributesOfItem(atPath: videoURL(item).path)
            return total + Int64((attributes?[.size] as? Int) ?? 0)
        }
    }

    var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    /// Biten export'u kütüphaneye alır. Aynı dosya iki kez eklenmesin diye
    /// çağrı `ExportFlow.Phase` .done'a GEÇTİĞİNDE yapılır (görünüm her
    /// belirdiğinde değil).
    @discardableResult
    func add(videoAt url: URL, templateID: String, templateName: String,
             duration: Double) -> ExportItem? {
        let item = ExportItem(id: UUID(), templateID: templateID,
                              templateName: templateName,
                              createdAt: Date(), duration: duration)
        let destination = videoURL(item)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            return nil
        }
        writePoster(for: item, from: destination)
        items.insert(item, at: 0)
        save()
        return item
    }

    func remove(_ item: ExportItem) {
        try? FileManager.default.removeItem(at: videoURL(item))
        try? FileManager.default.removeItem(at: posterURL(item))
        items.removeAll { $0.id == item.id }
        save()
    }

    // MARK: - Disk

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let stored = try? JSONDecoder().decode([ExportItem].self, from: data)
        else { return }
        // Dosyası kaybolmuş kayıtları (ör. kullanıcı verisini sildi) ele.
        items = stored.filter { FileManager.default.fileExists(atPath: videoURL($0).path) }
        if items.count != stored.count { save() }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    /// Liste için tek kare. Şablonların çoğu fade/animasyonla AÇILIR — başa
    /// yakın kare siyah çıkıyor, o yüzden videonun ~%35'i alınır.
    private func writePoster(for item: ExportItem, from video: URL) {
        let asset = AVURLAsset(url: video)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 540, height: 960)
        // Kare, istenen zamana yakın olsun (varsayılan tolerans saniyelerce
        // kayabilir ve yine siyah kareye düşebilir).
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)
        let time = CMTime(seconds: max(0.5, item.duration * 0.35), preferredTimescale: 600)
        guard let image = try? generator.copyCGImage(at: time, actualTime: nil),
              let destination = CGImageDestinationCreateWithURL(
                posterURL(item) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        CGImageDestinationFinalize(destination)
    }
}
