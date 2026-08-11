import SwiftUI
import AVFoundation
import TemplateKit

/// "Videon hazır" ekranı — uygulamanın ÖDÜL anı.
///
/// Neden ayrı bir tam ekran: eskiden export bitince editörün küçük 9:16 sahnesi
/// sessizce oynayan videoya dönüşüyor, altındaki düğmeler "Kaydet / Paylaş"
/// oluyordu. Kullanıcının emek verdiği iş bittiğinde ekranda hiçbir şey
/// "oldu!" demiyordu; üstelik video, düzenleme alanlarıyla aynı ekranı
/// paylaştığı için küçücük kalıyordu. Burada video tüm ekranı alır, tek bir
/// onay cümlesi ve iki net eylem vardır.
///
/// Ekran KAPANDIĞINDA editör `.idle`'a döner (bkz. `EditorView.dismissResult`) —
/// böylece kullanıcı metnini değiştirip videoyu yeniden oluşturabilir. Eski
/// akışta export'tan sonra "Video Oluştur" düğmesi kaybolduğu için düzenlemeye
/// devam eden kullanıcı kilitleniyordu.
struct ExportResultView<Overlay: View>: View {
    let url: URL
    let templateID: String
    let duration: Double
    let accentHex: String
    /// Ücretsiz kullanıcıya filigranı kaldırma yolu burada da açık dursun.
    let showsProUpsell: Bool
    let onUpgrade: () -> Void
    let onEditAgain: () -> Void
    let onNewVideo: () -> Void
    /// Videonun üstüne canlı çizilecek katman (simulator montaj önizlemesinde
    /// metin overlay'i). Oynatıcıyı bu ekran kurduğu için closure'a o verilir.
    @ViewBuilder var overlay: (AVPlayer) -> Overlay

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var loopToken: NSObjectProtocol?
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var savedToPhotos = false
    @State private var showShare = false
    /// Başlık ve düğmeler videodan sonra belirsin — anı bir "sonuç" gibi
    /// göstermenin en ucuz yolu.
    @State private var revealed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                banner
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : -8)

                Group {
                    if let player {
                        PlayerScrubView(player: player, duration: duration,
                                        accentHex: accentHex) { overlay(player) }
                    } else {
                        Color.black
                    }
                }
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxHeight: .infinity)

                if let saveMessage {
                    Text(saveMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                actions
                    .opacity(revealed ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShare) { ShareSheet(items: [url]) }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    // MARK: - Parçalar

    private var banner: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 19))
                .foregroundStyle(Color(hex: accentHex))
            VStack(alignment: .leading, spacing: 1) {
                Text("Videon hazır")
                    .font(.system(size: 17, weight: .bold))
                Text("Videolarım'a kaydedildi")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
        .padding(.trailing, 52)   // sağ üstteki kapatma düğmesine yer
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { save() } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Label(savedToPhotos ? "Kaydedildi" : "Kaydet",
                                  systemImage: savedToPhotos
                                    ? "checkmark" : "square.and.arrow.down")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                }
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .disabled(isSaving)

                Button {
                    Haptics.tap()
                    Analytics.shared.log(.videoShared(templateID: templateID))
                    showShare = true
                } label: {
                    Label("Paylaş", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                }
                .background(Color(hex: accentHex), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.black)
            }

            if showsProUpsell {
                // Filigranı kaldırmanın en doğal anı: kullanıcı filigranlı
                // videosunu ilk kez tam ekran gördüğü an.
                Button {
                    Haptics.tap()
                    onUpgrade()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "crown.fill").font(.system(size: 11))
                        Text("Filigranı kaldır").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "#F2C14E"))
                    .padding(.vertical, 8).padding(.horizontal, 16)
                    .background(Color(hex: "#F2C14E").opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // MÜZİK İPUCU. Üçüncü parti bir editör kullanıcıya popüler şarkı
            // VEREMEZ: o lisans Instagram/TikTok'a aittir ve yalnız kendi
            // platformlarında çalınırken geçerlidir. Ama kullanıcı videoyu
            // oraya yükledikten SONRA lisanslı şarkıyı kendisi ekleyebilir —
            // erişebileceği en iyi müzik bu. Rakiplerin çoğu bunu söylemiyor.
            HStack(spacing: 7) {
                Image(systemName: "music.note").font(.system(size: 10))
                Text("İstediğin şarkıyı Instagram veya TikTok'a yükledikten sonra ekleyebilirsin")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 8)

            HStack(spacing: 20) {
                Button {
                    Haptics.tap()
                    onEditAgain()
                } label: {
                    Label("Düzenlemeye dön", systemImage: "slider.horizontal.3")
                }
                Button {
                    Haptics.tap()
                    onNewVideo()
                } label: {
                    Label("Yeni video", systemImage: "square.grid.2x2")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .buttonStyle(.plain)
        }
    }

    private var closeButton: some View {
        Button {
            Haptics.tap()
            onEditAgain()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Kapat"))
        .padding(.trailing, 18)
        .padding(.top, 10)
    }

    // MARK: - Oynatma / kaydetme

    private func start() {
        let item = AVPlayer(url: url)
        item.actionAtItemEnd = .none
        loopToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item.currentItem, queue: .main) { _ in
                item.seek(to: .zero)
                item.play()
            }
        player = item
        item.play()
        Haptics.success()
        withAnimation(.easeOut(duration: 0.35).delay(0.1)) { revealed = true }
    }

    private func stop() {
        player?.pause()
        if let loopToken { NotificationCenter.default.removeObserver(loopToken) }
        loopToken = nil
    }

    private func save() {
        isSaving = true
        saveMessage = nil
        Task {
            let outcome = await PhotoSaver.save(videoAt: url)
            isSaving = false
            savedToPhotos = outcome == .saved
            outcome == .saved ? Haptics.success() : Haptics.warning()
            withAnimation { saveMessage = PhotoSaver.message(for: outcome) }
        }
    }
}

extension ExportResultView where Overlay == EmptyView {
    init(url: URL, templateID: String, duration: Double, accentHex: String,
         showsProUpsell: Bool, onUpgrade: @escaping () -> Void,
         onEditAgain: @escaping () -> Void, onNewVideo: @escaping () -> Void) {
        self.init(url: url, templateID: templateID, duration: duration, accentHex: accentHex,
                  showsProUpsell: showsProUpsell, onUpgrade: onUpgrade,
                  onEditAgain: onEditAgain, onNewVideo: onNewVideo) { _ in EmptyView() }
    }
}
