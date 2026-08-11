#if canImport(CoreGraphics)
import Foundation
import CoreGraphics

/// Medya slotu maskelerinin geometrisi. Path tabanlı maskeler (yıldız, kalp)
/// hem CALayer (CAShapeLayer mask, 2. geçiş) hem CoreImage (mask görüntüsü,
/// montaj 1. geçişi) tarafından kullanılır — tek kaynak, iki tüketen.
public enum MaskShape {

    /// Verilen dikdörtgene oturan mask path'i. `rect`/`circle` için nil döner
    /// (onlar cornerRadius ile daha ucuz çizilir); yıldız/kalp path verir.
    public static func path(for mask: MaskKind, in rect: CGRect) -> CGPath? {
        switch mask {
        case .rect, .circle: return nil
        case .star: return starPath(in: rect)
        case .heart: return heartPath(in: rect)
        }
    }

    /// CoreImage yolu (montaj compositor) için alfa maskesi: şekil OPAK beyaz,
    /// dışı tamamen SAYDAM. `rect` maskede nil döner (kırpma zaten yeterli).
    ///
    /// Önemli: `CIBlendWithAlphaMask` maskenin ALFA kanalını okur — gri tonlamalı
    /// (alfasız) maske her yeri opak sayar ve hiçbir şeyi kırpmaz. Bu yüzden
    /// RGBA + saydam arka planla üretilir.
    /// Not: CoreImage y-yukarı çalışır; path'ler CALayer (y-aşağı) için
    /// üretildiğinden burada dikey aynalanır.
    public static func alphaMaskImage(for mask: MaskKind, size: CGSize) -> CGImage? {
        guard mask != .rect, size.width >= 1, size.height >= 1 else { return nil }
        let w = Int(size.width.rounded()), h = Int(size.height.rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        ctx.clear(CGRect(origin: .zero, size: size))       // saydam zemin
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        let rect = CGRect(origin: .zero, size: size)
        if mask == .circle {
            let d = min(size.width, size.height)
            ctx.fillEllipse(in: CGRect(x: rect.midX - d / 2, y: rect.midY - d / 2,
                                       width: d, height: d))
        } else if let path = path(for: mask, in: rect) {
            // CALayer (y-aşağı) path'ini CoreImage (y-yukarı) için aynala.
            var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
            if let flipped = path.copy(using: &flip) {
                ctx.addPath(flipped)
                ctx.fillPath()
            }
        }
        return ctx.makeImage()
    }

    /// 5 köşeli yıldız (kutuya ortalanmış, en büyük sığan).
    static func starPath(in rect: CGRect, points: Int = 5,
                         innerRatio: CGFloat = 0.42) -> CGPath {
        let path = CGMutablePath()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = CGFloat.pi / CGFloat(points)
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = -CGFloat.pi / 2 + CGFloat(i) * step
            let point = CGPoint(x: center.x + radius * cos(angle),
                                y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// Kalp (kutuya ortalanmış). İki üst yarım daire + alt uç.
    /// Not: CG koordinatı y-yukarı; "uç" y=min'de olacak şekilde çizilir.
    static func heartPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = min(rect.width, rect.height)
        // Kutuya ortalanmış kare alan içinde çiz.
        let box = CGRect(x: rect.midX - w / 2, y: rect.midY - w / 2, width: w, height: w)
        // Normalize (0..1) kalp noktaları, sonra box'a ölçekle. y-yukarı: uç altta.
        func p(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
            CGPoint(x: box.minX + nx * w, y: box.minY + ny * w)
        }
        path.move(to: p(0.5, 0.06))                       // alt uç
        path.addCurve(to: p(0.03, 0.66),                  // sol yan yukarı
                      control1: p(0.28, 0.24), control2: p(0.03, 0.42))
        path.addArc(center: p(0.26, 0.74), radius: 0.24 * w,
                    startAngle: .pi, endAngle: 0, clockwise: false)   // sol lob
        path.addArc(center: p(0.74, 0.74), radius: 0.24 * w,
                    startAngle: .pi, endAngle: 0, clockwise: false)   // sağ lob
        path.addCurve(to: p(0.5, 0.06),                   // sağ yan aşağı uca
                      control1: p(0.97, 0.42), control2: p(0.72, 0.24))
        path.closeSubpath()
        // Path y-yukarı çizildi (uç küçük y'de). Tüketiciler (CALayer mask)
        // y-aşağı; rect'in dikey ekseninde aynalayıp ucu alta getir.
        var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.midY * 2)
        return path.copy(using: &flip) ?? path
    }
}
#endif
