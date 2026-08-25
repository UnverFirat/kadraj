import SwiftUI
import AVFoundation
import CoreGraphics
import TemplateKit

/// Tek bir medya slotunun ayarları: **kadraj**, **klibin hangi saniyesinden
/// başlayacağı**, **hız**, sıra ve değiştirme.
///
/// NEDEN VAR: motor `CropTransform` ve `videoStart` alanlarını ta başından beri
/// okuyordu ama arayüzde karşılığı yoktu. Sonuç, kullanıcının en çok canını
/// yakan iki şeydi: 30 saniyelik videosundan HEP ilk saniyeler alınıyor ve
/// hangi saniye olduğunu seçemiyor; dikey olmayan bir fotoğrafta öznesi
/// merkeze göre kırpılıp kadraj dışında kalıyor. Şablon uygulaması "hazır
/// düzen" satar, ama kullanıcının kendi çekimi o düzene DÜZGÜN oturmuyorsa
/// oyuncak gibi duruyor.
///
/// Dolu bir kareye dokunmak artık medyayı değiştirmiyor, bu ekranı açıyor
/// (değiştirme burada bir düğme) — video editörlerinin alışılmış davranışı.
struct ClipSettingsView: View {
    /// Kullanıcıya gösterilen sıra (1'den başlar).
    let displayIndex: Int
    let totalSlots: Int
    /// Slotun şablondaki kadraj oranı (genişlik / yükseklik).
    let slotAspect: Double
    /// Bu slotun sahnede kaç saniye göründüğü (montajda sahne penceresi,
    /// klasik şablonda tüm süre) — "klibin ne kadarı kullanılacak" hesabı için.
    let windowDuration: Double
    let accentHex: String
    /// Video slotu mu (trim ve hız yalnız videoda anlamlı).
    let videoURL: URL?
    /// Foto slotu ise görüntü.
    let photo: CGImage?

    @Binding var crop: CropTransform
    @Binding var start: Double
    @Binding var speed: Double

    let onReplace: () -> Void
    let onRemove: () -> Void
    /// nil = o yöne taşınamaz (baştaki/sondaki klip).
    let onMoveEarlier: (() -> Void)?
    let onMoveLater: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// Kaynak klibin süresi (video); yüklenene kadar nil.
    @State private var clipDuration: Double?
    /// Kadraj alanında gösterilen kare (video: `start` anındaki kare).
    @State private var frame: CGImage?
    /// Şerit kareleri (trim çubuğu).
    @State private var strip: [CGImage] = []
    /// Sürükleme başındaki kadraj — jest boyunca birikimli hesap için.
    @State private var dragOrigin: CropTransform?
    @State private var pinchOrigin: Double?

    private var tint: Color { Color(hex: accentHex) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    cropStage
                    if videoURL != nil { trimSection }
                    if videoURL != nil { speedSection }
                    orderSection
                    actionSection
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(Text("Klip \(displayIndex)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
        }
        .task { await loadMedia() }
        // Başlangıç değişince kadraj alanındaki kare de değişmeli — kullanıcı
        // kırptığı ANI kadrajlıyor.
        .task(id: start) { await loadFrame() }
    }

    // MARK: - Kadraj

    private var cropStage: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    Color.white.opacity(0.06)
                    if let image = frame ?? photo {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height)
                            // Motor sırası: aspect-fill → scale → offset.
                            // Önizleme birebir aynı sırayı uygular, yoksa
                            // kullanıcı burada kadrajladığını export'ta
                            // bulamaz.
                            .scaleEffect(crop.scale)
                            .offset(x: crop.offsetX * size.width,
                                    y: crop.offsetY * size.height)
                            .clipped()
                    } else {
                        ProgressView().tint(.white)
                    }
                    grid
                }
                .contentShape(Rectangle())
                .gesture(panGesture(in: size))
                .gesture(zoomGesture)
            }
            .aspectRatio(slotAspect, contentMode: .fit)
            // YÜKSEKLİK SINIRLI: 9:16 bir slotta kadraj alanı ekranın tamamını
            // kaplıyor ve altındaki trim/hız/sıra kontrollerine ULAŞILAMIYOR —
            // üstelik alan kaydırma jestini kadrajlama için yuttuğu için
            // sheet'i kaydırmak da mümkün olmuyor. Sınırla birlikte tüm
            // kontroller tek ekrana sığıyor.
            //
            // GENİŞLİK SINIRSIZ BIRAKILMAZ: burada bir zamanlar `maxWidth:
            // .infinity` vardı ve çerçeveyi ekran genişliğine yayıyordu —
            // altındaki clip/stroke da o boş kutuya çiziliyor, kullanıcının
            // fotoğrafı ortada dar bir şerit olarak kalıyordu. Oysa bu ekranın
            // tek işi "fotoğrafımın neresi videoya girecek" sorusunu
            // yanıtlamak; çerçeve kadrajın KENDİSİNİ göstermeli. Genişlik
            // orandan türesin, kutuyu VStack ortalasın.
            .frame(maxHeight: 330)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.18), lineWidth: 1))

            HStack(spacing: 10) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 11))
                Text("Sürükleyerek kadrajla, iki parmakla yakınlaştır")
                    .font(.system(size: 11))
                Spacer()
                if !crop.isIdentity {
                    Button {
                        Haptics.tap()
                        crop = CropTransform()
                    } label: {
                        Text("Kadrajı sıfırla")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(.white.opacity(0.45))
        }
    }

    /// Üçler kuralı ızgarası — kadrajlarken referans çizgisi olmadan öznenin
    /// nereye geldiği kestirilemiyor.
    private var grid: some View {
        GeometryReader { geo in
            Path { path in
                for i in 1..<3 {
                    let x = geo.size.width * Double(i) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    let y = geo.size.height * Double(i) / 3
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.16), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let origin = dragOrigin ?? crop
                if dragOrigin == nil { dragOrigin = crop }
                var updated = origin
                updated.offsetX = origin.offsetX + value.translation.width / size.width
                updated.offsetY = origin.offsetY + value.translation.height / size.height
                crop = clamped(updated)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let origin = pinchOrigin ?? crop.scale
                if pinchOrigin == nil { pinchOrigin = crop.scale }
                var updated = crop
                updated.scale = min(max(origin * value, CropTransform.scaleRange.lowerBound),
                                    CropTransform.scaleRange.upperBound)
                crop = clamped(updated)
            }
            .onEnded { _ in pinchOrigin = nil }
    }

    /// Kadrajı boşluk çıkmayacak şekilde sınırlar.
    ///
    /// Kaydırma payı iki kaynaktan gelir: (1) yakınlaştırma, (2) aspect-fill'in
    /// kendiliğinden taşırdığı kenar — 4:3 bir fotoğraf 9:16 slota oturunca
    /// yataya zaten taşar, yani kullanıcı zoom yapmadan da yatay kaydırabilmeli.
    private func clamped(_ value: CropTransform) -> CropTransform {
        var result = value
        result.scale = min(max(value.scale, CropTransform.scaleRange.lowerBound),
                           CropTransform.scaleRange.upperBound)
        let source = (frame ?? photo).map { Double($0.width) / Double($0.height) }
            ?? slotAspect
        var overflowX = 0.0, overflowY = 0.0
        if source > slotAspect {
            overflowX = source / slotAspect - 1
        } else if source < slotAspect {
            overflowY = slotAspect / source - 1
        }
        let roomX = (overflowX + result.scale - 1) / 2
        let roomY = (overflowY + result.scale - 1) / 2
        result.offsetX = min(max(value.offsetX, -roomX), roomX)
        result.offsetY = min(max(value.offsetY, -roomY), roomY)
        return result
    }

    // MARK: - Trim

    private var trimSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Nereden başlasın")
                Spacer()
                Text(Self.timeLabel(start) + " → " + Self.timeLabel(start + usedSeconds))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            filmstrip
            Text(usedText)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    /// Klibin bu sahnede kullanılacak süresi (hız çarpanıyla).
    private var usedSeconds: Double {
        let wanted = windowDuration * speed
        guard let clipDuration else { return wanted }
        return min(wanted, max(clipDuration - start, 0.1))
    }

    private var usedText: String {
        guard let clipDuration else { return "" }
        if windowDuration * speed > clipDuration - start + 0.05 {
            return String(localized: "Klip bu sahne için kısa: kalan bölüm sahneye yayılacak.")
        }
        return String(localized: "\(Int((clipDuration).rounded())) sn'lik klibin \(Self.timeLabel(start)) anından \(String(format: "%.1f", usedSeconds)) sn'si kullanılacak.")
    }

    /// Şerit: klibin eşit aralıklı kareleri + kullanılacak bölümün penceresi.
    private var filmstrip: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let total = clipDuration ?? 1
            let ratio = min(usedSeconds / max(total, 0.01), 1)
            let windowWidth = max(width * ratio, 28)
            let maxStart = max(total - usedSeconds, 0)
            let x = maxStart > 0 ? (start / maxStart) * (width - windowWidth) : 0
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    if strip.isEmpty {
                        Color.white.opacity(0.08)
                    } else {
                        ForEach(Array(strip.enumerated()), id: \.offset) { _, image in
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width / Double(strip.count))
                                .clipped()
                        }
                    }
                }
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                // Kullanılmayan bölüm karartılır: kullanıcı hangi parçayı
                // aldığını bir bakışta görsün.
                Color.black.opacity(0.55)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .mask {
                        HStack(spacing: 0) {
                            Rectangle().frame(width: x)
                            Color.clear.frame(width: windowWidth)
                            Rectangle()
                        }
                    }
                    .allowsHitTesting(false)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tint, lineWidth: 2.5)
                    .frame(width: windowWidth, height: 52)
                    .offset(x: x)
                    .allowsHitTesting(false)
            }
            .frame(height: 52)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard maxStart > 0, width > windowWidth else { return }
                        // Parmağın altındaki nokta pencerenin MERKEZİ olsun.
                        let centered = value.location.x - windowWidth / 2
                        let ratio = min(max(centered / (width - windowWidth), 0), 1)
                        start = ratio * maxStart
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Klip başlangıcı"))
            .accessibilityValue(Text(Self.timeLabel(start)))
            .accessibilityAdjustableAction { direction in
                let step = max(maxStart / 10, 0.2)
                start = min(max(start + (direction == .increment ? step : -step), 0), maxStart)
            }
        }
        .frame(height: 52)
    }

    // MARK: - Hız

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Hız")
            HStack(spacing: 6) {
                ForEach(EditorView.speedChoices, id: \.self) { value in
                    let selected = abs(speed - value) < 0.001
                    Button {
                        Haptics.select()
                        speed = value
                    } label: {
                        Text(EditorView.speedLabel(value))
                            .font(.system(size: 12, weight: selected ? .bold : .medium))
                            .foregroundStyle(selected ? .black : .white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(selected ? AnyShapeStyle(tint)
                                                 : AnyShapeStyle(.white.opacity(0.09)),
                                        in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Hız videonun süresini değiştirmez; klibin bu sahneye sığdırılan bölümünü değiştirir.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Sıra ve eylemler

    @ViewBuilder private var orderSection: some View {
        if totalSlots > 1, onMoveEarlier != nil || onMoveLater != nil {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Sıra")
                HStack(spacing: 10) {
                    orderButton("Geri al", icon: "arrow.left", action: onMoveEarlier)
                    orderButton("İleri al", icon: "arrow.right", action: onMoveLater)
                }
                Text("Klip \(displayIndex) / \(totalSlots) — medyayla birlikte kadrajı, başlangıcı ve hızı da taşınır")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func orderButton(_ title: String, icon: String,
                             action: (() -> Void)?) -> some View {
        Button {
            Haptics.select()
            action?()
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(.white.opacity(action == nil ? 0.04 : 0.09),
                            in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(action == nil ? .white.opacity(0.25) : .white)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private var actionSection: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap()
                onReplace()
            } label: {
                Label("Medyayı değiştir", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(tint, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.warning()
                onRemove()
                dismiss()
            } label: {
                Label("Bu klibi kaldır", systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
    }

    // MARK: - Medya yükleme

    private func loadMedia() async {
        guard let videoURL else { return }
        let asset = AVURLAsset(url: videoURL)
        clipDuration = try? await asset.load(.duration).seconds
        await loadFrame()
        await loadStrip(asset)
    }

    /// Kadraj alanındaki kare — `start` anından.
    private func loadFrame() async {
        guard let videoURL else { return }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 1280)
        // Tolerans var: kadrajlarken anahtar kareye yuvarlanmak yeterli, kare
        // kare kesinlik için oynatıcı beklemesi gerekiyor.
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.3, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.3, preferredTimescale: 600)
        let time = CMTime(seconds: max(start, 0.05), preferredTimescale: 600)
        if let image = try? await generator.image(at: time).image {
            frame = image
        }
    }

    private func loadStrip(_ asset: AVURLAsset) async {
        guard let total = clipDuration, total > 0 else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 280)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        var images: [CGImage] = []
        let count = 6
        for index in 0..<count {
            let seconds = total * (Double(index) + 0.5) / Double(count)
            if let image = try? await generator.image(
                at: CMTime(seconds: seconds, preferredTimescale: 600)).image {
                images.append(image)
            }
        }
        strip = images
    }

    static func timeLabel(_ seconds: Double) -> String {
        String(format: "%d:%04.1f", Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60))
    }
}
