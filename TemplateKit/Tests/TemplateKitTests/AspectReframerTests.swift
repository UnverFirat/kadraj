#if canImport(AVFoundation) && canImport(CoreImage)
import XCTest
import AVFoundation
@testable import TemplateKit

/// Gönderi (4:5) ve kare (1:1) çıktısı: tasarım BOZULMADAN yeni kadraja
/// oturmalı.
///
/// Kritik iddia "tasarımın tamamı görünür kalır". Ölçüm: 9:16 kaynak videonun
/// TAM ORTASINA parlak bir bant konur; çıktının orta bandı da aynı parlaklıkta
/// olmalı (yani içerik kırpılmamış), kenarlar ise bulanık dolgu olduğu için
/// FARKLI olmalı.
final class AspectReframerTests: XCTestCase {

    private var root: URL!
    private var sourceURL: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("reframe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        sourceURL = root.appendingPathComponent("story.mp4")
        // 9:16 kaynak: siyah zemin, ortada beyaz bir bant.
        try await ProbeClip.write(at: sourceURL, size: CGSize(width: 180, height: 320),
                                  seconds: 1.5, fps: 30) { _, _, y, _, height in
            let band = height / 4
            return (y > (height - band) / 2 && y < (height + band) / 2) ? 255 : 0
        }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testPresetsProduceExpectedSizeAndKeepDuration() async throws {
        let expected: [AspectReframer.Preset: CGSize] = [
            .post: CGSize(width: 180, height: 226),   // 4:5 (180/0.8 = 225 → çift)
            .square: CGSize(width: 180, height: 180)
        ]
        for (preset, size) in expected {
            let output = root.appendingPathComponent("out-\(preset.rawValue).mp4")
            _ = try await AspectReframer.render(source: sourceURL, preset: preset,
                                                outputURL: output)
            let asset = AVURLAsset(url: output)
            let track = try await asset.loadTracks(withMediaType: .video).first
            let natural = try await XCTUnwrap(track).load(.naturalSize)
            XCTAssertEqual(natural.width, size.width, accuracy: 2, "\(preset) genişlik")
            XCTAssertEqual(natural.height, size.height, accuracy: 2, "\(preset) yükseklik")

            let duration = try await asset.load(.duration).seconds
            XCTAssertEqual(duration, 1.5, accuracy: 0.1, "\(preset): süre korunmalı")
        }
    }

    /// İki iddia birden: (1) tasarım kırpılmadı — ortadaki beyaz bant çıktının
    /// ortasında hâlâ parlak; (2) artan alan SİYAH BANT değil, dolu — kenar
    /// şeridi de aydınlanmış (bulanık kopya oraya taşmış).
    func testDesignSurvivesAndEmptyAreaIsFilled() async throws {
        let output = root.appendingPathComponent("out-post.mp4")
        _ = try await AspectReframer.render(source: sourceURL, preset: .post,
                                            outputURL: output)
        let center = try await ProbeClip.gray(of: output, at: 0.7, region: .center)
        let edge = try await ProbeClip.gray(of: output, at: 0.7, region: .leftEdge)
        XCTAssertGreaterThan(center, 0.5, "ortadaki beyaz bant kaybolmuş (içerik kırpılmış)")
        XCTAssertGreaterThan(edge, 0.05,
                             "kenarda siyah bant var — dolgu uygulanmamış (letterbox)")
    }
}
#endif
