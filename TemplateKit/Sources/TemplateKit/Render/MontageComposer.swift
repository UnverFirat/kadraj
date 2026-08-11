#if canImport(AVFoundation) && canImport(CoreImage)
import Foundation
import AVFoundation
import CoreImage
import CoreGraphics

/// 1. geçiş: sahneli şablonun TÜM video içeriğini tek bir ara MP4'e düzleştirir —
/// sahne sıralaması, aynı anda oynayan çoklu video slotları (kolaj), geçişler
/// (crossDissolve/blurDissolve) ve arka plan rengi.
///
/// CoreAnimationTool'un 1-video sınırı burada geçerli değil: kareleri özel
/// `MontageCompositor` (AVVideoCompositing, CoreImage) üretir. Grafik/metin/foto
/// katmanları bu dosyanın işi DEĞİLDİR — 2. geçişte kanıtlanmış CA hattı,
/// bu ara videoyu tek tam-ekran video olarak alıp üstüne biner.
public enum MontageComposer {

    public struct VideoSource {
        public var asset: AVAsset
        public var start: Double

        public init(asset: AVAsset, start: Double = 0) {
            self.asset = asset
            self.start = start
        }
    }

    /// - Parameter videos: slotIndex -> kaynak klip. Video atanmamış slotlar
    ///   sessizce atlanır (2. geçişte placeholder/foto olarak görünürler).
    public static func render(template: Template,
                              edits: UserEdits,
                              videos: [Int: VideoSource],
                              photos: [Int: CGImage] = [:],
                              outputURL: URL,
                              progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        guard let scenes = template.scenes, !scenes.isEmpty else {
            throw TemplateExportError.failed(underlying: nil)
        }
        let timeline = MontageTimeline(scenes: scenes)
        let renderSize = CGSize(width: template.canvas.width, height: template.canvas.height)
        let palette = template.resolvedPalette(override: edits.paletteOverride)
        let background = palette["background"] ?? RGBAColor(red: 0, green: 0, blue: 0)

        // Saniyeleri KARE ızgarasına oturt. AVFoundation, video composition
        // instruction sınırları frame'e oturmazsa kompozisyonu reddeder
        // (-11841 "could not be composed"). Şablon süreleri serbest yazılabilsin
        // diye snap motorda yapılır; segment sınırları hep aynı double'dan
        // türediği için komşu segmentler birbirine kilitli (boşluk/çakışma yok).
        let fps = Int32(template.canvas.fps)
        func snap(_ seconds: Double) -> CMTime {
            CMTime(value: CMTimeValue((seconds * Double(fps)).rounded()), timescale: fps)
        }

        let composition = AVMutableComposition()
        var itemsByScene: [Int: [MontageInstruction.MediaItem]] = [:]

        for window in timeline.windows {
            let scene = scenes[window.index]
            for layer in scene.layers {
                guard case .mediaSlot(let slot) = layer.content else { continue }
                let assignment = edits.slots[slot.slotIndex]
                let crop = assignment?.crop ?? CropTransform()

                // Şekilli maske: hedef kutu boyutunda alfa maskesi bir kez üretilir.
                let targetSize = CGSize(width: layer.frame.width * renderSize.width,
                                        height: layer.frame.height * renderSize.height)
                let maskImage = MaskShape.alphaMaskImage(for: slot.mask, size: targetSize)

                // kenBurns preset'i varsa efekt bilgisini çıkar; sahne penceresine
                // kilitli (compositor mutlak zamanla ilerletir).
                let kenBurns = layer.animations.first { $0.preset == "kenBurns" }.map {
                    MontageInstruction.KenBurns(
                        zoom: $0.params.double("zoom") ?? 1.1,
                        direction: $0.params.string("direction") ?? "up",
                        start: snap(window.start).seconds,
                        end: snap(window.end).seconds)
                }

                // Video kaynağı varsa (ve slot video kabul ediyorsa) video track;
                // yoksa foto kaynağı varsa foto item. Bir slotta ikisinden biri.
                if slot.media.allowsVideo, let source = videos[slot.slotIndex] {
                    guard let sourceTrack = try await source.asset
                        .loadTracks(withMediaType: .video).first else {
                        throw TemplateExportError.missingVideoTrack
                    }
                    guard let track = composition.addMutableTrack(
                        withMediaType: .video,
                        preferredTrackID: kCMPersistentTrackID_Invalid) else {
                        throw TemplateExportError.missingVideoTrack
                    }

                    let assetDuration = try await source.asset.load(.duration)
                    let clipStart = snap(source.start)
                    // Sahne penceresini frame sınırlarından türet (start/end ayrı
                    // snap → süre ikisinin farkı, komşu sahnelerle kilitli).
                    let at = snap(window.start)
                    let needed = snap(window.end) - at
                    let available = assetDuration - clipStart
                    let insertDuration = min(available, needed)
                    try track.insertTimeRange(
                        CMTimeRange(start: clipStart, duration: insertDuration),
                        of: sourceTrack, at: at)
                    if insertDuration < needed {
                        track.scaleTimeRange(CMTimeRange(start: at, duration: insertDuration),
                                             toDuration: needed)
                    }

                    let preferredTransform = try await sourceTrack.load(.preferredTransform)
                    itemsByScene[window.index, default: []].append(
                        MontageInstruction.MediaItem(
                            source: .video(trackID: track.trackID,
                                           preferredTransform: preferredTransform),
                            normalizedRect: layer.frame, crop: crop, kenBurns: kenBurns,
                            filter: slot.filter, filterIntensity: slot.filterIntensity,
                            maskImage: maskImage))
                } else if let photo = photos[slot.slotIndex] {
                    // Foto slot: track yok, compositor doğrudan çizer. Foto'lar
                    // da kolaj + geçiş (crossDissolve/blur) hattından geçer.
                    itemsByScene[window.index, default: []].append(
                        MontageInstruction.MediaItem(
                            source: .photo(photo),
                            normalizedRect: layer.frame, crop: crop, kenBurns: kenBurns,
                            filter: slot.filter, filterIntensity: slot.filterIntensity,
                            maskImage: maskImage))
                }
            }
        }

        // Talimat aralıkları kompozisyon süresini boşluksuz örtmek zorunda;
        // ayrıca video içermeyen sahnelerde bile kompozisyonun toplam süreyi
        // kapsaması gerekir -> tüm süreyi kaplayan sessiz bir taban track.
        if let baseTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let blankURL = outputURL.deletingLastPathComponent()
                .appendingPathComponent("montage-base-blank.mp4")
            try await BlankClipGenerator.generate(at: blankURL, size: renderSize,
                                                  duration: 1.0,
                                                  fps: Int32(template.canvas.fps))
            let blank = AVURLAsset(url: blankURL)
            if let blankTrack = try await blank.loadTracks(withMediaType: .video).first {
                let blankDuration = try await blank.load(.duration)
                try baseTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: blankDuration),
                    of: blankTrack, at: .zero)
                baseTrack.scaleTimeRange(
                    CMTimeRange(start: .zero, duration: blankDuration),
                    toDuration: snap(timeline.totalDuration))
            }
        }

        let instructions: [MontageInstruction] = timeline.segments.map { segment in
            let range = CMTimeRange(start: snap(segment.start), end: snap(segment.end))
            switch segment {
            case .scene(let index, _, _):
                let items = itemsByScene[index] ?? []
                return MontageInstruction(timeRange: range,
                                          items: items,
                                          fromItemCount: items.count,
                                          primaryScene: index,
                                          transition: nil,
                                          background: background)
            case .transition(let from, let to, let style, let start, let end):
                let fromItems = itemsByScene[from] ?? []
                let toItems = itemsByScene[to] ?? []
                return MontageInstruction(
                    timeRange: range,
                    items: fromItems + toItems,
                    fromItemCount: fromItems.count,
                    primaryScene: from,
                    transition: .init(from: from, to: to, style: style,
                                      start: start, end: end),
                    background: background)
            }
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = MontageCompositor.self
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1,
                                                timescale: CMTimeScale(template.canvas.fps))
        videoComposition.instructions = instructions

        try? FileManager.default.removeItem(at: outputURL)
        guard let session = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw TemplateExportError.exportSessionCreationFailed
        }
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = videoComposition

        let progressTask: Task<Void, Never>? = progress.map { report in
            Task {
                while !Task.isCancelled {
                    report(Double(session.progress))
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }
        defer { progressTask?.cancel() }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        guard session.status == .completed else {
            if session.status == .cancelled { throw TemplateExportError.cancelled }
            throw TemplateExportError.failed(underlying: session.error)
        }
        return outputURL
    }
}

// MARK: - Instruction

/// Bir zaman diliminin compositor talimatı: hangi track hangi slota, geçiş var mı.
final class MontageInstruction: NSObject, AVVideoCompositionInstructionProtocol {

    /// Bir sahnedeki tek bir medya yerleşimi — video track'i ya da foto.
    /// İkisi de aynı kolaj + geçiş hattından geçer.
    struct MediaItem {
        enum Source {
            /// Compositor kareyi `sourceFrame(byTrackID:)` ile alır.
            case video(trackID: CMPersistentTrackID, preferredTransform: CGAffineTransform)
            /// Compositor doğrudan bu görüntüyü çizer (track gerekmez).
            case photo(CGImage)
        }
        let source: Source
        /// Şablon koordinatı (normalize, merkez bazlı, y-aşağı).
        let normalizedRect: NormalizedRect
        let crop: CropTransform
        /// Sahne boyunca yavaş zoom (kenBurns preset'i). Compositor zaman-tabanlı
        /// uygular; nil ise statik.
        var kenBurns: KenBurns?
        /// Renk gradasyonu (ColorGrade preset); nil ise ham medya.
        var filter: String?
        var filterIntensity: Double = 1
        /// Şekilli maske (circle/star/heart) — hedef kutu boyutunda alfa maskesi.
        /// Composer bir kez üretir, compositor her karede CIBlendWithAlphaMask ile
        /// uygular. rect maskede nil (kırpma yeterli).
        var maskImage: CGImage?
    }

    struct KenBurns {
        let zoom: Double
        let direction: String
        /// Efektin sürdüğü mutlak zaman aralığı (montaj saniyesi).
        let start: Double
        let end: Double
    }

    struct Transition {
        let from: Int
        let to: Int
        let style: String
        let start: Double
        let end: Double
    }

    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid

    /// Geçiş talimatında sıra: önce `from` sahnesinin item'ları, sonra `to`nunkiler.
    let items: [MediaItem]
    /// `items` içinde `from` sahnesine ait olanların sayısı (compositor ayrımı).
    /// Geçişsiz talimatta items.count'a eşittir.
    let fromItemCount: Int
    let primaryScene: Int
    let transition: Transition?
    let background: RGBAColor

    init(timeRange: CMTimeRange,
         items: [MediaItem],
         fromItemCount: Int,
         primaryScene: Int,
         transition: Transition?,
         background: RGBAColor) {
        self.timeRange = timeRange
        self.items = items
        self.fromItemCount = fromItemCount
        self.primaryScene = primaryScene
        self.transition = transition
        self.background = background
        // Yalnız video item'ları track ister; foto'ların track'i yok.
        let trackIDs: [NSValue] = items.compactMap {
            if case .video(let trackID, _) = $0.source { return NSNumber(value: trackID) }
            return nil
        }
        self.requiredSourceTrackIDs = trackIDs.isEmpty ? nil : trackIDs
        super.init()
    }
}

// MARK: - Compositor

/// CoreImage tabanlı kare üretici. Her karede: sahnenin arka plan rengi +
/// aktif video slotları (aspect-fill + kullanıcı kadrajı) + varsa geçiş harmanı.
final class MontageCompositor: NSObject, AVVideoCompositing {

    // Simulator'ın GPU/IOSurface hattı çok sayıda video karesinde (kolaj +
    // her kare newPixelBuffer) tükeniyor ve QuartzCore'da IOSurface crash'i
    // veriyor. Simulator'da CPU render'a düşürülür — cihazda donanım
    // hızlandırmalı kalır (mimari fark yok, yalnızca render backend'i).
    private static let ciContext: CIContext = {
        #if targetEnvironment(simulator)
        return CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
        #else
        return CIContext(options: [.cacheIntermediates: false])
        #endif
    }()

    var sourcePixelBufferAttributes: [String: Any]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA]]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: Any] {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA]]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func cancelAllPendingVideoCompositionRequests() {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        autoreleasepool {
            guard let instruction = request.videoCompositionInstruction as? MontageInstruction,
                  let outputBuffer = request.renderContext.newPixelBuffer() else {
                request.finish(with: TemplateExportError.failed(underlying: nil))
                return
            }
            let size = request.renderContext.size
            let canvas = CGRect(origin: .zero, size: size)
            let time = CMTimeGetSeconds(request.compositionTime)

            let bg = instruction.background
            let backgroundImage = CIImage(color: CIColor(red: bg.red, green: bg.green,
                                                         blue: bg.blue))
                .cropped(to: canvas)

            func compose(_ items: ArraySlice<MontageInstruction.MediaItem>) -> CIImage {
                var result = backgroundImage
                for item in items {
                    var image: CIImage
                    switch item.source {
                    case .video(let trackID, let preferredTransform):
                        guard let buffer = request.sourceFrame(byTrackID: trackID) else {
                            continue
                        }
                        image = CIImage(cvPixelBuffer: buffer)
                            .transformed(by: preferredTransform)
                    case .photo(let cgImage):
                        image = CIImage(cgImage: cgImage)
                    }
                    // Renk gradasyonu kaynak medyaya uygulanır (transform öncesi).
                    if let filter = item.filter {
                        image = ColorGrade.apply(image, preset: filter,
                                                 intensity: item.filterIntensity)
                    }
                    // Extent'i orijine taşı (video preferredTransform sonrası
                    // negatif başlayabilir; foto zaten 0-based ama zararsız).
                    image = image.transformed(by: CGAffineTransform(
                        translationX: -image.extent.minX, y: -image.extent.minY))

                    // Şablon koordinatı y-aşağı; CoreImage y-yukarı.
                    let rect = item.normalizedRect
                    let target = CGRect(
                        x: (rect.x - rect.width / 2) * size.width,
                        y: size.height - (rect.y + rect.height / 2) * size.height,
                        width: rect.width * size.width,
                        height: rect.height * size.height)

                    // kenBurns: sahne boyunca 1→zoom yavaş büyüme + yönlü kayma.
                    var kbScale: CGFloat = 1
                    var kbPanX: CGFloat = 0, kbPanY: CGFloat = 0
                    if let kb = item.kenBurns, kb.end > kb.start {
                        let p = min(max((time - kb.start) / (kb.end - kb.start), 0), 1)
                        kbScale = 1 + CGFloat(kb.zoom - 1) * CGFloat(p)
                        // Zoom'un açtığı hareket payının yarısı kadar kayma.
                        let room = (kbScale - 1)
                        switch kb.direction {
                        case "up": kbPanY = -target.height * room * 0.5 * CGFloat(p)
                        case "down": kbPanY = target.height * room * 0.5 * CGFloat(p)
                        case "left": kbPanX = -target.width * room * 0.5 * CGFloat(p)
                        case "right": kbPanX = target.width * room * 0.5 * CGFloat(p)
                        default: break
                        }
                    }

                    let sourceSize = image.extent.size
                    let scale = max(target.width / sourceSize.width,
                                    target.height / sourceSize.height)
                        * CGFloat(item.crop.scale) * kbScale
                    image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    let scaled = image.extent.size
                    let dx = target.midX - scaled.width / 2
                        + CGFloat(item.crop.offsetX) * target.width + kbPanX
                    let dy = target.midY - scaled.height / 2
                        - CGFloat(item.crop.offsetY) * target.height + kbPanY
                    image = image.transformed(by: CGAffineTransform(translationX: dx, y: dy))
                        .cropped(to: target)

                    // Şekilli maske (circle/star/heart): alfa maskesini hedef
                    // kutuya hizalayıp uygula — dışı saydam kalır.
                    if let maskCG = item.maskImage {
                        let mask = CIImage(cgImage: maskCG)
                        let ms = mask.extent.size
                        let fit = CGAffineTransform(
                            scaleX: ms.width > 0 ? target.width / ms.width : 1,
                            y: ms.height > 0 ? target.height / ms.height : 1)
                        let placed = mask.transformed(by: fit)
                            .transformed(by: CGAffineTransform(translationX: target.minX,
                                                               y: target.minY))
                        image = image.applyingFilter("CIBlendWithAlphaMask", parameters: [
                            kCIInputBackgroundImageKey: CIImage.empty(),
                            kCIInputMaskImageKey: placed
                        ])
                    }
                    result = image.composited(over: result)
                }
                return result
            }

            let output: CIImage
            if let transition = instruction.transition {
                // Composer, items dizisini [from-sahnesi..., to-sahnesi...]
                // sırasıyla doldurur; fromCount ile ikiye ayrılır.
                let fromCount = instruction.fromItemCount
                let fromImage = compose(instruction.items.prefix(fromCount))
                let toImage = compose(instruction.items.suffix(from: fromCount))
                let duration = max(transition.end - transition.start, 0.001)
                let p = min(max((time - transition.start) / duration, 0), 1)
                output = MontageCompositor.blend(style: transition.style, progress: p,
                                                 from: fromImage, to: toImage,
                                                 canvas: canvas).cropped(to: canvas)
            } else {
                output = compose(instruction.items[...])
            }

            MontageCompositor.ciContext.render(
                output, to: outputBuffer, bounds: canvas,
                colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            request.finish(withComposedVideoFrame: outputBuffer)
        }
    }

    // MARK: - Geçiş harmanları

    /// İki sahne karesini geçiş stiline göre progress p∈[0,1] ile harmanlar.
    /// Tanınmayan stil crossDissolve'a düşer (overlap zaten varsayıldığı için
    /// güvenli — MontageTimeline.overlappingStyles ile tutarlı).
    static func blend(style: String, progress p: CGFloat,
                      from: CIImage, to: CIImage, canvas: CGRect) -> CIImage {
        let w = canvas.width, h = canvas.height
        func slide(dx: CGFloat, dy: CGFloat) -> CIImage {
            // from dışarı, to içeri kayar (aynı yönde, push etkisi).
            let fromOut = from.transformed(by: CGAffineTransform(
                translationX: -dx * p, y: -dy * p))
            let toIn = to.transformed(by: CGAffineTransform(
                translationX: dx * (1 - p), y: dy * (1 - p)))
            return toIn.composited(over: fromOut)
        }

        switch style {
        case "slide", "slideLeft":  return slide(dx: w, dy: 0)
        case "slideRight":          return slide(dx: -w, dy: 0)
        case "slideUp":             return slide(dx: 0, dy: -h)
        case "slideDown":           return slide(dx: 0, dy: h)

        case "zoomIn", "zoomOut":
            // from büyüyerek kaybolur, to küçülerek girer (ya da tersi).
            let zoomingIn = style == "zoomIn"
            let center = CGPoint(x: canvas.midX, y: canvas.midY)
            func scaled(_ img: CIImage, _ s: CGFloat) -> CIImage {
                let t = CGAffineTransform(translationX: center.x, y: center.y)
                    .scaledBy(x: s, y: s)
                    .translatedBy(x: -center.x, y: -center.y)
                return img.transformed(by: t)
            }
            let fromS = scaled(from, zoomingIn ? 1 + p * 0.6 : 1 - p * 0.4)
            let toS = scaled(to, zoomingIn ? 1.4 - p * 0.4 : 0.7 + p * 0.3)
            return dissolve(scaled: fromS, toS, p: p, canvas: canvas)

        case "whip":
            // Hızlı yatay kayma + ortada yoğun motion blur (CapCut whip pan).
            let radius = sin(p * .pi) * 60
            var a = from.transformed(by: CGAffineTransform(translationX: -w * p, y: 0))
            var b = to.transformed(by: CGAffineTransform(translationX: w * (1 - p), y: 0))
            if radius > 0.5 {
                a = a.clampedToExtent().applyingGaussianBlur(sigma: radius)
                b = b.clampedToExtent().applyingGaussianBlur(sigma: radius)
            }
            return b.composited(over: a)

        case "blurDissolve":
            let radius = sin(p * .pi) * 30
            var a = from, b = to
            if radius > 0.5 {
                a = a.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: canvas)
                b = b.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: canvas)
            }
            return dissolve(scaled: a, b, p: p, canvas: canvas)

        default: // crossDissolve ve tanınmayan
            return dissolve(scaled: from, to, p: p, canvas: canvas)
        }
    }

    private static func dissolve(scaled a: CIImage, _ b: CIImage,
                                 p: CGFloat, canvas: CGRect) -> CIImage {
        guard let filter = CIFilter(name: "CIDissolveTransition") else { return b }
        filter.setValue(a.cropped(to: canvas), forKey: kCIInputImageKey)
        filter.setValue(b.cropped(to: canvas), forKey: kCIInputTargetImageKey)
        filter.setValue(p, forKey: kCIInputTimeKey)
        return filter.outputImage ?? b
    }
}
#endif
