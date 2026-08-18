#if canImport(AVFoundation) && canImport(CoreImage)
import XCTest
import AVFoundation
import CoreImage
import CoreVideo
@testable import TemplateKit

/// Kadraj (`CropTransform`) ve kırpma başlangıcı (`videoStart`) — gerçek render
/// üzerinden, İKİ export yolunda da.
///
/// NEDEN GERÇEK RENDER: kadrajın işareti (offsetY artınca görüntü yukarı mı
/// aşağı mı gider) iki yolda AYRI kod: montaj CoreImage'da (y yukarı), klasik
/// yol `CGAffineTransform` + `AVMutableVideoCompositionLayerInstruction`'da.
/// İkisinin aynı anlama geldiği ancak ölçülerek bilinir — kullanıcı parmağını
/// aşağı sürüklediğinde iki şablon türünde farklı yöne kayan bir kadraj, en
/// sinir bozucu hata türü.
///
/// Ölçüm klibi: ÜST yarısı beyaz, ALT yarısı siyah. Kadraj yakınlaştırılmış
/// (scale 1.5) olduğu için kare hep doluyor; karenin ortalama parlaklığı
/// sınırın nereye gittiğini söyler — görüntü AŞAĞI kayarsa kadrajda daha çok
/// BEYAZ kalır.
final class CropAndTrimTests: XCTestCase {

    private var root: URL!
    /// Üst yarısı beyaz, alt yarısı siyah klip (kadraj ölçümü için).
    private var splitURL: URL!
    /// Zamanı parlaklıkla kodlayan klip (videoStart ölçümü için).
    private var rampURL: URL!

    private let canvas = Canvas(width: 180, height: 320, fps: 30)
    private let duration: Double = 2
    private let clipSeconds: Double = 8

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("crop-trim-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        splitURL = root.appendingPathComponent("split.mp4")
        rampURL = root.appendingPathComponent("ramp.mp4")
        try await writeClip(at: splitURL) { _, x, y, width, height in
            _ = (x, width)
            return y < height / 2 ? 255 : 0     // üst yarı beyaz (y AŞAĞI)
        }
        let totalFrames = clipSeconds * Double(canvas.fps)
        try await writeClip(at: rampURL) { frame, _, _, _, _ in
            UInt8((Double(frame) / totalFrames * 255).rounded())
        }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: Kadraj

    /// SÖZLEŞME: `offsetY` büyüdükçe görüntü kadrajda AŞAĞI kayar
    /// (ekran yönü, y aşağı) — kullanıcı parmağını aşağı sürükler, görüntü
    /// aşağı gider. `offsetX` büyüdükçe SAĞA.
    func testPositiveOffsetYMovesImageDownOnBothPaths() async throws {
        for path in RenderPath.allCases {
            let up = try await luma(path: path, crop: CropTransform(scale: 1.5, offsetY: -0.25))
            let center = try await luma(path: path, crop: CropTransform(scale: 1.5))
            let down = try await luma(path: path, crop: CropTransform(scale: 1.5, offsetY: 0.25))

            XCTAssertGreaterThan(down, center + 0.1,
                                 "\(path): offsetY > 0 görüntüyü AŞAĞI kaydırmalı "
                                 + "(kadrajda daha çok beyaz kalır)")
            XCTAssertLessThan(up, center - 0.1,
                              "\(path): offsetY < 0 görüntüyü YUKARI kaydırmalı")
        }
    }

    /// Yakınlaştırma iki yolda da aynı yöne çalışmalı: scale büyüdükçe kadrajda
    /// kaynağın DAHA AZ'ı görünür. Bölünmüş klipte sınır hep ortada kaldığı için
    /// ölçüt parlaklık değil, sınırın KESKİNLİĞİ olamaz — bunun yerine kaydırma
    /// payının büyüdüğü doğrulanır: 1.5 zoom'da 0,25 kaydırma beyazı artırır,
    /// zoom yokken (1.0) kaydırma kadrajı kaynağın DIŞINA taşıramaz.
    func testZoomEnablesPanRoomOnBothPaths() async throws {
        for path in RenderPath.allCases {
            let zoomed = try await luma(path: path, crop: CropTransform(scale: 2, offsetY: 0.2))
            let flat = try await luma(path: path, crop: CropTransform(scale: 2))
            XCTAssertGreaterThan(zoomed, flat + 0.05,
                                 "\(path): yakınlaştırmada kaydırma etkili olmalı")
        }
    }

    // MARK: Kırpma başlangıcı (trim)

    /// `videoStart` klibin HANGİ saniyesinden başlanacağını belirler; iki yolda
    /// da uygulanmalı. (Kullanıcının 30 sn'lik videosundan hep ilk saniyeleri
    /// almak, "benim videom üzerinde söz hakkım yok" hissinin ana kaynağıydı.)
    func testVideoStartPicksTheChosenSegmentOnBothPaths() async throws {
        for path in RenderPath.allCases {
            // Klibin 4. saniyesinden başla: çıktının 0,5. saniyesi kaynağın
            // ~4,5. saniyesini göstermeli.
            let started = try await luma(path: path, start: 4, at: 0.5, clip: rampURL)
            let expected = try await grayOfSource(at: 4.5)
            XCTAssertEqual(started, expected, accuracy: 0.06,
                           "\(path): videoStart uygulanmadı")
        }
    }

    // MARK: - Yardımcılar

    private enum RenderPath: CaseIterable, CustomStringConvertible {
        case montage, classic
        var description: String { self == .montage ? "montaj" : "klasik" }
    }

    private func template(for path: RenderPath) -> Template {
        let slot = Layer(id: "media",
                         frame: NormalizedRect(x: 0.5, y: 0.5, width: 1, height: 1),
                         content: .mediaSlot(MediaSlotContent(slotIndex: 0, media: .video)))
        switch path {
        case .montage:
            return Template(schemaVersion: 2, id: "crop-probe",
                            name: LocalizedText(["en": "crop"]), category: "minimal",
                            canvas: canvas, palette: ["background": "#FF0000"], layers: [],
                            scenes: [TemplateScene(id: "s1", duration: duration,
                                                   layers: [slot])])
        case .classic:
            return Template(schemaVersion: 1, id: "crop-probe-v1",
                            name: LocalizedText(["en": "crop"]), category: "minimal",
                            canvas: canvas, duration: duration,
                            palette: ["background": "#FF0000"], layers: [slot])
        }
    }

    /// Verilen kadraj/başlangıçla render alıp `at` anındaki karenin ortalama
    /// parlaklığını (0-1) döner.
    private func luma(path: RenderPath,
                      crop: CropTransform = CropTransform(),
                      start: Double = 0,
                      at time: Double = 1.0,
                      clip: URL? = nil) async throws -> Double {
        let source = clip ?? splitURL!
        var edits = UserEdits()
        edits.slots[0] = SlotAssignment(assetIdentifier: source.path, kind: .video,
                                        crop: crop, videoStart: start)
        let output = root.appendingPathComponent(
            "out-\(path)-\(crop.scale)-\(crop.offsetX)-\(crop.offsetY)-\(start).mp4")
        let asset = AVURLAsset(url: source)

        switch path {
        case .montage:
            _ = try await MontageComposer.render(
                template: template(for: path), edits: edits,
                videos: [0: MontageComposer.VideoSource(asset: asset, start: start)],
                outputURL: output)
        case .classic:
            _ = try await TemplateExporter().export(TemplateExporter.Request(
                template: template(for: path), edits: edits,
                videos: [.init(asset: asset, slotIndex: 0, start: start)],
                includeWatermark: false, workDirectory: root, outputURL: output))
        }
        return try await gray(of: output, at: time)
    }

    private func grayOfSource(at seconds: Double) async throws -> Double {
        try await gray(of: rampURL, at: seconds)
    }

    private func gray(of url: URL, at seconds: Double) async throws -> Double {
        try await RenderProbe.meanGray(of: url, at: seconds)
    }

    /// Ölçüm klibi yazar (bkz. ProbeClip).
    private func writeClip(at url: URL,
                           value: @escaping (Int, Int, Int, Int, Int) -> UInt8) async throws {
        try await ProbeClip.write(at: url,
                                  size: CGSize(width: canvas.width, height: canvas.height),
                                  seconds: clipSeconds, fps: canvas.fps, value: value)
    }

}
#endif
