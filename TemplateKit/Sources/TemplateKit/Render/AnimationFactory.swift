#if canImport(QuartzCore)
import Foundation
import QuartzCore

/// Preset animasyonları CAAnimation'a çevirir.
///
/// Zaman modeli: tüm beginTime'lar şablon zamanında mutlaktır ve
/// `context.baseTime` üzerine eklenir. Export determinizmi için her animasyonda
/// `fillMode = .both` + `isRemovedOnCompletion = false` zorunludur — bunlar
/// `configure`'da merkezi olarak set edilir, preset kodu unutamaz.
public enum AnimationFactory {

    /// Katmanın render'a hazır bilgisi (factory model tipini değil, hesaplanmış
    /// geometriyi görür — böylece testlerde bağımsız kurulabilir).
    public struct LayerInfo {
        /// Katmanın nokta cinsinden çerçevesi (container koordinatında).
        public var frame: CGRect
        /// Katmanın hedef opaklığı (fade animasyonları buna döner).
        public var baseOpacity: Float
        /// Sahnede olduğu aralık: (start, end) saniye.
        public var window: (start: Double, end: Double)

        public init(frame: CGRect, baseOpacity: Float, window: (start: Double, end: Double)) {
            self.frame = frame
            self.baseOpacity = baseOpacity
            self.window = window
        }
    }

    /// Tek bir AnimationSpec'i CAAnimation listesine çevirir.
    /// Tanınmayan preset boş liste döner ve uyarı ekler (graceful degrade).
    public static func animations(for spec: AnimationSpec,
                                  layer info: LayerInfo,
                                  context: RenderContext,
                                  warnings: inout [String]) -> [CAAnimation] {
        let begin: Double
        switch spec.role {
        case .in:
            begin = info.window.start + spec.delay
        case .out:
            begin = max(info.window.start, info.window.end - spec.duration - spec.delay)
        case .loop:
            begin = info.window.start + spec.delay
        }

        // `loop` rolü katmanın penceresi boyunca TEKRARLAR. Eskiden bir kez
        // çalıyordu (kenBurns süresi zaten pencere kadar olduğu için fark
        // edilmemişti); nabız/dalga gibi kısa döngüler bu olmadan yalnız bir kez
        // oynuyordu.
        func repeated(_ animations: [CAAnimation]) -> [CAAnimation] {
            guard spec.role == .loop else { return animations }
            let window = max(0, info.window.end - begin)
            for animation in animations where animation.duration < window {
                animation.repeatDuration = window
            }
            return animations
        }

        // Preset gövdesi (aşağıda `repeated` ile sarılır).
        func build() -> [CAAnimation] {
        switch spec.preset {
        case "fadeIn":
            let a = basic("opacity", from: 0, to: info.baseOpacity)
            return [configured(a, begin: begin, spec: spec, context: context)]

        case "fadeOut":
            let a = basic("opacity", from: info.baseOpacity, to: 0)
            return [configured(a, begin: begin, spec: spec, context: context)]

        case "slideIn", "slideOut":
            let isIn = spec.preset == "slideIn"
            let direction = spec.params.string("direction") ?? "up"
            let distance = context.points(spec.params.double("distance") ?? 0.05)
            let (dx, dy) = offset(direction: direction, distance: distance, inverted: !isIn)
            let final = CGPoint(x: info.frame.midX, y: info.frame.midY)
            let shifted = CGPoint(x: final.x + dx, y: final.y + dy)
            let a = CABasicAnimation(keyPath: "position")
            a.fromValue = isIn ? shifted : final
            a.toValue = isIn ? final : shifted
            var result = [configured(a, begin: begin, spec: spec, context: context)]
            // Slide genelde fade ile birlikte istenir; preset bunu içerir.
            let fade = basic("opacity", from: isIn ? 0 : info.baseOpacity,
                             to: isIn ? info.baseOpacity : 0)
            result.append(configured(fade, begin: begin, spec: spec, context: context))
            return result

        case "scaleIn":
            let from = spec.params.double("from") ?? 0.8
            let a = basic("transform.scale", from: from, to: 1)
            return [configured(a, begin: begin, spec: spec, context: context)]

        case "pop":
            let overshoot = spec.params.double("overshoot") ?? 1.06
            let a = CAKeyframeAnimation(keyPath: "transform.scale")
            a.values = [0.85, overshoot, 1.0]
            a.keyTimes = [0, 0.7, 1]
            return [configured(a, begin: begin, spec: spec, context: context)]

        case "kenBurns":
            // Aralık boyunca yavaş zoom + yönlü sürüklenme. Süre pencereye kilitli.
            let zoom = spec.params.double("zoom") ?? 1.1
            let direction = spec.params.string("direction") ?? "up"
            let windowLength = info.window.end - info.window.start
            let scale = basic("transform.scale", from: 1, to: zoom)
            let drift = info.frame.height * CGFloat(zoom - 1) * 0.25
            let (dx, dy) = offset(direction: direction, distance: drift, inverted: true)
            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = CGPoint(x: info.frame.midX, y: info.frame.midY)
            move.toValue = CGPoint(x: info.frame.midX + dx, y: info.frame.midY + dy)
            return [scale, move].map {
                let a = configured($0, begin: info.window.start, spec: spec, context: context)
                a.duration = windowLength
                if $0 === scale { a.timingFunction = CAMediaTimingFunction(name: .linear) }
                return a
            }

        case "wipeReveal":
            // Builder, bu preset'i gördüğünde anchorPoint'i yöne göre kaydırır
            // (bkz. TemplateLayerBuilder.adjustAnchorForWipe).
            let direction = spec.params.string("direction") ?? "right"
            let keyPath = (direction == "up" || direction == "down")
                ? "transform.scale.y" : "transform.scale.x"
            let a = basic(keyPath, from: 0.001, to: 1)
            return [configured(a, begin: begin, spec: spec, context: context)]

        case "bounce":
            // Yaylanarak yerleşme: aşağıdan gelip birkaç kez sekerek durur.
            let a = CAKeyframeAnimation(keyPath: "transform.scale")
            a.values = [0.4, 1.18, 0.92, 1.06, 0.98, 1.0]
            a.keyTimes = [0, 0.35, 0.55, 0.72, 0.88, 1]
            a.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut),
                                      count: 5)
            var result = [configured(a, begin: begin, spec: spec, context: context)]
            let fade = basic("opacity", from: 0, to: info.baseOpacity)
            let f = configured(fade, begin: begin, spec: spec, context: context)
            f.duration = min(spec.duration * 0.4, spec.duration)
            result.append(f)
            return result

        case "pulse":
            // Nabız: ölçeği ileri geri götürür. `role: loop` ile katmanın tüm
            // penceresi boyunca tekrarlar (dalga çubuğu, canlı rozeti, CTA).
            // `axis: y` yalnız dikey ölçekler — çubuk grafiği/waveform için.
            let axis = spec.params.string("axis")
            let keyPath = axis == "y" ? "transform.scale.y"
                        : axis == "x" ? "transform.scale.x" : "transform.scale"
            let scale = spec.params.double("scale") ?? 1.12
            let a = basic(keyPath, from: 1, to: scale)
            a.autoreverses = true
            return [configured(a, begin: begin, spec: spec, context: context)]

        case "punchIn":
            // Sert yaklaşma: büyükten hızla yerine oturur. Ritme vuran giriş —
            // fadeIn'in "slayt" hissini kıran en ucuz hamle.
            let from = spec.params.double("from") ?? 1.6
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [from, 0.97, 1.0]
            scale.keyTimes = [0, 0.75, 1]
            scale.timingFunctions = [CAMediaTimingFunction(name: .easeOut),
                                     CAMediaTimingFunction(name: .easeOut)]
            var result = [configured(scale, begin: begin, spec: spec, context: context)]
            let fade = basic("opacity", from: 0, to: info.baseOpacity)
            let f = configured(fade, begin: begin, spec: spec, context: context)
            f.duration = max(spec.duration * 0.35, 0.05)
            result.append(f)
            return result

        case "spinIn":
            // Dönerek yerleşme: küçük açıdan gelir, ölçekle birlikte oturur.
            let degrees = spec.params.double("degrees") ?? 12
            let spin = basic("transform.rotation.z", from: degrees * .pi / 180, to: 0)
            let scale = basic("transform.scale", from: spec.params.double("from") ?? 0.82, to: 1)
            let fade = basic("opacity", from: 0, to: info.baseOpacity)
            return [spin, scale, fade].map {
                configured($0, begin: begin, spec: spec, context: context)
            }

        case "swingIn":
            // Sallanarak asılma (sticker/rozet): açıdan gelir, birkaç kez salınır.
            let degrees = spec.params.double("degrees") ?? 14
            let radians = degrees * .pi / 180
            let swing = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            swing.values = [radians, -radians * 0.45, radians * 0.20, -radians * 0.08, 0]
            swing.keyTimes = [0, 0.4, 0.62, 0.82, 1]
            swing.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut),
                                          count: 4)
            var result = [configured(swing, begin: begin, spec: spec, context: context)]
            let fade = basic("opacity", from: 0, to: info.baseOpacity)
            let f = configured(fade, begin: begin, spec: spec, context: context)
            f.duration = max(spec.duration * 0.3, 0.05)
            result.append(f)
            return result

        case "floatLoop":
            // Sürekli hafif süzülme. Tek sahneli şablonların %80'i hareketsiz
            // duruyordu; bu, kadraja durmadan can veren en ucuz katman.
            let amount = context.points(spec.params.double("distance") ?? 0.008)
            let axis = spec.params.string("axis") ?? "y"
            let keyPath = axis == "x" ? "position.x" : "position.y"
            let center = axis == "x" ? info.frame.midX : info.frame.midY
            let a = CABasicAnimation(keyPath: keyPath)
            a.fromValue = center - amount
            a.toValue = center + amount
            a.autoreverses = true
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            return [configured(a, begin: begin, spec: spec, context: context)]

        case "shake":
            // Dikkat çeken küçük titreşim (rozet, CTA). `role: loop` ile tekrarlar.
            let degrees = spec.params.double("degrees") ?? 2.5
            let radians = degrees * .pi / 180
            let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            a.values = [0, radians, -radians, radians * 0.5, 0]
            a.keyTimes = [0, 0.25, 0.5, 0.75, 1]
            return [configured(a, begin: begin, spec: spec, context: context)]

        case "kineticWords":
            // Kelime kelime giriş. Katmanlar builder'da kurulur (kelime
            // geometrisi orada bilinir — bkz. TemplateLayerBuilder); burada
            // yalnız görünürlük sağlanır, çift fade olmasın diye anlık.
            let a = basic("opacity", from: 0, to: info.baseOpacity)
            let visible = configured(a, begin: begin, spec: spec, context: context)
            visible.duration = 0.01
            return [visible]

        case "typewriter":
            // Gerçek daktilo: metin görüntüsünün maskesi karakter karakter açılır.
            // Maske animasyonu builder'da kurulur (metin genişliği orada bilinir);
            // burada yalnız görünürlük sağlanır — çift fade olmasın diye kısa.
            let a = basic("opacity", from: 0, to: info.baseOpacity)
            let configuredFade = configured(a, begin: begin, spec: spec, context: context)
            configuredFade.duration = 0.01
            return [configuredFade]

        default:
            warnings.append("Unknown animation preset '\(spec.preset)' skipped")
            return []
        }
        }
        return repeated(build())
    }

    /// Katman, timing penceresi dışında görünmez olmalı. Bu, preset
    /// animasyonlardan bağımsız bir "presence" keyframe'idir ve builder
    /// tarafından CONTAINER katmanına uygulanır (preset'ler content'e uygulanır,
    /// böylece aynı keyPath üzerinde çakışmazlar).
    public static func presenceAnimation(window: (start: Double, end: Double),
                                         context: RenderContext) -> CAAnimation? {
        let coversStart = window.start <= 0
        let coversEnd = window.end >= context.duration
        if coversStart && coversEnd { return nil }

        // .discrete modda keyTimes ARALIK SINIRLARIDIR: values.count + 1 eleman
        // olmak zorunda; eşleşmezse Core Animation animasyonu sessizce yok sayar
        // (ve katman hiç görünmez — export'ta bulunan gerçek bug).
        var values: [Float] = []
        var keyTimes: [NSNumber] = [0]
        if !coversStart {
            values.append(0)
            keyTimes.append(NSNumber(value: window.start / context.duration))
        }
        values.append(1)
        if !coversEnd {
            keyTimes.append(NSNumber(value: window.end / context.duration))
            values.append(0)
        }
        keyTimes.append(1)

        let a = CAKeyframeAnimation(keyPath: "opacity")
        a.calculationMode = .discrete
        a.values = values
        a.keyTimes = keyTimes
        a.beginTime = context.baseTime
        a.duration = context.duration
        a.fillMode = .both
        a.isRemovedOnCompletion = false
        return a
    }

    // MARK: - Helpers

    private static func basic(_ keyPath: String, from: Any, to: Any) -> CABasicAnimation {
        let a = CABasicAnimation(keyPath: keyPath)
        a.fromValue = from
        a.toValue = to
        return a
    }

    private static func configured(_ animation: CAAnimation,
                                   begin: Double,
                                   spec: AnimationSpec,
                                   context: RenderContext) -> CAAnimation {
        animation.beginTime = context.baseTime + begin
        animation.duration = spec.duration
        animation.timingFunction = timingFunction(for: spec.easing)
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        return animation
    }

    private static func timingFunction(for easing: Easing) -> CAMediaTimingFunction {
        switch easing {
        case .linear: return CAMediaTimingFunction(name: .linear)
        case .easeIn: return CAMediaTimingFunction(name: .easeIn)
        case .easeOut: return CAMediaTimingFunction(name: .easeOut)
        case .easeInOut: return CAMediaTimingFunction(name: .easeInEaseOut)
        case .spring:
            // Hafif taşmalı yaklaşık yay eğrisi. Gerçek CASpringAnimation süresi
            // fizikten türediği için şablonun sabit süre modeline uymaz.
            return CAMediaTimingFunction(controlPoints: 0.3, 1.15, 0.4, 1)
        }
    }

    private static func offset(direction: String,
                               distance: CGFloat,
                               inverted: Bool) -> (CGFloat, CGFloat) {
        let sign: CGFloat = inverted ? -1 : 1
        switch direction {
        case "up": return (0, sign * distance)      // yukarı girer -> aşağıdan başlar
        case "down": return (0, -sign * distance)
        case "left": return (sign * distance, 0)
        case "right": return (-sign * distance, 0)
        default: return (0, sign * distance)
        }
    }
}
#endif
