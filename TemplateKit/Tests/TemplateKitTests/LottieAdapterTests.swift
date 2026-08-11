#if canImport(QuartzCore)
import XCTest
import AVFoundation
import QuartzCore
@testable import TemplateKit
import TemplateKitLottie

/// Gerçek lottie-ios adaptörü. Bu testler iki sinsi hatayı kilitliyor
/// (ikisi de export'ta "animasyon yok" gibi görünüyordu, sebepleri farklıydı):
/// 1. `play()` animasyonları hemen kurmaz — `display()` tetiklenmezse ağaç boş
///    kalır (ve zaman kaydırması boş ağaca uygulanır).
/// 2. Ölçek/konum İÇ katmana uygulanmazsa içerik yarım kanvas kayar, yani
///    kadrajın dışına çıkar.
final class LottieAdapterTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lottie-adapter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("assets"), withIntermediateDirectories: true)
        try Data(LottieAdapterTests.sampleAnimation.utf8).write(
            to: directory.appendingPathComponent("assets/box.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func request(startTime: Double = 0.4,
                         size: CGSize = CGSize(width: 540, height: 960)) -> LottieRequest {
        LottieRequest(asset: "assets/box.json", loopMode: .loop, colorOverrides: [:],
                      size: size, duration: 3,
                      baseTime: AVCoreAnimationBeginTimeAtZero, startTime: startTime)
    }

    func testLayerCarriesAnimationsStartingAtRequestedTime() throws {
        let layer = try XCTUnwrap(LottieAdapter(searchDirectories: [directory])
            .makeLayer(for: request()))
        let begins = LottieAdapterTests.beginTimes(in: layer)
        XCTAssertFalse(begins.isEmpty, "display() tetiklenmezse ağaçta hiç animasyon olmaz")
        for begin in begins {
            XCTAssertEqual(begin, AVCoreAnimationBeginTimeAtZero + 0.4, accuracy: 0.0001,
                           "animasyon katmanın sahneye girdiği anda başlamalı")
        }
    }

    /// Kare ORANI farklı: 1080x1920 animasyon, 540x540 kutu → ölçek 0.28125,
    /// içerik ortada. (Dış katmanı ölçeklemek bu testi geçmez.)
    func testInnerLayerIsScaledAndCentered() throws {
        let size = CGSize(width: 540, height: 540)
        let layer = try XCTUnwrap(LottieAdapter(searchDirectories: [directory])
            .makeLayer(for: request(size: size)))
        let root = try XCTUnwrap(layer.sublayers?.first)
        XCTAssertEqual(root.position.x, 270, accuracy: 0.01)
        XCTAssertEqual(root.position.y, 270, accuracy: 0.01)
        XCTAssertEqual(root.transform.m11, 540.0 / 1920.0, accuracy: 0.0001)
        XCTAssertEqual(root.transform.m22, 540.0 / 1920.0, accuracy: 0.0001)
    }

    func testMissingAssetFallsBackToPlaceholder() {
        let adapter = LottieAdapter(searchDirectories: [directory])
        let missing = LottieRequest(asset: "assets/yok.json", loopMode: .once,
                                    colorOverrides: [:], size: CGSize(width: 100, height: 100),
                                    duration: 1, baseTime: 0, startTime: 0)
        XCTAssertNil(adapter.makeLayer(for: missing))
    }

    /// `colorRemap` gerçekten lottie'ye giriyor mu: kırmızı dolgu palet
    /// rengiyle çizilmeli (rewriter'ın çıktısı adaptörden geçiyor mu).
    func testColorOverrideReachesRenderedLayer() throws {
        let adapter = LottieAdapter(searchDirectories: [directory])
        let recolored = LottieRequest(asset: "assets/box.json", loopMode: .once,
                                      colorOverrides: ["#FF0000": RGBAColor(hex: "#00FF00")!],
                                      size: CGSize(width: 1080, height: 1920), duration: 3,
                                      baseTime: 0, startTime: 0)
        let layer = try XCTUnwrap(adapter.makeLayer(for: recolored))
        let colors = LottieAdapterTests.fillColors(in: layer)
        XCTAssertFalse(colors.isEmpty, "şekil katmanı bulunamadı")
        for color in colors {
            let components = color.components ?? []
            XCTAssertEqual(components.count, 4)
            XCTAssertEqual(Double(components[1]), 1, accuracy: 0.01, "yeşile dönmeliydi")
            XCTAssertEqual(Double(components[0]), 0, accuracy: 0.01)
        }
    }

    // MARK: - Yardımcılar

    private static func beginTimes(in layer: CALayer) -> [CFTimeInterval] {
        var result: [CFTimeInterval] = []
        for key in layer.animationKeys() ?? [] {
            if let animation = layer.animation(forKey: key) { result.append(animation.beginTime) }
        }
        for sublayer in layer.sublayers ?? [] { result += beginTimes(in: sublayer) }
        return result
    }

    /// Dolgu rengi katmanın kendisinde DEĞİL, lottie'nin eklediği animasyonun
    /// içindedir (sabit renk de tek değerli bir animasyon olarak kurulur).
    private static func fillColors(in layer: CALayer) -> [CGColor] {
        var result: [CGColor] = []
        if let shape = layer as? CAShapeLayer {
            if let group = shape.animation(forKey: "fillColor") as? CAAnimationGroup,
               let inner = group.animations?.first {
                let value: Any? = (inner as? CAKeyframeAnimation)?.values?.first
                    ?? (inner as? CABasicAnimation).flatMap { $0.toValue ?? $0.fromValue }
                if let value, CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                    result.append(value as! CGColor)
                }
            } else if let color = shape.fillColor {
                result.append(color)
            }
        }
        for sublayer in layer.sublayers ?? [] { result += fillColors(in: sublayer) }
        return result
    }

    /// 3 sn boyunca aşağı inen tek kırmızı kare (1080x1920 kanvas).
    private static let sampleAnimation = """
    {"v":"5.7.4","fr":30,"ip":0,"op":90,"w":1080,"h":1920,"nm":"box","ddd":0,"assets":[],
     "layers":[{"ddd":0,"ind":1,"ty":4,"nm":"box","sr":1,
      "ks":{"o":{"a":0,"k":100},"r":{"a":0,"k":0},
            "p":{"a":1,"k":[{"t":0,"s":[540,100]},{"t":90,"s":[540,1820]}]},
            "a":{"a":0,"k":[0,0,0]},"s":{"a":0,"k":[100,100,100]}},
      "ao":0,
      "shapes":[{"ty":"gr","nm":"g","it":[
        {"ty":"rc","d":1,"s":{"a":0,"k":[240,240]},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0}},
        {"ty":"fl","nm":"fill","r":1,"c":{"a":0,"k":[1,0,0,1]},"o":{"a":0,"k":100}},
        {"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},
         "r":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],
      "ip":0,"op":90,"st":0,"bm":0}]}
    """
}
#endif
