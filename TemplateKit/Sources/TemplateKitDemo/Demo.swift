import Foundation
import TemplateKit
import TemplateKitLottie
import AVFoundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Export hattının uçtan uca kanıtı (macOS, headless).
///
/// - v1 (sahnesiz) şablon: foto + metin, CoreAnimationTool tek geçiş.
/// - v2 (montaj) şablon: sentetik renkli/hareketli test klipleri üretilir,
///   MontageComposer ile kolaj+geçiş+sıralama düzleştirilir, sonra grafik/metin
///   katmanları biner. Video slotları içeren şablonda gerçek klip gerekmez —
///   üreteç her slota etiketli hareketli bir klip verir ki kolaj ve geçişler
///   kare kontrolünde net görülsün.
///
/// Kullanım (TemplateKit dizininden):
///   swift run templatekit-demo [şablon.json] [çıktı-dizini]
///   swift run -c release templatekit-demo --music [parça-id] [saniye]
///     → kütüphanedeki parçaları demo-output/music/ altına WAV olarak yazar
///       (dinleyip beğenmediğini söyleyebilmen için; release'de çok daha hızlı).
@main
struct Demo {
    static func main() async throws {
        let arguments = CommandLine.arguments
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        if arguments.count > 1, arguments[1] == "--music" {
            try renderMusic(id: arguments.count > 2 ? arguments[2] : nil,
                            seconds: arguments.count > 3 ? Double(arguments[3]) ?? 20 : 20,
                            outputDir: cwd.appendingPathComponent("demo-output/music"))
            return
        }
        let templateURL = arguments.count > 1
            ? URL(fileURLWithPath: arguments[1])
            : cwd.deletingLastPathComponent()
                .appendingPathComponent("templates/reel-collage-01.json")
        let outputDir = arguments.count > 2
            ? URL(fileURLWithPath: arguments[2])
            : cwd.appendingPathComponent("demo-output")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Lottie katmanları gerçek animasyonla çıksın: varlıklar şablonun
        // yanındaki `assets/` klasöründe (renderer takılmazsa yer tutucu).
        LottieRendererRegistry.install(
            LottieAdapter(searchDirectories: [templateURL.deletingLastPathComponent()]))

        print("Şablon: \(templateURL.path)")
        let template = try JSONDecoder().decode(Template.self,
                                                from: Data(contentsOf: templateURL))
        try TemplateValidator.validate(template)
        let sceneInfo = template.scenes.map { "\($0.count) sahne" } ?? "sahnesiz"
        print(String(format: "Validasyon: OK (%@, %.1fs toplam)",
                     sceneInfo, template.totalDuration))

        var edits = UserEdits(textOverrides: [:])
        var videoInputs: [TemplateExporter.VideoInput] = []
        var photos: [Int: CGImage] = [:]

        let mediaSlots = template.mediaSlots
        if template.scenes != nil, !mediaSlots.isEmpty {
            // Montaj: video slotlara sentetik klip, foto slotlara sentetik foto.
            let colors: [CGColor] = [
                CGColor(srgbRed: 0.85, green: 0.35, blue: 0.30, alpha: 1),
                CGColor(srgbRed: 0.30, green: 0.55, blue: 0.80, alpha: 1),
                CGColor(srgbRed: 0.35, green: 0.70, blue: 0.45, alpha: 1),
                CGColor(srgbRed: 0.75, green: 0.55, blue: 0.25, alpha: 1),
                CGColor(srgbRed: 0.55, green: 0.35, blue: 0.70, alpha: 1)
            ]
            var vi = 0, pi = 0
            for m in mediaSlots {
                if m.allowsVideo {
                    let clipURL = outputDir.appendingPathComponent("clip-slot\(m.slot).mp4")
                    try await SyntheticClip.generate(at: clipURL, label: "slot \(m.slot)",
                                                     color: colors[vi % colors.count], duration: 5.0)
                    videoInputs.append(.init(asset: AVURLAsset(url: clipURL), slotIndex: m.slot))
                    edits.slots[m.slot] = SlotAssignment(assetIdentifier: clipURL.path, kind: .video)
                    vi += 1
                } else {
                    photos[m.slot] = makeLabeledPhoto(index: pi, slot: m.slot)
                    edits.slots[m.slot] = SlotAssignment(assetIdentifier: "photo", kind: .photo)
                    pi += 1
                }
            }
            print("Montaj medya: \(videoInputs.count) klip, \(photos.count) foto")
        } else {
            // Klasik (sahnesiz) yol: her foto slotuna örnek foto.
            let slots = mediaSlots
            if slots.isEmpty {
                photos[0] = makePlaceholderPhoto()
            } else {
                for (i, m) in slots.enumerated() {
                    photos[m.slot] = makeLabeledPhoto(index: i, slot: m.slot)
                }
            }
        }

        // Müzik: şablonun önerdiği parça, kütüphaneden çalışma anında sentezlenir.
        var audio: TemplateExporter.AudioInput?
        if let track = MusicLibrary.defaultTrack(for: template) {
            let musicURL = try MusicLibrary.materialize(trackID: track.id,
                                                        duration: template.totalDuration,
                                                        in: outputDir)
            audio = TemplateExporter.AudioInput(
                asset: AVURLAsset(url: musicURL),
                volume: Float(template.audio?.volume ?? 1))
            print("Müzik: \(track.title.resolved(languageCode: "tr")) (\(track.id), \(track.bpm) BPM)")
        }

        let request = TemplateExporter.Request(
            template: template,
            edits: edits,
            photos: photos,
            videos: videoInputs,
            audio: audio,
            includeWatermark: true,
            workDirectory: outputDir,
            outputURL: outputDir.appendingPathComponent("export.mp4"))

        let start = Date()
        let exporter = TemplateExporter()
        let outputURL = try await exporter.export(request) { progress in
            print(String(format: "  render %%%.0f", progress * 100))
        }
        let elapsed = Date().timeIntervalSince(start)

        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let bytes = (attributes[.size] as? Int) ?? 0
        let asset = AVURLAsset(url: outputURL)
        let duration = try await asset.load(.duration).seconds
        print(String(format: "Export: %@ — %.1fs video, %.2f MB, %.1fs sürdü",
                     outputURL.lastPathComponent, duration,
                     Double(bytes) / 1_048_576, elapsed))

        // Kontrol kareleri: toplam süreyi eşit aralıklarla örnekle
        // (kolaj, geçişler ve tam-ekran sahneler yakalansın).
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        // Kontrol kareleri gözle bakmak için; küçük tutmak inceleme maliyetini
        // düşürür (düzen/renk/animasyon bu boyutta net görünür).
        generator.maximumSize = CGSize(width: 480, height: 854)
        let sampleCount = 8
        for i in 0..<sampleCount {
            let seconds = duration * (Double(i) + 0.5) / Double(sampleCount)
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            let image = try generator.copyCGImage(at: time, actualTime: nil)
            let frameURL = outputDir.appendingPathComponent(
                String(format: "frame-%04.1fs.png", seconds))
            try writePNG(image, to: frameURL)
            print("Kare: \(frameURL.lastPathComponent)")
        }
        print("Bitti → \(outputDir.path)")
    }

    /// Foto montaj (slideshow/kolaj) için etiketli renkli test fotoğrafı.
    /// Ardışık slotlar farklı renk → geçişler (crossDissolve) kare kontrolünde net.
    static func makeLabeledPhoto(index: Int, slot: Int,
                                 width: Int = 1080, height: Int = 1350) -> CGImage {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let tints: [(CGFloat, CGFloat, CGFloat)] = [
            (0.90, 0.50, 0.42), (0.35, 0.55, 0.72), (0.45, 0.68, 0.52),
            (0.78, 0.62, 0.35), (0.58, 0.45, 0.70)
        ]
        let t = tints[index % tints.count]
        let g = CGGradient(colorsSpace: cs, colors: [
            CGColor(srgbRed: t.0, green: t.1, blue: t.2, alpha: 1),
            CGColor(srgbRed: t.0 * 0.55, green: t.1 * 0.55, blue: t.2 * 0.55, alpha: 1)
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(height)),
                               end: CGPoint(x: CGFloat(width), y: 0), options: [])
        // Köşe işareti (foto numarası) — yön/geçiş kontrolü için.
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
        ctx.fillEllipse(in: CGRect(x: CGFloat(width) * 0.4, y: CGFloat(height) * 0.42,
                                   width: CGFloat(width) * 0.2, height: CGFloat(width) * 0.2))
        return ctx.makeImage()!
    }

    /// Yön/flip hatalarını görünür kılan asimetrik test görseli.
    static func makePlaceholderPhoto(width: Int = 1200, height: Int = 1500) -> CGImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: 0,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [CGColor(srgbRed: 0.55, green: 0.65, blue: 0.80, alpha: 1),
                     CGColor(srgbRed: 0.12, green: 0.16, blue: 0.24, alpha: 1)] as CFArray,
            locations: [0, 1])!
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: CGFloat(height)),
                                   end: CGPoint(x: 0, y: 0),
                                   options: [])
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
        context.fillEllipse(in: CGRect(x: 80, y: CGFloat(height) - 380,
                                       width: 300, height: 300))
        context.setFillColor(CGColor(srgbRed: 0.05, green: 0.05, blue: 0.08, alpha: 0.9))
        context.fill(CGRect(x: CGFloat(width) - 340, y: 90, width: 250, height: 250))
        return context.makeImage()!
    }

    /// Müzik kütüphanesini WAV olarak diske döker (dinleyerek değerlendirme için).
    static func renderMusic(id: String?, seconds: Double, outputDir: URL) throws {
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let tracks = id.map { wanted in MusicLibrary.all.filter { $0.id == wanted } }
            ?? MusicLibrary.all
        guard !tracks.isEmpty else {
            print("Parça bulunamadı: \(id ?? "-")")
            return
        }
        for track in tracks {
            let start = Date()
            // Cache'i atla — her koşuda güncel sentezi duymak istiyoruz.
            let file = outputDir.appendingPathComponent("\(track.id).wav")
            try? FileManager.default.removeItem(at: file)
            _ = try MusicLibrary.materialize(trackID: track.id, duration: seconds,
                                             in: outputDir)
            try? FileManager.default.moveItem(
                at: outputDir.appendingPathComponent(
                    "\(track.id)-s\(AudioSynth.version)-\(Int(seconds * 10)).wav"),
                to: file)
            print(String(format: "%@ — %@ · %@ · %d BPM · %.1fs sentez",
                         track.id, track.title.resolved(languageCode: "tr"),
                         track.mood.rawValue, track.bpm, Date().timeIntervalSince(start)))
        }
        print("→ \(outputDir.path)")
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

/// Etiketli, hareketli sentetik test klibi üretici. Düz renk + hareket eden
/// beyaz nokta (her karede yer değiştirir) + köşe işareti → kolajda hangi
/// klibin nerede olduğu ve geçişlerin harmanı kare kontrolünde net görülür.
enum SyntheticClip {
    static func generate(at url: URL, label: String, color: CGColor,
                         size: CGSize = CGSize(width: 1080, height: 1920),
                         duration: Double = 5.0, fps: Int32 = 30) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let frameCount = Int(duration * Double(fps))
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else { break }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
            guard let buffer = pb else { continue }
            CVPixelBufferLockBaseAddress(buffer, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                width: Int(size.width), height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                    | CGBitmapInfo.byteOrder32Little.rawValue)!
            ctx.setFillColor(color)
            ctx.fill(CGRect(origin: .zero, size: size))
            // Hareketli beyaz nokta (soldan sağa).
            let p = Double(frame) / Double(max(1, frameCount - 1))
            let dot = CGRect(x: p * (Double(size.width) - 160) + 40,
                             y: Double(size.height) * 0.5 - 60, width: 120, height: 120)
            ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95))
            ctx.fillEllipse(in: dot)
            // Etiket metni (üstte).
            if let img = TextImage.make(label, size: CGSize(width: size.width * 0.8,
                                                            height: size.height * 0.2),
                                        fontSize: size.height * 0.03) {
                ctx.draw(img, in: CGRect(x: size.width * 0.1, y: size.height * 0.72,
                                         width: size.width * 0.8, height: size.height * 0.2))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame),
                                                                timescale: fps))
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }
}

/// Basit CoreText -> CGImage (demo etiketleri için; ürün TextRasterizer kullanır).
enum TextImage {
    static func make(_ text: String, size: CGSize, fontSize: CGFloat) -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String):
                CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(gray: 1, alpha: 1)
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        let ctFrame = CTFramesetterCreateFrame(framesetter,
                                               CFRange(location: 0, length: 0), path, nil)
        CTFrameDraw(ctFrame, ctx)
        return ctx.makeImage()
    }
}
