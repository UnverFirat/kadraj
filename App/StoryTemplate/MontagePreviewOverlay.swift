import SwiftUI
import AVFoundation
import TemplateKit

/// Montaj önizlemesi: kolaj+geçiş videosu (MontageComposer çıktısı) üstüne
/// şablonun metin/şekil katmanlarını CANLI bindirir. Katmanlar sahne penceresine
/// göre görünüp kaybolur (flattenedLayersForRender mutlak-zamanlı timing verir).
///
/// Bu, export'un 2. geçişinin (grafik katmanları videoya gömer) önizleme
/// karşılığıdır — gerçek uygulamada montaj önizlemesi de böyle çalışır: video
/// akar, grafikler üstünde gerçek zamanlı. (Export gömer; önizleme bindirir.)
struct MontagePreviewOverlay: View {
    let template: Template
    let texts: [String: String]
    /// Kullanıcının seçtiği vurgu rengi (yoksa şablonunki). Export bunu
    /// `edits.paletteOverride` ile gömüyor; bindirme de aynı rengi
    /// kullanmazsa "Renk" sekmesi simulator'da hiçbir şey yapmıyor görünür.
    var accentHex: String?
    let player: AVPlayer

    @State private var time: Double = 0

    private var overlayLayers: [Layer] {
        // Video slotları hariç grafik/metin katmanları, mutlak zamanlı.
        var edits = UserEdits(textOverrides: texts)
        for i in 0..<8 { edits.slots[i] = SlotAssignment(assetIdentifier: "x", kind: .video) }
        return template.flattenedLayersForRender(edits: edits)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(overlayLayers) { layer in
                    // KATMANIN KENDİ SAYDAMLIĞI ÇARPILIR. Yok sayıldığında
                    // tam kadraj scrim'ler (quote-01'de opacity 0.62) dolu
                    // renkle çizilip ALTTAKİ VİDEOYU tamamen örtüyordu:
                    // önizleme siyah zeminde metin gösteriyor, kullanıcının
                    // fotoğrafı görünmüyordu. Simulator'a özel bir yol ama
                    // simulator doğrulamasını yalanlıyordu.
                    layerView(layer, in: geo.size)
                        .opacity(isVisible(layer) ? layer.opacity : 0)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { observe() }
    }

    @ViewBuilder
    private func layerView(_ layer: Layer, in size: CGSize) -> some View {
        let rect = frame(layer.frame, in: size)
        switch layer.content {
        case .text(let content):
            Text(displayText(layer, content))
                .font(.system(size: content.font.size * size.height,
                              weight: weight(content.font.name)))
                .tracking(content.letterSpacing * size.height)
                .foregroundStyle(color(content.colorRole))
                .padding(.horizontal, content.highlightColorRole != nil ? 6 : 0)
                .padding(.vertical, content.highlightColorRole != nil ? 2 : 0)
                .background(content.highlightColorRole.map { color($0) } ?? .clear)
                .shadow(color: content.highlightColorRole == nil ? .black.opacity(0.35) : .clear,
                        radius: 6)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .shape(let content):
            Rectangle()
                .fill(color(content.colorRole))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        default:
            EmptyView()
        }
    }

    private func displayText(_ layer: Layer, _ content: TextContent) -> String {
        var s = texts[layer.id] ?? content.default.resolved(languageCode: AppLanguage.code)
        if content.allCaps { s = s.uppercased(with: Locale(identifier: "tr_TR")) }
        return s
    }

    private func frame(_ n: NormalizedRect, in size: CGSize) -> CGRect {
        CGRect(x: (n.x - n.width / 2) * size.width,
               y: (n.y - n.height / 2) * size.height,
               width: n.width * size.width, height: n.height * size.height)
    }

    private func isVisible(_ layer: Layer) -> Bool {
        let w = layer.timing.window(templateDuration: template.totalDuration)
        return time >= w.start - 0.05 && time <= w.end + 0.05
    }

    private func color(_ role: String) -> Color {
        if role == "accent", let accentHex { return Color(hex: accentHex) }
        return Color(hex: template.palette[role] ?? "#FFFFFF")
    }

    private func weight(_ fontName: String) -> Font.Weight {
        fontName.contains("SemiBold") ? .semibold
            : fontName.contains("Bold") ? .bold : .regular
    }

    private func observe() {
        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main) { t in time = t.seconds }
    }
}
