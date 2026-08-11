#if canImport(QuartzCore)
import Foundation
import CoreGraphics
import CoreText

/// Metni CoreText ile CGImage'a rasterize eder; katmanlar bu görüntüyü
/// `contents` olarak taşır.
///
/// Neden CATextLayer değil: CATextLayer, AVVideoCompositionCoreAnimationTool
/// export hattında render edilmiyor (macOS 26'da düz string'le bile boş çıktı —
/// export_probe ile doğrulandı). Görüntü içerikli katmanlar ise aynı hatta
/// sorunsuz. Rasterize etmek ayrıca önizleme/export pikselini birebir eşitler
/// ve tipografi kontrolünü (kern, satır, hizalama) tamamen bize verir.
public enum TextRasterizer {

    public struct Spec {
        public var text: String
        /// PostScript adı; bulunamazsa CoreText en yakın fonta düşer.
        public var fontName: String
        /// Nokta cinsinden (normalize değil).
        public var fontSize: CGFloat
        public var color: CGColor
        public var alignment: TextAlignment
        /// Nokta cinsinden ek harf aralığı.
        public var kern: CGFloat
        /// Hedef kutu (nokta). Metin kutuya sığdırılır, dikeyde ortalanır.
        public var size: CGSize
        /// Piksel yoğunluğu (önizlemede ekran scale'i, export'ta 1).
        public var scale: CGFloat
        /// Metnin arkasına satır bazlı renkli vurgu (CapCut tarzı). nil = yok.
        public var highlightColor: CGColor?

        public init(text: String, fontName: String, fontSize: CGFloat,
                    color: CGColor, alignment: TextAlignment = .center,
                    kern: CGFloat = 0, size: CGSize, scale: CGFloat = 1,
                    highlightColor: CGColor? = nil) {
            self.text = text
            self.fontName = fontName
            self.fontSize = fontSize
            self.color = color
            self.alignment = alignment
            self.kern = kern
            self.size = size
            self.scale = scale
            self.highlightColor = highlightColor
        }
    }

    public static func makeAttributedString(_ spec: Spec) -> NSAttributedString {
        let font = CTFontCreateWithName(spec.fontName as CFString, spec.fontSize, nil)

        var ctAlignment: CTTextAlignment
        switch spec.alignment {
        case .left: ctAlignment = .left
        case .center: ctAlignment = .center
        case .right: ctAlignment = .right
        }
        let paragraphStyle = withUnsafeBytes(of: &ctAlignment) { pointer in
            CTParagraphStyleCreate([CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: pointer.baseAddress!)], 1)
        }

        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): spec.color,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraphStyle
        ]
        if spec.kern != 0 {
            attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = spec.kern
        }
        return NSAttributedString(string: spec.text, attributes: attributes)
    }

    /// Rasterize edilmiş metin + kelimelerin geometrisi.
    public struct Layout {
        public var image: CGImage
        /// Her kelimenin kutusu, `spec.size` uzayında ve **y AŞAĞI** yönlü
        /// (katman ağacı `isGeometryFlipped` olduğu için katman koordinatıyla
        /// aynı). Kelime sırası okuma sırasıdır.
        public var words: [CGRect]
    }

    /// Auto-shrink sonucu ve çerçeve — `rasterize` ve `layout` aynı yerleşimi
    /// kullansın diye tek yerde.
    private static func fit(_ spec: Spec) -> (spec: Spec, frame: CTFrame, drawRect: CGRect)? {
        // Kullanıcı metni serbesttir; kutuya sığmayan metinde satır kırpmak
        // yerine font sığana kadar küçültülür (auto-shrink).
        let constraint = CGSize(width: spec.size.width, height: .greatestFiniteMagnitude)
        var fitted = spec
        var framesetter = CTFramesetterCreateWithAttributedString(makeAttributedString(fitted))
        var textSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: 0), nil, constraint, nil)
        while textSize.height > spec.size.height, fitted.fontSize > 8 {
            fitted.fontSize *= 0.92
            fitted.kern *= 0.92
            framesetter = CTFramesetterCreateWithAttributedString(makeAttributedString(fitted))
            textSize = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter, CFRange(location: 0, length: 0), nil, constraint, nil)
        }

        // Kutudan taşan metin kırpılır (maxLines yerine kutu yüksekliği sınırlar;
        // şablon üretim aracı taşmayı lint'ler).
        let drawHeight = min(ceil(textSize.height) + 2, spec.size.height)
        let originY = (spec.size.height - drawHeight) / 2
        let rect = CGRect(x: 0, y: originY, width: spec.size.width, height: drawHeight)
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter,
                                             CFRange(location: 0, length: 0), path, nil)
        return (fitted, frame, rect)
    }

    /// Metni çizer ve kelime kutularını verir. `kineticWords` preset'i her
    /// kelimeyi ayrı bir katmana koyup sırayla animasyonlamak için bunu kullanır
    /// — kelimeler TEK bir yerleşimden çıktığı için satır kırılması, hizalama ve
    /// auto-shrink düz metinle birebir aynı kalır.
    public static func layout(_ spec: Spec) -> Layout? {
        guard let image = rasterize(spec), let fitted = fit(spec) else { return nil }

        guard let lines = CTFrameGetLines(fitted.frame) as? [CTLine], !lines.isEmpty else {
            return Layout(image: image, words: [])
        }
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(fitted.frame, CFRange(location: 0, length: 0), &origins)

        let ns = spec.text as NSString
        var words: [CGRect] = []
        for (index, line) in lines.enumerated() {
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            let range = CTLineGetStringRange(line)
            let end = range.location + range.length
            var cursor = range.location
            while cursor < end {
                // Boşlukları atla, kelimenin sonuna kadar ilerle.
                while cursor < end,
                      isSeparator(ns.character(at: cursor)) { cursor += 1 }
                guard cursor < end else { break }
                let start = cursor
                while cursor < end, !isSeparator(ns.character(at: cursor)) { cursor += 1 }

                let x1 = CTLineGetOffsetForStringIndex(line, start, nil)
                let x2 = CTLineGetOffsetForStringIndex(line, cursor, nil)
                guard x2 > x1 else { continue }
                // CoreText y-YUKARI çizer; katman uzayı y-AŞAĞI. Satır origin'i
                // ÇERÇEVE YOLUNA GÖRELİDİR (bkz. fit: yol dikey ortalanır), yolun
                // kendi origin'i eklenmezse kelime kutuları o kadar kayar.
                words.append(CGRect(x: fitted.drawRect.minX + origins[index].x + x1,
                                    y: spec.size.height
                                        - (fitted.drawRect.minY + origins[index].y + ascent),
                                    width: x2 - x1,
                                    height: ascent + descent))
            }
        }
        return Layout(image: image, words: words)
    }

    private static func isSeparator(_ unit: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(unit) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    public static func rasterize(_ spec: Spec) -> CGImage? {
        guard !spec.text.isEmpty,
              spec.size.width >= 1, spec.size.height >= 1, spec.scale > 0 else {
            return nil
        }
        guard let fitted = fit(spec) else { return nil }

        guard let context = CGContext(
            data: nil,
            width: max(1, Int(spec.size.width * spec.scale)),
            height: max(1, Int(spec.size.height * spec.scale)),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.scaleBy(x: spec.scale, y: spec.scale)

        let frame = fitted.frame

        // Satır bazlı vurgu: her metin satırının arkasına yuvarlak dikdörtgen.
        // Metinden ÖNCE çizilir ki metin üstte kalsın.
        if let highlight = spec.highlightColor,
           let lines = CTFrameGetLines(frame) as? [CTLine], !lines.isEmpty {
            var origins = [CGPoint](repeating: .zero, count: lines.count)
            CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
            let padX = fitted.spec.fontSize * 0.20
            let padY = fitted.spec.fontSize * 0.10
            let radius = fitted.spec.fontSize * 0.14
            context.setFillColor(highlight)
            for (i, line) in lines.enumerated() {
                var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
                let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
                if width < 1 { continue }   // boş satırda vurgu çizme
                // Satır origin'leri çerçeve YOLUNA görelidir; yol dikey ortalandığı
                // için (bkz. fit) yolun origin'i eklenmezse vurgu satırın altına kayar.
                let origin = CGPoint(x: fitted.drawRect.minX + origins[i].x,
                                     y: fitted.drawRect.minY + origins[i].y)
                let rect = CGRect(x: origin.x - padX,
                                  y: origin.y - descent - padY,
                                  width: width + padX * 2,
                                  height: ascent + descent + padY * 2)
                context.addPath(CGPath(roundedRect: rect, cornerWidth: radius,
                                       cornerHeight: radius, transform: nil))
                context.fillPath()
            }
        }

        CTFrameDraw(frame, context)
        return context.makeImage()
    }
}
#endif
