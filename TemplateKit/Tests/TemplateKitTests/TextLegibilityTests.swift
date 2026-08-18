#if canImport(AVFoundation) && canImport(QuartzCore)
import XCTest
import AVFoundation
import CoreGraphics
@testable import TemplateKit

/// İki gerçek export hatası, ikisi de GERÇEK RENDER üzerinden ölçülüyor:
///
/// 1. Kullanıcının açık renkli medyası şablonun beyaz metnini yutuyordu.
///    Modeli okuyan bir test bunu gösteremez — okunabilirlik PİKSELDE olur.
///    Ölçüm hilesi: bembeyaz bir fotoğrafın üstüne beyaz metin. Metin bandının
///    STANDART SAPMASI "orada ayırt edilebilir bir şey var mı" demektir;
///    beyaz-üstüne-beyazda ~0'dır, okunabilir metinde yüksektir.
///
/// 2. Rozetin arka planı yazısından önce giriyordu (ekranda boş renkli kutu).
///    Ölçüm: hap KIRMIZI, yazı YEŞİL — R ve G kanalları iki katmanı birbirinden
///    bağımsız sayar, böylece "hangisi önce göründü" kare kare ölçülebilir.
final class TextLegibilityTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("legibility-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - 1) Medya üstündeki metnin okunabilirliği

    /// Bembeyaz fotoğrafın üstündeki beyaz metin okunabilir olmalı.
    func testTextOverMediaStaysLegibleOnBrightPhoto() async throws {
        let over = try await stats(of: overPhotoTemplate(legibility: nil))
        let raw = try await stats(of: overPhotoTemplate(legibility: .off))

        // Koruma kapalıyken metin fotoğrafın içinde kayboluyor: bant düz beyaz.
        XCTAssertLessThan(raw.deviation, 0.03,
                          "kurulum hatalı: koruma kapalıyken metin zaten görünüyor")
        XCTAssertGreaterThan(over.deviation, 0.15,
                             "medyanın üstündeki metin hâlâ okunmuyor")
        XCTAssertLessThan(over.mean, raw.mean - 0.05,
                          "yazının arkasına kontrast tabanı konmamış")
    }

    /// `always`: zemin bilinse bile hap konur (bilinçli sticker tipografisi).
    func testAlwaysModeAppliesEvenWithoutMedia() async throws {
        let plain = try await stats(of: solidBackgroundTemplate(legibility: .off))
        let forced = try await stats(of: solidBackgroundTemplate(legibility: .always))
        XCTAssertNotEqual(plain.mean, forced.mean, accuracy: 0.005,
                          "'always' modu hiçbir şey değiştirmedi")
    }

    // MARK: - 2) Tasarıma dokunmama garantileri

    /// Düz renk zemin üstündeki metin (tipografi şablonları) AYNEN kalmalı:
    /// zemin paletle birlikte tasarlandı, hap tasarımı bozar.
    func testTextOnSolidBackgroundIsUntouched() async throws {
        let auto = try await stats(of: solidBackgroundTemplate(legibility: nil))
        let off = try await stats(of: solidBackgroundTemplate(legibility: .off))
        XCTAssertEqual(auto.mean, off.mean, accuracy: 0.001,
                       "düz zemin üstündeki metne dokunuldu")
        XCTAssertEqual(auto.deviation, off.deviation, accuracy: 0.001)
    }

    /// Metin, medyanın üstündeki TAM OPAK bir kartın üstündeyse zemin yine
    /// biliniyordur — hap konmamalı.
    func testTextOnOpaqueCardOverMediaIsUntouched() async throws {
        let auto = try await stats(of: cardOverPhotoTemplate(legibility: nil))
        let off = try await stats(of: cardOverPhotoTemplate(legibility: .off))
        XCTAssertGreaterThan(off.deviation, 0.15, "kurulum hatalı: kartın üstünde metin yok")
        XCTAssertEqual(auto.mean, off.mean, accuracy: 0.001,
                       "opak kartın üstündeki metne gereksiz hap kondu")
    }

    /// Şablonun kendi KOYU YARI SAYDAM örtüsü medyayı yeterince karartıyorsa
    /// (a ≥ 0,7) motor geri çekilir; hafif bir örtü (a = 0,2) yetmez.
    /// Bu ayrım olmadan `sale-promo-01` gibi scrim'li şablonlarda alt kenardaki
    /// küçük metinler de gereksiz yere haplanıyordu.
    func testHeavyTranslucentVeilMakesTheEngineStepBack() async throws {
        let heavy = try await stats(of: veiledTemplate(veil: "#000000CC"))
        let light = try await stats(of: veiledTemplate(veil: "#00000033"))
        let heavyOff = try await stats(of: veiledTemplate(veil: "#000000CC", legibility: .off))
        let lightOff = try await stats(of: veiledTemplate(veil: "#00000033", legibility: .off))

        XCTAssertEqual(heavy.mean, heavyOff.mean, accuracy: 0.001,
                       "yeterince koyu örtünün üstündeki metne gereksiz hap kondu")
        XCTAssertLessThan(light.mean, lightOff.mean - 0.05,
                          "hafif örtü yeterli sayıldı ve metin korumasız kaldı")
    }

    // MARK: - Depodaki şablonlar üzerinde kilit (poster regresyonu)

    /// Sezgiselin YANLIŞ POZİTİF ürettiği iki gerçek şablon ve doğru çalıştığı
    /// bir tanesi, katman adlarıyla kilitleniyor.
    ///
    /// Bu testler var olmadan bir tur regresyon üretildi: paket yeşilken
    /// `spa-calm-01`'in krem zemindeki üç metni ve `makeup-look-01`'in pembe
    /// kart üstündeki iki etiketi hap aldı. Kare ölçen testler bunu göremezdi
    /// (yapay şablonlarda o geometri yoktu), o yüzden kilit DEPODAKİ dosyalar
    /// üzerinde ve KATMAN ADIYLA.
    func testScrimTargetsOnShippedTemplates() throws {
        // (şablon, hap ALMASI gerekenler, hap ALMAMASI gerekenler)
        let cases: [(id: String, expected: Set<String>, forbidden: Set<String>)] = [
            // Montaj: medya üstteki %56'da, alt yarı krem düz zemin.
            ("spa-calm-01", [], ["kicker", "title", "sub"]),
            // Klasik: etiketler portre slotunun kenarına DEĞİYOR, üstünde değil.
            ("makeup-look-01", [], ["dotlabel0", "dotlabel1", "dotlabel2", "dotlabel3",
                                    "dotnum0", "dotnum1", "dotnum2", "dotnum3",
                                    "kicker", "look-name", "sub", "cta"]),
            // Asıl kazanım: kadrajı tümüyle kaplayan medyanın üstündeki başlık.
            ("sale-promo-01", ["headline", "old-price", "new-price"],
                              // Opak hapların üstünde + alt kenarda koyu scrim.
                              ["badge", "cta", "handle"]),
            // Emoji sticker'lar: arkalarına kutu koymak sticker'ı öldürür.
            ("sticker-fun-01", [], ["sticker-heart", "sticker-party", "sticker-spark"]),
            ("pet-star-01", ["pet-name"], ["heart", "paw", "star"]),
            // Portrenin iki kenarına SİMETRİK oturan dört kalp: kapsamaları
            // 0,55 ve 0,60: gevşek bir eşikte yalnız biri hap alıp simetriyi
            // bozuyordu.
            ("valentines-01", [], ["h1", "h2", "h3", "h4"])
        ]
        for (id, expected, forbidden) in cases {
            let targets = try scrimTargets(forTemplate: id)
            for layer in expected {
                XCTAssertTrue(targets.contains(layer),
                              "\(id): '\(layer)' hap ALMALIYDI — medyanın üstünde")
            }
            for layer in forbidden {
                XCTAssertFalse(targets.contains(layer),
                               "\(id): '\(layer)' hap ALMAMALIYDI (poster regresyonu)")
            }
        }
    }

    /// Kenarına DEĞEN medya hap sebebi değildir. `makeup-look-01`'de sol
    /// etiketler slota 2,8e-17 birim değiyor (kayan nokta artığı), sağdakiler
    /// tam 0,0 — poster sol/sağ asimetrik çıkıyordu.
    func testHairlineOverlapDoesNotTriggerAScrim() throws {
        let targets = try scrimTargets(forTemplate: "makeup-look-01")
        XCTAssertEqual(targets, [], "kıl payı kesişim hap tetikledi")
    }

    /// Medya metnin kutusunu YARIM örtüyorsa hap yok, TAMAMEN örtüyorsa var.
    /// Eşiğin kendisi bir tasarım kararı; testin kilitlediği yön: şüphede kalan
    /// metne dokunulmaz.
    func testPartialMediaCoverageDoesNotTriggerAScrim() {
        func targets(mediaWidth: Double) -> Set<String> {
            let media = Layer(id: "photo",
                              frame: NormalizedRect(x: 0, y: 0.5,
                                                    width: mediaWidth * 2, height: 1),
                              content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .photo)))
            let template = Template(schemaVersion: 1, id: "coverage",
                                    name: LocalizedText(["en": "probe"]), category: "promo",
                                    canvas: Self.canvas, duration: 2,
                                    palette: ["background": "#101014", "text": "#FFFFFF"],
                                    layers: [media, Self.headline()])
            let context = RenderContext(canvasSize: CGSize(width: 180, height: 320),
                                        duration: 2, palette: template.resolvedPalette())
            return TemplateLayerBuilder.legibilityScrimTargets(template: template,
                                                               edits: UserEdits(),
                                                               context: context)
        }
        // Başlık kutusu 0,05–0,95 arası; medya soldan gelir.
        XCTAssertEqual(targets(mediaWidth: 0.5), [], "yarı örtülen metne hap kondu")
        XCTAssertEqual(targets(mediaWidth: 1.0), ["headline"], "tam örtülen metin korumasız")
    }

    /// Emoji sticker asla hap almaz — metin katmanı olarak taşınsa bile.
    func testEmojiStickerNeverGetsAScrim() {
        let media = Layer(id: "photo",
                          frame: NormalizedRect(x: 0.5, y: 0.5, width: 1, height: 1),
                          content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .photo)))
        let sticker = Layer(id: "sticker",
                            frame: NormalizedRect(x: 0.5, y: 0.3, width: 0.2, height: 0.1),
                            content: .text(TextContent(
                                key: "sticker",
                                default: LocalizedText(["en": "❤️"]),
                                font: FontSpec(name: "Helvetica", size: 0.08),
                                colorRole: "text")))
        let template = Template(schemaVersion: 1, id: "sticker-probe",
                                name: LocalizedText(["en": "probe"]), category: "promo",
                                canvas: Self.canvas, duration: 2,
                                palette: ["background": "#101014", "text": "#FFFFFF"],
                                layers: [media, sticker, Self.headline()])
        let context = RenderContext(canvasSize: CGSize(width: 180, height: 320),
                                    duration: 2, palette: template.resolvedPalette())
        let targets = TemplateLayerBuilder.legibilityScrimTargets(template: template,
                                                                  edits: UserEdits(),
                                                                  context: context)
        XCTAssertFalse(targets.contains("sticker"), "emoji sticker'a hap kondu")
        XCTAssertTrue(targets.contains("headline"), "kurulum hatalı: gerçek metin de hap almadı")
    }

    private func scrimTargets(forTemplate id: String) throws -> Set<String> {
        let url = Self.repositoryRoot.appendingPathComponent("templates/\(id).json")
        let template = try JSONDecoder().decode(Template.self, from: Data(contentsOf: url))
        let context = RenderContext(
            canvasSize: CGSize(width: template.canvas.width, height: template.canvas.height),
            duration: template.totalDuration,
            palette: template.resolvedPalette())
        return TemplateLayerBuilder.legibilityScrimTargets(template: template,
                                                           edits: UserEdits(),
                                                           context: context)
    }

    /// Şablonun kendi satır vurgusu (`highlightColorRole`) varsa zemin zaten
    /// opak bir renktir; üstüne hap koymak kadrajı karartır.
    func testExistingHighlightSuppressesTheScrim() {
        let template = overPhotoTemplate(legibility: nil, highlight: "accent")
        let context = RenderContext(canvasSize: CGSize(width: 180, height: 320),
                                    duration: 2,
                                    palette: template.resolvedPalette())
        let scene = TemplateLayerBuilder.build(template: template, edits: UserEdits(),
                                               photos: [:], context: context)
        XCTAssertTrue(scene.warnings.isEmpty)
    }

    // MARK: - 3) Model: geriye uyumluluk

    func testLegibilityFieldIsOptionalAndBackwardCompatible() throws {
        // Alanı hiç taşımayan (yani depodaki 127) şablon: güvenli varsayılan.
        let legacy = try JSONDecoder().decode(Template.self, from: Data(minimalJSON.utf8))
        XCTAssertNil(legacy.textLegibility)
        XCTAssertEqual(legacy.legibility, .auto)

        // Alan yoksa ENCODE da yazmamalı: 127 JSON'un round-trip'i değişmez.
        let encoded = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(legacy)) as? [String: Any]
        XCTAssertNil(encoded?["textLegibility"])

        for (raw, expected) in [("off", TextLegibility.off), ("always", .always),
                                ("auto", .auto),
                                // Bilinmeyen değer güvenli varsayılana düşer
                                // (preset/geçiş stilleriyle aynı kural).
                                ("shadow-2027", .auto)] {
            let json = minimalJSON.replacingOccurrences(
                of: "\"palette\"", with: "\"textLegibility\": \"\(raw)\", \"palette\"")
            let template = try JSONDecoder().decode(Template.self, from: Data(json.utf8))
            XCTAssertEqual(template.legibility, expected, "mod '\(raw)' yanlış çözüldü")
        }
    }

    /// Depodaki gerçek şablonların hepsi alan olmadan çözülüp `.auto` olmalı.
    func testShippedTemplatesDecodeWithSafeDefault() throws {
        let dir = Self.repositoryRoot.appendingPathComponent("templates")
        let files = try FileManager.default.contentsOfDirectory(at: dir,
                                                                includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
        XCTAssertGreaterThan(files.count, 100)
        for file in files {
            let template = try JSONDecoder().decode(Template.self,
                                                    from: Data(contentsOf: file))
            XCTAssertEqual(template.legibility, .auto, file.lastPathComponent)
        }
    }

    // MARK: - 4) Plaka, etiketiyle birlikte girer

    /// Gerçek şablon: hap ve yazısı aynı ana çekilmeli.
    func testPlateWaitsForItsLabelInShippedTemplate() throws {
        let url = Self.repositoryRoot.appendingPathComponent("templates/sale-promo-01.json")
        let template = try JSONDecoder().decode(Template.self, from: Data(contentsOf: url))
        let flat = template.flattenedLayersForRender(edits: UserEdits())
        func start(_ id: String) -> Double? { flat.first { $0.id == id }?.timing.start }

        XCTAssertEqual(start("cta-pill"), start("cta"), "CTA hapı yazısından önce giriyor")
        XCTAssertEqual(start("badge-bg"), start("badge"), "rozet zemini yazısından önce giriyor")
        // Etiketlerin KENDİ anı korunur: kaydırılan plakadır, ritim değil.
        XCTAssertEqual(start("cta"), 2.3)
        XCTAssertEqual(start("badge"), 0.45)
        // Plaka olmayan katmanlar hiç etkilenmez.
        XCTAssertEqual(start("headline"), 0.6)
        XCTAssertEqual(start("underline"), 1.1)
    }

    /// Metninden belirgin BÜYÜK bir kart plaka değildir; dekoru geciktirmek
    /// tasarımı çökertir (davetiye kartı 0. sn'de, "RSVP" 2,6. sn'de girer).
    func testLargeCardIsNotTreatedAsAPlate() {
        let card = Layer(id: "card",
                         frame: NormalizedRect(x: 0.5, y: 0.5, width: 0.8, height: 0.6),
                         content: .shape(ShapeContent(colorRole: "surface")))
        let label = Layer(id: "rsvp",
                          frame: NormalizedRect(x: 0.5, y: 0.6, width: 0.6, height: 0.05),
                          timing: Timing(start: 2.6),
                          content: .text(TextContent(key: "rsvp",
                                                     default: LocalizedText(["en": "RSVP"]),
                                                     font: FontSpec(name: "Helvetica", size: 0.03),
                                                     colorRole: "text")))
        let bound = Layer.bindingPlatesToLabels([card, label])
        XCTAssertEqual(bound[0].timing.start, 0, "kart plaka sanıldı ve geciktirildi")
    }

    /// Plakanın açık uçlu olmayan penceresi kaydırılırken SONU korunmalı:
    /// geç giren plaka geç de çıkmamalı.
    func testBoundPlateKeepsItsEnd() {
        let plate = Layer(id: "chip",
                          frame: NormalizedRect(x: 0.5, y: 0.5, width: 0.4, height: 0.08),
                          timing: Timing(start: 1.0, duration: 2.0),
                          content: .shape(ShapeContent(colorRole: "accent")))
        let label = Layer(id: "chip-text",
                          frame: NormalizedRect(x: 0.5, y: 0.5, width: 0.4, height: 0.05),
                          timing: Timing(start: 1.3),
                          content: .text(TextContent(key: "t",
                                                     default: LocalizedText(["en": "HI"]),
                                                     font: FontSpec(name: "Helvetica", size: 0.03),
                                                     colorRole: "text")))
        let bound = Layer.bindingPlatesToLabels([plate, label])
        XCTAssertEqual(bound[0].timing.start, 1.3)
        XCTAssertEqual(bound[0].timing.duration ?? 0, 1.7, accuracy: 0.0001)
    }

    /// Ve gerçek export'ta: hiçbir karede yazısız hap görünmemeli.
    func testPlateNeverAppearsWithoutItsLabelInTheRender() async throws {
        let canvas = Canvas(width: 360, height: 640, fps: 30)
        let plate = Layer(id: "pill",
                          frame: NormalizedRect(x: 0.5, y: 0.5, width: 0.8, height: 0.14),
                          timing: Timing(start: 1.0),
                          animations: [AnimationSpec(role: .in, preset: "bounce", duration: 0.7)],
                          content: .shape(ShapeContent(colorRole: "plate")))
        let label = Layer(id: "pill-text",
                          frame: NormalizedRect(x: 0.5, y: 0.5, width: 0.8, height: 0.1),
                          timing: Timing(start: 1.3),
                          animations: [AnimationSpec(role: .in, preset: "fadeIn", duration: 0.3)],
                          content: .text(TextContent(
                            key: "cta",
                            default: LocalizedText(["en": "LAST 3 DAYS"]),
                            font: FontSpec(name: "HelveticaNeue-Bold", size: 0.06),
                            colorRole: "label",
                            allCaps: true)))
        // Hap KIRMIZI, yazı YEŞİL: iki katman iki ayrı kanalda sayılır.
        let template = Template(schemaVersion: 1, id: "plate-probe",
                                name: LocalizedText(["en": "probe"]), category: "promo",
                                canvas: canvas, duration: 3,
                                palette: ["background": "#000000",
                                          "plate": "#FF0000",
                                          "label": "#00FF00"],
                                layers: [plate, label])
        let output = root.appendingPathComponent("plate.mp4")
        _ = try await TemplateExporter().export(TemplateExporter.Request(
            template: template, edits: UserEdits(), includeWatermark: false,
            workDirectory: root, outputURL: output))

        var plateAt: Double?
        var labelAt: Double?
        for frame in 0..<Int(3 * 30) {
            let t = Double(frame) / 30 + 0.5 / 30      // kare ORTASINDAN örnekle
            let counts = try await Self.counts(of: output, at: t)
            if plateAt == nil, counts.red > 200 { plateAt = t }
            if labelAt == nil, counts.green > 40 { labelAt = t }
            if plateAt != nil, labelAt != nil { break }
        }
        let plateTime = try XCTUnwrap(plateAt, "hap hiç görünmedi")
        let labelTime = try XCTUnwrap(labelAt, "yazı hiç görünmedi")
        // Yazı kendi fade'ini oynatırken hapın bir-iki kare önde olması normal;
        // eskisi gibi 0,3 sn boyunca BOŞ durması değil.
        XCTAssertLessThan(plateTime - labelTime, 0.10,
                          "hap yazısından \(plateTime - labelTime) sn önce girdi")
    }

    // MARK: - Şablon kurulumları

    private func overPhotoTemplate(legibility: TextLegibility?,
                                   highlight: String? = nil) -> Template {
        Template(schemaVersion: 1, id: "over-photo",
                 name: LocalizedText(["en": "probe"]), category: "promo",
                 canvas: Self.canvas, duration: 2,
                 palette: ["background": "#000000", "text": "#FFFFFF",
                           "accent": "#FF2E63", "surface": "#101014"],
                 textLegibility: legibility,
                 layers: [Self.photoSlot,
                          Self.headline(highlight: highlight)])
    }

    private func solidBackgroundTemplate(legibility: TextLegibility?) -> Template {
        Template(schemaVersion: 1, id: "solid",
                 name: LocalizedText(["en": "probe"]), category: "minimal",
                 canvas: Self.canvas, duration: 2,
                 palette: ["background": "#1B2A4A", "text": "#FFFFFF",
                           "accent": "#FF2E63", "surface": "#101014"],
                 textLegibility: legibility,
                 layers: [Self.headline()])
    }

    private func veiledTemplate(veil: String, legibility: TextLegibility? = nil) -> Template {
        let scrim = Layer(id: "scrim",
                          frame: NormalizedRect(x: 0.5, y: 0.5, width: 1, height: 1),
                          content: .shape(ShapeContent(colorRole: "veil")))
        return Template(schemaVersion: 1, id: "veiled-\(veil.dropFirst())",
                        name: LocalizedText(["en": "probe"]), category: "promo",
                        canvas: Self.canvas, duration: 2,
                        palette: ["background": "#000000", "text": "#FFFFFF",
                                  "accent": "#FF2E63", "veil": veil],
                        textLegibility: legibility,
                        layers: [Self.photoSlot, scrim, Self.headline()])
    }

    private func cardOverPhotoTemplate(legibility: TextLegibility?) -> Template {
        let card = Layer(id: "card",
                         frame: NormalizedRect(x: 0.5, y: 0.5, width: 0.95, height: 0.4),
                         content: .shape(ShapeContent(colorRole: "surface")))
        return Template(schemaVersion: 1, id: "card-over-photo",
                        name: LocalizedText(["en": "probe"]), category: "promo",
                        canvas: Self.canvas, duration: 2,
                        palette: ["background": "#000000", "text": "#FFFFFF",
                                  "accent": "#FF2E63", "surface": "#101014"],
                        textLegibility: legibility,
                        layers: [Self.photoSlot, card, Self.headline()])
    }

    private static let canvas = Canvas(width: 180, height: 320, fps: 30)

    private static let photoSlot = Layer(
        id: "photo",
        frame: NormalizedRect(x: 0.5, y: 0.5, width: 1, height: 1),
        content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .photo)))

    private static func headline(highlight: String? = nil) -> Layer {
        Layer(id: "headline",
              frame: NormalizedRect(x: 0.5, y: 0.5, width: 0.9, height: 0.2),
              content: .text(TextContent(
                key: "headline",
                default: LocalizedText(["en": "SUMMER SALE"]),
                font: FontSpec(name: "HelveticaNeue-Bold", size: 0.07),
                colorRole: "text",
                maxLines: 2,
                allCaps: true,
                highlightColorRole: highlight)))
    }

    // MARK: - Ölçüm

    /// Metin bandının ortalaması ve standart sapması (tam çözünürlükte).
    private func stats(of template: Template) async throws -> (mean: Double, deviation: Double) {
        let output = root.appendingPathComponent(
            "\(template.id)-\(template.textLegibility?.rawValue ?? "default").mp4")
        _ = try await TemplateExporter().export(TemplateExporter.Request(
            template: template, edits: UserEdits(),
            photos: [0: Self.whiteImage], includeWatermark: false,
            workDirectory: root, outputURL: output))
        return try await Self.bandStats(of: output, at: 1.0)
    }

    /// Bembeyaz fotoğraf: beyaz metnin kaybolduğu en kötü durum.
    private static let whiteImage: CGImage = {
        let context = CGContext(data: nil, width: 180, height: 320, bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 180, height: 320))
        return context.makeImage()!
    }()

    private static func pixels(of url: URL, at seconds: Double)
        async throws -> (data: [UInt8], width: Int, height: Int) {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(
            at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress,
                                    width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0,
                                           width: image.width, height: image.height))
        }
        return (data, image.width, image.height)
    }

    /// Kadrajın orta bandındaki parlaklık dağılımı. Standart sapma
    /// "ayırt edilebilir bir şey var mı" sorusunun cevabıdır.
    private static func bandStats(of url: URL, at seconds: Double)
        async throws -> (mean: Double, deviation: Double) {
        let (data, width, height) = try await pixels(of: url, at: seconds)
        var values: [Double] = []
        for y in Int(Double(height) * 0.42)..<Int(Double(height) * 0.58) {
            for x in 0..<width {
                let i = (y * width + x) * 4
                values.append((0.2126 * Double(data[i]) + 0.7152 * Double(data[i + 1])
                               + 0.0722 * Double(data[i + 2])) / 255)
            }
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return (mean, variance.squareRoot())
    }

    /// Belirgin KIRMIZI ve belirgin YEŞİL piksel sayısı.
    private static func counts(of url: URL, at seconds: Double)
        async throws -> (red: Int, green: Int) {
        let (data, width, height) = try await pixels(of: url, at: seconds)
        var red = 0, green = 0
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            let r = Int(data[i]), g = Int(data[i + 1])
            if r > 110 && g < 60 { red += 1 }
            if g > 110 && r < 90 { green += 1 }
        }
        return (red, green)
    }

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TemplateKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // TemplateKit
            .deletingLastPathComponent()   // repo
    }

    private let minimalJSON = """
    {"schemaVersion": 1, "id": "x", "name": {"en": "X"}, "category": "minimal",
     "duration": 3, "palette": {"background": "#000000"}, "layers": []}
    """
}
#endif
