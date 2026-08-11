import XCTest
@testable import TemplateKit

final class TemplateDecodingTests: XCTestCase {

    private func loadFixture() throws -> Template {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/minimal-fade-01",
                                                  withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Template.self, from: data)
    }

    func testDecodesFixture() throws {
        let template = try loadFixture()
        XCTAssertEqual(template.id, "minimal-fade-01")
        XCTAssertEqual(template.schemaVersion, 1)
        XCTAssertEqual(template.canvas, .story)
        XCTAssertEqual(template.totalDuration, 6.0)
        XCTAssertEqual(template.explicitDuration, 6.0)
        XCTAssertNil(template.scenes)
        XCTAssertEqual(template.layers.count, 5)
        XCTAssertEqual(template.name.resolved(languageCode: "tr"), "Minimal Geçiş")
        XCTAssertEqual(template.name.resolved(languageCode: "de"), "Minimal Fade") // en fallback
    }

    func testLayerContentAndDefaults() throws {
        let template = try loadFixture()

        // bg: timing verilmemiş -> tüm süre; rotation/opacity varsayılanları.
        let bg = template.layers[0]
        XCTAssertEqual(bg.rotation, 0)
        XCTAssertEqual(bg.opacity, 1)
        XCTAssertEqual(bg.timing.window(templateDuration: 6.0).end, 6.0)
        guard case .shape(let shape) = bg.content else { return XCTFail("bg should be shape") }
        XCTAssertEqual(shape.colorRole, "background")
        XCTAssertEqual(shape.cornerRadius, 0) // default

        // photo-main: mediaSlot + kenBurns parametreleri.
        guard case .mediaSlot(let slot) = template.layers[1].content else {
            return XCTFail("layer 1 should be mediaSlot")
        }
        XCTAssertEqual(slot.slotIndex, 0)
        XCTAssertEqual(slot.media, .photoOrVideo)
        let kenBurns = try XCTUnwrap(template.layers[1].animations.first { $0.preset == "kenBurns" })
        XCTAssertEqual(kenBurns.params.double("zoom"), 1.1)
        XCTAssertEqual(kenBurns.params.string("direction"), "up")

        // headline: text içeriği + animasyon varsayılanları.
        let headline = template.layers[3]
        guard case .text(let text) = headline.content else {
            return XCTFail("layer 3 should be text")
        }
        XCTAssertTrue(text.allCaps)
        XCTAssertEqual(text.maxLines, 2)
        let slideIn = try XCTUnwrap(headline.animations.first { $0.preset == "slideIn" })
        XCTAssertEqual(slideIn.delay, 0) // default
        XCTAssertEqual(slideIn.easing, .easeOut)

        // accent-bar: duration'sız timing -> şablon sonuna kadar.
        let bar = template.layers[2]
        XCTAssertEqual(bar.timing.start, 0.5)
        XCTAssertEqual(bar.timing.window(templateDuration: 6.0).end, 6.0)
    }

    func testRoundTrip() throws {
        let template = try loadFixture()
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(Template.self, from: data)
        XCTAssertEqual(template, decoded)
    }

    func testGradientShapeDecoding() throws {
        let json = """
        {"schemaVersion": 1, "id": "g", "name": {"en": "G"}, "category": "promo",
         "duration": 3, "palette": {"clear": "#00000000", "solid": "#000000CC"},
         "layers": [{"id": "scrim", "type": "shape", "colorRole": "clear",
                     "frame": {"x": 0.5, "y": 0.5, "width": 1, "height": 0.4},
                     "gradient": {"from": "clear", "to": "solid", "direction": "down"}}]}
        """
        let template = try JSONDecoder().decode(Template.self, from: Data(json.utf8))
        guard case .shape(let shape) = template.layers[0].content else {
            return XCTFail("shape bekleniyordu")
        }
        XCTAssertEqual(shape.gradient?.from, "clear")
        XCTAssertEqual(shape.gradient?.to, "solid")
        XCTAssertEqual(shape.gradient?.direction, "down")
        XCTAssertNoThrow(try TemplateValidator.validate(template))
    }

    func testGradientWithUnknownRoleIsRejected() throws {
        let json = """
        {"schemaVersion": 1, "id": "g", "name": {"en": "G"}, "category": "promo",
         "duration": 3, "palette": {"clear": "#00000000"},
         "layers": [{"id": "scrim", "type": "shape", "colorRole": "clear",
                     "frame": {"x": 0.5, "y": 0.5, "width": 1, "height": 0.4},
                     "gradient": {"from": "clear", "to": "yok", "direction": "down"}}]}
        """
        let template = try JSONDecoder().decode(Template.self, from: Data(json.utf8))
        XCTAssertThrowsError(try TemplateValidator.validate(template)) { error in
            XCTAssertEqual(error as? TemplateValidationError,
                           .unknownColorRole(layerID: "scrim", role: "yok"))
        }
    }

    func testUnknownLayerTypeFailsDecoding() {
        let json = """
        {"schemaVersion":1,"id":"x","name":{"en":"X"},"category":"minimal",
         "canvas":{"width":1080,"height":1920,"fps":30},"duration":3,
         "palette":{"background":"#000000"},
         "layers":[{"id":"a","type":"hologram",
                    "frame":{"x":0.5,"y":0.5,"width":1,"height":1}}]}
        """
        XCTAssertThrowsError(try JSONDecoder().decode(Template.self,
                                                      from: Data(json.utf8)))
    }

    func testPaletteResolution() throws {
        let template = try loadFixture()
        let palette = template.resolvedPalette(override: ["accent": "#FF0000"])
        XCTAssertEqual(palette["accent"], RGBAColor(red: 1, green: 0, blue: 0))
        XCTAssertEqual(palette["textPrimary"], RGBAColor(red: 1, green: 1, blue: 1))
    }

    func testOverlaySpecDecoding() throws {
        let json = """
        {"schemaVersion":1,"id":"x","name":{"en":"X"},"category":"minimal",
         "duration":3,"palette":{"background":"#000000"},
         "overlay":{"vignette":0.5,"grain":0.3},"layers":[]}
        """
        let template = try JSONDecoder().decode(Template.self, from: Data(json.utf8))
        XCTAssertEqual(template.overlay?.vignette, 0.5)
        XCTAssertEqual(template.overlay?.grain, 0.3)
        // overlay yoksa nil
        let bare = json.replacingOccurrences(
            of: "\"overlay\":{\"vignette\":0.5,\"grain\":0.3},", with: "")
        let plain = try JSONDecoder().decode(Template.self, from: Data(bare.utf8))
        XCTAssertNil(plain.overlay)
    }

    func testMediaSlotFilterDecoding() throws {
        let json = """
        {"slotIndex": 0, "media": "photo", "filter": "vintage", "filterIntensity": 0.6}
        """
        let slot = try JSONDecoder().decode(MediaSlotContent.self, from: Data(json.utf8))
        XCTAssertEqual(slot.filter, "vintage")
        XCTAssertEqual(slot.filterIntensity, 0.6, accuracy: 0.0001)
        // filter yoksa nil, intensity varsayılan 1.
        let bare = try JSONDecoder().decode(MediaSlotContent.self,
                                            from: Data("{\"slotIndex\": 1}".utf8))
        XCTAssertNil(bare.filter)
        XCTAssertEqual(bare.filterIntensity, 1.0)
    }

    func testMaskKindDecoding() throws {
        // Yeni maskeler (star, heart) decode edilebilmeli; bilinmeyen → hata.
        for raw in ["rect", "circle", "star", "heart"] {
            let json = "\"\(raw)\""
            XCTAssertNoThrow(try JSONDecoder().decode(MaskKind.self, from: Data(json.utf8)),
                             "mask '\(raw)' decode edilemedi")
        }
        XCTAssertThrowsError(try JSONDecoder().decode(MaskKind.self,
                                                      from: Data("\"hexagon\"".utf8)))
    }

    func testHexParsing() {
        XCTAssertEqual(RGBAColor(hex: "#FFFFFF"), RGBAColor(red: 1, green: 1, blue: 1))
        XCTAssertEqual(RGBAColor(hex: "000000"), RGBAColor(red: 0, green: 0, blue: 0))
        XCTAssertEqual(RGBAColor(hex: "#FF000080")?.alpha ?? 0, 128.0 / 255, accuracy: 0.001)
        XCTAssertNil(RGBAColor(hex: "#GGGGGG"))
        XCTAssertNil(RGBAColor(hex: "#FFF"))
    }
}

final class TemplateValidatorTests: XCTestCase {

    private func makeTemplate(layers: [Layer]) -> Template {
        Template(id: "t", name: LocalizedText(["en": "T"]), category: "minimal",
                 duration: 5,
                 palette: ["background": "#000000", "accent": "#FF0000"],
                 layers: layers)
    }

    private let fullFrame = NormalizedRect(x: 0.5, y: 0.5, width: 1, height: 1)

    func testFixturePassesValidation() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/minimal-fade-01",
                                                  withExtension: "json"))
        let template = try JSONDecoder().decode(Template.self, from: Data(contentsOf: url))
        XCTAssertNoThrow(try TemplateValidator.validate(template))
    }

    func testRejectsUnknownColorRole() {
        let template = makeTemplate(layers: [
            Layer(id: "a", frame: fullFrame, content: .shape(ShapeContent(colorRole: "nope")))
        ])
        XCTAssertThrowsError(try TemplateValidator.validate(template)) { error in
            XCTAssertEqual(error as? TemplateValidationError,
                           .unknownColorRole(layerID: "a", role: "nope"))
        }
    }

    func testRejectsUnknownHighlightRole() {
        let text = TextContent(key: "t", default: LocalizedText(["en": "Hi"]),
                               font: FontSpec(name: "Helvetica", size: 0.04),
                               colorRole: "accent", highlightColorRole: "ghost")
        let template = makeTemplate(layers: [
            Layer(id: "a", frame: fullFrame, content: .text(text))
        ])
        XCTAssertThrowsError(try TemplateValidator.validate(template)) { error in
            XCTAssertEqual(error as? TemplateValidationError,
                           .unknownColorRole(layerID: "a", role: "ghost"))
        }
    }

    func testRejectsDuplicateSlotIndex() {
        let template = makeTemplate(layers: [
            Layer(id: "a", frame: fullFrame,
                  content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .photo))),
            Layer(id: "b", frame: fullFrame,
                  content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .photo)))
        ])
        XCTAssertThrowsError(try TemplateValidator.validate(template)) { error in
            XCTAssertEqual(error as? TemplateValidationError, .duplicateSlotIndex(0))
        }
    }

    func testRejectsMultipleVideoCapableSlots() {
        let template = makeTemplate(layers: [
            Layer(id: "a", frame: fullFrame,
                  content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .video))),
            Layer(id: "b", frame: fullFrame,
                  content: .mediaSlot(MediaSlotContent(slotIndex: 1, media: .photoOrVideo)))
        ])
        XCTAssertThrowsError(try TemplateValidator.validate(template)) { error in
            XCTAssertEqual(error as? TemplateValidationError, .multipleVideoSlots)
        }
    }

    func testRejectsTimingBeyondDuration() {
        let template = makeTemplate(layers: [
            Layer(id: "a", frame: fullFrame, timing: Timing(start: 6),
                  content: .shape(ShapeContent(colorRole: "accent")))
        ])
        XCTAssertThrowsError(try TemplateValidator.validate(template)) { error in
            XCTAssertEqual(error as? TemplateValidationError, .invalidTiming(layerID: "a"))
        }
    }
}

#if canImport(QuartzCore)
import QuartzCore

final class RenderCoreTests: XCTestCase {

    private var context: RenderContext {
        RenderContext(canvasSize: CGSize(width: 1080, height: 1920),
                      duration: 6.0,
                      baseTime: 0,
                      palette: ["background": RGBAColor(red: 0, green: 0, blue: 0),
                                "surface": RGBAColor(red: 0.1, green: 0.1, blue: 0.1),
                                "accent": RGBAColor(red: 1, green: 0, blue: 0),
                                "textPrimary": RGBAColor(red: 1, green: 1, blue: 1),
                                "textSecondary": RGBAColor(red: 0.7, green: 0.7, blue: 0.7)])
    }

    private var layerInfo: AnimationFactory.LayerInfo {
        AnimationFactory.LayerInfo(frame: CGRect(x: 100, y: 200, width: 400, height: 300),
                                   baseOpacity: 1,
                                   window: (start: 0.5, end: 5.5))
    }

    func testFadeInTiming() {
        var warnings: [String] = []
        let spec = AnimationSpec(role: .in, preset: "fadeIn", delay: 0.1, duration: 0.6)
        let animations = AnimationFactory.animations(for: spec, layer: layerInfo,
                                                     context: context, warnings: &warnings)
        XCTAssertEqual(animations.count, 1)
        let a = try! XCTUnwrap(animations.first as? CABasicAnimation)
        XCTAssertEqual(a.beginTime, 0.6, accuracy: 0.0001) // window.start + delay
        XCTAssertEqual(a.duration, 0.6, accuracy: 0.0001)
        XCTAssertEqual(a.fillMode, .both)
        XCTAssertFalse(a.isRemovedOnCompletion)
    }

    func testOutRoleAlignsToWindowEnd() {
        var warnings: [String] = []
        let spec = AnimationSpec(role: .out, preset: "fadeOut", duration: 0.4)
        let animations = AnimationFactory.animations(for: spec, layer: layerInfo,
                                                     context: context, warnings: &warnings)
        let a = try! XCTUnwrap(animations.first)
        XCTAssertEqual(a.beginTime, 5.1, accuracy: 0.0001) // end - duration
    }

    func testExportBaseTimeIsAdded() {
        var exportContext = context
        exportContext.baseTime = AVCoreAnimationBeginTimeAtZeroLike
        var warnings: [String] = []
        let spec = AnimationSpec(role: .in, preset: "fadeIn", duration: 0.5)
        let a = AnimationFactory.animations(for: spec, layer: layerInfo,
                                            context: exportContext, warnings: &warnings).first!
        XCTAssertEqual(a.beginTime, AVCoreAnimationBeginTimeAtZeroLike + 0.5, accuracy: 0.0001)
    }

    func testUnknownPresetDegradesGracefully() {
        var warnings: [String] = []
        let spec = AnimationSpec(role: .in, preset: "quantumFlip", duration: 0.5)
        let animations = AnimationFactory.animations(for: spec, layer: layerInfo,
                                                     context: context, warnings: &warnings)
        XCTAssertTrue(animations.isEmpty)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("quantumFlip"))
    }

    func testPresenceAnimationOnlyWhenWindowed() {
        XCTAssertNil(AnimationFactory.presenceAnimation(window: (0, 6.0), context: context))
        let presence = AnimationFactory.presenceAnimation(window: (1.0, 5.0), context: context)
        let keyframe = try! XCTUnwrap(presence as? CAKeyframeAnimation)
        XCTAssertEqual(keyframe.calculationMode, .discrete)
        XCTAssertEqual(keyframe.values as? [Float], [0, 1, 0])
        // discrete mod kuralı: keyTimes = values.count + 1 (aralık sınırları).
        XCTAssertEqual(keyframe.keyTimes?.count, 4)
        XCTAssertEqual(keyframe.keyTimes?.map(\.doubleValue),
                       [0, 1.0 / 6.0, 5.0 / 6.0, 1])
    }

    func testBuilderProducesLayerTree() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/minimal-fade-01",
                                                  withExtension: "json"))
        let template = try JSONDecoder().decode(Template.self, from: Data(contentsOf: url))
        let scene = TemplateLayerBuilder.build(template: template,
                                               edits: UserEdits(),
                                               photos: [:],
                                               context: context)
        XCTAssertEqual(scene.root.sublayers?.count, 5)
        XCTAssertNil(scene.videoSlotLayer) // medya atanmadı -> video yolu kapalı
        // accent-bar (index 2) pencereli -> presence animasyonu almalı.
        let bar = try XCTUnwrap(scene.root.sublayers?[2])
        XCTAssertNotNil(bar.animation(forKey: "presence"))
        // bg (index 0) tüm süre görünür -> presence yok.
        let bg = try XCTUnwrap(scene.root.sublayers?[0])
        XCTAssertNil(bg.animation(forKey: "presence"))
        // headline'ın content katmanı slideIn'den 2 animasyon (position+fade) almalı.
        let headlineContent = try XCTUnwrap(scene.root.sublayers?[3].sublayers?.first)
        XCTAssertNotNil(headlineContent.animation(forKey: "preset-0-0"))
        XCTAssertNotNil(headlineContent.animation(forKey: "preset-0-1"))
    }

    func testBuilderAppliesTextOverride() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/minimal-fade-01",
                                                  withExtension: "json"))
        let template = try JSONDecoder().decode(Template.self, from: Data(contentsOf: url))
        let edits = UserEdits(textOverrides: ["headline": "Düğünümüze bekleriz"])
        let scene = TemplateLayerBuilder.build(template: template, edits: edits,
                                               photos: [:], context: context)
        // allCaps şablondan geliyor; locale'li uppercase (TR'de i -> İ).
        XCTAssertEqual(scene.resolvedTexts["headline"],
                       "Düğünümüze bekleriz".uppercased(with: Locale.current))
        // Override'sız katman şablon default'una düşer (makine diline göre en/tr).
        let subtitle = try XCTUnwrap(scene.resolvedTexts["subtitle"])
        XCTAssertTrue(["A short caption", "Kısa bir alt yazı"].contains(subtitle))
        // Metin, rasterize edilmiş contents olarak taşınmalı (CATextLayer değil —
        // export hattında render edilmiyor).
        let textLayer = try XCTUnwrap(scene.root.sublayers?[3].sublayers?.first?.sublayers?.first)
        XCTAssertFalse(textLayer is CATextLayer)
        XCTAssertNotNil(textLayer.contents)
    }

    func testTextRasterizerProducesImage() {
        let spec = TextRasterizer.Spec(text: "MERHABA",
                                       fontName: "HelveticaNeue-Bold",
                                       fontSize: 40,
                                       color: CGColor(gray: 1, alpha: 1),
                                       size: CGSize(width: 400, height: 100),
                                       scale: 2)
        let image = TextRasterizer.rasterize(spec)
        XCTAssertEqual(image?.width, 800)   // size * scale
        XCTAssertEqual(image?.height, 200)
        // Boş metin görüntü üretmez.
        var empty = spec
        empty.text = ""
        XCTAssertNil(TextRasterizer.rasterize(empty))
    }

    /// Kelime kutuları GERÇEKTEN metnin pikselleri üzerinde olmalı.
    ///
    /// Metin kutusu içinde dikey ORTALANIR; `CTFrameGetLineOrigins` satır
    /// origin'lerini çerçeve yoluna GÖRE verdiği için yolun kendi origin'i
    /// eklenmezse kutular ortalama payı kadar kayar. kineticWords her kelimeyi
    /// bu kutuyla kırptığından kayma "glifin yarısı kesilmiş" olarak görünür.
    func testWordBoxesLandOnGlyphs() throws {
        // Kutu metinden çok daha yüksek: ortalama payı büyük, kayma varsa
        // kelime kutuları bomboş bölgeye düşer.
        let spec = TextRasterizer.Spec(text: "MERHABA DÜNYA",
                                       fontName: "HelveticaNeue-Bold",
                                       fontSize: 40,
                                       color: CGColor(gray: 1, alpha: 1),
                                       size: CGSize(width: 400, height: 300),
                                       scale: 1)
        let layout = try XCTUnwrap(TextRasterizer.layout(spec))
        XCTAssertEqual(layout.words.count, 2)
        let pixels = try XCTUnwrap(Self.alphaMap(layout.image))
        for box in layout.words {
            let painted = Self.paintedRatio(in: box, of: pixels)
            XCTAssertGreaterThan(painted, 0.15,
                                 "kelime kutusu \(box) metnin üzerinde değil (oran \(painted))")
        }
    }

    /// Satır vurgusu (highlightColorRole) satırın ARKASINDA olmalı, altına kaymamalı.
    func testLineHighlightSitsBehindText() throws {
        let spec = TextRasterizer.Spec(text: "iki satır\nvurgulu metin",
                                       fontName: "HelveticaNeue-Bold",
                                       fontSize: 40,
                                       color: CGColor(gray: 0, alpha: 1),
                                       size: CGSize(width: 400, height: 300),
                                       scale: 1,
                                       highlightColor: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        let image = try XCTUnwrap(TextRasterizer.rasterize(spec))
        let band = try XCTUnwrap(Self.opaqueRowBand(image))
        // Metin kutuda ortalandığı için vurgu bandı da ortalanmalı.
        let center = Double(band.lowerBound + band.upperBound) / 2
        XCTAssertEqual(center, 150, accuracy: 8,
                       "vurgu bandı \(band) ortalanmamış — satır origin'i yola göre mi?")
    }

    // MARK: - Piksel yardımcıları

    /// Görüntünün alfa kanalı (y AŞAĞI, satır başına genişlik kadar bayt).
    private static func alphaMap(_ image: CGImage) -> (bytes: [UInt8], width: Int, height: Int)? {
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &bytes, width: w, height: h,
                                 bitsPerComponent: 8, bytesPerRow: w,
                                 space: CGColorSpaceCreateDeviceGray(),
                                 bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (bytes, w, h)
    }

    private static func paintedRatio(in box: CGRect,
                                     of map: (bytes: [UInt8], width: Int, height: Int)) -> Double {
        // Kutu y-AŞAĞI; alfa haritası da y-AŞAĞI (CGContext.draw ters çevirir).
        let x0 = max(0, Int(box.minX)), x1 = min(map.width, Int(box.maxX))
        let y0 = max(0, Int(box.minY)), y1 = min(map.height, Int(box.maxY))
        guard x1 > x0, y1 > y0 else { return 0 }
        var painted = 0
        for y in y0..<y1 {
            for x in x0..<x1 where map.bytes[y * map.width + x] > 40 { painted += 1 }
        }
        return Double(painted) / Double((x1 - x0) * (y1 - y0))
    }

    /// Opak (vurgu) piksel içeren ilk ve son satır — y AŞAĞI.
    private static func opaqueRowBand(_ image: CGImage) -> ClosedRange<Int>? {
        guard let map = alphaMap(image) else { return nil }
        var first: Int?, last: Int?
        for y in 0..<map.height {
            let rowHasFill = (0..<map.width).contains { map.bytes[y * map.width + $0] > 200 }
            if rowHasFill {
                if first == nil { first = y }
                last = y
            }
        }
        guard let f = first, let l = last else { return nil }
        return f...l
    }
}

/// AVFoundation'ı test hedefine bağlamamak için sabitin bilinen değeri değil,
/// "sıfırdan farklı bir taban eklenince beginTime kayar" davranışı test ediliyor.
private let AVCoreAnimationBeginTimeAtZeroLike: CFTimeInterval = 1e-10
#endif
