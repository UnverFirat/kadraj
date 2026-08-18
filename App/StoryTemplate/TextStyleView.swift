import SwiftUI
import TemplateKit

/// Bir metin alanının STİLİ: boyut, renk, yazı tipi.
///
/// NEDEN VAR: editörde metnin yalnız içeriği değiştirilebiliyordu. "Şablonun
/// dışına çıkamıyorum" hissinin ana kaynağı buydu — kullanıcı kendi markasının
/// rengini/yazısını kuramıyor, başlığı biraz küçültmek isteyince yapamıyordu.
/// Motor tipografiyi zaten parametrik çiziyor; eksik olan tek şey arayüzdü.
///
/// Şablonun tasarımı VARSAYILAN kalır: burada yalnız dokunulan şey değişir,
/// "sıfırla" her zaman bir dokunuş uzakta.
struct TextStyleView: View {
    let fieldLabel: String
    /// Örnek olarak gösterilecek metin (kullanıcının kendi yazdığı).
    let sample: String
    /// Şablonun bu katman için tasarladığı font adı (kalınlığı korunur).
    let templateFontName: String
    /// Şablonun bu katman için tasarladığı renk (sıfırlama örneği).
    let templateColorHex: String
    /// Sahne zemini — rengi zemin üstünde görmek gerekiyor.
    let backgroundHex: String
    /// Şablonun paletindeki renkler (kullanıcı kendi şablonuna uyumlu kalabilsin).
    let paletteHexes: [String]
    let accentHex: String

    @Binding var style: TextStyleOverride
    @Environment(\.dismiss) private var dismiss

    private var tint: Color { Color(hex: accentHex) }

    /// Renk seçenekleri: şablonun paleti + her tasarımda işe yarayan nötrler.
    private var colorChoices: [String] {
        var seen = Set<String>()
        return (paletteHexes + ["#FFFFFF", "#000000", "#F2C14E", "#FF2E63",
                                "#00E5A0", "#6C8CFF"])
            .filter { $0.count >= 7 && seen.insert($0.uppercased()).inserted }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    previewBox
                    sizeSection
                    colorSection
                    fontSection
                    if !style.isEmpty {
                        Button {
                            Haptics.tap()
                            style = TextStyleOverride()
                        } label: {
                            Label("Şablonun stiline dön", systemImage: "arrow.uturn.backward")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(.white.opacity(0.07),
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(Text(fieldLabel))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
        }
    }

    // MARK: Önizleme

    private var previewBox: some View {
        ZStack {
            Color(hex: backgroundHex)
            Text(sample.isEmpty ? String(localized: "Örnek metin") : sample)
                .font(previewFont)
                .foregroundStyle(Color(hex: style.colorHex ?? templateColorHex))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 18)
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    /// Önizleme fontu: aile seçiliyse onun PostScript adı (motorla aynı ad),
    /// değilse şablonun kendi fontu. Bulunmayan ad sistem fontuna düşer.
    private var previewFont: Font {
        let name = TextFontFamily.from(style.fontFamily)?
            .postScriptName(preservingWeightOf: templateFontName) ?? templateFontName
        return .custom(name, size: 26 * style.scale)
    }

    // MARK: Boyut

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionTitle("Boyut")
                Spacer()
                Text("%\(Int((style.scale * 100).rounded()))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            HStack(spacing: 12) {
                Image(systemName: "textformat.size.smaller")
                    .foregroundStyle(.white.opacity(0.5))
                Slider(value: Binding(get: { style.scale },
                                      set: { style.scale = TextStyleOverride.clampScale($0) }),
                       in: TextStyleOverride.scaleRange)
                    .tint(tint)
                Image(systemName: "textformat.size.larger")
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text("Şablonun tasarladığı boyuta göre. Metin kutuya sığmazsa motor ayrıca küçültür.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: Renk

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Renk")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    swatch(nil, hex: templateColorHex)
                    ForEach(colorChoices, id: \.self) { hex in
                        swatch(hex, hex: hex)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func swatch(_ value: String?, hex: String) -> some View {
        let selected = style.colorHex?.uppercased() == value?.uppercased()
        return Button {
            Haptics.select()
            style.colorHex = value
        } label: {
            ZStack {
                Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                if value == nil {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: hex).isLight ? .black : .white)
                }
            }
            .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 0))
            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: selected ? 0 : 1))
            .padding(2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == nil ? Text("Şablonun rengi") : Text("Renk \(hex)"))
    }

    // MARK: Yazı tipi

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Yazı tipi")
            HStack(spacing: 8) {
                fontChip(nil, title: String(localized: "Şablon"), name: templateFontName)
                ForEach(TextFontFamily.allCases, id: \.self) { family in
                    fontChip(family, title: Self.title(for: family),
                             name: family.postScriptName(preservingWeightOf: templateFontName))
                }
            }
        }
    }

    private func fontChip(_ family: TextFontFamily?, title: String, name: String) -> some View {
        let selected = style.fontFamily == family?.rawValue
        return Button {
            Haptics.select()
            style.fontFamily = family?.rawValue
        } label: {
            VStack(spacing: 3) {
                Text("Aa")
                    .font(.custom(name, size: 19))
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? .black : .white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selected ? AnyShapeStyle(tint) : AnyShapeStyle(.white.opacity(0.09)),
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    static func title(for family: TextFontFamily) -> String {
        switch family {
        case .sans:    return String(localized: "Modern")
        case .serif:   return String(localized: "Klasik")
        case .round:   return String(localized: "Yumuşak")
        case .display: return String(localized: "İddialı")
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
    }
}

extension Color {
    /// Sıfırlama işaretinin rengini seçmek için: zemin açık mı?
    var isLight: Bool {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return false
        }
        // Algısal parlaklık (Rec. 601) — düz ortalama sarıyı koyu sanıyor.
        let luma = 0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2]
        return luma > 0.6
    }
}
