#if canImport(AVFoundation) && canImport(CoreImage)
import XCTest
import AVFoundation
import CoreImage
import CoreVideo
@testable import TemplateKit

/// Klip hızı (hızlandır / ağır çekim) — gerçek render üzerinden.
///
/// NEDEN GERÇEK RENDER: hız, `scaleTimeRange` ile kompozisyon zaman haritasına
/// yazılıyor; modeli okuyan bir test bunun ÇALIŞTIĞINI göstermez. Burada zamanı
/// PARLAKLIKLA kodlayan bir klip üretilip montaj render'ı alınır: çıktının
/// verilen anındaki gri değeri, o anda kaynağın KAÇINCI saniyesinin
/// gösterildiğini söyler. Böylece "2x, aynı pencerede klibin iki katını
/// oynatır" iddiası ölçülebilir hale gelir.
final class ClipSpeedTests: XCTestCase {

    private var root: URL!
    private var clipURL: URL!

    /// Kaynak klibin uzunluğu. Hızlı senaryoda pencerenin (2 sn) 4 katı
    /// tüketilebilsin diye bolca uzun.
    private let clipDuration: Double = 8
    private let canvas = Canvas(width: 180, height: 320, fps: 30)
    private let sceneDuration: Double = 2

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-speed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        clipURL = root.appendingPathComponent("ramp.mp4")
        try await makeRampClip(at: clipURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: Testler

    /// Aynı anda bakıldığında: 2x klibin iki katı ileride, 0,5x yarısı kadar.
    ///
    /// Ölçüm, gri değeri saniyeye ÇEVİRMİYOR; çıktının karesini KAYNAĞIN
    /// beklenen karesiyle karşılaştırıyor. Sebebi renk hattı: video kanalı
    /// YUV'dan sRGB'ye dönerken gri değerleri hafifçe kayıyor (0,19 → 0,24).
    /// İki ölçüm de aynı decode yolundan geçtiği için bu kayma sadeleşiyor.
    func testSpeedChangesHowFarIntoTheClipTheFrameComesFrom() async throws {
        let sampleAt = 1.5
        let cases: [(speed: Double, sourceTime: Double, what: String)] = [
            (1, 1.5, "hız 1'de kaynak kendi zamanında akmalı"),
            (2, 3.0, "2x, aynı pencerede klibin iki katını oynatmalı"),
            (0.5, 0.75, "0,5x ağır çekim olmalı")
        ]
        for (speed, sourceTime, what) in cases {
            let rendered = try await gray(of: try await render(speed: speed), at: sampleAt)
            let expected = try await gray(of: clipURL, at: sourceTime)
            // 0,05 gri ≈ 0,3 sn kaynak: 1x ile 2x'i (0,19 gri fark) ayırt etmeye
            // fazlasıyla yeter, yeniden kodlamanın gürültüsüne de pay bırakır.
            XCTAssertEqual(rendered, expected, accuracy: 0.05, what)
        }
    }

    /// EN ÖNEMLİ DAVRANIŞ: hız videonun SÜRESİNİ değiştirmez. Şablonun ritmi ve
    /// müzik hizası sabit kalsın diye hız yalnız pencereye sığdırılan kaynak
    /// bölümünü değiştiriyor.
    func testSpeedDoesNotChangeOutputDuration() async throws {
        for speed in [0.5, 1.0, 3.0] {
            let url = try await render(speed: speed)
            let duration = try await AVURLAsset(url: url).load(.duration).seconds
            XCTAssertEqual(duration, sceneDuration, accuracy: 0.05,
                           "hız \(speed) videonun süresini değiştirmemeli")
        }
    }

    /// Klasik (sahnesiz) yol da hızı uygulamalı — katalogun büyük kısmı orada.
    /// Bu yol montajdan tamamen ayrı bir kod hattı (`TemplateExporter` +
    /// CoreAnimationTool), yani ayrıca kanıtlanmalı.
    func testSpeedAppliesOnTheClassicSingleClipPath() async throws {
        let slot = Layer(id: "media",
                         frame: NormalizedRect(x: 0.5, y: 0.5, width: 1, height: 1),
                         content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .video)))
        let classic = Template(schemaVersion: 1, id: "speed-classic",
                               name: LocalizedText(["en": "speed"]), category: "minimal",
                               canvas: canvas, duration: sceneDuration,
                               palette: ["background": "#000000"], layers: [slot])

        for (speed, sourceTime) in [(1.0, 1.5), (2.0, 3.0)] {
            var edits = UserEdits()
            edits.slots[0] = SlotAssignment(assetIdentifier: clipURL.path, kind: .video,
                                            speed: speed)
            let output = root.appendingPathComponent("classic-\(speed).mp4")
            let url = try await TemplateExporter().export(TemplateExporter.Request(
                template: classic, edits: edits,
                videos: [.init(asset: AVURLAsset(url: clipURL), slotIndex: 0)],
                includeWatermark: false, workDirectory: root, outputURL: output))

            let rendered = try await gray(of: url, at: 1.5)
            let expected = try await gray(of: clipURL, at: sourceTime)
            XCTAssertEqual(rendered, expected, accuracy: 0.05,
                           "klasik yolda hız \(speed) uygulanmadı")
        }
    }

    /// RİTİM ŞABLONLARININ TEMELİ: aynı klip birden çok sahnede geçtiğinde
    /// baştan başlamaz, kaldığı yerden devam eder. (Eskiden her kesmede aynı
    /// yarım saniye tekrar oynuyordu; tek klipten dört kesmelik bir kurgu
    /// çıkarmak bu yüzden mümkün değildi.)
    func testSameClipContinuesAcrossScenes() async throws {
        let slot = Layer(id: "media",
                         frame: NormalizedRect(x: 0.5, y: 0.5, width: 1, height: 1),
                         content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .video)))
        // Üç sahne, her biri 1 sn, kesmeyle: aynı slot üç kez geçiyor.
        let rhythmic = Template(
            schemaVersion: 2, id: "continue-probe",
            name: LocalizedText(["en": "rhythm"]), category: "minimal",
            canvas: canvas, palette: ["background": "#000000"], layers: [],
            scenes: (0..<3).map { index in
                TemplateScene(id: "s\(index)", duration: 1, layers: [slot],
                              transition: index < 2 ? TransitionSpec(style: "cut", duration: 0)
                                                    : nil)
            })
        var edits = UserEdits()
        edits.slots[0] = SlotAssignment(assetIdentifier: clipURL.path, kind: .video)
        let output = try await MontageComposer.render(
            template: rhythmic, edits: edits,
            videos: [0: MontageComposer.VideoSource(asset: AVURLAsset(url: clipURL))],
            outputURL: root.appendingPathComponent("continue.mp4"))

        // 3. sahnenin ortası (t=2,5) klibin ~2,5. saniyesini göstermeli —
        // baştan başlıyor olsaydı ~0,5. saniyeyi gösterirdi.
        let rendered = try await gray(of: output, at: 2.5)
        let continued = try await gray(of: clipURL, at: 2.5)
        let restarted = try await gray(of: clipURL, at: 0.5)
        XCTAssertEqual(rendered, continued, accuracy: 0.05,
                       "klip sahneler arasında devam etmeli")
        XCTAssertGreaterThan(abs(rendered - restarted), 0.1,
                             "klip her sahnede baştan başlıyor")
    }

    /// Aralık dışı / bozuk hız motora HİÇ ulaşmamalı: 0 bir zaman aralığını
    /// sıfıra ölçekler ve AVFoundation kompozisyonu tümden reddeder.
    func testSpeedIsClampedToSafeRange() {
        XCTAssertEqual(SlotAssignment(assetIdentifier: "a", kind: .video, speed: 0).speed, 0.25)
        XCTAssertEqual(SlotAssignment(assetIdentifier: "a", kind: .video, speed: -3).speed, 0.25)
        XCTAssertEqual(SlotAssignment(assetIdentifier: "a", kind: .video, speed: 99).speed, 4)
        XCTAssertEqual(SlotAssignment(assetIdentifier: "a", kind: .video,
                                      speed: .nan).speed, 1)
    }

    /// Hız alanı olmayan (eski) taslak normal hızda açılmalı, alan taşıyan
    /// taslak da gidiş dönüş kaybetmemeli.
    func testSpeedDecodingIsBackwardCompatible() throws {
        let legacy = #"{"assetIdentifier": "a", "kind": "video"}"#
        let decoded = try JSONDecoder().decode(SlotAssignment.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.speed, 1)

        let edits = UserEdits(slots: [0: SlotAssignment(assetIdentifier: "a", kind: .video,
                                                        speed: 2)])
        let roundTrip = try JSONDecoder().decode(
            UserEdits.self, from: try JSONEncoder().encode(edits))
        XCTAssertEqual(roundTrip.slots[0]?.speed, 2)

        // Bozuk bir taslak (0) okunurken de güvenli aralığa çekilmeli.
        let broken = #"{"assetIdentifier": "a", "kind": "video", "speed": 0}"#
        XCTAssertEqual(
            try JSONDecoder().decode(SlotAssignment.self, from: Data(broken.utf8)).speed, 0.25)
    }

    // MARK: - Yardımcılar

    private var template: Template {
        let slot = Layer(id: "media",
                         frame: NormalizedRect(x: 0.5, y: 0.5, width: 1, height: 1),
                         content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .video)))
        return Template(schemaVersion: 2, id: "speed-probe",
                        name: LocalizedText(["en": "speed"]), category: "minimal",
                        canvas: canvas, palette: ["background": "#000000"], layers: [],
                        scenes: [TemplateScene(id: "s1", duration: sceneDuration,
                                               layers: [slot])])
    }

    private func render(speed: Double) async throws -> URL {
        var edits = UserEdits()
        edits.slots[0] = SlotAssignment(assetIdentifier: clipURL.path, kind: .video, speed: speed)
        return try await MontageComposer.render(
            template: template, edits: edits,
            videos: [0: MontageComposer.VideoSource(asset: AVURLAsset(url: clipURL))],
            outputURL: root.appendingPathComponent("out-\(speed).mp4"))
    }

    /// Karenin 0-1 arası gri değeri — ramp klibinde bu, kaynağın kaçıncı
    /// saniyesine bakıldığının ölçüsü.
    private func gray(of url: URL, at seconds: Double) async throws -> Double {
        try await RenderProbe.meanGray(of: url, at: seconds)
    }

    /// Zamanı parlaklıkla kodlayan klip: t. saniyedeki kare düz gri ve değeri
    /// `t / clipDuration`. Böylece çıktıdaki bir kareye bakıp kaynağın kaçıncı
    /// saniyesinin gösterildiği ölçülebiliyor.
    private func makeRampClip(at url: URL) async throws {
        let total = clipDuration * Double(canvas.fps)
        try await ProbeClip.write(at: url,
                                  size: CGSize(width: canvas.width, height: canvas.height),
                                  seconds: clipDuration, fps: canvas.fps) { frame, _, _, _, _ in
            UInt8((Double(frame) / total * 255).rounded())
        }
    }

}
#endif
