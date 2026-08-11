import Foundation

/// Sahne listesinden montaj zaman çizelgesini hesaplar. Saf matematik —
/// AVFoundation'sız, böylece birim testleri Mac'te milisaniyede koşar.
///
/// Zaman modeli: geçişler sahneleri ÖRTÜŞTÜRÜR. `transition.duration = d` ise
/// sonraki sahne, önceki bitmeden d saniye önce başlar ve pencere boyunca
/// harmanlanır. Toplam süre = sahne süreleri toplamı - geçiş süreleri toplamı.
///
///   sahne A [0 ────────── 4.0]
///   sahne B        [3.4 ────────── 7.4]     (A->B geçişi 0.6s: [3.4, 4.0])
public struct MontageTimeline: Equatable, Sendable {

    public struct SceneWindow: Equatable, Sendable {
        public let index: Int
        /// Mutlak başlangıç (örtüşme düşülmüş).
        public let start: Double
        public let duration: Double
        public var end: Double { start + duration }
    }

    /// Zaman çizelgesinin boşluksuz dilimleri; compositor talimatları buradan üretilir.
    public enum Segment: Equatable, Sendable {
        case scene(index: Int, start: Double, end: Double)
        case transition(from: Int, to: Int, style: String, start: Double, end: Double)

        public var start: Double {
            switch self {
            case .scene(_, let s, _), .transition(_, _, _, let s, _): return s
            }
        }
        public var end: Double {
            switch self {
            case .scene(_, _, let e), .transition(_, _, _, _, let e): return e
            }
        }
    }

    public let windows: [SceneWindow]
    public let segments: [Segment]
    public let totalDuration: Double

    /// Sahneleri ÖRTÜŞTÜREN geçiş stilleri. "cut" örtüşmez; bu sette olmayan
    /// (tanınmayan) stil de örtüşmez → güvenli varsayılan sert kesme.
    /// Compositor bu stillerin her birini kendi harmanıyla render eder.
    public static let overlappingStyles: Set<String> = [
        "crossDissolve", "blurDissolve", "slide", "slideLeft", "slideRight",
        "slideUp", "slideDown", "zoomIn", "zoomOut", "whip"
    ]

    public init(scenes: [TemplateScene]) {
        func overlap(after index: Int) -> Double {
            guard index < scenes.count - 1,
                  let transition = scenes[index].transition,
                  MontageTimeline.overlappingStyles.contains(transition.style)
            else { return 0 }
            return max(0, transition.duration)
        }

        var windows: [SceneWindow] = []
        var cursor = 0.0
        for (index, scene) in scenes.enumerated() {
            windows.append(SceneWindow(index: index, start: cursor, duration: scene.duration))
            cursor += scene.duration - overlap(after: index)
        }
        self.windows = windows
        self.totalDuration = windows.last?.end ?? 0

        var segments: [Segment] = []
        for window in windows {
            let incoming = window.index > 0 ? overlap(after: window.index - 1) : 0
            let outgoing = overlap(after: window.index)
            let interiorStart = window.start + incoming
            let interiorEnd = window.end - outgoing
            if interiorEnd > interiorStart {
                segments.append(.scene(index: window.index,
                                       start: interiorStart, end: interiorEnd))
            }
            if outgoing > 0 {
                segments.append(.transition(from: window.index,
                                            to: window.index + 1,
                                            style: scenes[window.index].transition?.style ?? "cut",
                                            start: interiorEnd,
                                            end: window.end))
            }
        }
        self.segments = segments
    }
}
