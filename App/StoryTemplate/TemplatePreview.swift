import SwiftUI
import AVFoundation
import CoreGraphics
import TemplateKit

/// Şablonu SwiftUI ile çizen GENEL önizleme.
///
/// Neden: eski önizleme katman id'lerine ("headline", "cap0"…) göre elle
/// yazılmıştı; şablon sayısı arttıkça çoğu şablonu yanlış/boş gösteriyordu.
/// Burada şablonun KENDİ katmanları okunur — hangi şablon eklenirse eklensin
/// (CDN'den gelen dahil) galeri kartı ve editör önizlemesi doğru görünür.
///
/// Sınırlar: animasyon yok, tek bir "poster anı" çizilir (o anda sahnede olan
/// katmanlar). Gerçek çıktı her zaman `TemplateExporter`'dan gelir; bu yalnız
/// hızlı bir temsil.
struct TemplatePreview: View {
    let template: Template
    var texts: [String: String] = [:]
    var photos: [Int: CGImage] = [:]
    var videos: [Int: URL] = [:]
    /// Şablon süresinin hangi anı çizilsin (0-1). Varsayılan: çoğu katmanın
    /// sahnede olduğu geç an.
    var progress: Double = 0.75
    /// Medya slotu boşsa gradient yer tutucu çiz.
    var showsPlaceholders = true
    /// Kullanıcının seçtiği vurgu rengi (motor `paletteOverride`'ının önizleme
    /// karşılığı) — editörde renk değiştirince sahne anında güncellensin.
    var accentOverride: String?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color(hex: template.palette["background"] ?? "#000000")
                ForEach(Array(visibleLayers.enumerated()), id: \.offset) { _, layer in
                    layerView(layer, canvas: size)
                        .frame(width: size.width * layer.frame.width,
                               height: size.height * layer.frame.height)
                        .rotationEffect(.degrees(layer.rotation))
                        .opacity(layer.opacity)
                        .position(x: size.width * layer.frame.x,
                                  y: size.height * layer.frame.y)
                }
            }
            .clipped()
        }
    }

    // MARK: - Katman seçimi

    private var time: Double { template.totalDuration * progress }

    /// Poster anında sahnede olan katmanlar (montajda o anki sahne + global).
    private var visibleLayers: [Layer] {
        var result: [Layer] = []
        if let scenes = template.scenes, !scenes.isEmpty {
            let timeline = MontageTimeline(scenes: scenes)
            let window = timeline.windows.first { time >= $0.start && time < $0.end }
                ?? timeline.windows[timeline.windows.count - 1]
            let scene = scenes[window.index]
            let local = min(max(0, time - window.start), scene.duration)
            result = scene.layers.filter {
                let w = $0.timing.window(templateDuration: scene.duration)
                return local >= w.start && local <= w.end
            }
            result += template.layers
        } else {
            result = template.layers.filter {
                let w = $0.timing.window(templateDuration: template.totalDuration)
                return time >= w.start && time <= w.end
            }
        }
        return result
    }

    // MARK: - Katman çizimi

    @ViewBuilder
    private func layerView(_ layer: Layer, canvas: CGSize) -> some View {
        switch layer.content {
        case .shape(let shape):
            let radius = canvas.height * shape.cornerRadius
            if let gradient = shape.gradient {
                RoundedRectangle(cornerRadius: radius)
                    .fill(LinearGradient(colors: [color(gradient.from), color(gradient.to)],
                                         startPoint: gradientStart(gradient.direction),
                                         endPoint: gradientEnd(gradient.direction)))
            } else {
                RoundedRectangle(cornerRadius: radius).fill(color(shape.colorRole))
            }

        case .text(let content):
            let value = resolvedText(layer: layer, content: content)
            Text(value)
                .font(.system(size: canvas.height * content.font.size,
                              weight: weight(content.font.name),
                              design: content.font.name.contains("Didot") ? .serif : .default))
                .tracking(canvas.height * content.letterSpacing)
                .foregroundStyle(color(content.colorRole))
                .multilineTextAlignment(alignment(content.alignment))
                .lineLimit(max(content.maxLines, 4))
                .minimumScaleFactor(0.4)
                .padding(.horizontal, content.highlightColorRole == nil ? 0 : canvas.width * 0.015)
                .background {
                    if let highlight = content.highlightColorRole {
                        RoundedRectangle(cornerRadius: canvas.height * 0.004)
                            .fill(color(highlight))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: frameAlignment(content.alignment))

        case .mediaSlot(let slot):
            mediaView(slot: slot)
                .clipShape(MaskShapeView(kind: slot.mask,
                                         cornerRadius: canvas.height * slot.cornerRadius))

        case .lottie:
            // Önizlemede lottie yok — yerine hafif bir vurgu dairesi.
            Circle().fill(color("accent").opacity(0.25))
        }
    }

    @ViewBuilder
    private func mediaView(slot: MediaSlotContent) -> some View {
        if let photo = photos[slot.slotIndex] {
            Image(decorative: photo, scale: 1).resizable().scaledToFill()
        } else if let url = videos[slot.slotIndex] {
            VideoThumbnail(url: url)
        } else if showsPlaceholders {
            ZStack {
                LinearGradient(colors: [color("accent").opacity(0.55),
                                        color("surface").opacity(0.8)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: slot.media == .video ? "play.circle" : "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    // MARK: - Yardımcılar

    private func resolvedText(layer: Layer, content: TextContent) -> String {
        let raw = texts[layer.id] ?? content.default.resolved(languageCode: AppLanguage.code)
        return content.allCaps ? raw.uppercased(with: Locale(identifier: "tr_TR")) : raw
    }

    private func color(_ role: String) -> Color {
        if role == "accent", let accentOverride {
            return Color(hex: accentOverride)
        }
        return Color(hex: template.palette[role] ?? "#00000000")
    }

    private func weight(_ font: String) -> Font.Weight {
        if font.contains("Heavy") { return .heavy }
        if font.contains("Bold") { return font.contains("Demi") ? .semibold : .bold }
        if font.contains("Medium") { return .medium }
        return .regular
    }

    private func alignment(_ value: TemplateKit.TextAlignment) -> SwiftUI.TextAlignment {
        switch value {
        case .left: return .leading
        case .right: return .trailing
        case .center: return .center
        }
    }

    private func frameAlignment(_ value: TemplateKit.TextAlignment) -> Alignment {
        switch value {
        case .left: return .leading
        case .right: return .trailing
        case .center: return .center
        }
    }

    private func gradientStart(_ direction: String) -> UnitPoint {
        switch direction {
        case "up": return .bottom
        case "left": return .trailing
        case "right": return .leading
        case "diagonal": return .topLeading
        default: return .top
        }
    }

    private func gradientEnd(_ direction: String) -> UnitPoint {
        switch direction {
        case "up": return .top
        case "left": return .leading
        case "right": return .trailing
        case "diagonal": return .bottomTrailing
        default: return .bottom
        }
    }
}

/// Slot maskesini SwiftUI şekline çevirir (motordaki `MaskShape` ile aynı fikir).
private struct MaskShapeView: Shape {
    let kind: MaskKind
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .circle:
            return Path(ellipseIn: rect)
        case .star, .heart:
            return MaskShape.path(for: kind, in: rect).map(Path.init) ?? Path(rect)
        case .rect:
            return Path(roundedRect: rect, cornerRadius: cornerRadius)
        }
    }
}

/// Video slotunun ilk karesi (galeri kartı ve editör önizlemesi için).
private struct VideoThumbnail: View {
    let url: URL
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image.resizable().scaledToFill()
            } else {
                Color.white.opacity(0.08)
            }
        }
        .task(id: url) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 360, height: 640)
            if let cg = try? await generator.image(at: CMTime(seconds: 0.4,
                                                              preferredTimescale: 600)).image {
                image = Image(decorative: cg, scale: 1)
            }
        }
    }
}
