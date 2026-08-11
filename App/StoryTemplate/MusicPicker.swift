import SwiftUI
import AVFoundation
import TemplateKit

/// Müzik seçici: kütüphanedeki parçalar ruh haline göre gruplu, dokununca
/// çalar (sentez + cache), seç dediğinde export bu parçayı kullanır.
///
/// Parçalar telifsiz — dosya indirilmez, `MusicLibrary` tarifinden çalışma
/// anında üretilir (bkz. TemplateKit/Audio).
struct MusicPicker: View {
    /// Seçili parça (nil = müziksiz).
    @Binding var selection: TemplateKit.MusicTrack?
    /// Önizleme/parça uzunluğu — şablonun süresi.
    let duration: Double
    /// Pro parçalar kilitli mi (paywall bağlanınca entitlement'tan gelir).
    let isPro: Bool
    /// Kullanıcının videosunun kendi sesi kullanılsın mı.
    @Binding var useOriginalAudio: Bool
    /// Kullanıcı en az bir VİDEO seçtiyse bu seçenek gösterilir (fotoğrafın
    /// sesi olmaz).
    var offersOriginalAudio: Bool = false
    var onRequestPro: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var preview = MusicPreviewPlayer()

    private var moods: [TemplateKit.MusicTrack.Mood] {
        TemplateKit.MusicTrack.Mood.allCases.filter { !MusicLibrary.tracks(mood: $0).isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if offersOriginalAudio { originalAudioRow }
                    silentRow
                }
                ForEach(moods, id: \.self) { mood in
                    Section(mood.label.resolved(languageCode: AppLanguage.code)) {
                        ForEach(MusicLibrary.tracks(mood: mood)) { track in
                            trackRow(track)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Müzik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { preview.stop(); dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { preview.stop() }
    }

    /// Kullanıcının kendi klibinin sesi. Instagram/TikTok'a yüklenecek bir
    /// videoda en doğal ses çoğu zaman budur — üstelik telif sorunu yok.
    private var originalAudioRow: some View {
        Button {
            Haptics.select()
            preview.stop()
            selection = nil
            useOriginalAudio = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .frame(width: 30)
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Videonun kendi sesi").font(.system(size: 16, weight: .medium))
                    Text("Çektiğin klibin sesi korunur")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                if useOriginalAudio { checkmark }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var silentRow: some View {
        Button {
            Haptics.select()
            preview.stop()
            selection = nil
            useOriginalAudio = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "speaker.slash")
                    .frame(width: 30)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Müziksiz").font(.system(size: 16, weight: .medium))
                    Text("Sessiz video").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                if selection == nil, !useOriginalAudio { checkmark }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Parça satırı.
    ///
    /// Dinlemek ve SEÇMEK ayrı eylemler: eskiden satıra dokunmak ikisini
    /// birden yapıyordu, yani "acaba nasıl bir şey" diye merak eden kullanıcı
    /// istemeden seçimini de değiştiriyordu. Soldaki düğme yalnız çalar,
    /// satırın geri kalanı seçer.
    private func trackRow(_ track: TemplateKit.MusicTrack) -> some View {
        let locked = track.isPro && !isPro
        let playing = preview.playingID == track.id
        return HStack(spacing: 12) {
            Button {
                guard !locked else { return onRequestPro() }
                Haptics.tap()
                preview.toggle(track: track, duration: duration)
            } label: {
                Image(systemName: locked ? "lock.fill"
                                 : (playing ? "pause.fill" : "play.fill"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(locked ? .secondary : .primary)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(playing ? 0.22 : 0.1), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playing ? Text("Duraklat") : Text("Dinle"))

            Button {
                guard !locked else { return onRequestPro() }
                Haptics.select()
                useOriginalAudio = false
                selection = track
                if !playing { preview.toggle(track: track, duration: duration) }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title.resolved(languageCode: AppLanguage.code))
                            .font(.system(size: 16, weight: .medium))
                        // "116 BPM" bir üretici terimi; kullanıcı parçanın
                        // hızlı mı yavaş mı olduğunu bilmek ister.
                        Text(Self.tempoLabel(bpm: track.bpm) + (locked ? " · Pro" : ""))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selection?.id == track.id, !useOriginalAudio { checkmark }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var checkmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
    }

    /// BPM → hız kelimesi.
    private static func tempoLabel(bpm: Int) -> String {
        switch bpm {
        case ..<76: return String(localized: "Çok sakin")
        case 76..<96: return String(localized: "Yavaş")
        case 96..<116: return String(localized: "Orta tempo")
        default: return String(localized: "Hareketli")
        }
    }
}

/// Seçici içindeki dinleme oynatıcısı. Parçayı dosyaya alır (cache) ve döngüde
/// çalar; ikinci dokunuş durdurur.
@MainActor
final class MusicPreviewPlayer: ObservableObject {
    @Published private(set) var playingID: String?
    private var player: AVAudioPlayer?

    func toggle(track: TemplateKit.MusicTrack, duration: Double) {
        if playingID == track.id { return stop() }
        stop()
        guard let url = ExportFlow.musicURL(track: track, duration: max(6, duration)),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.play()
        self.player = player
        playingID = track.id
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }
}
