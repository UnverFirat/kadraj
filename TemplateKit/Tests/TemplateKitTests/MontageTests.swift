import XCTest
@testable import TemplateKit

final class MontageTimelineTests: XCTestCase {

    private func scene(_ id: String, _ duration: Double,
                       _ transition: TransitionSpec? = nil) -> TemplateScene {
        TemplateScene(id: id, duration: duration, layers: [], transition: transition)
    }

    func testCutTransitionsDoNotOverlap() {
        let timeline = MontageTimeline(scenes: [
            scene("a", 4, TransitionSpec(style: "cut", duration: 0.5)),
            scene("b", 3)
        ])
        // cut örtüşme yaratmaz: 4 + 3 = 7.
        XCTAssertEqual(timeline.totalDuration, 7, accuracy: 0.0001)
        XCTAssertEqual(timeline.windows[0].start, 0)
        XCTAssertEqual(timeline.windows[1].start, 4)
    }

    func testCrossDissolveOverlaps() {
        let timeline = MontageTimeline(scenes: [
            scene("a", 4, TransitionSpec(style: "crossDissolve", duration: 0.6)),
            scene("b", 4)
        ])
        // Örtüşme 0.6: toplam 8 - 0.6 = 7.4; b, 3.4'te başlar.
        XCTAssertEqual(timeline.totalDuration, 7.4, accuracy: 0.0001)
        XCTAssertEqual(timeline.windows[1].start, 3.4, accuracy: 0.0001)
    }

    func testNewTransitionStylesOverlap() {
        // slide/zoom/whip de (crossDissolve gibi) sahneleri örtüştürmeli.
        for style in ["slide", "slideUp", "zoomIn", "whip"] {
            let timeline = MontageTimeline(scenes: [
                scene("a", 4, TransitionSpec(style: style, duration: 0.5)),
                scene("b", 4)
            ])
            XCTAssertEqual(timeline.totalDuration, 7.5, accuracy: 0.0001,
                           "stil '\(style)' örtüşmedi")
        }
        // Tanınmayan stil örtüşmez (güvenli cut).
        let cutLike = MontageTimeline(scenes: [
            scene("a", 4, TransitionSpec(style: "hologram", duration: 0.5)),
            scene("b", 4)
        ])
        XCTAssertEqual(cutLike.totalDuration, 8, accuracy: 0.0001)
    }

    func testSegmentsCoverTimelineWithoutGaps() throws {
        let timeline = MontageTimeline(scenes: [
            scene("a", 4, TransitionSpec(style: "blurDissolve", duration: 0.6)),
            scene("b", 4, TransitionSpec(style: "crossDissolve", duration: 0.5)),
            scene("c", 3.5)
        ])
        // Segmentler boşluksuz ve sıralı olmalı, 0'dan totalDuration'a.
        let first = try XCTUnwrap(timeline.segments.first)
        let last = try XCTUnwrap(timeline.segments.last)
        XCTAssertEqual(first.start, 0, accuracy: 0.0001)
        XCTAssertEqual(last.end, timeline.totalDuration, accuracy: 0.0001)
        for (a, b) in zip(timeline.segments, timeline.segments.dropFirst()) {
            XCTAssertEqual(a.end, b.start, accuracy: 0.0001)
        }
        // Sıra: scene, transition, scene, transition, scene.
        let kinds = timeline.segments.map { seg -> String in
            if case .transition = seg { return "T" } else { return "S" }
        }
        XCTAssertEqual(kinds, ["S", "T", "S", "T", "S"])
    }

    func testTransitionSegmentTimesMatchOverlap() {
        let timeline = MontageTimeline(scenes: [
            scene("a", 4, TransitionSpec(style: "crossDissolve", duration: 0.6)),
            scene("b", 4)
        ])
        guard case .transition(_, _, _, let start, let end)? =
                timeline.segments.first(where: { if case .transition = $0 { return true }; return false })
        else { return XCTFail("no transition segment") }
        // Örtüşme penceresi [3.4, 4.0].
        XCTAssertEqual(start, 3.4, accuracy: 0.0001)
        XCTAssertEqual(end, 4.0, accuracy: 0.0001)
    }
}

final class MontageTemplateTests: XCTestCase {

    private func loadFixture() throws -> Template {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/reel-collage-01",
                                                  withExtension: "json"))
        return try JSONDecoder().decode(Template.self, from: Data(contentsOf: url))
    }

    func testDecodesMontageFixture() throws {
        let template = try loadFixture()
        XCTAssertEqual(template.schemaVersion, 2)
        XCTAssertNil(template.explicitDuration)
        XCTAssertEqual(template.scenes?.count, 3)
        // 4 + 4 + 3.5, geçişler: blur 0.6 + cross 0.5 = 1.1 örtüşme -> 10.4.
        XCTAssertEqual(template.totalDuration, 10.4, accuracy: 0.0001)
        XCTAssertEqual(template.scenes?[0].transition?.style, "blurDissolve")
    }

    func testMontageFixturePassesValidation() throws {
        XCTAssertNoThrow(try TemplateValidator.validate(try loadFixture()))
    }

    func testFlattenExcludesVideoSlotsAndOffsetsTiming() throws {
        let template = try loadFixture()
        // 3 kolaj bandı + hero-1 + hero-2 video slotu.
        let edits = UserEdits(slots: [
            0: SlotAssignment(assetIdentifier: "a", kind: .video),
            1: SlotAssignment(assetIdentifier: "b", kind: .video),
            2: SlotAssignment(assetIdentifier: "c", kind: .video),
            3: SlotAssignment(assetIdentifier: "d", kind: .video),
            4: SlotAssignment(assetIdentifier: "e", kind: .video)
        ])
        let flat = template.flattenedLayersForRender(edits: edits)
        // Video slotları hariç: intro-title, headline, outro-bar, handle = 4.
        XCTAssertEqual(flat.count, 4)
        XCTAssertFalse(flat.contains { if case .mediaSlot = $0.content { return true }; return false })

        // headline (2. sahne, sahne start 0.7) mutlak zamanda 3.4 + 0.7 = 4.1.
        let headline = try XCTUnwrap(flat.first { $0.id == "headline" })
        XCTAssertEqual(headline.timing.start, 4.1, accuracy: 0.0001)

        // outro-bar (3. sahne). 3. sahne start: 3.4 (b başlangıcı) + 4 - 0.5 = 6.9;
        // + local 0.4 = 7.3.
        let bar = try XCTUnwrap(flat.first { $0.id == "outro-bar" })
        XCTAssertEqual(bar.timing.start, 7.3, accuracy: 0.0001)
    }

    func testScenesRequireSchemaV2() {
        var template = Template(
            schemaVersion: 1, id: "x", name: LocalizedText(["en": "X"]),
            category: "promo", palette: ["background": "#000000"],
            scenes: [TemplateScene(id: "s", duration: 2)])
        XCTAssertThrowsError(try TemplateValidator.validate(template)) {
            XCTAssertEqual($0 as? TemplateValidationError, .scenesRequireSchemaV2)
        }
        // schemaVersion 2 ile geçmeli.
        template.schemaVersion = 2
        XCTAssertNoThrow(try TemplateValidator.validate(template))
    }

    func testRejectsOverlongTransition() {
        let template = Template(
            schemaVersion: 2, id: "x", name: LocalizedText(["en": "X"]),
            category: "promo", palette: ["background": "#000000"],
            scenes: [
                TemplateScene(id: "a", duration: 2,
                              transition: TransitionSpec(style: "crossDissolve", duration: 1.5)),
                TemplateScene(id: "b", duration: 4)
            ])
        // 1.5 > min(2,4)/2 = 1.0 -> geçersiz.
        XCTAssertThrowsError(try TemplateValidator.validate(template)) {
            XCTAssertEqual($0 as? TemplateValidationError, .invalidTransition(sceneID: "a"))
        }
    }

    func testRejectsTooManyVideoSlotsInScene() {
        var layers: [Layer] = []
        for i in 0..<5 {
            layers.append(Layer(
                id: "v\(i)",
                frame: NormalizedRect(x: 0.5, y: 0.5, width: 1, height: 0.2),
                content: .mediaSlot(MediaSlotContent(slotIndex: i, media: .video))))
        }
        let template = Template(
            schemaVersion: 2, id: "x", name: LocalizedText(["en": "X"]),
            category: "promo", palette: ["background": "#000000"],
            scenes: [TemplateScene(id: "a", duration: 3, layers: layers)])
        XCTAssertThrowsError(try TemplateValidator.validate(template)) {
            XCTAssertEqual($0 as? TemplateValidationError, .tooManyVideoSlotsInScene(sceneID: "a"))
        }
    }

    func testSingleSceneTemplateStillAllowsOnlyOneVideoInV1Path() {
        // Sahnesiz (v1) şablonda hâlâ tek video kuralı geçerli.
        let template = Template(
            schemaVersion: 1, id: "x", name: LocalizedText(["en": "X"]),
            category: "promo", duration: 5, palette: ["background": "#000000"],
            layers: [
                Layer(id: "a", frame: NormalizedRect(x: 0.5, y: 0.25, width: 1, height: 0.5),
                      content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .video))),
                Layer(id: "b", frame: NormalizedRect(x: 0.5, y: 0.75, width: 1, height: 0.5),
                      content: .mediaSlot(MediaSlotContent(slotIndex: 1, media: .video)))
            ])
        XCTAssertThrowsError(try TemplateValidator.validate(template)) {
            XCTAssertEqual($0 as? TemplateValidationError, .multipleVideoSlots)
        }
    }

    func testPhotoMontageDecodesAndFlattensMediaOut() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/photo-slideshow-01",
                                                  withExtension: "json"))
        let template = try JSONDecoder().decode(Template.self, from: Data(contentsOf: url))
        XCTAssertNoThrow(try TemplateValidator.validate(template))
        XCTAssertEqual(template.scenes?.count, 4)

        // Foto slotlar da (video gibi) 1. geçişe gider → flatten'da hariç.
        // Kullanıcı foto atamış olsun; yine de hariç tutulmalı.
        var edits = UserEdits()
        for i in 0..<4 { edits.slots[i] = SlotAssignment(assetIdentifier: "p", kind: .photo) }
        let flat = template.flattenedLayersForRender(edits: edits)
        XCTAssertFalse(flat.contains {
            if case .mediaSlot = $0.content { return true }; return false
        })
        // Grafik/metin katmanları kalmalı: cap0 (s0) + scrim, endline, endtext (s3) = 4.
        XCTAssertEqual(flat.count, 4)
        // cap0 mutlak zamanlı (s0 start 0 + local 0.4).
        let cap = try XCTUnwrap(flat.first { $0.id == "cap0" })
        XCTAssertEqual(cap.timing.start, 0.4, accuracy: 0.0001)
    }

    func testMissingDurationRejectedWhenNoScenes() {
        let template = Template(
            schemaVersion: 1, id: "x", name: LocalizedText(["en": "X"]),
            category: "promo", duration: nil, palette: ["background": "#000000"],
            layers: [])
        XCTAssertThrowsError(try TemplateValidator.validate(template)) {
            XCTAssertEqual($0 as? TemplateValidationError, .missingDuration)
        }
    }
}
