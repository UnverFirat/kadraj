#if canImport(QuartzCore)
import XCTest
import QuartzCore
@testable import TemplateKit

/// Lottie seam'i: renderer takılıyken katman ağacına giriyor mu, takılı
/// değilken şablon yine açılıyor mu, `colorRemap` doğru çözülüyor mu.
final class LottieTests: XCTestCase {

    /// Sahte renderer: gerçek lottie-ios yerine işaretli bir katman döner.
    private final class SpyRenderer: LottieRendering, @unchecked Sendable {
        private let lock = NSLock()
        private var _requests: [LottieRequest] = []
        var requests: [LottieRequest] { lock.lock(); defer { lock.unlock() }; return _requests }
        var returnsNil = false

        func makeLayer(for request: LottieRequest) -> CALayer? {
            lock.lock(); _requests.append(request); lock.unlock()
            if returnsNil { return nil }
            let layer = CALayer()
            layer.name = "spy-lottie"
            return layer
        }
    }

    override func tearDown() {
        LottieRendererRegistry.install(nil)
        super.tearDown()
    }

    private func template() -> Template {
        let layer = Layer(id: "sticker",
                          frame: NormalizedRect(x: 0.5, y: 0.4, width: 0.5, height: 0.3),
                          timing: Timing(start: 1, duration: 2),
                          content: .lottie(LottieContent(
                            asset: "confetti.json", loopMode: .loop,
                            colorRemap: ["#ff0000": "accent", "00FF00": "yok"])))
        return Template(schemaVersion: 1, id: "lottie-test",
                        name: LocalizedText(["tr": "Lottie"]), category: "minimal",
                        duration: 5,
                        palette: ["background": "#000000", "accent": "#D9A441"],
                        layers: [layer])
    }

    private func context(for template: Template) -> RenderContext {
        RenderContext(canvasSize: CGSize(width: 1080, height: 1920),
                      duration: template.totalDuration,
                      palette: template.palette.compactMapValues { RGBAColor(hex: $0) })
    }

    func testRendererReceivesResolvedColorsAndTiming() {
        let spy = SpyRenderer()
        LottieRendererRegistry.install(spy)
        let template = self.template()

        let scene = TemplateLayerBuilder.build(template: template, edits: UserEdits(),
                                               photos: [:], context: context(for: template))

        let request = try? XCTUnwrap(spy.requests.first)
        XCTAssertEqual(request?.asset, "confetti.json")
        XCTAssertEqual(request?.loopMode, .loop)
        XCTAssertEqual(request?.startTime, 1, "animasyon katmanın sahneye girdiği anda başlamalı")
        XCTAssertEqual(request?.duration, 2, "süre presence penceresi kadar olmalı")
        // Bilinen rol çözülür, bilinmeyen rol sessizce atlanır.
        XCTAssertEqual(request?.colorOverrides.count, 1)
        XCTAssertEqual(request?.colorOverrides["#FF0000"], RGBAColor(hex: "#D9A441"))
        XCTAssertTrue(scene.warnings.isEmpty, "renderer takılıyken uyarı olmamalı")

        // Katman gerçekten ağaca girdi mi?
        XCTAssertTrue(containsLayer(named: "spy-lottie", in: scene.root))
    }

    func testWithoutRendererTemplateStillBuildsWithWarning() {
        let template = self.template()
        let scene = TemplateLayerBuilder.build(template: template, edits: UserEdits(),
                                               photos: [:], context: context(for: template))
        XCTAssertFalse(containsLayer(named: "spy-lottie", in: scene.root))
        XCTAssertEqual(scene.warnings.count, 1)
        XCTAssertTrue(scene.warnings[0].contains("no renderer installed"))
        // Yer tutucu yine de ağaçta: düzen kaymaz.
        XCTAssertTrue(containsLayer(named: "lottie:confetti.json", in: scene.root))
    }

    /// Renderer varlığı açamazsa (bozuk/eksik json) yer tutucuya düşülmeli.
    func testRendererReturningNilFallsBackToPlaceholder() {
        let spy = SpyRenderer()
        spy.returnsNil = true
        LottieRendererRegistry.install(spy)
        let template = self.template()
        let scene = TemplateLayerBuilder.build(template: template, edits: UserEdits(),
                                               photos: [:], context: context(for: template))
        XCTAssertEqual(spy.requests.count, 1)
        XCTAssertEqual(scene.warnings.count, 1)
    }

    func testHexKeysAreNormalized() {
        XCTAssertEqual(LottieContent.normalizedHex("ff0000"), "#FF0000")
        XCTAssertEqual(LottieContent.normalizedHex("#Ff0000"), "#FF0000")
    }

    private func containsLayer(named name: String, in layer: CALayer) -> Bool {
        if layer.name == name { return true }
        return (layer.sublayers ?? []).contains { containsLayer(named: name, in: $0) }
    }
}
#endif

#if canImport(QuartzCore)
/// `colorRemap`'in Lottie JSON'una gerçekten uygulanması (adaptörün lottie-ios'a
/// vermeden önce yaptığı dönüşüm). Bu taraf bağımlılıksız olduğu için test
/// edilebiliyor — gerçek çizim doğrulaması simulator'da.
final class LottieAssetRewriterTests: XCTestCase {

    private func data(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private func object(_ data: Data) -> [String: Any] {
        try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    /// Kırmızı dolgu, alfası korunarak palet rengine dönmeli.
    func testStaticFillColorIsReplaced() throws {
        let source = data([
            "layers": [[
                "shapes": [[
                    "ty": "gr",
                    "it": [
                        ["ty": "rc", "s": ["a": 0, "k": [20, 30]]],
                        ["ty": "fl", "c": ["a": 0, "k": [1, 0, 0, 1]], "o": ["a": 0, "k": 100]]
                    ]
                ]]
            ]]
        ])
        let result = try LottieAssetRewriter.apply(["#FF0000": RGBAColor(hex: "#00FF80")!], to: source)
        XCTAssertEqual(result.replacements, 1)

        let fill = ((((object(result.data)["layers"] as! [[String: Any]])[0]["shapes"]
                      as! [[String: Any]])[0]["it"] as! [[String: Any]])[1])
        let components = (fill["c"] as! [String: Any])["k"] as! [Double]
        XCTAssertEqual(components[0], 0, accuracy: 0.004)
        XCTAssertEqual(components[1], 1, accuracy: 0.004)
        XCTAssertEqual(components[2], 0.502, accuracy: 0.004)
        XCTAssertEqual(components[3], 1, "alfa varlığın kendi değeriyle kalmalı")
    }

    /// Keyframe'li renk: her karedeki "s"/"e" ayrı ayrı eşlenir.
    func testKeyframedColorIsReplaced() throws {
        let source = data([
            "layers": [[
                "shapes": [[
                    "ty": "fl",
                    "c": ["a": 1, "k": [
                        ["t": 0, "s": [1, 0, 0, 1], "e": [0, 0, 1, 1]],
                        ["t": 30, "s": [0, 0, 1, 1]]
                    ]]
                ]]
            ]]
        ])
        let result = try LottieAssetRewriter.apply([
            "#FF0000": RGBAColor(hex: "#FFFFFF")!,
            "#0000FF": RGBAColor(hex: "#000000")!
        ], to: source)
        XCTAssertEqual(result.replacements, 3, "iki kare, üç renk alanı (s, e, s)")

        let keyframes = ((((object(result.data)["layers"] as! [[String: Any]])[0]["shapes"]
                           as! [[String: Any]])[0]["c"] as! [String: Any])["k"] as! [[String: Any]])
        XCTAssertEqual((keyframes[0]["s"] as! [Double])[0], 1)
        XCTAssertEqual((keyframes[0]["e"] as! [Double])[2], 0)
        XCTAssertEqual((keyframes[1]["s"] as! [Double])[2], 0)
    }

    /// Renge benzeyen ama renk OLMAYAN diziler (konum, ölçek) korunmalı.
    func testNonColorArraysAreUntouched() throws {
        let source = data([
            "layers": [[
                "ks": ["p": ["a": 0, "k": [1, 0, 0]], "s": ["a": 0, "k": [100, 100, 100]]]
            ]]
        ])
        let result = try LottieAssetRewriter.apply(["#FF0000": RGBAColor(hex: "#00FF00")!], to: source)
        XCTAssertEqual(result.replacements, 0)

        let transform = (object(result.data)["layers"] as! [[String: Any]])[0]["ks"] as! [String: Any]
        XCTAssertEqual(((transform["p"] as! [String: Any])["k"] as! [Double]), [1, 0, 0])
    }

    /// Eski araçların 0–255 yazdığı renkler de eşlenir ve aynı ölçekte döner.
    func testLegacyByteScaleColors() throws {
        let source = data(["layers": [["shapes": [["ty": "fl", "c": ["a": 0, "k": [255, 0, 0]]]]]]])
        let result = try LottieAssetRewriter.apply(["#FF0000": RGBAColor(hex: "#0000FF")!], to: source)
        XCTAssertEqual(result.replacements, 1)

        let components = ((((object(result.data)["layers"] as! [[String: Any]])[0]["shapes"]
                            as! [[String: Any]])[0]["c"] as! [String: Any])["k"] as! [Double])
        XCTAssertEqual(components, [0, 0, 255])
    }

    /// Eşleme yoksa veri hiç dokunulmadan dönmeli (gereksiz JSON turu yok).
    func testEmptyOverridesReturnsSourceUntouched() throws {
        let source = data(["v": "5.7.4"])
        let result = try LottieAssetRewriter.apply([:], to: source)
        XCTAssertEqual(result.data, source)
        XCTAssertEqual(result.replacements, 0)
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try LottieAssetRewriter.apply(
            ["#FF0000": RGBAColor(hex: "#FFFFFF")!], to: Data("not json".utf8)))
    }
}
#endif
