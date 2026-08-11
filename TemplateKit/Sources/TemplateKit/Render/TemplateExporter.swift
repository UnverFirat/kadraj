#if canImport(AVFoundation) && canImport(QuartzCore)
import Foundation
import AVFoundation
import QuartzCore
import CoreGraphics

public enum TemplateExportError: Error {
    case missingVideoTrack
    case missingBlankClip
    case exportSessionCreationFailed
    case cancelled
    case failed(underlying: Error?)
}

/// Şablon + düzenlemeler -> MP4 (1080x1920, H.264).
///
/// İki yol:
/// - Sahnesiz (v1) şablon: AVMutableComposition + CoreAnimationTool, tek geçiş.
///   En fazla 1 video slotu (CoreAnimationTool sınırı).
/// - Sahneli (v2/montaj) şablon: 1. geçişte MontageComposer tüm video içeriğini
///   (kolaj, sıralama, geçişler) tek ara videoya düzleştirir; 2. geçişte o video
///   tam-kanvas taban olarak buradan geçer ve grafik/metin/foto katmanları
///   kanıtlanmış CA hattıyla üstüne biner.
///
/// Pro/filigran kararı parametre olarak gelir; motor abonelik sistemini bilmez.
public final class TemplateExporter {

    public struct VideoInput {
        public var asset: AVAsset
        public var slotIndex: Int
        /// Kullanıcının seçtiği başlangıç saniyesi (SlotAssignment.videoStart).
        public var start: Double

        public init(asset: AVAsset, slotIndex: Int, start: Double = 0) {
            self.asset = asset
            self.slotIndex = slotIndex
            self.start = start
        }
    }

    public struct AudioInput {
        public var asset: AVAsset
        public var start: Double
        public var volume: Float

        public init(asset: AVAsset, start: Double = 0, volume: Float = 1) {
            self.asset = asset
            self.start = start
            self.volume = volume
        }
    }

    public struct Request {
        public var template: Template
        public var edits: UserEdits
        /// slotIndex -> çözülmüş fotoğraf (çağıran PHAsset'ten hazırlar).
        public var photos: [Int: CGImage]
        /// Video atanmış slotların klipleri. Sahnesiz şablonda en fazla 1 kullanılır.
        public var videos: [VideoInput]
        public var audio: AudioInput?
        /// Free kullanıcıda true; watermark katmanını exporter ekler.
        public var includeWatermark: Bool
        public var watermarkImage: CGImage?
        /// Filigran yazısı. Motor uygulamanın adını bilmez — marka adı
        /// uygulama katmanında tek yerde durur (`AppInfo.displayName`).
        public var watermarkText: String
        /// Ara dosyalar ve foto-only taban klibi için çalışma dizini.
        public var workDirectory: URL
        public var outputURL: URL

        public init(template: Template,
                    edits: UserEdits,
                    photos: [Int: CGImage] = [:],
                    videos: [VideoInput] = [],
                    audio: AudioInput? = nil,
                    includeWatermark: Bool,
                    watermarkImage: CGImage? = nil,
                    watermarkText: String = "Made with StoryTemplate",
                    workDirectory: URL,
                    outputURL: URL) {
            self.template = template
            self.edits = edits
            self.photos = photos
            self.videos = videos
            self.audio = audio
            self.includeWatermark = includeWatermark
            self.watermarkImage = watermarkImage
            self.watermarkText = watermarkText
            self.workDirectory = workDirectory
            self.outputURL = outputURL
        }
    }

    private var session: AVAssetExportSession?

    public init() {}

    public func cancel() {
        session?.cancelExport()
    }

    /// Arka planda render; `progress` 0-1 arası çağrılır (ana kuyrukta değil).
    public func export(_ request: Request,
                       progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        if let scenes = request.template.scenes, !scenes.isEmpty {
            // 1. geçiş: montaj (ilerleme payı 0-0.5).
            let montageURL = request.workDirectory
                .appendingPathComponent("montage-intermediate.mp4")
            var sources: [Int: MontageComposer.VideoSource] = [:]
            for input in request.videos {
                sources[input.slotIndex] = MontageComposer.VideoSource(asset: input.asset,
                                                                       start: input.start)
            }
            _ = try await MontageComposer.render(template: request.template,
                                                 edits: request.edits,
                                                 videos: sources,
                                                 photos: request.photos,
                                                 outputURL: montageURL) { p in
                progress?(p * 0.5)
            }
            defer {
                try? FileManager.default.removeItem(at: montageURL)
                try? FileManager.default.removeItem(at: request.workDirectory
                    .appendingPathComponent("montage-base-blank.mp4"))
            }
            // 2. geçiş: montaj tam-kanvas taban video (ilerleme payı 0.5-1).
            let base = BaseVideo(asset: AVURLAsset(url: montageURL),
                                 start: 0, slotIndex: nil, isMontage: true)
            return try await compositeAndExport(request, baseVideo: base,
                                                progressOffset: 0.5, progress: progress)
        }

        let base = request.videos.first.map {
            BaseVideo(asset: $0.asset, start: $0.start,
                      slotIndex: $0.slotIndex, isMontage: false)
        }
        return try await compositeAndExport(request, baseVideo: base,
                                            progressOffset: 0, progress: progress)
    }

    // MARK: - Core (2. geçiş / v1 tek geçiş)

    private struct BaseVideo {
        let asset: AVAsset
        let start: Double
        let slotIndex: Int?
        let isMontage: Bool
    }

    private func compositeAndExport(_ request: Request,
                                    baseVideo: BaseVideo?,
                                    progressOffset: Double,
                                    progress: (@Sendable (Double) -> Void)?) async throws -> URL {
        let template = request.template
        let renderSize = CGSize(width: template.canvas.width, height: template.canvas.height)
        let duration = template.totalDuration
        let fullRange = CMTimeRange(start: .zero,
                                    duration: CMTime(seconds: duration,
                                                     preferredTimescale: 600))

        // 1) Komposizyon: taban video track (klip/montaj/blank) + müzik.
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw TemplateExportError.missingVideoTrack
        }

        if let base = baseVideo {
            let sourceTracks = try await base.asset.loadTracks(withMediaType: .video)
            guard let sourceTrack = sourceTracks.first else {
                throw TemplateExportError.missingVideoTrack
            }
            let assetDuration = try await base.asset.load(.duration)
            let start = CMTime(seconds: base.start, preferredTimescale: 600)
            let available = assetDuration - start
            let wanted = fullRange.duration
            let range = CMTimeRange(start: start, duration: min(available, wanted))
            try videoTrack.insertTimeRange(range, of: sourceTrack, at: .zero)
            // Klip şablondan kısaysa son bölümü uzat (son karede donma etkisi).
            if range.duration < wanted {
                videoTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: range.duration),
                                          toDuration: wanted)
            }
        } else {
            let blankURL = request.workDirectory.appendingPathComponent("export-blank.mp4")
            try await BlankClipGenerator.generate(at: blankURL, size: renderSize,
                                                  fps: Int32(template.canvas.fps))
            let blank = AVURLAsset(url: blankURL)
            let blankTracks = try await blank.loadTracks(withMediaType: .video)
            guard let blankTrack = blankTracks.first else {
                throw TemplateExportError.missingBlankClip
            }
            let blankDuration = try await blank.load(.duration)
            try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: blankDuration),
                                           of: blankTrack, at: .zero)
            videoTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: blankDuration),
                                      toDuration: fullRange.duration)
        }

        var audioMix: AVAudioMix?
        if let audio = request.audio {
            let sourceTracks = try await audio.asset.loadTracks(withMediaType: .audio)
            if let sourceTrack = sourceTracks.first,
               let audioTrack = composition.addMutableTrack(
                   withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                let start = CMTime(seconds: audio.start, preferredTimescale: 600)
                let assetDuration = try await audio.asset.load(.duration)
                let range = CMTimeRange(start: start,
                                        duration: min(assetDuration - start, fullRange.duration))
                try audioTrack.insertTimeRange(range, of: sourceTrack, at: .zero)

                let parameters = AVMutableAudioMixInputParameters(track: audioTrack)
                parameters.setVolume(audio.volume, at: .zero)
                // Son 0.5 sn fade-out — ani kesilme hissini yok eder.
                let fadeStart = CMTime(seconds: max(0, duration - 0.5),
                                       preferredTimescale: 600)
                parameters.setVolumeRamp(fromStartVolume: audio.volume, toEndVolume: 0,
                                         timeRange: CMTimeRange(start: fadeStart,
                                                                end: fullRange.end))
                let mix = AVMutableAudioMix()
                mix.inputParameters = [parameters]
                audioMix = mix
            }
        }

        // 2) Katman ağacı (export zaman tabanıyla).
        let context = RenderContext(
            canvasSize: renderSize,
            displayScale: 1,
            duration: duration,
            baseTime: AVCoreAnimationBeginTimeAtZero,
            palette: template.resolvedPalette(override: request.edits.paletteOverride))
        let scene = TemplateLayerBuilder.build(template: template,
                                               edits: request.edits,
                                               photos: request.photos,
                                               context: context,
                                               prerenderedVideo: baseVideo?.isMontage == true)

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        // CoreAnimationTool CG koordinat sisteminde render eder.
        parentLayer.isGeometryFlipped = true

        let videoLayer: CALayer
        if let slotLayer = scene.videoSlotLayer {
            videoLayer = slotLayer            // video kareleri slotun/tabanın içine çizilir
            parentLayer.addSublayer(scene.root)
        } else {
            // Blank klip: videoLayer zorunlu ama görünmemeli — sahnenin altında kalır.
            videoLayer = CALayer()
            videoLayer.frame = parentLayer.frame
            parentLayer.addSublayer(videoLayer)
            parentLayer.addSublayer(scene.root)
        }

        if request.includeWatermark {
            parentLayer.addSublayer(makeWatermarkLayer(canvasSize: renderSize,
                                                       image: request.watermarkImage,
                                                       text: request.watermarkText))
        }

        // 3) Video kompozisyonu.
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(template.canvas.fps))
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayers: [videoLayer], in: parentLayer)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = fullRange
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        if let base = baseVideo, !base.isMontage {
            // Kullanıcı klibi: kadrajla (zoom/pan) renderSize'ı doldur.
            // Montajda gereksiz: boyutlar birebir aynı.
            let slotAssignment = base.slotIndex.flatMap { request.edits.slots[$0] }
            layerInstruction.setTransform(
                try await fillTransform(for: videoTrack,
                                        renderSize: renderSize,
                                        crop: slotAssignment?.crop ?? CropTransform()),
                at: .zero)
        }
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // 4) Export.
        try? FileManager.default.removeItem(at: request.outputURL)
        guard let session = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw TemplateExportError.exportSessionCreationFailed
        }
        session.outputURL = request.outputURL
        session.outputFileType = .mp4
        session.videoComposition = videoComposition
        session.audioMix = audioMix
        self.session = session

        let progressTask: Task<Void, Never>? = progress.map { report in
            Task {
                while !Task.isCancelled {
                    report(progressOffset + Double(session.progress) * (1 - progressOffset))
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }
        defer { progressTask?.cancel() }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }

        switch session.status {
        case .completed:
            progress?(1.0)
            return request.outputURL
        case .cancelled:
            throw TemplateExportError.cancelled
        default:
            throw TemplateExportError.failed(underlying: session.error)
        }
    }

    // MARK: - Helpers

    /// Kaynak videoyu renderSize'ı aspect-fill dolduracak şekilde dönüştürür,
    /// kullanıcı kadrajını (zoom/pan) üstüne bindirir.
    private func fillTransform(for track: AVAssetTrack,
                               renderSize: CGSize,
                               crop: CropTransform) async throws -> CGAffineTransform {
        let naturalSize = try await track.load(.naturalSize)
        let preferred = try await track.load(.preferredTransform)
        let oriented = naturalSize.applying(preferred)
        let sourceSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))

        let scale = max(renderSize.width / sourceSize.width,
                        renderSize.height / sourceSize.height) * CGFloat(crop.scale)
        let scaledSize = CGSize(width: sourceSize.width * scale,
                                height: sourceSize.height * scale)
        let tx = (renderSize.width - scaledSize.width) / 2
            + CGFloat(crop.offsetX) * renderSize.width
        let ty = (renderSize.height - scaledSize.height) / 2
            + CGFloat(crop.offsetY) * renderSize.height

        return preferred
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
    }

    private func makeWatermarkLayer(canvasSize: CGSize, image: CGImage?,
                                    text: String) -> CALayer {
        // Ağaç isGeometryFlipped (y aşağı) olduğundan sağ alt = büyük y.
        let margin: CGFloat = canvasSize.width * 0.04
        let layer = CALayer()
        if let image {
            let width = canvasSize.width * 0.22
            let height = width * CGFloat(image.height) / CGFloat(image.width)
            layer.contents = image
            layer.opacity = 0.7
            layer.frame = CGRect(x: canvasSize.width - width - margin,
                                 y: canvasSize.height - height - margin,
                                 width: width, height: height)
            return layer
        }
        let size = CGSize(width: canvasSize.width * 0.5,
                          height: canvasSize.height * 0.03)
        let spec = TextRasterizer.Spec(
            text: text,
            fontName: "HelveticaNeue-Medium",
            fontSize: canvasSize.height * 0.016,
            color: CGColor(gray: 1, alpha: 0.6),
            alignment: .right,
            size: size,
            scale: 1)
        layer.contents = TextRasterizer.rasterize(spec)
        layer.frame = CGRect(x: canvasSize.width - size.width - margin,
                             y: canvasSize.height - size.height - margin,
                             width: size.width, height: size.height)
        return layer
    }
}
#endif
