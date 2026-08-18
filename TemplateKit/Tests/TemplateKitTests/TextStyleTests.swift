#if canImport(AVFoundation) && canImport(QuartzCore)
import XCTest
import AVFoundation
@testable import TemplateKit

/// Kullanıcının metin stili (boyut / renk / yazı tipi) gerçekten render'a
/// gidiyor mu — export hattının tamamı üzerinden.
///
/// Ölçüm hilesi: siyah zemin üzerine BEYAZ metin. Karenin ortalama parlaklığı
/// "ne kadar beyaz piksel var" demek, yani metnin büyüklüğünü ve rengini
/// dolaylı olarak ölçer. Katman ağacına bakan bir test bunu gösteremezdi
/// (TextRasterizer'ın çıktısı piksel).
final class TextStyleTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("text-style-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testUserFontSizeReachesTheRender() async throws {
        let small = try await brightness(style: TextStyleOverride(scale: 0.6))
        let normal = try await brightness(style: TextStyleOverride())
        let large = try await brightness(style: TextStyleOverride(scale: 1.8))

        XCTAssertGreaterThan(large, normal, "kullanıcı büyüttüğünde metin BÜYÜMELİ")
        XCTAssertLessThan(small, normal, "kullanıcı küçülttüğünde metin KÜÇÜLMELİ")
    }

    func testUserTextColorReachesTheRender() async throws {
        let template = try await brightness(style: TextStyleOverride())
        // Zeminle aynı renge boyanan metin kaybolur: ortalama parlaklık ~0.
        let black = try await brightness(style: TextStyleOverride(colorHex: "#000000"))
        XCTAssertLessThan(black, template * 0.35,
                          "renk override'ı uygulanmadı (metin hâlâ beyaz)")
    }

    /// Yazı tipi ailesi değişince kare de değişmeli. Hangi fontun "daha parlak"
    /// olduğu iddia EDİLEMEZ (sistemde hangi font var, bilinmez) — bu yüzden
    /// yalnız "çıktı farklı" doğrulanır.
    func testUserFontFamilyChangesTheRender() async throws {
        let base = try await brightness(style: TextStyleOverride())
        let display = try await brightness(style: TextStyleOverride(fontFamily: "display"))
        XCTAssertNotEqual(base, display, accuracy: 0.0,
                          "yazı tipi ailesi render'a gitmedi")
    }

    func testStyleOverrideIsClampedAndBackwardCompatible() throws {
        XCTAssertEqual(TextStyleOverride(scale: 0).scale, 0.6)
        XCTAssertEqual(TextStyleOverride(scale: 99).scale, 1.8)
        XCTAssertEqual(TextStyleOverride(scale: .nan).scale, 1)

        // Stil alanı hiç taşımayan eski taslak açılabilmeli.
        let legacy = #"{"textOverrides": {"a": "b"}}"#
        let edits = try JSONDecoder().decode(UserEdits.self, from: Data(legacy.utf8))
        XCTAssertEqual(edits.textOverrides["a"], "b")
        XCTAssertTrue(edits.textStyles.isEmpty)

        let roundTrip = try JSONDecoder().decode(
            UserEdits.self,
            from: try JSONEncoder().encode(
                UserEdits(textStyles: ["t": TextStyleOverride(scale: 1.4,
                                                             colorHex: "#FF0000",
                                                             fontFamily: "serif")])))
        XCTAssertEqual(roundTrip.textStyles["t"]?.scale, 1.4)
        XCTAssertEqual(roundTrip.textStyles["t"]?.colorHex, "#FF0000")
        XCTAssertEqual(roundTrip.textStyles["t"]?.fontFamily, "serif")
    }

    /// Yazı tipi ailesi şablonun KALINLIĞINI korumalı: kullanıcı yazı tipini
    /// değiştirdiğinde başlığın ağırlığı da kaybolursa tasarım çöküyor.
    func testFontFamilyPreservesWeight() {
        XCTAssertEqual(TextFontFamily.serif.postScriptName(preservingWeightOf: "HelveticaNeue-Bold"),
                       "Didot-Bold")
        XCTAssertEqual(TextFontFamily.serif.postScriptName(preservingWeightOf: "HelveticaNeue"),
                       "Didot")
        XCTAssertEqual(TextFontFamily.sans.postScriptName(preservingWeightOf: "Didot-Heavy"),
                       "HelveticaNeue-Bold")
    }

    // MARK: - Yardımcılar

    /// Verilen stille render alıp karenin ortalama parlaklığını döner.
    private func brightness(style: TextStyleOverride) async throws -> Double {
        let canvas = Canvas(width: 180, height: 320, fps: 30)
        let text = Layer(id: "headline",
                         frame: NormalizedRect(x: 0.5, y: 0.5, width: 0.9, height: 0.5),
                         content: .text(TextContent(
                            key: "headline",
                            default: LocalizedText(["en": "HHHH HHHH", "tr": "HHHH HHHH"]),
                            font: FontSpec(name: "HelveticaNeue-Bold", size: 0.09),
                            colorRole: "text",
                            alignment: .center,
                            maxLines: 2)))
        let template = Template(schemaVersion: 1, id: "text-style-probe",
                                name: LocalizedText(["en": "probe"]), category: "minimal",
                                canvas: canvas, duration: 2,
                                palette: ["background": "#000000", "text": "#FFFFFF"],
                                layers: [text])
        let edits = UserEdits(textStyles: style.isEmpty ? [:] : ["headline": style])
        let output = root.appendingPathComponent(
            "out-\(style.scale)-\(style.colorHex ?? "-")-\(style.fontFamily ?? "-").mp4")
        _ = try await TemplateExporter().export(TemplateExporter.Request(
            template: template, edits: edits, includeWatermark: false,
            workDirectory: root, outputURL: output))
        return try await RenderProbe.meanGray(of: output, at: 1.0)
    }
}
#endif
