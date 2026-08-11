#if canImport(QuartzCore)
import Foundation
import QuartzCore
import CoreGraphics

/// Template + UserEdits -> CALayer ağacı. Motorun kalbi.
///
/// Aynı ağaç hem önizlemede hem export'ta kullanılır (WYSIWYG garantisi).
/// Her şablon katmanı iki CALayer olur:
///   container (presence/görünürlük penceresi + rotation)
///   └── content (asıl çizim + preset animasyonlar)
/// Bu ayrım, presence keyframe'i ile fade preset'lerinin aynı "opacity"
/// keyPath'inde çakışmasını önler.
public enum TemplateLayerBuilder {

    public struct BuiltScene {
        /// Kanvas boyutunda kök katman. Önizlemede bir view'a takılır;
        /// export'ta CoreAnimationTool'a verilir.
        public let root: CALayer
        /// Video slotu varsa, exporter'ın AVVideoCompositionCoreAnimationTool'a
        /// vereceği boş katman (video kareleri buraya render edilir).
        /// Önizlemede aynı konuma AVPlayerLayer yerleştirilir.
        public let videoSlotLayer: CALayer?
        public let videoSlotIndex: Int?
        /// Katman id -> ekranda görünen çözümlenmiş metin (override + allCaps
        /// uygulanmış). Editör alan listesi ve testler için.
        public let resolvedTexts: [String: String]
        /// Degrade edilen preset'ler, eksik roller vb. — analytics'e gider.
        public let warnings: [String]
    }

    /// - Parameters:
    ///   - photos: slotIndex -> çözülmüş görüntü. PHAsset yükleme async olduğu
    ///     için çağıran taraf hazırlar; builder saf ve senkron kalır.
    ///   - prerenderedVideo: sahneli (montaj) şablonlarda true — video içeriği
    ///     1. geçişte tek videoya düzleştirilmiştir; ağacın en altına tam-kanvas
    ///     bir videoLayer eklenir ve video atanmış slotlar ağaçtan çıkarılır
    ///     (flattenedLayersForRender bunu yapar).
    public static func build(template: Template,
                             edits: UserEdits,
                             photos: [Int: CGImage],
                             context: RenderContext,
                             prerenderedVideo: Bool = false) -> BuiltScene {
        var warnings: [String] = []
        var videoSlotLayer: CALayer?
        var videoSlotIndex: Int?
        var resolvedTexts: [String: String] = [:]

        // Implicit animasyonlar export'ta kare kayması yapar; ağaç kurulumu
        // boyunca kapalı.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: context.canvasSize)
        root.masksToBounds = true
        root.backgroundColor = context.color("background") ?? CGColor(gray: 0, alpha: 1)

        if prerenderedVideo {
            let montageLayer = CALayer()
            montageLayer.frame = root.bounds
            root.addSublayer(montageLayer)
            videoSlotLayer = montageLayer
        }

        for layer in template.flattenedLayersForRender(edits: edits) {
            let window = layer.timing.window(templateDuration: context.duration)
            let frameRect = context.rect(layer.frame)

            let container = CALayer()
            container.bounds = CGRect(origin: .zero, size: frameRect.size)
            container.position = CGPoint(x: frameRect.midX, y: frameRect.midY)
            if layer.rotation != 0 {
                container.setAffineTransform(
                    CGAffineTransform(rotationAngle: CGFloat(layer.rotation) * .pi / 180))
            }
            if let presence = AnimationFactory.presenceAnimation(window: window, context: context) {
                // Pencere başlamadan görünmesin diye taban değeri de kapalı;
                // keyframe pencere içinde 1'e çeker.
                if window.start > 0 { container.opacity = 0 }
                container.add(presence, forKey: "presence")
            }

            let content = CALayer()
            content.bounds = container.bounds
            content.position = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
            content.opacity = Float(layer.opacity)

            // Maskenin içindeki medya katmanı: kenBurns bunu hedefler ki
            // slot çerçevesi sabit kalıp fotoğraf/video içeride zoom yapsın.
            var innerMediaLayer: CALayer?

            switch layer.content {
            case .shape(let shape):
                if let gradient = shape.gradient {
                    // Geçiş ayrı bir CAGradientLayer olarak biner; container'ın
                    // dönüşü/animasyonları aynen geçerli kalır.
                    let gradientLayer = CAGradientLayer()
                    gradientLayer.frame = content.bounds
                    gradientLayer.colors = [gradient.from, gradient.to].map {
                        resolvedColor($0, context: context, layerID: layer.id,
                                      warnings: &warnings) ?? CGColor(gray: 0, alpha: 0)
                    }
                    let (start, end) = Self.gradientPoints(gradient.direction)
                    gradientLayer.startPoint = start
                    gradientLayer.endPoint = end
                    gradientLayer.cornerRadius = context.points(shape.cornerRadius)
                    content.addSublayer(gradientLayer)
                } else {
                    content.backgroundColor = resolvedColor(shape.colorRole, context: context,
                                                            layerID: layer.id,
                                                            warnings: &warnings)
                }
                content.cornerRadius = context.points(shape.cornerRadius)
                content.masksToBounds = shape.cornerRadius > 0

            case .mediaSlot(let slot):
                innerMediaLayer = configureMediaSlot(
                    slot, on: content, layer: layer, edits: edits,
                    photos: photos, context: context,
                    videoSlotLayer: &videoSlotLayer,
                    videoSlotIndex: &videoSlotIndex,
                    warnings: &warnings)

            case .text(let text):
                let resolved = configureText(text, on: content, layer: layer, edits: edits,
                                             context: context, warnings: &warnings)
                resolvedTexts[layer.id] = resolved

            case .lottie(let lottie):
                content.name = "lottie:\(lottie.asset)"
                // Renderer uygulama tarafında takılıysa (LottieRendererRegistry)
                // gerçek animasyon; takılı değilse yer tutucu — lottie taşıyan
                // bir şablon indirilse bile uygulama kırılmaz.
                let request = LottieRequest(
                    asset: lottie.asset,
                    loopMode: lottie.loopMode,
                    colorOverrides: lottie.resolvedColors(palette: context.palette),
                    size: frameRect.size,
                    duration: window.end - window.start,
                    baseTime: context.baseTime,
                    startTime: window.start)
                if let lottieLayer = LottieRendererRegistry.current?.makeLayer(for: request) {
                    lottieLayer.frame = CGRect(origin: .zero, size: frameRect.size)
                    content.addSublayer(lottieLayer)
                } else {
                    warnings.append("Lottie layer '\(layer.id)' rendered as placeholder (no renderer installed)")
                }
            }

            // wipeReveal, kenardan büyüme efekti için anchor kaydırması ister.
            if let wipe = layer.animations.first(where: { $0.preset == "wipeReveal" }) {
                adjustAnchorForWipe(content, direction: wipe.params.string("direction") ?? "right")
            }

            let info = AnimationFactory.LayerInfo(
                frame: CGRect(origin: .zero, size: frameRect.size)
                    .offsetBy(dx: content.position.x - frameRect.size.width / 2,
                              dy: content.position.y - frameRect.size.height / 2),
                baseOpacity: Float(layer.opacity),
                window: window)
            for (index, spec) in layer.animations.enumerated() {
                let animations = AnimationFactory.animations(for: spec, layer: info,
                                                             context: context,
                                                             warnings: &warnings)
                let target = (spec.preset == "kenBurns" ? innerMediaLayer : nil) ?? content
                for (j, animation) in animations.enumerated() {
                    target.add(animation, forKey: "preset-\(index)-\(j)")
                }
            }

            container.addSublayer(content)
            root.addSublayer(container)
        }

        // Sinematik overlay (vignette + grain) her şeyin üstünde; tek görüntü
        // olarak üretilir, hem klasik hem montaj 2. geçişinde aynı çalışır.
        if let overlay = template.overlay,
           let image = EffectOverlay.makeImage(size: context.canvasSize,
                                               vignette: overlay.vignette,
                                               grain: overlay.grain) {
            let effectLayer = CALayer()
            effectLayer.frame = root.bounds
            effectLayer.contents = image
            root.addSublayer(effectLayer)
        }

        return BuiltScene(root: root,
                          videoSlotLayer: videoSlotLayer,
                          videoSlotIndex: videoSlotIndex,
                          resolvedTexts: resolvedTexts,
                          warnings: warnings)
    }

    // MARK: - Media slot

    /// Döner: maskenin içindeki medya katmanı (kenBurns hedefi); boş slotta nil.
    private static func configureMediaSlot(_ slot: MediaSlotContent,
                                           on content: CALayer,
                                           layer: Layer,
                                           edits: UserEdits,
                                           photos: [Int: CGImage],
                                           context: RenderContext,
                                           videoSlotLayer: inout CALayer?,
                                           videoSlotIndex: inout Int?,
                                           warnings: inout [String]) -> CALayer? {
        content.masksToBounds = true
        switch slot.mask {
        case .rect:
            content.cornerRadius = context.points(slot.cornerRadius)
        case .circle:
            content.cornerRadius = min(content.bounds.width, content.bounds.height) / 2
        case .star, .heart:
            // Path tabanlı maske: CAShapeLayer content'in alpha maskesi olur.
            if let path = MaskShape.path(for: slot.mask, in: content.bounds) {
                let maskLayer = CAShapeLayer()
                maskLayer.path = path
                maskLayer.fillColor = CGColor(gray: 0, alpha: 1)
                content.mask = maskLayer
            }
        }

        let assignment = edits.slots[slot.slotIndex]

        if assignment?.kind == .video {
            // Video kareleri export'ta CoreAnimationTool, önizlemede AVPlayerLayer
            // tarafından bu katmanın İÇİNE çizilir; builder sadece yer açar.
            let host = CALayer()
            host.frame = content.bounds
            content.addSublayer(host)
            videoSlotLayer = host
            videoSlotIndex = slot.slotIndex
            return host
        }

        if var image = photos[slot.slotIndex] {
            // Renk gradasyonu (varsa) foto'ya önceden uygulanır.
            if let filter = slot.filter {
                image = ColorGrade.applyToCGImage(image, preset: filter,
                                                  intensity: slot.filterIntensity)
            }
            let imageLayer = CALayer()
            imageLayer.contents = image
            imageLayer.contentsGravity = .resizeAspectFill
            imageLayer.frame = content.bounds
            if let crop = assignment?.crop, crop != CropTransform() {
                var transform = CGAffineTransform.identity
                transform = transform.translatedBy(
                    x: CGFloat(crop.offsetX) * content.bounds.width,
                    y: CGFloat(crop.offsetY) * content.bounds.height)
                transform = transform.scaledBy(x: CGFloat(crop.scale), y: CGFloat(crop.scale))
                imageLayer.setAffineTransform(transform)
            }
            content.addSublayer(imageLayer)
            return imageLayer
        } else {
            // Boş slot: editörde "medya ekle" placeholder'ı.
            content.backgroundColor = context.color("surface")
                ?? CGColor(gray: 0.15, alpha: 1)
            return nil
        }
    }

    // MARK: - Text

    /// Metin, CoreText ile görüntüye rasterize edilip contents olarak taşınır —
    /// CATextLayer export hattında render edilmediği için (bkz. TextRasterizer).
    /// Döner: ekranda görünen çözümlenmiş metin.
    private static func configureText(_ text: TextContent,
                                      on content: CALayer,
                                      layer: Layer,
                                      edits: UserEdits,
                                      context: RenderContext,
                                      warnings: inout [String]) -> String {
        var string = edits.textOverrides[layer.id] ?? text.default.resolved()
        // Locale'li uppercase: Türkçe i -> İ (locale'siz uppercased() I üretir).
        if text.allCaps { string = string.uppercased(with: Locale.current) }

        let highlight = text.highlightColorRole.flatMap {
            resolvedColor($0, context: context, layerID: layer.id, warnings: &warnings)
        }
        let spec = TextRasterizer.Spec(
            text: string,
            fontName: text.font.name,
            fontSize: context.points(text.font.size),
            color: resolvedColor(text.colorRole, context: context,
                                 layerID: layer.id, warnings: &warnings)
                ?? CGColor(gray: 1, alpha: 1),
            alignment: text.alignment,
            kern: context.points(text.letterSpacing),
            size: content.bounds.size,
            scale: max(1, context.displayScale),
            highlightColor: highlight)

        // Kelime kelime giriş: metin TEK yerleşimden çıkar, sonra her kelime
        // kendi katmanına ayrılıp sırayla girer.
        if let kinetic = layer.animations.first(where: { $0.preset == "kineticWords" }),
           let layout = TextRasterizer.layout(spec), layout.words.count > 1 {
            buildKineticWords(layout, on: content, spec: kinetic,
                              layer: layer, context: context)
            return string
        }

        if let image = TextRasterizer.rasterize(spec) {
            let textLayer = CALayer()
            textLayer.contents = image
            textLayer.frame = content.bounds
            textLayer.contentsGravity = .resize
            content.addSublayer(textLayer)

            // Gerçek daktilo efekti: metnin maskesi karakter karakter genişler.
            // (AnimationFactory metin genişliğini bilmez; maske burada kurulur.)
            if let spec = layer.animations.first(where: { $0.preset == "typewriter" }) {
                applyTypewriterMask(to: textLayer, text: string, spec: spec,
                                    layer: layer, bounds: content.bounds, context: context)
            }
        } else if !string.isEmpty {
            warnings.append("Layer '\(layer.id)': text rasterization failed")
        }
        return string
    }

    /// Her kelimeyi ayrı bir katmana koyar ve sırayla (stagger) girdirir.
    ///
    /// NASIL: metin bir kez rasterize edilir; her kelime katmanı AYNI görüntüyü
    /// `contents` olarak taşır ama `contentsRect` ile yalnız kendi kutusunu
    /// gösterir. Böylece satır kırılması, hizalama ve auto-shrink düz metinle
    /// birebir aynı kalır — kelimeleri ayrı ayrı rasterize etseydik kerning ve
    /// satır sonları kayardı.
    ///
    /// Her kelime, tam metin görüntüsünden KENDİ KAREsine kırpılır
    /// (`CGImage.cropping`). Önce `contentsRect` denendi ve çok satırlı metinde
    /// komşu satırın parçaları kelimenin bandına sızıyordu; kırpma, katman
    /// hareket ederken bile yalnız o kelimenin pikselini taşır.
    ///
    /// Maske de kullanılmaz: maske katmanla birlikte hareket ettiği için kelime
    /// kendi penceresinin dışına kayamıyordu.
    private static func buildKineticWords(_ layout: TextRasterizer.Layout,
                                          on content: CALayer,
                                          spec: AnimationSpec,
                                          layer: Layer,
                                          context: RenderContext) {
        let bounds = content.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let window = layer.timing.window(templateDuration: context.duration)
        let start = context.baseTime + window.start + spec.delay
        // Her kelime bir öncekinden `stagger` kadar sonra girer; toplam süre
        // preset'in `duration`'ını aşmasın diye pay hesaplanır.
        let count = layout.words.count
        let each = min(spec.duration * 0.55, 0.5)
        let stagger = count > 1 ? max((spec.duration - each) / Double(count - 1), 0.02) : 0
        let rise = context.points(spec.params.double("distance") ?? 0.022)

        // Kelime kutuları nokta cinsinden; görüntü `scale` katı piksel taşıyor.
        let pixelScale = CGFloat(layout.image.width) / bounds.width

        for (index, word) in layout.words.enumerated() {
            // CGImage kırpması piksel uzayında ve y AŞAĞI (sol-üst köşe) —
            // kelime kutularıyla aynı yön, dönüşüm gerekmiyor.
            let pixels = CGRect(x: word.minX * pixelScale, y: word.minY * pixelScale,
                                width: word.width * pixelScale,
                                height: word.height * pixelScale).integral
            guard let cropped = layout.image.cropping(to: pixels) else { continue }

            let wordLayer = CALayer()
            wordLayer.contents = cropped
            wordLayer.contentsGravity = .resize
            wordLayer.frame = word
            wordLayer.opacity = 0
            content.addSublayer(wordLayer)

            let begin = start + Double(index) * stagger
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            // Kelime YERİNDE büyüyerek girer, DİKEY YOL ALMAZ.
            //
            // Dikey giriş denendi (`position.y` ve `transform.translation.y`,
            // ikisi de): son kare her seferinde doğru çıkıyor ama ara karelerde
            // hareket eden kelime ikiye bölünmüş görünüyor. Kelime kutuları
            // ölçüldü ve DOĞRU (satır yükseklikleri, hizalama, kırpma hepsi
            // yerinde), yani sorun geometride değil; `isGeometryFlipped` ağacında
            // hareketli alt katmanın çizimiyle ilgili ve kapsamı bu iş için fazla.
            // Ölçek + opaklık kombinasyonu kare kare doğrulandı ve etkisi
            // yeterince güçlü; dikey giriş ayrı bir iş olarak açık bırakıldı.
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1 - min(rise / max(word.height, 1), 0.25)
            scale.toValue = 1
            for animation in [fade, scale] {
                animation.beginTime = begin
                animation.duration = each
                animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animation.fillMode = .both
                animation.isRemovedOnCompletion = false
                wordLayer.add(animation, forKey: animation.keyPath)
            }
        }
    }

    /// Metin katmanına soldan sağa KARAKTER ADIMLARIYLA açılan maske ekler.
    private static func applyTypewriterMask(to textLayer: CALayer, text: String,
                                            spec: AnimationSpec, layer: Layer,
                                            bounds: CGRect, context: RenderContext) {
        let steps = max(text.count, 1)
        let mask = CALayer()
        mask.backgroundColor = CGColor(gray: 0, alpha: 1)
        mask.anchorPoint = CGPoint(x: 0, y: 0.5)
        mask.position = CGPoint(x: 0, y: bounds.midY)
        mask.bounds = CGRect(x: 0, y: 0, width: 0, height: bounds.height)
        textLayer.mask = mask

        // Discrete keyframe kuralı: keyTimes = values.count + 1 (aralık sınırları).
        let values = (0...steps).map { bounds.width * CGFloat($0) / CGFloat(steps) }
        let animation = CAKeyframeAnimation(keyPath: "bounds.size.width")
        animation.calculationMode = .discrete
        animation.values = values
        animation.keyTimes = (0...values.count).map {
            NSNumber(value: Double($0) / Double(values.count))
        }
        let window = layer.timing.window(templateDuration: context.duration)
        animation.beginTime = context.baseTime + window.start + spec.delay
        animation.duration = max(spec.duration, 0.01)
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        mask.add(animation, forKey: "typewriter")
    }

    // MARK: - Helpers

    private static func resolvedColor(_ role: String,
                                      context: RenderContext,
                                      layerID: String,
                                      warnings: inout [String]) -> CGColor? {
        if let color = context.color(role) { return color }
        // Validator bunu normalde yakalar; yine de çökmek yerine uyar ve geç.
        warnings.append("Layer '\(layerID)': color role '\(role)' missing from palette")
        return CGColor(gray: 0.5, alpha: 1)
    }

    /// Gradient yönü -> CAGradientLayer başlangıç/bitiş noktaları.
    /// NOT: katman ağacı `isGeometryFlipped` ile çizildiği için "down"
    /// birim karede yukarıdan aşağıya gider (ekranda da öyle görünür).
    private static func gradientPoints(_ direction: String) -> (CGPoint, CGPoint) {
        switch direction {
        case "up":       return (CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0))
        case "left":     return (CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 0.5))
        case "right":    return (CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5))
        case "diagonal": return (CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1))
        default:         return (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1))
        }
    }

    /// wipeReveal kenardan büyüsün diye anchor'ı kaydırır; position'ı aynı
    /// görsel konumu koruyacak şekilde düzeltir.
    private static func adjustAnchorForWipe(_ layer: CALayer, direction: String) {
        let old = layer.anchorPoint
        let new: CGPoint
        switch direction {
        case "left": new = CGPoint(x: 1, y: 0.5)
        case "right": new = CGPoint(x: 0, y: 0.5)
        case "up": new = CGPoint(x: 0.5, y: 1)
        case "down": new = CGPoint(x: 0.5, y: 0)
        default: new = CGPoint(x: 0, y: 0.5)
        }
        layer.anchorPoint = new
        layer.position = CGPoint(
            x: layer.position.x + (new.x - old.x) * layer.bounds.width,
            y: layer.position.y + (new.y - old.y) * layer.bounds.height)
    }
}
#endif
