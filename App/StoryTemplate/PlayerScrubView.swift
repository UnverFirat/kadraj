import SwiftUI
import AVFoundation
import TemplateKit

/// Video oynatıcı + **scrub çubuğu**: oynat/duraklat, kareye gitme, süre.
///
/// Neden AVKit'in `VideoPlayer`'ı değil: onun kendi kontrol katmanı var, üstüne
/// bindirilen şablon katmanlarını (montaj önizlemesi) yutuyor ve tam ekran
/// düğmesi editörün akışını bozuyor. Burada yalnız `AVPlayerLayer` var, kontrol
/// bizim — böylece overlay ve scrub aynı koordinat düzleminde kalıyor.
///
/// Scrub sırasında `seek` **tolerance sıfır** ile yapılır: şablon videoları
/// kısa (5-15 sn) ve kullanıcı belirli bir ANI arıyor; anahtar kareye yuvarlanan
/// seek "çubuğu oynattım ama görüntü değişmedi" hissi veriyordu.
struct PlayerScrubView<Overlay: View>: View {
    let player: AVPlayer
    /// Şablon süresi (saniye) — asset yüklenmeden çubuğu çizebilmek için.
    let duration: Double
    var accentHex: String = "#D9A441"
    @ViewBuilder var overlay: () -> Overlay

    @State private var time: Double = 0
    @State private var isPlaying = true
    @State private var isScrubbing = false
    @State private var observer: Any?
    /// Kontroller görünür mü. Oynatırken kısa süre sonra solar.
    @State private var controlsVisible = true
    /// Solma zamanlayıcısı — her etkileşimde sıfırlanır.
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            PlayerLayerView(player: player)
                .contentShape(Rectangle())
                .onTapGesture { togglePlayback() }
            overlay()
                .allowsHitTesting(false)
            // Kontroller kadrajın İÇİNE bindirilir: editörde sahne alanı 9:16
            // sabit, kontroller altına ayrı bir satır olarak konunca videoyu
            // eziyor ve şablon küçücük kalıyordu.
            //
            // İÇERİDE olduğu için de kalıcı DURAMAZLAR: videonun sağ alt
            // köşesindeki filigranın (ve şablonun kendi alt yazılarının)
            // üstüne biniyorlar. Oynatma başlayınca solar, dokununca ya da
            // duraklatınca geri gelirler — kullanıcının asıl bakmak istediği
            // şey videonun kendisi.
            controls
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                        .padding(.top, -26)
                        .allowsHitTesting(false)
                )
                .opacity(controlsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: controlsVisible)
                .allowsHitTesting(controlsVisible)
        }
        .onAppear {
            startObserving()
            scheduleHide()
        }
        .onDisappear {
            stopObserving()
            hideTask?.cancel()
        }
    }

    /// Oynatma sürerken kontrolleri belirli bir süre sonra gizler. Duraklamış,
    /// scrub ediliyor ya da kullanıcı yeni dokunmuşsa gizlenmez.
    private func scheduleHide() {
        hideTask?.cancel()
        guard isPlaying else { return }
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled, isPlaying, !isScrubbing else { return }
            controlsVisible = false
        }
    }

    private func revealControls() {
        controlsVisible = true
        scheduleHide()
    }

    // MARK: Kontroller

    private var controls: some View {
        HStack(spacing: 10) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .accessibilityHidden(true)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(.black.opacity(0.45), in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? Text("Duraklat") : Text("Oynat"))

            scrubBar

            Text("\(Self.timeLabel(time)) / \(Self.timeLabel(duration))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .monospacedDigit()
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var scrubBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = duration > 0 ? min(max(time / duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15)).frame(height: 4)
                Capsule().fill(Color(hex: accentHex))
                    .frame(width: width * fraction, height: 4)
                Circle()
                    .fill(.white)
                    .frame(width: isScrubbing ? 16 : 11, height: isScrubbing ? 16 : 11)
                    .offset(x: width * fraction - (isScrubbing ? 8 : 5.5))
            }
            .frame(height: 30)
            .contentShape(Rectangle())
            // Basılı tutup sürükleme: parmağın altındaki oran doğrudan zaman.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isScrubbing {
                            isScrubbing = true
                            player.pause()
                            hideTask?.cancel()
                        }
                        let ratio = min(max(value.location.x / width, 0), 1)
                        time = ratio * duration
                        seek(to: time)
                    }
                    .onEnded { _ in
                        isScrubbing = false
                        if isPlaying { player.play() }
                        scheduleHide()
                    }
            )
            .animation(.easeOut(duration: 0.12), value: isScrubbing)
            // VoiceOver: çubuk bir "ayarlanabilir" öğe olur, yukarı/aşağı
            // kaydırmayla saniye saniye gezilir.
            .accessibilityElement()
            .accessibilityLabel(Text("Video konumu"))
            .accessibilityValue(Text(Self.timeLabel(time)))
            .accessibilityAdjustableAction { direction in
                let step = max(duration / 20, 0.5)
                let target = direction == .increment ? time + step : time - step
                time = min(max(target, 0), duration)
                seek(to: time)
            }
        }
        .frame(height: 30)
    }

    // MARK: Oynatma

    /// Kadraja dokunma: kontroller gizliyse önce onları geri getirir (video
    /// yanlışlıkla durmasın), görünürse oynatmayı değiştirir.
    private func togglePlayback() {
        guard controlsVisible else { return revealControls() }
        isPlaying.toggle()
        isPlaying ? player.play() : player.pause()
        isPlaying ? scheduleHide() : hideTask?.cancel()
    }

    private func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Çubuğu oynatmayla eşler. Scrub sırasında güncelleme YAPILMAZ — yoksa
    /// oynatıcının bir önceki zamanı parmağın altındaki değeri geri çekiyor.
    private func startObserving() {
        guard observer == nil else { return }
        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main) { current in
                guard !isScrubbing else { return }
                time = current.seconds
            }
    }

    private func stopObserving() {
        if let observer { player.removeTimeObserver(observer) }
        observer = nil
    }

    static func timeLabel(_ seconds: Double) -> String {
        let total = max(0, seconds)
        return String(format: "%d:%02d", Int(total) / 60, Int(total) % 60)
    }
}

extension PlayerScrubView where Overlay == EmptyView {
    init(player: AVPlayer, duration: Double, accentHex: String = "#D9A441") {
        self.init(player: player, duration: duration, accentHex: accentHex) { EmptyView() }
    }
}

/// Çıplak `AVPlayerLayer` — kontrolsüz, kenarlıksız, tam kadraj.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: PlayerHostView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
    }

    /// `layerClass` ile katman doğrudan view'ın kendisi olur — ayrı bir sublayer
    /// tutup `layoutSubviews`'ta boyut kovalamak gerekmez (döndürmede/klavye
    /// açılışında katman geride kalıyordu).
    final class PlayerHostView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
