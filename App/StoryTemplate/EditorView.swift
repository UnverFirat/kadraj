import SwiftUI
import AVKit
import AVFoundation
import CoreGraphics
import ImageIO
import TemplateKit

/// Şablon düzenleme ekranı.
///
/// DÜZEN KARARI: ekranın büyük kısmı ÖNİZLEMEDİR. Eskiden sahne, altındaki
/// dikey form (medya şeridi + müzik satırı + metin alanları) ve sekme çubuğuyla
/// aynı `VStack`'i paylaşıyordu; 9:16 kadraj sıkışıp 430 pt genişliğinde bir
/// ekranda 174 pt'lik bir şeride düşüyor, formun son alanı da eylem çubuğunun
/// altında kalıp ERİŞİLEMEZ oluyordu. Artık:
///
/// - sekme çubuğu bu ekranda gizlenir (`.toolbar(.hidden, for: .tabBar)`),
/// - düzenleme kontrolleri sabit yükseklikli tek bir panelde ve üç sekmede
///   toplanır (Medya / Metin / Müzik) — hepsi aynı anda değil, sırası gelen
///   görünür,
/// - kalan tüm alan sahneye gider.
///
/// Böylece önizleme ~%75 büyür ve hiçbir alan kırpılmaz.
struct EditorView: View {
    let project: DemoProject
    let autoExport: Bool

    @EnvironmentObject var store: Store
    @EnvironmentObject var exports: ExportLibrary
    /// Galeri posteri — boş editörde sahne bunu gösterir (aşağıya bak).
    @EnvironmentObject var thumbnails: ThumbnailStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flow = ExportFlow()
    /// Editördeki oynatılabilir önizleme: motorun kendisiyle küçük çözünürlükte
    /// ön-render (bkz. `ExportFlow.Quality`). Kullanıcının videosuyla aynı
    /// hattan çıkar, yani önizlemede gördüğü kare export'ta da aynıdır.
    @StateObject private var preview = ExportFlow(quality: .preview)
    @State private var previewPlayer: AVPlayer?
    /// Metin/medya/müzik değişti mi — önizleme bayat, yenilenmesi gerek.
    @State private var previewStale = false
    @State private var texts: [String: String]
    /// Güncel medya (başlangıçta boş, kullanıcı galeriden seçer).
    @State private var photos: [Int: CGImage]
    @State private var videos: [Int: URL]
    /// Açık modal. TEK sheet var: aynı view'a birden fazla `.sheet` takmak
    /// SwiftUI'da yanlış içeriği açabiliyor (bir kere müzik seçici, medya
    /// seçicinin yerine açıldı) — hepsi bu enum üzerinden gider.
    @State private var sheet: Sheet?
    /// Seçili müzik (başlangıçta şablonun önerdiği parça).
    @State private var music: TemplateKit.MusicTrack?
    /// Kullanıcının seçtiği vurgu rengi; nil = şablonun kendi rengi.
    @State private var accent: String?
    /// Kullanıcının kendi klibinin sesi kullanılsın mı (müziğin yerine geçer).
    @State private var useOriginalAudio = false
    /// Simulator montaj önizlemesinde müziği ayrıca çalar (bkz. needsAudioOverlay).
    @StateObject private var previewMusic = MusicPreviewPlayer()
    /// Oynatıcı döngüsü için kayıtlı bildirim gözlemcileri (çıkışta silinir).
    @State private var loopTokens: [NSObjectProtocol] = []
    /// Biten export — tam ekran sonuç ekranını açar.
    @State private var result: ExportResult?
    /// Panelde açık olan sekme.
    @State private var panel: Panel = .media
    /// Seçilen dosya okunuyor (iCloud videosu birkaç saniye sürebilir).
    @State private var isImportingMedia = false
    /// Medya alınamadıysa gösterilecek açıklama.
    @State private var mediaError: String?
    @FocusState private var focusedField: String?

    enum Sheet: Identifiable {
        /// Galeri seçici: hangi slot, hangi medya türü.
        case picker(slot: Int, kind: MediaPicker.Kind)
        case music

        var id: String {
            switch self {
            case .picker(let slot, _): return "picker-\(slot)"
            case .music: return "music"
            }
        }
    }

    /// Tam ekran sonuç ekranının girdisi (kalıcı kütüphanedeki dosya).
    struct ExportResult: Identifiable {
        let id = UUID()
        let url: URL
    }

    enum Panel: String, CaseIterable, Identifiable {
        case media, text, color, music
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .media: return "photo.on.rectangle"
            case .text: return "textformat"
            case .color: return "paintpalette"
            case .music: return "music.note"
            }
        }

        var title: String {
            switch self {
            case .media: return String(localized: "Medya")
            case .text: return String(localized: "Metin")
            case .color: return String(localized: "Renk")
            case .music: return String(localized: "Müzik")
            }
        }
    }

    /// Kullanıcının seçebileceği vurgu renkleri. Şablonun KENDİ vurgusu ilk
    /// sırada durur (nil = dokunulmamış); gerisi markasına uydurmak isteyen
    /// esnaf için yaygın bir palet.
    static let accentChoices: [String] = [
        "#FF2E63", "#F2C14E", "#00E5A0", "#6C8CFF",
        "#B06BFF", "#FF7A45", "#2BB3C0", "#FFFFFF",
    ]

    init(project: DemoProject, autoExport: Bool) {
        self.project = project
        self.autoExport = autoExport
        _texts = State(initialValue: project.texts)
        _photos = State(initialValue: project.photoSlots)
        _videos = State(initialValue: project.videoSlots)
        _music = State(initialValue: MusicLibrary.defaultTrack(for: project.template))
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                stage
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .background(Color(hex: project.template.palette["background"] ?? "#0B0B0D"))
                    .overlay { if isImportingMedia { importingBadge } }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                editPanel(height: panelHeight(for: geo.size.height))
                actionBar
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(project.template.name.resolved(languageCode: AppLanguage.code))
        .navigationBarTitleDisplayMode(.inline)
        // Düzenleme bir GÖREV akışıdır: sekme çubuğu hem yer yiyor hem de
        // kullanıcıyı işin ortasında başka yere davet ediyor.
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // Klavyeyi kapatmanın açık bir yolu: panel sabit yükseklikli
            // olduğu için "boşluğa dokun" alanı neredeyse yok.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Bitti") { focusedField = nil }
            }
        }
        .onAppear {
            Analytics.shared.log(.templateOpened(id: project.id,
                                                 isPro: project.template.isPro))
            // Screenshot otomasyonu: PHPicker seçimini taklit et — verilen medyayı
            // ilk slota koyup (kullanıcının galeriden seçmesiyle aynı yol) export et.
            injectMediaIfRequested()
            if autoExport {
                startExport()
            } else if hasMedia, case .idle = preview.phase {
                startPreview()
            }
            if ProcessInfo.processInfo.arguments.contains("--open-picker"),
               let slot = templateSlots.first {
                sheet = .picker(slot: slot, kind: pickerKind(forSlot: slot))
            }
            if ProcessInfo.processInfo.arguments.contains("--open-music") {
                sheet = .music
            }
        }
        // Editöre deep link / doğrudan açılışla gelindiyse poster henüz
        // yüklenmemiş olabilir (galeriden geçilmedi).
        .task {
            if let entry = project.entry { await thumbnails.load(entry) }
        }
        .sheet(item: $sheet) { active in
            switch active {
            case .picker(let slot, let kind):
                MediaPicker(kind: kind,
                            onPick: { picked in
                                isImportingMedia = false
                                assign(picked, toSlot: slot)
                            },
                            onStart: { isImportingMedia = true },
                            onError: {
                                isImportingMedia = false
                                Haptics.error()
                                mediaError = String(localized: "Bu dosya açılamadı. iCloud'daki bir video olabilir — indirilmesini bekleyip tekrar dener misin?")
                            })
                .ignoresSafeArea()
            case .music:
                MusicPicker(selection: $music,
                            duration: project.template.totalDuration,
                            isPro: store.entitlements.isPro,
                            useOriginalAudio: $useOriginalAudio,
                            offersOriginalAudio: !videos.isEmpty,
                            onRequestPro: {
                                sheet = nil
                                store.showPaywall(reason: String(localized: "Bu parça Pro"))
                            })
            }
        }
        // Kütüphaneye ekleme FAZ GEÇİŞİNDE yapılır (önizleme her belirdiğinde
        // değil) — aynı video iki kez "Videolarım"a düşmesin.
        .onChange(of: flow.phase) { _, phase in
            if case .done(let url) = phase {
                previewMusic.stop()
                result = ExportResult(url: register(url))
            }
        }
        .onChange(of: music?.id) { _, id in
            Analytics.shared.log(.musicSelected(trackID: id))
            markDirty()
        }
        .onChange(of: useOriginalAudio) { _, _ in markDirty() }
        .fullScreenCover(item: $result) { finished in
            ExportResultView(
                url: finished.url,
                templateID: project.id,
                duration: project.template.totalDuration,
                accentHex: tintHex,
                showsProUpsell: !store.entitlements.isPro,
                onUpgrade: {
                    closeResult()
                    store.showPaywall(reason: String(localized: "Filigransız dışa aktarım Pro'da"))
                },
                onEditAgain: { closeResult() },
                onNewVideo: {
                    closeResult()
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        dismiss()
                    }
                },
                overlay: { player in
                    if needsTextOverlay {
                        MontagePreviewOverlay(template: project.template,
                                              texts: texts, player: player)
                    }
                })
        }
        .alert(Text("Medya eklenemedi"),
               isPresented: Binding(get: { mediaError != nil },
                                    set: { if !$0 { mediaError = nil } })) {
            Button("Tamam", role: .cancel) { mediaError = nil }
        } message: {
            Text(mediaError ?? "")
        }
        .onDisappear {
            previewMusic.stop()
            loopTokens.forEach(NotificationCenter.default.removeObserver)
            loopTokens = []
        }
    }

    /// Panel yüksekliği ekran boyuna göre. SE gibi kısa cihazlarda panel
    /// küçülür ki sahne tamamen ezilmesin.
    private func panelHeight(for available: CGFloat) -> CGFloat {
        available < 620 ? 148 : 182
    }

    /// Geçici klasördeki export'u kalıcı kütüphaneye alır ve kalıcı dosyayı verir.
    private func register(_ url: URL) -> URL {
        let item = exports.add(videoAt: url,
                               templateID: project.id,
                               templateName: project.template.name.resolved(languageCode: AppLanguage.code),
                               duration: project.template.totalDuration)
        return item.map { exports.videoURL($0) } ?? url
    }

    /// Sonuç ekranını kapatır ve editörü yeniden DÜZENLENEBİLİR hale getirir.
    ///
    /// Eski akışta export bittiğinde `flow.phase` `.done`'da kalıyor, alt
    /// düğmeler kalıcı olarak "Kaydet / Paylaş"a dönüşüyordu: kullanıcı metnini
    /// değiştirse bile videoyu bir daha oluşturamıyordu. Faz burada `.idle`'a
    /// çekilir — video "Videolarım"da duruyor, editör ise açık.
    private func closeResult() {
        result = nil
        flow.phase = .idle
    }

    // MARK: - Düzenleme paneli

    private func editPanel(height: CGFloat) -> some View {
        VStack(spacing: 10) {
            panelTabs
            Group {
                switch panel {
                case .media: mediaPanel
                case .text: textPanel
                case .color: colorPanel
                case .music: musicPanel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: height)
        .padding(.top, 10)
    }

    private var panelTabs: some View {
        HStack(spacing: 5) {
            ForEach(Panel.allCases) { item in
                let selected = panel == item
                Button {
                    Haptics.select()
                    withAnimation(.easeOut(duration: 0.18)) { panel = item }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.icon).font(.system(size: 12, weight: .semibold))
                        // Dört sekme dar ekranda sıkışıyor: etiket asla iki
                        // satıra bölünmemeli, gerekiyorsa küçülsün.
                        Text(item.title)
                            .font(.system(size: 13, weight: selected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                        if item == .media, filledSlotCount > 0 {
                            Text("\(filledSlotCount)/\(templateSlots.count)")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(selected ? Color.black.opacity(0.12)
                                                     : Color.white.opacity(0.14),
                                            in: Capsule())
                        }
                    }
                    .foregroundStyle(selected ? .black : .white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 4)
                    .background(selected ? Color.white : Color.white.opacity(0.08),
                                in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
    }

    // MARK: Medya paneli

    @ViewBuilder private var mediaPanel: some View {
        if !needsMedia {
            panelEmpty(icon: "textformat",
                       message: String(localized: "Bu şablon yazı tabanlı — medya gerekmiyor"))
        } else {
            mediaSlots
        }
    }

    private var mediaSlots: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(templateSlots, id: \.self) { slot in
                        Button {
                            Haptics.tap()
                            sheet = .picker(slot: slot, kind: pickerKind(forSlot: slot))
                        } label: {
                            MediaThumb(url: videos[slot], cgImage: photos[slot],
                                       index: slot, isPhoto: !slotAllowsVideo(slot))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mediaSlotLabel(slot))
                        .accessibilityHint(Text("Fotoğraf veya video seçmek için dokun"))
                    }
                }
                .padding(.horizontal, 20)
            }
            Text(hasMedia
                 ? String(localized: "Değiştirmek için bir kareye dokun")
                 : String(localized: "Kendi fotoğraf ve videolarını ekle"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 20)
        }
    }

    // MARK: Metin paneli

    @ViewBuilder private var textPanel: some View {
        if editableTextKeys.isEmpty {
            panelEmpty(icon: "textformat",
                       message: String(localized: "Bu şablonda düzenlenecek metin yok"))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(editableTextKeys.enumerated()), id: \.element) { index, key in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fieldLabel(key, index: index))
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                            TextField(placeholder(for: key), text: binding(for: key), axis: .vertical)
                                .lineLimit(1...3)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .focused($focusedField, equals: key)
                                .submitLabel(.done)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(.white.opacity(focusedField == key ? 0.14 : 0.08),
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: Renk paneli

    /// Tek dokunuşla renk şeması. Motor paleti ROL üzerinden çözdüğü için
    /// yalnız `accent` rolünü değiştirmek şablondaki tüm vurguları (rozet,
    /// çizgi, fiyat, buton) birlikte döndürür — katman katman renk seçtirmeye
    /// gerek yok.
    private var colorPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    swatch(nil, color: Color(hex: project.accentHex))
                    ForEach(Self.accentChoices, id: \.self) { hex in
                        swatch(hex, color: Color(hex: hex))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            Text("Şablonun tüm vurgu renkleri birlikte değişir")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 20)
        }
    }

    private func swatch(_ hex: String?, color: Color) -> some View {
        let selected = accent == hex
        return Button {
            Haptics.select()
            accent = hex
            markDirty()
        } label: {
            ZStack {
                Circle().fill(color).frame(width: 42, height: 42)
                if hex == nil {
                    // Şablonun kendi rengi: üstünde küçük bir "sıfırla" işareti.
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black.opacity(0.55))
                }
            }
            .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 0))
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: selected ? 0 : 1))
            .padding(3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hex == nil ? Text("Şablonun kendi rengi") : Text("Vurgu rengi"))
    }

    // MARK: Müzik paneli

    private var musicPanel: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.tap()
                sheet = .music
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: useOriginalAudio ? "waveform"
                                      : (music == nil ? "speaker.slash" : "music.quarternote.3"))
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: tintHex))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(useOriginalAudio ? String(localized: "Videonun kendi sesi")
                             : (music?.title.resolved(languageCode: AppLanguage.code)
                                ?? String(localized: "Müziksiz")))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Text(useOriginalAudio
                             ? String(localized: "Çektiğin klibin sesi korunur")
                             : (music.map { $0.mood.label.resolved(languageCode: AppLanguage.code) }
                                ?? String(localized: "Parça seçmek için dokun")))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Text("Değiştir")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: tintHex))
                }
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if music != nil || useOriginalAudio {
                Button {
                    Haptics.tap()
                    music = nil
                    useOriginalAudio = false
                } label: {
                    Label("Sessiz yap", systemImage: "speaker.slash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func panelEmpty(icon: String, message: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.25))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Galeriden seçilen medyayı slota atar; aynı slottaki diğer türü temizler.
    private func assign(_ media: PickedMedia, toSlot slot: Int) {
        let wasEmpty = !hasMedia
        switch media {
        case .photo(let cg):
            photos[slot] = cg
            videos[slot] = nil
            Analytics.shared.log(.mediaPicked(slot: slot, kind: "photo"))
        case .video(let url):
            videos[slot] = url
            photos[slot] = nil
            Analytics.shared.log(.mediaPicked(slot: slot, kind: "video"))
        }
        Haptics.select()
        if wasEmpty {
            // İlk medya: önizlemeyi kendiliğinden üret — kullanıcı seçtiği
            // görüntünün şablonda nasıl durduğunu hemen görsün.
            startPreview()
        } else {
            markDirty()
        }
    }

    /// Slotun kabul ettiği medya türü.
    ///
    /// Şablon `video` dese bile FOTOĞRAF da kabul edilir: motor (hem klasik hat
    /// hem `MontageComposer`) her slotta fotoğrafı destekliyor, ama seçici
    /// yalnız videoları gösterdiği için galerisinde video olmayan kullanıcı
    /// çıkmaz sokağa giriyordu ("Video Yok" ekranı). Yalnız `photo` diyen slot
    /// gerçekten fotoğrafla sınırlıdır (ör. polaroid kartı).
    private func pickerKind(forSlot slot: Int) -> MediaPicker.Kind {
        slotAllowsVideo(slot) ? .any : .photo
    }

    private func slotAllowsVideo(_ slot: Int) -> Bool {
        var kind: MediaKind?
        func scan(_ layers: [Layer]) {
            for layer in layers {
                if case .mediaSlot(let s) = layer.content, s.slotIndex == slot {
                    kind = s.media
                }
            }
        }
        project.template.scenes?.forEach { scan($0.layers) }
        scan(project.template.layers)
        return kind?.allowsVideo ?? true
    }

    // MARK: - Stage (önizleme alanı)

    @ViewBuilder private var stage: some View {
        switch flow.phase {
        case .exporting(let progress):
            VStack(spacing: 16) {
                renderProgress(progress, title: "Video oluşturuluyor")
                // Uzun süren bir işten çıkış yolu her zaman görünür olmalı.
                Button("İptal") { flow.cancel() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(Color(hex: "#F2C14E"))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button { startExport() } label: {
                    Label("Tekrar dene", systemImage: "arrow.clockwise")
                        .modifier(StageBadge())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            previewStage
        }
    }

    /// Editör önizlemesi. Hazır bir ön-render varsa oynatılır (scrub edilebilir);
    /// yoksa şablonun katmanlarından çizilen statik poster gösterilir ve
    /// üstünde onu üretecek düğme durur.
    @ViewBuilder private var previewStage: some View {
        switch preview.phase {
        case .done(let url) where !previewStale:
            Group {
                if let previewPlayer {
                    PlayerScrubView(player: previewPlayer,
                                    duration: project.template.totalDuration,
                                    accentHex: tintHex) {
                        if needsTextOverlay {
                            MontagePreviewOverlay(template: project.template,
                                                  texts: texts, player: previewPlayer)
                        }
                    }
                } else {
                    staticPreview
                }
            }
            .task(id: url) {
                let p = makeLoopingPlayer(url)
                previewPlayer = p
                p.play()
                if needsAudioOverlay, let music {
                    previewMusic.toggle(track: music, duration: project.template.totalDuration)
                }
            }
        case .exporting(let progress):
            renderProgress(progress, title: "Önizleme hazırlanıyor")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            ZStack {
                staticPreview
                if needsMedia, !hasMedia { emptyStageScrim }
                previewButton
            }
        }
    }

    /// Sahnenin hareketsiz hali.
    ///
    /// Kullanıcı medyasını seçmeden ÖNCE galeri posteri gösterilir: kartta
    /// gördüğü görselin aynısı. Eskiden burada şablonun katmanları boş
    /// slotlarla çiziliyordu ve çoğu montaj şablonunda ortaya bomboş bir
    /// gradyan çıkıyordu — kullanıcı galeride güzel bir kart görüp dokununca
    /// boş bir dikdörtgenle karşılaşıyordu. Poster, kartın verdiği sözü
    /// editörde de tutar.
    ///
    /// Medya seçildiği anda `TemplatePreview`'a geçilir; artık kullanıcının
    /// kendi görüntüsü şablonun içinde görünür.
    @ViewBuilder private var staticPreview: some View {
        if needsMedia, !hasMedia, let entry = project.entry,
           let poster = thumbnails.image(for: entry) {
            Image(decorative: poster, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            TemplatePreview(template: project.template, texts: texts,
                            photos: photos, videos: videos,
                            // Boş projede montajın SON sahnesi çoğu şablonda
                            // yalnız kapanış yazısı taşıyor; ilk sahne düzeni
                            // daha iyi anlatır.
                            progress: hasMedia ? 0.75 : 0.15,
                            accentOverride: accent)
        }
    }

    /// Boş projede sahnenin üstüne hafif bir karartma: altındaki şablon düzeni
    /// görünür kalır (kullanıcı ne alacağını görsün) ama tek eylem — medya
    /// eklemek — öne çıkar.
    /// Seçilen dosya okunurken sahnenin üstünde duran rozet. Büyük bir iCloud
    /// videosunda bu adım saniyeler sürebiliyor ve o sırada ekranda hiçbir
    /// şeyin değişmemesi "dokundum, olmadı" hissi veriyordu.
    private var importingBadge: some View {
        ZStack {
            Color.black.opacity(0.45)
            HStack(spacing: 9) {
                ProgressView().tint(.white)
                Text("Medya alınıyor…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(.black.opacity(0.6), in: Capsule())
        }
        .transition(.opacity)
    }

    private var emptyStageScrim: some View {
        LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.55)],
                       startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }

    /// Statik posterin üstündeki oynat/yenile düğmesi. "Yenile" metni, önizleme
    /// bir kez üretildikten sonra metin/medya değişince çıkar — kullanıcı
    /// gördüğü karenin bayat olduğunu bilmeli.
    @ViewBuilder private var previewButton: some View {
        if canExport {
            Button {
                Haptics.tap()
                startPreview()
            } label: {
                Label(previewStale ? "Önizlemeyi yenile" : "Önizle",
                      systemImage: previewStale ? "arrow.clockwise" : "play.fill")
                    .modifier(StageBadge())
            }
            .buttonStyle(.plain)
        } else if let first = templateSlots.first {
            VStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    sheet = .picker(slot: first, kind: pickerKind(forSlot: first))
                } label: {
                    Label("Medya ekle", systemImage: "photo.badge.plus")
                        .modifier(StageBadge())
                }
                .buttonStyle(.plain)
                Text("Fotoğrafın şablona yerleşsin")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    /// Sahne alanı 9:16 sabittir; ilerleme/hata içerikleri de o kadrajı
    /// DOLDURMALI, yoksa çerçeve içeriğe göre büzülüp düzen zıplıyor.
    private func renderProgress(_ progress: Double, title: String) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color(hex: tintHex))
                .frame(width: 180)
            // Yüzde biçimi dile göre değişiyor ("%39" / "39%") — formatter
            // bunu locale'den alsın.
            Text("\(title)… \(progress.formatted(.percent.precision(.fractionLength(0))))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    /// Döngüye alınmış oynatıcı. Bildirim kaydı tutulur (`loopTokens`) — her
    /// önizleme yenilemesinde yeni bir item gelir, eskisinin gözlemcisi
    /// bırakılırsa birikir.
    private func makeLoopingPlayer(_ url: URL) -> AVPlayer {
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none
        let token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem, queue: .main) { _ in
                player.seek(to: .zero)
                player.play()
            }
        loopTokens.append(token)
        return player
    }

    /// Önizlemeyi (yeniden) üretir. Kullanıcının videosuyla aynı hat, yalnız
    /// küçük kadraj — bkz. `ExportFlow.Quality.preview`.
    private func startPreview() {
        previewMusic.stop()
        previewPlayer = nil
        previewStale = false
        preview.run(project: project, texts: texts, photos: photos, videos: videos,
                    music: music, entitlements: store.entitlements,
                    accentOverride: accent,
                    originalAudioFrom: originalAudioSource)
    }

    /// Girdi değişti: eldeki ön-render artık ekrandakini göstermiyor.
    private func markDirty() {
        guard case .done = preview.phase else { return }
        previewStale = true
        previewPlayer = nil
        previewMusic.stop()
    }

    // MARK: - Alt aksiyon çubuğu

    private var actionBar: some View {
        VStack(spacing: 8) {
            // Ücretsiz kullanıcıya filigranı export'tan ÖNCE söyle (sürpriz olmasın).
            if !store.entitlements.isPro {
                Button {
                    Haptics.tap()
                    store.showPaywall(reason: String(localized: "Filigransız dışa aktarım Pro'da"))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill").font(.system(size: 10))
                        Text("Filigranlı").font(.system(size: 11, weight: .medium))
                        Text("· Kaldır")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "#F2C14E"))
                    }
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            primaryButton
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    /// Tek birincil eylem. Medya yokken DEVRE DIŞI bir düğme göstermek yerine
    /// (ekranın en dikkat çeken öğesine dokunup hiçbir şey olmaması kötü bir
    /// his) düğme kullanıcıyı eksik olan adıma götürür.
    private var primaryButton: some View {
        Button {
            if canExport {
                Haptics.tap()
                startExport()
            } else if let first = templateSlots.first {
                Haptics.tap()
                panel = .media
                sheet = .picker(slot: first, kind: pickerKind(forSlot: first))
            }
        } label: {
            Label(canExport ? "Video Oluştur" : "Fotoğraf / video ekle",
                  systemImage: canExport ? "sparkles" : "photo.badge.plus")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 15)
        }
        .background(Color(hex: tintHex), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.black)
        .disabled(isExporting)
        .opacity(isExporting ? 0.45 : 1)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

        /// Orijinal ses seçiliyse hangi klipten alınacağı (ilk video slotu).
    private var originalAudioSource: URL? {
        guard useOriginalAudio else { return nil }
        return videos.sorted { $0.key < $1.key }.first?.value
    }

    /// Arayüzün vurgu rengi: kullanıcı seçtiyse onunki, yoksa şablonunki.
    private var tintHex: String { accent ?? project.accentHex }

    private var isExporting: Bool {
        if case .exporting = flow.phase { return true }; return false
    }

    /// Kullanıcı en az bir slota kendi medyasını koydu mu.
    private var hasMedia: Bool { !photos.isEmpty || !videos.isEmpty }

    /// Şablon MEDYA İSTİYOR mu? 17 şablon (alıntı kartı, liste, geri sayım,
    /// tebrik…) saf tipografidir ve hiç slotu yoktur. Bunlarda "önce medya seç"
    /// akışı anlamsız — üstelik düğme hiçbir şey yapmıyordu, çünkü
    /// dokunulduğunda açılacak bir slot yok.
    private var needsMedia: Bool { !templateSlots.isEmpty }

    /// Video oluşturulabilir mi: ya şablon medya istemiyor ya da kullanıcı koydu.
    private var canExport: Bool { !needsMedia || hasMedia }

    private var filledSlotCount: Int {
        templateSlots.filter { photos[$0] != nil || videos[$0] != nil }.count
    }

    /// Simulator'da montaj çıktısı metinsiz kolaj videosudur → metni canlı
    /// bindir. Cihazda tam export metni gömer → overlay gerekmez.
    private var needsTextOverlay: Bool {
        #if targetEnvironment(simulator)
        return project.isMontage
        #else
        return false
        #endif
    }

    /// Simulator montaj çıktısı yalnız 1. geçiş videosudur (ses track'i yok) →
    /// önizlemede müziği ayrıca çal. Cihazda müzik export'a gömülür.
    private var needsAudioOverlay: Bool { needsTextOverlay }

    private func startExport() {
        previewMusic.stop()
        flow.run(project: project, texts: texts, photos: photos, videos: videos,
                 music: music, entitlements: store.entitlements,
                 accentOverride: accent,
                 originalAudioFrom: originalAudioSource)
    }

    /// --inject-media ile PHPicker seçimini programatik taklit eder: belirgin
    /// bir test fotosunu tüm slotlara koyar (assign() ile aynı yol). Böylece
    /// "kullanıcı kendi medyasını seçti → export onu kullandı" akışı screenshot'la
    /// doğrulanabilir (gerçek galeri dokunuşu simctl'de otomatikleştirilemiyor).
    private func injectMediaIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--inject-media"),
              let cg = EditorView.injectedTestPhoto() else { return }
        for slot in templateSlots { assign(.photo(cg), toSlot: slot) }
    }

    /// `--inject-media [yol]`: yol verilmişse GERÇEK bir görüntü dosyası okunur
    /// (ör. `simctl` ile uygulama kabına kopyalanmış bir fotoğraf), yoksa
    /// sentetik gradyan. Gerçek fotoğrafla test etmek şart: sentetik görüntü
    /// tasarımı düzleştiriyor ve "boş/yanlış kadraj" hataları görünmez oluyor.
    private static func injectedTestPhoto() -> CGImage? {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--inject-media"),
           arguments.index(after: index) < arguments.endIndex {
            let path = arguments[arguments.index(after: index)]
            if !path.hasPrefix("--"),
               let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return image
            }
        }
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: 1080, height: 1350,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let g = CGGradient(colorsSpace: cs, colors: [
            CGColor(srgbRed: 0.18, green: 0.72, blue: 0.52, alpha: 1),
            CGColor(srgbRed: 0.10, green: 0.30, blue: 0.62, alpha: 1)] as CFArray,
            locations: [0, 1])!
        ctx.drawLinearGradient(g, start: .zero,
                               end: CGPoint(x: 1080, y: 1350), options: [])
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95))
        ctx.fillEllipse(in: CGRect(x: 390, y: 540, width: 300, height: 300))
        return ctx.makeImage()
    }

    /// VoiceOver: slotun kaçıncı olduğu ve dolu mu boş mu.
    private func mediaSlotLabel(_ slot: Int) -> Text {
        if videos[slot] != nil { return Text("Medya \(slot + 1), video seçili") }
        if photos[slot] != nil { return Text("Medya \(slot + 1), fotoğraf seçili") }
        return Text("Medya \(slot + 1), boş")
    }

    /// Şablondaki tüm medya slot indeksleri (sahne + global), sıralı ve tekil.
    private var templateSlots: [Int] {
        var set = Set<Int>()
        func scan(_ layers: [Layer]) {
            for layer in layers {
                if case .mediaSlot(let s) = layer.content { set.insert(s.slotIndex) }
            }
        }
        project.template.scenes?.forEach { scan($0.layers) }
        scan(project.template.layers)
        return set.sorted()
    }

    private var editableTextKeys: [String] {
        // Şablon katman sırasına göre metin katmanları.
        var keys: [String] = []
        func scan(_ layers: [Layer]) {
            for layer in layers {
                if case .text = layer.content, texts[layer.id] != nil { keys.append(layer.id) }
            }
        }
        project.template.scenes?.forEach { scan($0.layers) }
        scan(project.template.layers)
        return keys.isEmpty ? Array(texts.keys).sorted() : keys
    }

    private func fieldLabel(_ key: String, index: Int) -> String {
        TextFieldLabels.label(forLayerID: key, fallbackIndex: index)
    }

    /// Alanın yer tutucusu: şablonun kendi varsayılan metni. Kullanıcı alanı
    /// tamamen silerse ne yazılabileceğini yine görür.
    private func placeholder(for key: String) -> String {
        project.texts[key] ?? ""
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { texts[key] ?? "" },
                set: { newValue in
                    texts[key] = newValue
                    // Metin her tuşta yeniden render EDİLMEZ (her karakterde
                    // saniyeler süren bir render kabul edilemez); önizleme
                    // bayat işaretlenir, kullanıcı hazır olunca yeniler.
                    // Statik poster ise anında güncellenir.
                    markDirty()
                })
    }
}

/// Sahnenin üstündeki eylem rozetinin ortak görünümü.
private struct StageBadge: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.black.opacity(0.55), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            .foregroundStyle(.white)
    }
}

struct MediaThumb: View {
    var url: URL?
    var cgImage: CGImage?
    var index: Int
    var isPhoto: Bool = false
    @State private var image: Image?

    private let size = CGSize(width: 64, height: 88)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.1))
                .frame(width: size.width, height: size.height)
            // Foto doğrudan çizilir (prop değişince anında güncellenir); video
            // thumbnail'i asenkron üretilip `image` state'ine yazılır.
            if let cgImage {
                filled(Image(decorative: cgImage, scale: 1))
            } else if let image {
                filled(image)
            } else {
                // Boş slot: eklenecek yer olduğu bakışta anlaşılsın diye
                // kesikli çerçeve + artı.
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: isPhoto ? "photo" : "video")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: size.width, height: size.height)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold))
                .padding(4).background(.black.opacity(0.6), in: Circle())
                .padding(4)
        }
        // Video URL'i değişince thumbnail'i yeniden üret.
        .task(id: url) {
            guard cgImage == nil, let url else { return }
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            if let cg = try? gen.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600),
                                             actualTime: nil) {
                image = Image(decorative: cg, scale: 1)
            }
        }
    }

    /// Dolu slot: küçük bir "değiştir" işareti taşır — aksi halde seçilmiş
    /// kare, dokunulabilir olduğunu hiç belli etmiyor.
    private func filled(_ image: Image) -> some View {
        image.resizable().aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.black.opacity(0.55), in: Circle())
                    .padding(3)
            }
    }
}
