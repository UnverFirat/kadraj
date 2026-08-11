import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import ImageIO

/// Vitrin varlıklarını (`thumbs/`, `previews/`) doldururken kullanılan örnek
/// kliplerin ÜRETİCİSİ.
///
/// NEDEN VAR: bu klipler galeri posterlerinin içine giriyor, yani uygulamayla
/// ve CDN'le dağıtılıyor. Kaynağı belirsiz bir görüntüyü (özellikle tanınabilir
/// insan içereni) dağıtmak telif ve kişilik hakkı riski; App Store incelemesi
/// de içerik haklarını beyan ettiriyor. Bu yüzden örnek medya SIFIRDAN
/// üretiliyor: soyut manzaralar (gökyüzü gradyanı, güneş/ay, silüet katmanları,
/// bokeh, tanecik). İnsan yok, marka yok, gerçek yer yok — hak zinciri
/// tamamen bizde.
///
/// Kullanım:
///   swift run -c release templatekit-assets --make-samples
enum SampleClipGenerator {

    /// On örnek sahne.
    ///
    /// İlk beşi manzara; kalan beşi FARKLI KOMPOZİSYONLAR. Neden: katalog 100
    /// şablona çıkınca kontak baskısında her posterin arkasında aynı
    /// "gökyüzü + güneş + dağ silüeti" iskeleti çıkıyordu — renkler değişiyor
    /// ama kadraj aynı kaldığı için şablonlar birbirine benziyor gibi
    /// görünüyordu. Oysa ayırt edici olan kompozisyondur: bir kafe iç mekânı,
    /// tepeden çekilmiş bir tabak ve bir portre kadrajı, aynı şablonu bambaşka
    /// gösterir. Yemek/moda/güzellik şablonlarının vitrini de artık konusuna
    /// yakın bir görüntüyle çıkıyor.
    enum Scene: String, CaseIterable {
        case sunset, ocean, forest, night, desert
        case city, cafe, plate, studio, fabric

        /// Hangi çizim rutini kullanılacak.
        enum Kind { case landscape, city, interior, tableTop, portrait, weave }

        var kind: Kind {
            switch self {
            case .sunset, .ocean, .forest, .night, .desert: return .landscape
            case .city:   return .city
            case .cafe:   return .interior
            case .plate:  return .tableTop
            case .studio: return .portrait
            case .fabric: return .weave
            }
        }

        /// (üst, orta, alt) gökyüzü renkleri.
        var sky: [(Double, Double, Double)] {
            switch self {
            case .sunset: return [(0.29, 0.24, 0.45), (0.93, 0.52, 0.38), (0.98, 0.79, 0.52)]
            case .ocean:  return [(0.10, 0.28, 0.44), (0.19, 0.53, 0.63), (0.62, 0.83, 0.82)]
            case .forest: return [(0.09, 0.20, 0.18), (0.20, 0.42, 0.31), (0.63, 0.76, 0.51)]
            case .night:  return [(0.04, 0.05, 0.14), (0.10, 0.12, 0.28), (0.28, 0.24, 0.44)]
            case .desert: return [(0.35, 0.30, 0.42), (0.85, 0.60, 0.42), (0.96, 0.85, 0.66)]
            case .city:   return [(0.05, 0.06, 0.13), (0.16, 0.13, 0.28), (0.42, 0.26, 0.36)]
            case .cafe:   return [(0.20, 0.13, 0.09), (0.46, 0.31, 0.20), (0.83, 0.68, 0.48)]
            case .plate:  return [(0.88, 0.84, 0.78), (0.80, 0.75, 0.68), (0.70, 0.64, 0.56)]
            case .studio: return [(0.30, 0.26, 0.30), (0.55, 0.48, 0.50), (0.80, 0.74, 0.72)]
            case .fabric: return [(0.14, 0.25, 0.32), (0.22, 0.40, 0.47), (0.40, 0.60, 0.63)]
            }
        }

        /// Silüet katmanlarının rengi (koyudan açığa doğru katman katman).
        var silhouette: (Double, Double, Double) {
            switch self {
            case .sunset: return (0.16, 0.11, 0.20)
            case .ocean:  return (0.06, 0.16, 0.26)
            case .forest: return (0.05, 0.13, 0.11)
            case .night:  return (0.02, 0.03, 0.08)
            case .desert: return (0.42, 0.26, 0.22)
            case .city:   return (0.03, 0.04, 0.10)
            case .cafe:   return (0.13, 0.08, 0.05)
            case .plate:  return (0.52, 0.46, 0.38)
            case .studio: return (0.22, 0.19, 0.21)
            case .fabric: return (0.08, 0.16, 0.21)
            }
        }

        /// Işık kaynağının (güneş/ay) rengi ve büyüklüğü (kanvas oranı).
        var light: (color: (Double, Double, Double), radius: Double) {
            switch self {
            case .sunset: return ((1.00, 0.87, 0.62), 0.16)
            case .ocean:  return ((1.00, 0.97, 0.88), 0.10)
            case .forest: return ((0.95, 0.98, 0.80), 0.09)
            case .night:  return ((0.92, 0.94, 1.00), 0.07)
            case .desert: return ((1.00, 0.93, 0.72), 0.14)
            case .city:   return ((1.00, 0.86, 0.60), 0.06)
            case .cafe:   return ((1.00, 0.88, 0.66), 0.13)
            case .plate:  return ((1.00, 0.98, 0.94), 0.10)
            case .studio: return ((1.00, 0.96, 0.92), 0.12)
            case .fabric: return ((0.85, 0.95, 1.00), 0.08)
            }
        }

        /// Silüet tepe sayısı — dalga (az tepe) ile orman (çok tepe) farkı.
        var ridges: Int {
            switch self {
            case .sunset: return 3
            case .ocean:  return 2
            case .forest: return 9
            case .night:  return 5
            case .desert: return 2
            case .city:   return 6
            case .cafe:   return 3
            case .plate:  return 2
            case .studio: return 2
            case .fabric: return 4
            }
        }
    }

    /// `source/` altındaki GERÇEK fotoğrafları yavaş zoom'lu kliplere çevirir.
    ///
    /// Sentetik sahneler hak zinciri temiz ama gerçek fotoğraf kadar satmıyor
    /// (gerçek görselle test edilince şablonların belirgin biçimde daha iyi
    /// göründüğü ölçüldü). Buraya konan her dosya poster ve önizlemelerin
    /// içine girip DAĞITILDIĞI için yalnız hakkı bizde olan görseller
    /// konmalı — `source/CREDITS.md` bunun kaydıdır.
    ///
    /// Dosya yoksa üreteç tamamen sentetik sahnelere düşer, yani bu klasör
    /// boşken de her şey çalışır.
    static func generatePhotoClips(from directory: URL, into output: URL,
                                   startingAt index: Int,
                                   size: CGSize, duration: Double,
                                   fps: Int) async throws -> Int {
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !files.isEmpty else { return 0 }

        for (offset, file) in files.enumerated() {
            guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
            // Ad TÜRÜ taşır: `MediaPool` klibin ne olduğunu dosya adından
            // anlar, sabit indekse bağlı kalmaz (gerçek fotoğraf eklenince
            // sıralama kayıyordu).
            let kind = file.deletingPathExtension().lastPathComponent
                .split(separator: "-").first.map(String.init) ?? "photo"
            let url = output.appendingPathComponent(
                String(format: "sample-%02d-%@.mp4", index + offset, kind))
            try await generate(photo: image, at: url, size: size,
                               duration: duration, fps: fps,
                               seed: offset)
            let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            print("  \(url.lastPathComponent)  \(file.lastPathComponent)  \((bytes ?? 0) / 1024) KB")
        }
        return files.count
    }

    /// Tek fotoğraftan Ken Burns'lü klip. Yön/zoom `seed`'e göre değişir ki
    /// kolajda yan yana gelen klipler aynı hareketi yapmasın.
    static func generate(photo: CGImage, at url: URL, size: CGSize,
                         duration: Double, fps: Int, seed: Int) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_000_000,
                AVVideoMaxKeyFrameIntervalKey: fps
            ]
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
        guard writer.startWriting(), let pool = adaptor.pixelBufferPool else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(duration * Double(fps))
        let zoomIn = seed % 2 == 0
        let panX = CGFloat((seed % 3) - 1) * 0.03      // -1, 0, +1 yönlerinde

        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let pixelBuffer = buffer else { throw CocoaError(.fileWriteUnknown) }
            let progress = Double(frame) / Double(max(frameCount - 1, 1))

            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let base = CVPixelBufferGetBaseAddress(pixelBuffer),
               let context = CGContext(
                data: base, width: Int(size.width), height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue) {

                // Aspect-fill + zaman içinde yavaş zoom/pan.
                let zoom = 1.06 + (zoomIn ? CGFloat(progress) : CGFloat(1 - progress)) * 0.10
                let imageSize = CGSize(width: photo.width, height: photo.height)
                let fill = max(size.width / imageSize.width, size.height / imageSize.height) * zoom
                let drawSize = CGSize(width: imageSize.width * fill,
                                      height: imageSize.height * fill)
                let origin = CGPoint(
                    x: (size.width - drawSize.width) / 2 + panX * size.width * CGFloat(progress),
                    y: (size.height - drawSize.height) / 2)
                context.setFillColor(CGColor(gray: 0, alpha: 1))
                context.fill(CGRect(origin: .zero, size: size))
                context.draw(photo, in: CGRect(origin: origin, size: drawSize))
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

            adaptor.append(pixelBuffer,
                           withPresentationTime: CMTime(value: CMTimeValue(frame),
                                                        timescale: CMTimeScale(fps)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status == .failed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
    }

    /// Klipleri verilen klasöre yazar (`sample-01.mp4` … `sample-10.mp4`).
    /// Ad SIFIR DOLGULU: `MediaPool` klipleri ada göre sıralıyor ve
    /// "sample-10" alfabetik olarak "sample-2"den önce geliyordu.
    static func generateAll(in directory: URL,
                            size: CGSize = CGSize(width: 1080, height: 1920),
                            duration: Double = 6,
                            fps: Int = 24) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // ESKİ klipleri sil: dosya adı hem SIRA hem TÜR taşıyor, `source/`ten bir
        // fotoğraf çıkarılınca numaralar kayıyor ve eski dosya öksüz kalıyordu —
        // MediaPool klasörü tarayıp onu da vitrine koyuyordu (elenen fotoğraf
        // posterlerde yaşamaya devam etti; bir kez yaşandı).
        for url in (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        where url.pathExtension.lowercased() == "mp4"
            && url.lastPathComponent.hasPrefix("sample-") {
            try? FileManager.default.removeItem(at: url)
        }
        // Önce gerçek fotoğraflar (varsa), sonra sentetik sahneler.
        let real = try await generatePhotoClips(
            from: directory.appendingPathComponent("source"),
            into: directory, startingAt: 1,
            size: size, duration: duration, fps: fps)
        for (index, scene) in Scene.allCases.enumerated() {
            let url = directory.appendingPathComponent(
                String(format: "sample-%02d-%@.mp4", real + index + 1, scene.rawValue))
            try await generate(scene: scene, at: url, size: size, duration: duration, fps: fps)
            let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            print("  \(url.lastPathComponent)  \(scene.rawValue)  \((bytes ?? 0) / 1024) KB")
        }
    }

    static func generate(scene: Scene, at url: URL, size: CGSize,
                         duration: Double, fps: Int) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_000_000,
                AVVideoMaxKeyFrameIntervalKey: fps
            ]
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
        guard writer.startWriting(), let pool = adaptor.pixelBufferPool else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(duration * Double(fps))
        var bokeh = Bokeh(scene: scene, size: size)

        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let pixelBuffer = buffer else { throw CocoaError(.fileWriteUnknown) }

            let progress = Double(frame) / Double(max(frameCount - 1, 1))
            draw(scene: scene, progress: progress, bokeh: &bokeh,
                 into: pixelBuffer, size: size)

            let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))
            adaptor.append(pixelBuffer, withPresentationTime: time)
        }

        input.markAsFinished()
        await writer.finishWriting()
        if writer.status == .failed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
    }

    // MARK: Çizim

    private static func draw(scene: Scene, progress: Double, bokeh: inout Bokeh,
                             into pixelBuffer: CVPixelBuffer, size: CGSize) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer),
              let context = CGContext(
                data: base, width: Int(size.width), height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return }

        // Kamera hareketi: yavaş dikey kaydırma + hafif zoom (Ken Burns hissi).
        let drift = CGFloat(progress) * size.height * 0.06
        let zoom = 1 + CGFloat(progress) * 0.05
        context.saveGState()
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.scaleBy(x: zoom, y: zoom)
        context.translateBy(x: -size.width / 2, y: -size.height / 2 - drift)

        switch scene.kind {
        case .landscape:
            drawLandscape(scene: scene, progress: progress, bokeh: &bokeh,
                          context: context, size: size, space: space)
        case .city:
            drawCity(scene: scene, progress: progress, bokeh: &bokeh,
                     context: context, size: size, space: space)
        case .interior:
            drawInterior(scene: scene, progress: progress, bokeh: &bokeh,
                         context: context, size: size, space: space)
        case .tableTop:
            drawTableTop(scene: scene, progress: progress, bokeh: &bokeh,
                         context: context, size: size, space: space)
        case .portrait:
            drawPortrait(scene: scene, progress: progress, bokeh: &bokeh,
                         context: context, size: size, space: space)
        case .weave:
            drawWeave(scene: scene, progress: progress,
                      context: context, size: size, space: space)
        }
        context.restoreGState()

        // Vinyet — kadrajın kenarını toplar, metin okunurluğunu artırır.
        let vignette = CGGradient(colorsSpace: space, colors: [
            CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.45)
        ] as CFArray, locations: [0.55, 1])!
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        context.drawRadialGradient(vignette, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: size.height * 0.72,
                                   options: [])
    }

    /// Zemin gradyanı — her kompozisyonun altında.
    private static func fillSky(_ scene: Scene, context: CGContext,
                                size: CGSize, space: CGColorSpace) {
        let sky = scene.sky
        let gradient = CGGradient(colorsSpace: space, colors: sky.map {
            CGColor(srgbRed: $0.0, green: $0.1, blue: $0.2, alpha: 1)
        } as CFArray, locations: [0, 0.55, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size.height * 1.1),
            end: CGPoint(x: 0, y: -size.height * 0.1), options: [])
    }

    // MARK: Manzara (ilk beş sahne)

    private static func drawLandscape(scene: Scene, progress: Double, bokeh: inout Bokeh,
                                      context: CGContext, size: CGSize,
                                      space: CGColorSpace) {
        // 1. Gökyüzü gradyanı.
        let sky = scene.sky
        let gradient = CGGradient(colorsSpace: space, colors: sky.map {
            CGColor(srgbRed: $0.0, green: $0.1, blue: $0.2, alpha: 1)
        } as CFArray, locations: [0, 0.55, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size.height * 1.1),
            end: CGPoint(x: 0, y: -size.height * 0.1), options: [])

        // 2. Işık kaynağı: yumuşak hâle + disk. Süre boyunca yükselir.
        let light = scene.light
        let lightCenter = CGPoint(x: size.width * (0.32 + 0.10 * CGFloat(progress)),
                                  y: size.height * (0.56 + 0.06 * CGFloat(progress)))
        let radius = CGFloat(light.radius) * size.width
        let glow = CGGradient(colorsSpace: space, colors: [
            CGColor(srgbRed: light.color.0, green: light.color.1, blue: light.color.2, alpha: 0.85),
            CGColor(srgbRed: light.color.0, green: light.color.1, blue: light.color.2, alpha: 0)
        ] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(glow, startCenter: lightCenter, startRadius: radius * 0.35,
                                   endCenter: lightCenter, endRadius: radius * 3.2, options: [])
        context.setFillColor(CGColor(srgbRed: light.color.0, green: light.color.1,
                                     blue: light.color.2, alpha: 0.95))
        context.fillEllipse(in: CGRect(x: lightCenter.x - radius, y: lightCenter.y - radius,
                                       width: radius * 2, height: radius * 2))

        // 3. Silüet katmanları (paralaks: arka katman az, ön katman çok kayar).
        let base3 = scene.silhouette
        for layer in 0..<3 {
            let depth = Double(layer)
            let alpha = 0.55 + depth * 0.2
            let shade = 1.0 - depth * 0.18
            context.setFillColor(CGColor(srgbRed: base3.0 * shade, green: base3.1 * shade,
                                         blue: base3.2 * shade, alpha: alpha))
            let shift = CGFloat(progress) * size.width * CGFloat(0.02 + depth * 0.03)
            ridgePath(in: context, size: size,
                      baseline: size.height * CGFloat(0.30 - depth * 0.07),
                      amplitude: size.height * CGFloat(0.05 + depth * 0.02),
                      ridges: scene.ridges + layer, phase: Double(shift) / Double(size.width))
            context.fillPath()
        }

        // 4. Bokeh: yavaşça süzülen ışık noktaları (derinlik hissi).
        bokeh.draw(in: context, progress: progress)
    }

    // MARK: Şehir silüeti — gece, pencereli bloklar

    private static func drawCity(scene: Scene, progress: Double, bokeh: inout Bokeh,
                                 context: CGContext, size: CGSize, space: CGColorSpace) {
        fillSky(scene, context: context, size: size, space: space)
        let light = scene.light
        let moon = CGPoint(x: size.width * 0.74, y: size.height * 0.80)
        let radius = CGFloat(light.radius) * size.width
        let glow = CGGradient(colorsSpace: space, colors: [
            CGColor(srgbRed: light.color.0, green: light.color.1, blue: light.color.2, alpha: 0.7),
            CGColor(srgbRed: light.color.0, green: light.color.1, blue: light.color.2, alpha: 0)
        ] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(glow, startCenter: moon, startRadius: radius * 0.3,
                                   endCenter: moon, endRadius: radius * 4, options: [])

        // Bloklar: deterministik yükseklikler, üstlerinde pencere ızgarası.
        var seed: UInt64 = 90210
        func rnd() -> Double {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Double(seed % 10_000) / 10_000
        }
        let base = scene.silhouette
        let columns = 11
        let blockWidth = size.width / CGFloat(columns - 1)
        for column in 0..<columns {
            let height = size.height * CGFloat(0.16 + rnd() * 0.30)
            let x = CGFloat(column) * blockWidth - blockWidth * 0.5
            let shade = 0.85 + rnd() * 0.3
            context.setFillColor(CGColor(srgbRed: base.0 * shade, green: base.1 * shade,
                                         blue: base.2 * shade, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: blockWidth * 0.92, height: height))

            // Pencereler — bir kısmı yanıyor, zamanla birkaçı değişiyor.
            let rows = Int(height / (size.height * 0.045))
            for row in 0..<max(rows, 0) {
                for cell in 0..<3 {
                    let lit = rnd()
                    let flicker = (lit + progress * 0.15).truncatingRemainder(dividingBy: 1)
                    guard flicker > 0.55 else { continue }
                    let wx = x + blockWidth * (0.18 + CGFloat(cell) * 0.26)
                    let wy = size.height * 0.02 + CGFloat(row) * size.height * 0.045
                    context.setFillColor(CGColor(srgbRed: light.color.0, green: light.color.1,
                                                 blue: light.color.2,
                                                 alpha: 0.25 + flicker * 0.45))
                    context.fill(CGRect(x: wx, y: wy, width: blockWidth * 0.16,
                                        height: size.height * 0.020))
                }
            }
        }
        bokeh.draw(in: context, progress: progress)
    }

    // MARK: İç mekân — pencereden düşen sıcak ışık, masa düzlemi

    private static func drawInterior(scene: Scene, progress: Double, bokeh: inout Bokeh,
                                     context: CGContext, size: CGSize, space: CGColorSpace) {
        fillSky(scene, context: context, size: size, space: space)
        let light = scene.light

        // Pencere: eğik ışık dikdörtgeni, süre boyunca hafifçe kayar.
        let slide = CGFloat(progress) * size.width * 0.05
        context.saveGState()
        context.translateBy(x: size.width * 0.26 + slide, y: size.height * 0.62)
        context.rotate(by: -0.32)
        for pane in 0..<2 {
            let beam = CGGradient(colorsSpace: space, colors: [
                CGColor(srgbRed: light.color.0, green: light.color.1,
                        blue: light.color.2, alpha: 0.34),
                CGColor(srgbRed: light.color.0, green: light.color.1,
                        blue: light.color.2, alpha: 0)
            ] as CFArray, locations: [0, 1])!
            let rect = CGRect(x: CGFloat(pane) * size.width * 0.30, y: -size.height * 0.34,
                              width: size.width * 0.22, height: size.height * 0.68)
            context.saveGState()
            context.clip(to: rect)
            context.drawLinearGradient(beam,
                                       start: CGPoint(x: rect.minX, y: rect.maxY),
                                       end: CGPoint(x: rect.minX, y: rect.minY), options: [])
            context.restoreGState()
        }
        context.restoreGState()

        // Masa düzlemi: alt üçte bir, koyu ve mat.
        let table = scene.silhouette
        context.setFillColor(CGColor(srgbRed: table.0, green: table.1, blue: table.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.30))
        let edge = CGGradient(colorsSpace: space, colors: [
            CGColor(srgbRed: light.color.0, green: light.color.1, blue: light.color.2, alpha: 0.22),
            CGColor(srgbRed: table.0, green: table.1, blue: table.2, alpha: 0)
        ] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(edge,
                                   start: CGPoint(x: 0, y: size.height * 0.30),
                                   end: CGPoint(x: 0, y: size.height * 0.20), options: [])

        // Masadaki iki nesne (fincan silüeti) — soyut, tanınabilir marka yok.
        for (cx, scale) in [(0.34, 1.0), (0.62, 0.72)] {
            let w = size.width * 0.15 * CGFloat(scale)
            let h = w * 1.15
            context.setFillColor(CGColor(srgbRed: table.0 * 1.9, green: table.1 * 1.9,
                                         blue: table.2 * 1.9, alpha: 1))
            context.fillEllipse(in: CGRect(x: size.width * CGFloat(cx) - w / 2,
                                           y: size.height * 0.27, width: w, height: h * 0.35))
            context.fill(CGRect(x: size.width * CGFloat(cx) - w / 2,
                                y: size.height * 0.30 - h, width: w, height: h))
        }
        bokeh.draw(in: context, progress: progress)
    }

    // MARK: Tepeden tabak — yemek şablonlarının vitrini

    private static func drawTableTop(scene: Scene, progress: Double, bokeh: inout Bokeh,
                                     context: CGContext, size: CGSize, space: CGColorSpace) {
        fillSky(scene, context: context, size: size, space: space)
        let surface = scene.silhouette

        // Yüzey dokusu: ince yatay tahta çizgileri.
        context.setLineWidth(size.width * 0.004)
        for line in 0..<26 {
            let y = size.height * CGFloat(line) / 26
            context.setStrokeColor(CGColor(srgbRed: surface.0, green: surface.1,
                                           blue: surface.2, alpha: 0.14))
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: size.width, y: y))
            context.strokePath()
        }

        // Ana tabak: hafifçe nefes alan büyük daire + iç halka.
        let breathe = 1 + CGFloat(sin(progress * .pi * 2)) * 0.012
        let plate = CGPoint(x: size.width * 0.5, y: size.height * 0.54)
        let r = size.width * 0.34 * breathe
        context.setFillColor(CGColor(gray: 0, alpha: 0.16))
        context.fillEllipse(in: CGRect(x: plate.x - r, y: plate.y - r - size.height * 0.012,
                                       width: r * 2, height: r * 2))
        context.setFillColor(CGColor(srgbRed: 0.97, green: 0.96, blue: 0.94, alpha: 1))
        context.fillEllipse(in: CGRect(x: plate.x - r, y: plate.y - r, width: r * 2, height: r * 2))
        context.setStrokeColor(CGColor(srgbRed: surface.0, green: surface.1,
                                       blue: surface.2, alpha: 0.25))
        context.setLineWidth(size.width * 0.006)
        context.strokeEllipse(in: CGRect(x: plate.x - r * 0.82, y: plate.y - r * 0.82,
                                         width: r * 1.64, height: r * 1.64))

        // Tabaktaki öğeler — soyut renkli lekeler.
        let bites: [(Double, Double, Double, (Double, Double, Double))] = [
            (0.44, 0.58, 0.13, (0.78, 0.32, 0.24)),
            (0.58, 0.56, 0.10, (0.42, 0.55, 0.26)),
            (0.50, 0.46, 0.09, (0.92, 0.74, 0.38)),
            (0.56, 0.64, 0.06, (0.35, 0.30, 0.28)),
        ]
        for (bx, by, br, color) in bites {
            let rr = size.width * CGFloat(br)
            context.setFillColor(CGColor(srgbRed: color.0, green: color.1, blue: color.2, alpha: 1))
            context.fillEllipse(in: CGRect(x: size.width * CGFloat(bx) - rr,
                                           y: size.height * CGFloat(by) - rr,
                                           width: rr * 2, height: rr * 2))
        }

        // Yan nesneler: küçük tabak ve çatal-benzeri ince çubuk.
        context.setFillColor(CGColor(srgbRed: 0.97, green: 0.96, blue: 0.94, alpha: 1))
        context.fillEllipse(in: CGRect(x: size.width * 0.06, y: size.height * 0.20,
                                       width: size.width * 0.24, height: size.width * 0.24))
        context.setFillColor(CGColor(srgbRed: 0.80, green: 0.79, blue: 0.76, alpha: 1))
        context.fill(CGRect(x: size.width * 0.86, y: size.height * 0.30,
                            width: size.width * 0.022, height: size.height * 0.20))
        bokeh.draw(in: context, progress: progress)
    }

    // MARK: Portre kadrajı — yumuşak fon, ortada soyut figür (yüz YOK)

    private static func drawPortrait(scene: Scene, progress: Double, bokeh: inout Bokeh,
                                     context: CGContext, size: CGSize, space: CGColorSpace) {
        fillSky(scene, context: context, size: size, space: space)
        let light = scene.light
        let key = CGPoint(x: size.width * 0.30, y: size.height * 0.74)
        let glow = CGGradient(colorsSpace: space, colors: [
            CGColor(srgbRed: light.color.0, green: light.color.1, blue: light.color.2, alpha: 0.42),
            CGColor(srgbRed: light.color.0, green: light.color.1, blue: light.color.2, alpha: 0)
        ] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(glow, startCenter: key, startRadius: 0,
                                   endCenter: key, endRadius: size.width * 0.9, options: [])

        // Omuz + baş silüeti; hafifçe sallanır (nefes).
        let sway = CGFloat(sin(progress * .pi * 2)) * size.width * 0.006
        let body = scene.silhouette
        context.setFillColor(CGColor(srgbRed: body.0, green: body.1, blue: body.2, alpha: 1))
        let shoulderW = size.width * 0.86
        context.fillEllipse(in: CGRect(x: size.width / 2 - shoulderW / 2 + sway,
                                       y: -size.height * 0.12,
                                       width: shoulderW, height: size.height * 0.52))
        let headW = size.width * 0.30
        context.fillEllipse(in: CGRect(x: size.width / 2 - headW / 2 + sway,
                                       y: size.height * 0.34,
                                       width: headW, height: headW * 1.22))
        // Kenar ışığı: figürün sağ konturu.
        context.setStrokeColor(CGColor(srgbRed: light.color.0, green: light.color.1,
                                       blue: light.color.2, alpha: 0.30))
        context.setLineWidth(size.width * 0.012)
        context.strokeEllipse(in: CGRect(x: size.width / 2 - headW / 2 + sway,
                                         y: size.height * 0.34,
                                         width: headW, height: headW * 1.22))
        bokeh.draw(in: context, progress: progress)
    }

    // MARK: Doku — yakın plan kumaş/örgü (moda ve minimal şablonlar için)

    private static func drawWeave(scene: Scene, progress: Double,
                                  context: CGContext, size: CGSize, space: CGColorSpace) {
        fillSky(scene, context: context, size: size, space: space)
        let thread = scene.silhouette
        let light = scene.light
        let step = size.width * 0.075
        let shift = CGFloat(progress) * step   // dokunun yavaşça kayması

        context.setLineCap(.round)
        context.setLineWidth(step * 0.42)
        var index = 0
        var x = -size.height
        while x < size.width + size.height {
            let warm = index % 3 == 0
            let color = warm
                ? CGColor(srgbRed: light.color.0, green: light.color.1,
                          blue: light.color.2, alpha: 0.22)
                : CGColor(srgbRed: thread.0 * 1.6, green: thread.1 * 1.6,
                          blue: thread.2 * 1.6, alpha: 0.55)
            context.setStrokeColor(color)
            context.move(to: CGPoint(x: x + shift, y: 0))
            context.addLine(to: CGPoint(x: x + shift + size.height, y: size.height))
            context.strokePath()
            x += step
            index += 1
        }
        // Ters yönde daha seyrek iplikler — örgü hissi.
        context.setLineWidth(step * 0.22)
        context.setStrokeColor(CGColor(gray: 0, alpha: 0.18))
        var y = -size.width
        while y < size.height + size.width {
            context.move(to: CGPoint(x: 0, y: y - shift))
            context.addLine(to: CGPoint(x: size.width, y: y - shift + size.width))
            context.strokePath()
            y += step * 2.4
        }
    }

    /// Sinüs tepelerinden silüet yolu (dağ/dalga/ağaç sırası).
    private static func ridgePath(in context: CGContext, size: CGSize,
                                  baseline: CGFloat, amplitude: CGFloat,
                                  ridges: Int, phase: Double) {
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 0))
        let steps = 90
        for step in 0...steps {
            let x = size.width * CGFloat(step) / CGFloat(steps)
            let t = Double(step) / Double(steps) + phase
            let wave = sin(t * Double(ridges) * .pi * 2) * 0.6
                + sin(t * Double(ridges) * .pi * 4.7 + 1.3) * 0.4
            context.addLine(to: CGPoint(x: x, y: baseline + amplitude * CGFloat(wave)))
        }
        context.addLine(to: CGPoint(x: size.width, y: 0))
        context.closePath()
    }

    /// Deterministik bokeh noktaları (aynı sahne her koşuda aynı çıksın —
    /// varlık üretimi tekrarlanabilir olmalı).
    private struct Bokeh {
        struct Dot { var x: Double; var y: Double; var radius: Double; var alpha: Double; var speed: Double }
        let dots: [Dot]
        let color: (Double, Double, Double)

        init(scene: Scene, size: CGSize) {
            var seed = UInt64(scene.rawValue.unicodeScalars.reduce(0) { $0 &+ UInt32($1.value) })
            func random() -> Double {
                // xorshift — Foundation'ın rastgelesi platformlar arası
                // tekrarlanabilir değil.
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 10_000) / 10_000
            }
            dots = (0..<26).map { _ in
                Dot(x: random(), y: 0.15 + random() * 0.85,
                    radius: 0.006 + random() * 0.030,
                    alpha: 0.05 + random() * 0.16,
                    speed: 0.02 + random() * 0.06)
            }
            color = scene.light.color
        }

        func draw(in context: CGContext, progress: Double) {
            let bounds = context.boundingBoxOfClipPath
            for dot in dots {
                let y = (dot.y + progress * dot.speed).truncatingRemainder(dividingBy: 1.2)
                let center = CGPoint(x: bounds.width * dot.x, y: bounds.height * y)
                let radius = bounds.width * dot.radius
                context.setFillColor(CGColor(srgbRed: color.0, green: color.1,
                                             blue: color.2, alpha: dot.alpha))
                context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                               width: radius * 2, height: radius * 2))
            }
        }
    }
}
