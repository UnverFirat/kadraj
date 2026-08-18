import Foundation
import AVFoundation
import CoreGraphics
import UIKit
import TemplateKit

/// Editör ile TemplateExporter arasındaki köprü. Örnek medyayı UserEdits'e
/// çevirir, export'u çalıştırır, ilerlemeyi ve sonucu yayınlar.
@MainActor
final class ExportFlow: ObservableObject {
    enum Phase: Equatable {
        case idle
        case exporting(Double)
        case done(URL)
        case failed(String)
    }

    /// Aynı hat iki amaca hizmet eder:
    /// - `.final` — kullanıcının videosu (tam çözünürlük, `HighestQuality`).
    /// - `.preview` — editörde oynatılan/scrub edilen ön-render (küçük kadraj).
    ///
    /// ÖNİZLEME KARARI (README'de açık bırakılmıştı): önizleme, CoreImage'ı
    /// canlı sürerek DEĞİL, motorun kendisiyle küçük çözünürlükte ön-render
    /// edilerek üretilir. Gerekçe: (1) tek doğruluk kaynağı — önizlemede
    /// görünen kare export'ta da aynı, ikinci bir render yolu bakımı yok;
    /// (2) montajda 4 eşzamanlı video + geçiş + filtre canlı sürüldüğünde
    /// cihazda kare düşüyor, ön-render'da bu maliyet bir kez ödeniyor;
    /// (3) scrub bedava — AVPlayer hazır dosyada anında kareye gidiyor.
    /// Bedeli: metin değişince önizleme bayatlar, kullanıcı yenilemeli.
    enum Quality {
        case final
        case preview

        /// Önizleme kadrajının genişliği (1080 → 360; 9:16'da 640 yükseklik).
        var previewWidth: Int? { self == .preview ? 360 : nil }
        var fps: Int? { self == .preview ? 20 : nil }
    }

    @Published var phase: Phase = .idle

    let quality: Quality
    private let exporter = TemplateExporter()
    /// Bir önceki önizleme render'ının geçici klasörü (yenilemede silinir).
    private var previousWorkDirectory: URL?
    /// Çalışan render — iptal bunu keser.
    private var job: Task<Void, Never>?
    /// Arka plana geçildiğinde işletim sisteminden istenen ek süre.
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    /// Export'un sığması için gereken asgari boş alan. 1080x1920 bir dakikalık
    /// H.264 ~60 MB; ara dosyalarla birlikte 250 MB güvenli eşik.
    private static let requiredFreeBytes: Int64 = 250 * 1024 * 1024

    init(quality: Quality = .final) {
        self.quality = quality
    }

    /// Kullanıcı vazgeçti. Motorun `cancel()`'ı AVAssetExportSession'ı durdurur;
    /// Task iptali de montaj geçişini keser.
    func cancel() {
        exporter.cancel()
        job?.cancel()
        job = nil
        endBackgroundTask()
        phase = .idle
    }

    /// - Parameters:
    ///   - photos/videos: kullanıcının (galeriden) seçtiği güncel medya —
    ///     project'in örnek medyasının yerini alır (slotIndex -> medya).
    ///   - music: kullanıcının seçtiği parça (nil = müziksiz).
    ///   - entitlements: filigran ve Pro içerik kararlarını verir.
    ///   - speeds: slotIndex -> klip hız çarpanı (1 = normal). Şablonun süresini
    ///     değiştirmez; klibin sahneye sığdırılan bölümünü değiştirir.
    ///   - crops: slotIndex -> kullanıcı kadrajı (yakınlaştır/kaydır).
    ///   - starts: slotIndex -> klibin hangi saniyesinden başlanacağı (trim).
    func run(project: DemoProject, texts: [String: String],
             photos: [Int: CGImage], videos: [Int: URL],
             music: TemplateKit.MusicTrack?, entitlements: Entitlements,
             accentOverride: String? = nil,
             speeds: [Int: Double] = [:],
             crops: [Int: CropTransform] = [:],
             starts: [Int: Double] = [:],
             textStyles: [String: TextStyleOverride] = [:],
             originalAudioFrom videoAudioURL: URL? = nil,
             originalAudioSpeed: Double = 1) {
        // Yer yoksa render'ı hiç başlatma: AVFoundation yarı yolda anlamsız bir
        // hata veriyor, kullanıcı da niye olmadığını anlamıyor.
        if let free = Self.freeDiskBytes(), free < Self.requiredFreeBytes {
            phase = .failed(ExportMessage.notEnoughSpace)
            if quality == .final {
                Analytics.shared.log(.exportFailed(templateID: project.id, reason: "no_space"))
            }
            return
        }

        phase = .exporting(0)
        beginBackgroundTask()
        let startedAt = Date()
        if quality == .final {
            Analytics.shared.log(.exportStarted(templateID: project.id, isPro: entitlements.isPro))
        }
        var template = project.template
        // TEMPOYA HİZALA: video süresi seçilen parçanın tam ölçüsüne oturur,
        // müzik yarım kesilmez ve girişler vuruşlarla tutarlı hale gelir.
        // Müzik yoksa ya da kullanıcının kendi sesi seçiliyse dokunulmaz.
        if videoAudioURL == nil, let track = entitlements.resolvedTrack(music) {
            template = TemplateTempo.aligned(template, bpm: track.bpm)
        }
        template.canvas = Self.renderCanvas(template.canvas, quality: quality)

        var edits = UserEdits(textOverrides: texts, textStyles: textStyles)
        // Kullanıcının seçtiği vurgu rengi. Motor paleti rol bazlı çözdüğü için
        // tek rolü değiştirmek şablonun TÜM vurgularını (rozet, çizgi, fiyat,
        // buton) birlikte döndürür — "tek dokunuşla renk şeması" bu demek.
        if let accentOverride {
            edits.paletteOverride = ["accent": accentOverride]
        }
        var videoInputs: [TemplateExporter.VideoInput] = []
        for (slot, url) in videos {
            let start = starts[slot] ?? 0
            edits.slots[slot] = SlotAssignment(assetIdentifier: url.path, kind: .video,
                                               crop: crops[slot] ?? CropTransform(),
                                               videoStart: start,
                                               speed: speeds[slot] ?? 1)
            // Motor klibin başlangıcını `VideoInput.start`'tan okuyor (montaj
            // yolunda `VideoSource.start`); `edits` tarafındaki `videoStart` da
            // aynı değeri taşır — taslak kaydı ve doğrulama tek yerden okunsun.
            videoInputs.append(.init(asset: AVURLAsset(url: url), slotIndex: slot,
                                     start: start))
        }
        for slot in photos.keys {
            edits.slots[slot] = SlotAssignment(assetIdentifier: "photo", kind: .photo,
                                               crop: crops[slot] ?? CropTransform())
        }

        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(quality == .preview ? "preview" : "export")-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let output = work.appendingPathComponent("story.mp4")
        // Önizleme her yenilemede yeniden üretilir; bir öncekini bırakmak
        // geçici klasörü büyütür (kullanıcının videosu ASLA silinmez — o
        // `ExportLibrary`'ye alınmış oluyor).
        //
        // Eski klasör HEMEN silinmez: otomatik yenilemede oynatıcı o dosyayı
        // hâlâ oynatıyor (bayat önizleme, yenisi hazırlanırken ekranda kalır).
        // Yeni render bitince silinir.
        let obsolete = quality == .preview ? previousWorkDirectory : nil
        previousWorkDirectory = work

        // Müzik: kütüphaneden video süresinde sentezlenir (cache'li), audio mix'i
        // exporter kurar (ses seviyesi + son 0.5 sn fade-out).
        var audio: TemplateExporter.AudioInput?
        if let videoAudioURL {
            // KULLANICININ KENDİ SESİ: motor ses kaynağı olarak herhangi bir
            // AVAsset kabul ettiği için kullanıcının klibini doğrudan veriyoruz —
            // ayrı bir "orijinal ses" yolu yazmaya gerek yok. Lisans maliyeti
            // sıfır: ses kullanıcının kendi çekiminden geliyor.
            audio = .init(asset: AVURLAsset(url: videoAudioURL), volume: 1,
                          speed: originalAudioSpeed)
        } else if let music = entitlements.resolvedTrack(music),
                  // Kilitli parça seçili kaldıysa ücretsiz alternatife düşülür.
                  let url = Self.musicURL(track: music, duration: template.totalDuration) {
            audio = .init(asset: AVURLAsset(url: url),
                          volume: Float(template.audio?.volume ?? 1))
        }

        let request = TemplateExporter.Request(
            template: template,
            edits: edits,
            photos: photos,
            videos: videoInputs,
            audio: audio,
            includeWatermark: entitlements.includeWatermark,
            watermarkText: "Made with \(AppInfo.displayName)",
            workDirectory: work,
            outputURL: output)

        let report: @Sendable (Double) -> Void = { p in
            Task { @MainActor in
                if case .exporting = self.phase { self.phase = .exporting(p) }
            }
        }

        #if targetEnvironment(simulator)
        // Simulator montaj stratejisi: export'un 2. geçişi (CoreAnimationTool +
        // gerçek video decode) simulator GPU'sunun IOSurface havuzunu tüketip
        // QuartzCore'da crash veriyor (cihazda sorun yok; motor macOS'ta kare
        // kare kanıtlı). Bu yüzden simulator'da yalnız 1. geçişi (MontageComposer:
        // kolaj + geçişler) çalıştırıp metni önizlemede canlı bindiriyoruz
        // (MontagePreviewOverlay). Cihazda aşağıdaki tam export yolu çalışır.
        if project.isMontage {
            var sources: [Int: MontageComposer.VideoSource] = [:]
            for (slot, url) in videos {
                sources[slot] = MontageComposer.VideoSource(asset: AVURLAsset(url: url),
                                                            start: starts[slot] ?? 0)
            }
            let montageOnly = work.appendingPathComponent("montage-only.mp4")
            job = Task {
                do {
                    let url = try await MontageComposer.render(
                        template: template, edits: edits, videos: sources,
                        photos: photos,
                        outputURL: montageOnly, progress: report)
                    self.finish(url, project: project, startedAt: startedAt,
                                entitlements: entitlements, obsolete: obsolete)
                } catch {
                    self.fail(error, project: project, obsolete: obsolete)
                }
            }
            return
        }
        #endif

        job = Task {
            do {
                let url = try await exporter.export(request, progress: report)
                self.finish(url, project: project, startedAt: startedAt,
                            entitlements: entitlements, obsolete: obsolete)
            } catch {
                self.fail(error, project: project, obsolete: obsolete)
            }
        }
    }

    private func finish(_ url: URL, project: DemoProject, startedAt: Date,
                        entitlements: Entitlements, obsolete: URL? = nil) {
        if let obsolete { try? FileManager.default.removeItem(at: obsolete) }
        if quality == .final {
            Analytics.shared.log(.exportFinished(templateID: project.id,
                                                 seconds: Date().timeIntervalSince(startedAt),
                                                 watermark: entitlements.includeWatermark))
        }
        job = nil
        endBackgroundTask()
        phase = .done(url)
    }

    /// Hata yolu. Kullanıcıya ANLAŞILIR bir cümle gösterilir (ham `Error`
    /// dökümü değil); analitiğe de mesaj değil hata TÜRÜ gider — mesaj dosya
    /// yolu taşıyabilir.
    private func fail(_ error: Error, project: DemoProject, obsolete: URL? = nil) {
        job = nil
        endBackgroundTask()
        // Render patlasa da bir önceki önizleme klasörü artık gereksiz; yoksa
        // her başarısız denemede geçici alanda bir kopya kalıyor.
        if let obsolete { try? FileManager.default.removeItem(at: obsolete) }
        if error is CancellationError || (error as? TemplateExportError).isCancelled {
            // Kullanıcı iptal etti: hata ekranı gösterme.
            phase = .idle
            return
        }
        if quality == .final {
            Analytics.shared.log(.exportFailed(templateID: project.id,
                                               reason: String(describing: type(of: error))))
        }
        phase = .failed(ExportMessage.text(for: error))
    }

    // MARK: - Arka plan ve disk

    /// Kullanıcı export sırasında uygulamadan çıkarsa render yarıda kalmasın —
    /// iOS'tan ek süre isteriz (tipik olarak ~30 sn, çoğu şablona yeter).
    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "export") { [weak self] in
            // Süre doldu: sistem uygulamayı askıya almadan önce temiz kapat.
            Task { @MainActor in self?.cancel() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private static func freeDiskBytes() -> Int64? {
        let url = FileManager.default.temporaryDirectory
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    /// Render kadrajı. Normalize koordinatlar sayesinde küçültme düzeni birebir
    /// korur — yalnız piksel sayısı düşer.
    private static func renderCanvas(_ canvas: Canvas, quality: Quality) -> Canvas {
        if let width = quality.previewWidth, let fps = quality.fps {
            return scaled(canvas, toWidth: width, fps: fps)
        }
        #if targetEnvironment(simulator)
        // Simulator'ın IOSurface/shared-memory hattı tam çözünürlüklü montajda
        // (10s+, çok katman) tükeniyor ve QuartzCore'da crash veriyor. Render
        // boyutunu düşürürüz. Cihazda tam 1080x1920 kalır (bu blok yalnız simulator).
        return scaled(canvas, toWidth: canvas.width / 2, fps: 15)
        #else
        return canvas
        #endif
    }

    /// H.264 tek sayı kenar sevmez — genişlik/yükseklik çifte yuvarlanır.
    private static func scaled(_ canvas: Canvas, toWidth width: Int, fps: Int) -> Canvas {
        let ratio = Double(width) / Double(canvas.width)
        let height = Int((Double(canvas.height) * ratio).rounded())
        return Canvas(width: width - width % 2, height: height - height % 2, fps: fps)
    }

    /// Parçayı istenen uzunlukta dosyaya alır (Caches/music, cache'li).
    /// Sentez birkaç yüz ms sürer; ilk kullanımda bir kez ödenir.
    static func musicURL(track: TemplateKit.MusicTrack, duration: Double) -> URL? {
        try? MusicLibrary.materialize(trackID: track.id,
                                      duration: duration,
                                      in: MusicLibrary.defaultCacheDirectory())
    }
}

/// Motor hatalarını kullanıcının anlayacağı cümlelere çevirir.
///
/// Ham `Error` dökümü ("TemplateExportError.failed(underlying: Optional(Error
/// Domain=AVFoundationErrorDomain Code=-11841…"))") kullanıcıya hiçbir şey
/// söylemiyor, üstelik dosya yolu sızdırıyordu.
enum ExportMessage {
    static var notEnoughSpace: String {
        String(localized: "Cihazında yeterli boş alan yok. Biraz yer açıp tekrar dene.")
    }

    static func text(for error: Error) -> String {
        if let export = error as? TemplateExportError {
            switch export {
            case .missingVideoTrack:
                return String(localized: "Seçtiğin videolardan biri okunamadı. Farklı bir klip dener misin?")
            case .missingBlankClip, .exportSessionCreationFailed:
                return String(localized: "Video hazırlanamadı. Uygulamayı yeniden açıp tekrar dener misin?")
            case .cancelled:
                return String(localized: "Video oluşturma iptal edildi.")
            case .failed(let underlying):
                return message(forUnderlying: underlying)
            }
        }
        return message(forUnderlying: error)
    }

    private static func message(forUnderlying error: Error?) -> String {
        let nsError = error as NSError?
        switch (nsError?.domain, nsError?.code) {
        case (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError?),
             (NSPOSIXErrorDomain, Int(ENOSPC)?):
            return notEnoughSpace
        case (AVFoundationErrorDomain, AVError.diskFull.rawValue?):
            return notEnoughSpace
        case (AVFoundationErrorDomain, AVError.operationInterrupted.rawValue?):
            return String(localized: "Video oluşturma kesintiye uğradı. Tekrar dener misin?")
        default:
            return String(localized: "Video oluşturulamadı. Tekrar dener misin?")
        }
    }
}

extension Optional where Wrapped == TemplateExportError {
    /// İptal, kullanıcı isteğidir — hata ekranı gösterilmez.
    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }
}
