#if canImport(CoreGraphics)
import Foundation
import CoreGraphics

/// Sinematik overlay efektleri: kenar karartma (vignette) ve film grain.
/// Tek bir CGImage olarak üretilir ve katman ağacının en üstüne konur —
/// böylece hem klasik hem montaj (2. geçiş) yolunda aynı şekilde çalışır.
/// Kendi implementasyonumuz; hazır varlık/LUT kullanılmaz.
public enum EffectOverlay {

    /// - Parameters:
    ///   - vignette: 0–1, kenarların karartma gücü.
    ///   - grain: 0–1, film tanesi yoğunluğu.
    /// - Returns: Saydam zeminli overlay görüntüsü; ikisi de 0 ise nil.
    public static func makeImage(size: CGSize, vignette: Double, grain: Double) -> CGImage? {
        let v = min(max(vignette, 0), 1)
        let g = min(max(grain, 0), 1)
        guard v > 0 || g > 0, size.width >= 1, size.height >= 1 else { return nil }

        let w = Int(size.width.rounded()), h = Int(size.height.rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.clear(CGRect(origin: .zero, size: size))

        if v > 0 {
            // Merkez saydam → kenar siyah radial gradient.
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!
            let colors = [CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0),
                          CGColor(srgbRed: 0, green: 0, blue: 0, alpha: CGFloat(v) * 0.85)]
            if let gradient = CGGradient(colorsSpace: cs, colors: colors as CFArray,
                                         locations: [0.45, 1.0]) {
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = max(size.width, size.height) * 0.72
                ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: radius,
                                       options: [.drawsAfterEndLocation])
            }
        }

        if g > 0 {
            // Film tanesi: seyrek, rastgele açık/koyu noktalar. Yoğunluk `g` ile
            // ölçeklenir; tam piksel gürültüsü yerine nokta serpme (ucuz + doğal).
            let dotCount = Int(Double(w * h) * 0.018 * g)
            var generator = SystemRandomNumberGenerator()
            for _ in 0..<dotCount {
                let x = CGFloat(Int.random(in: 0..<w, using: &generator))
                let y = CGFloat(Int.random(in: 0..<h, using: &generator))
                let bright = Bool.random(using: &generator)
                let alpha = CGFloat.random(in: 0.05...0.22, using: &generator) * CGFloat(g)
                ctx.setFillColor(CGColor(srgbRed: bright ? 1 : 0, green: bright ? 1 : 0,
                                         blue: bright ? 1 : 0, alpha: alpha))
                ctx.fill(CGRect(x: x, y: y, width: 1.5, height: 1.5))
            }
        }

        return ctx.makeImage()
    }
}
#endif
