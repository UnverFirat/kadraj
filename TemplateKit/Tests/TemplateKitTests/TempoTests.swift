import XCTest
@testable import TemplateKit

final class TemplateTempoTests: XCTestCase {

    private func makeTemplate(duration: Double) -> Template {
        let layer = Layer(
            id: "title",
            frame: NormalizedRect(x: 0.5, y: 0.5, width: 0.8, height: 0.1),
            timing: Timing(start: 1.0, duration: 2.0),
            animations: [AnimationSpec(role: .in, preset: "fadeIn",
                                       delay: 0.5, duration: 0.6)],
            content: .text(TextContent(key: "title",
                                       default: LocalizedText(["en": "Hi", "tr": "Selam"]),
                                       font: FontSpec(name: "AvenirNext-Bold", size: 0.05),
                                       colorRole: "textPrimary")))
        return Template(schemaVersion: 1, id: "t", name: LocalizedText(["en": "T"]),
                        category: "minimal", isPro: false,
                        canvas: Canvas(width: 1080, height: 1920, fps: 30),
                        duration: duration,
                        palette: ["background": "#000000", "textPrimary": "#FFFFFF"],
                        layers: [layer])
    }

    /// 120 BPM'de bir ölçü 2 sn; 6,3 sn'lik şablon 6,0'a oturmalı.
    func testAlignsDurationToWholeBars() {
        let aligned = TemplateTempo.aligned(makeTemplate(duration: 6.3), bpm: 120)
        XCTAssertEqual(aligned.totalDuration, 6.0, accuracy: 0.001)
    }

    /// Tüm zamanlar AYNI oranda ölçeklenmeli — tasarımın iç ritmi korunur.
    func testScalesLayerTimingProportionally() {
        let aligned = TemplateTempo.aligned(makeTemplate(duration: 6.3), bpm: 120)
        let scale = 6.0 / 6.3
        let layer = aligned.layers[0]
        XCTAssertEqual(layer.timing.start, 1.0 * scale, accuracy: 0.001)
        XCTAssertEqual(layer.timing.duration ?? 0, 2.0 * scale, accuracy: 0.001)
        XCTAssertEqual(layer.animations[0].delay, 0.5 * scale, accuracy: 0.001)
        XCTAssertEqual(layer.animations[0].duration, 0.6 * scale, accuracy: 0.001)
    }

    /// Gereken esneme çok büyükse şablona DOKUNULMAZ — süre bir tasarım kararı.
    func testLeavesTemplateAloneWhenStretchTooLarge() {
        // 40 BPM'de bir ölçü 6 sn; 4 sn'lik şablonu 6'ya çekmek %50 esneme.
        let original = makeTemplate(duration: 4.0)
        let aligned = TemplateTempo.aligned(original, bpm: 40)
        XCTAssertEqual(aligned.totalDuration, original.totalDuration)
    }

    /// Zaten ölçüdeyse gereksiz yeniden render tetiklenmemeli.
    func testNoOpWhenAlreadyOnBar() {
        let aligned = TemplateTempo.aligned(makeTemplate(duration: 6.0), bpm: 120)
        XCTAssertEqual(aligned.totalDuration, 6.0, accuracy: 0.001)
        XCTAssertEqual(aligned.layers[0].timing.start, 1.0, accuracy: 0.001)
    }

    /// Sahneli (montaj) şablonda sahne ve geçiş süreleri de ölçeklenir.
    func testScalesScenesAndTransitions() {
        let scene = TemplateScene(id: "a", duration: 3.0, layers: [],
                                  transition: TransitionSpec(style: "crossDissolve",
                                                             duration: 0.5))
        let second = TemplateScene(id: "b", duration: 3.5, layers: [])
        var template = makeTemplate(duration: 6.0)
        template.schemaVersion = 2
        template.explicitDuration = nil
        template.scenes = [scene, second]
        let scaled = template.timeScaled(by: 2)
        XCTAssertEqual(scaled.scenes?[0].duration, 6.0)
        XCTAssertEqual(scaled.scenes?[0].transition?.duration, 1.0)
        XCTAssertEqual(scaled.scenes?[1].duration, 7.0)
    }
}
