#if canImport(QuartzCore)
import Foundation
import QuartzCore
import CoreGraphics

/// Bir render geçişinin (önizleme ya da export) sabitleri.
/// Önizleme ile export arasındaki TEK fark bu yapıdır; katman ağacı aynıdır.
public struct RenderContext {
    /// Render edilen gerçek boyut (export: 1080x1920; önizleme: view boyutu).
    public var canvasSize: CGSize
    /// CATextLayer vb. için contentsScale (export'ta 1, cihazda UIScreen.scale).
    public var displayScale: CGFloat
    /// Şablonun toplam süresi (saniye).
    public var duration: Double
    /// Animasyon zaman tabanı:
    /// - önizleme: 0 (layer saatine göre)
    /// - export: AVCoreAnimationBeginTimeAtZero (exporter set eder; 0 export'ta geçersizdir)
    public var baseTime: CFTimeInterval
    /// Çözümlenmiş palet (şablon + kullanıcı override'ı).
    public var palette: [String: RGBAColor]

    public init(canvasSize: CGSize,
                displayScale: CGFloat = 1,
                duration: Double,
                baseTime: CFTimeInterval = 0,
                palette: [String: RGBAColor]) {
        self.canvasSize = canvasSize
        self.displayScale = displayScale
        self.duration = duration
        self.baseTime = baseTime
        self.palette = palette
    }

    // MARK: Normalize -> nokta dönüşümleri

    public func rect(_ normalized: NormalizedRect) -> CGRect {
        CGRect(x: (normalized.x - normalized.width / 2) * canvasSize.width,
               y: (normalized.y - normalized.height / 2) * canvasSize.height,
               width: normalized.width * canvasSize.width,
               height: normalized.height * canvasSize.height)
    }

    /// Skaler değerler (font boyutu, cornerRadius, mesafe) kanvas yüksekliğine normalize.
    public func points(_ normalizedScalar: Double) -> CGFloat {
        CGFloat(normalizedScalar) * canvasSize.height
    }

    public func color(_ role: String) -> CGColor? {
        palette[role]?.cgColor
    }
}

public extension RGBAColor {
    var cgColor: CGColor {
        CGColor(srgbRed: CGFloat(red), green: CGFloat(green),
                blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}
#endif
