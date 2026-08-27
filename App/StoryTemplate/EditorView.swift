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
    /// Yarım kalmış işler — bu ekran hem okur (devam) hem yazar (çıkışta).
    @EnvironmentObject var drafts: DraftStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var flow = ExportFlow()
    /// Editördeki oynatılabilir önizleme: motorun kendisiyle küçük çözünürlükte
    /// ön-render (bkz. `ExportFlow.Quality`). Kullanıcının videosuyla aynı
    /// hattan çıkar, yani önizlemede gördüğü kare export'ta da aynıdır.
    @StateObject private var preview = ExportFlow(quality: .preview)
    @State private var previewPlayer: AVPlayer?
    /// Ekranda oynayan önizleme dosyası. Faz `.done` olduğunda güncellenir;
    /// oynatıcı buna göre kurulur (bkz. previewStage).
    @State private var previewURL: URL?
    /// Otomatik yenileme için bekleyen iş (her değişiklikte sıfırlanır).
    /// Metin/medya/müzik değişti mi — önizleme bayat, yenilenmesi gerek.
    @State private var previewStale = false
    @State private var texts: [String: String]
    /// Güncel medya (başlangıçta boş, kullanıcı galeriden seçer).
    @State private var photos: [Int: CGImage]
    @State private var videos: [Int: URL]
    /// slotIndex -> klip hız çarpanı (kayıt yoksa 1). Yalnız VİDEO slotlarında
    /// anlamlı; şablonun süresini değiştirmez (bkz. `SlotAssignment.speed`).
    @State private var speeds: [Int: Double] = [:]
    /// slotIndex -> kullanıcı kadrajı (yakınlaştır/kaydır). Motor bu alanı ta
    /// başından okuyordu, arayüzde karşılığı yoktu: dikey olmayan her medya
    /// merkeze göre kırpılıyor ve kullanıcının öznesi kadraj dışında kalıyordu.
    @State private var crops: [Int: CropTransform] = [:]
    /// slotIndex -> klibin hangi saniyesinden başlanacağı (trim).
    @State private var starts: [Int: Double] = [:]
    /// Katman id -> metin stili (boyut/renk/yazı tipi). Şablonun tipografisi
    /// varsayılan; burada yalnız kullanıcının dokunduğu alan durur.
    @State private var textStyles: [String: TextStyleOverride] = [:]
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
    /// Bu export BAŞLARKEN bir kerelik ücretsiz hak duruyor muydu.
    ///
    /// Filigran kararı export başlarken veriliyor (motora o an geçiyor); hak
    /// ise bitişte tükeniyor. Sonuç ekranı da başlangıçtaki durumu anlatmalı,
    /// yoksa "hediye" mesajı kendi tükettiği hakkın ardından kaybolurdu.
    @State private var usedFirstFreeExport = false
    /// Panelde açık olan sekme.
    @State private var panel: Panel = .media
    /// Seçilen dosya okunuyor (iCloud videosu birkaç saniye sürebilir).
    @State private var isImportingMedia = false
    /// Medya alınamadıysa gösterilecek açıklama.
    @State private var mediaError: String?
    /// Bu oturum bir TASLAKTAN açıldı mı (kullanıcıya söylenmeli: alanların
    /// neden dolu olduğu açıklanmazsa "uygulama benim adıma bir şey mi yaptı"
    /// hissi veriyor).
    @State private var restoredDraft = false
    @FocusState private var focusedField: String?

    enum Sheet: Identifiable {
        /// Galeri seçici: hangi slottan başlanacağı, medya türü ve kaç medya
        /// birden seçilebileceği (1 = tek slot düzenleme).
        case picker(slot: Int, kind: MediaPicker.Kind, limit: Int)
        /// Dolu bir slotun ayarları: kadraj, başlangıç, hız, sıra.
        case clip(slot: Int)
        /// Bir metin alanının stili: boyut, renk, yazı tipi.
        case textStyle(key: String)
        case music

        var id: String {
            switch self {
            case .picker(let slot, _, let limit): return "picker-\(slot)-\(limit)"
            case .clip(let slot): return "clip-\(slot)"
            case .textStyle(let key): return "style-\(key)"
            case .music: return "music"
            }
        }
    }

    /// Tam ekran sonuç ekranının girdisi (kalıcı kütüphanedeki dosya).
    struct ExportResult: Identifiable {
        let id = UUID()
        let url: URL
        /// Bu video bir kerelik "ilk videon bizden" hakkıyla mı çıktı — sonuç
        /// ekranı hediyeyi söyleyip sonrakilerin filigranlı olacağını belirtir.
        let usedFirstFreeExport: Bool
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
                    .overlay(alignment: .top) { if restoredDraft { draftBanner } }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                editPanel(height: panelHeight(for: geo.size.height))
                    // Metin sekmesine geçerken panel büyüyor; sahne bu yüzden
                    // küçülüyor. Zıplamasın diye animasyonlu.
                    .animation(.easeInOut(duration: 0.22), value: panel)
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
            restoreDraftIfAvailable()
            if autoExport {
                startExport()
            }
            if ProcessInfo.processInfo.arguments.contains("--open-picker"),
               let slot = templateSlots.first {
                sheet = .picker(slot: slot, kind: pickerKind(forSlot: slot), limit: 1)
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
            case .picker(let slot, let kind, let limit):
                MediaPicker(kind: kind,
                            selectionLimit: limit,
                            onPick: { picked in
                                isImportingMedia = false
                                assign(picked, startingAt: slot)
                            },
                            onStart: { isImportingMedia = true },
                            onError: {
                                isImportingMedia = false
                                Haptics.error()
                                mediaError = String(localized: "Bu dosya açılamadı. iCloud'daki bir video olabilir — indirilmesini bekleyip tekrar dener misin?")
                            })
                .ignoresSafeArea()
            case .clip(let slot):
                ClipSettingsView(
                    displayIndex: (templateSlots.firstIndex(of: slot) ?? slot) + 1,
                    totalSlots: templateSlots.count,
                    slotAspect: slotAspect(slot),
                    windowDuration: slotWindowDuration(slot),
                    accentHex: tintHex,
                    videoURL: videos[slot],
                    photo: photos[slot],
                    crop: cropBinding(for: slot),
                    start: startBinding(for: slot),
                    speed: speedBinding(for: slot),
                    onReplace: { replaceMedia(in: slot) },
                    onRemove: { clearSlot(slot) },
                    onMoveEarlier: canMove(slot, by: -1) ? { move(slot, by: -1) } : nil,
                    onMoveLater: canMove(slot, by: 1) ? { move(slot, by: 1) } : nil)
            case .textStyle(let key):
                TextStyleView(
                    fieldLabel: fieldLabel(key, index: editableTextKeys.firstIndex(of: key) ?? 0),
                    sample: texts[key] ?? "",
                    templateFontName: textContent(key)?.font.name ?? "HelveticaNeue-Bold",
                    templateColorHex: templateTextColorHex(key),
                    backgroundHex: project.template.palette["background"] ?? "#0B0B0D",
                    paletteHexes: paletteHexes,
                    accentHex: tintHex,
                    style: textStyleBinding(for: key))
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
                // SONUÇ EKRANI KENDİ OYNATICISINI KURUYOR. Editörünki
                // duraklatılmazsa iki oynatıcı aynı anda video çözüyor: biri
                // görünmüyor bile, ama döngü bildirimi her bitişte tekrar
                // `play()` diyor ve kullanıcı sonuç ekranında dakikalarca
                // durabiliyor (Kaydet / Paylaş / oran seçimi).
                //
                // DURAKLATILIR, BIRAKILMAZ: oynatıcıyı yok etmek sahneyi de
                // boşaltıyordu — kullanıcı "Düzenlemeye dön" dediğinde ne
                // video ne de "Önizle" düğmesi kalıyordu (`.task(id:)`
                // yeniden çalışmadığı için oynatıcı geri gelmiyor).
                previewPlayer?.pause()
                result = ExportResult(url: register(url),
                                      usedFirstFreeExport: usedFirstFreeExport)
                // Hak burada tükenir: video GERÇEKTEN çıktı. Başlangıçta
                // tüketilseydi iptal eden ya da render'ı patlayan kullanıcı
                // hiç video görmeden hediyesini kaybederdi.
                store.markFirstFreeExportUsed()
                // İş bitti: yarım kalmış değil artık.
                drafts.markExported(templateID: project.id)
                restoredDraft = false
            }
        }
        // Önizleme render'ı bitti: oynatıcı yeni dosyaya geçer.
        .onChange(of: preview.phase) { _, phase in
            if case .done(let url) = phase {
                previewURL = url
                previewStale = false
            }
        }
        // SES DEĞİŞİNCE EKRANDAKİ SES HEMEN SUSAR. Müzik render'ın İÇİNE
        // gömülü; kullanıcı "Müziksiz" dediğinde eldeki video eski parçayı
        // çalmaya devam ediyordu ("kapattım ama kapanmıyor"). Yenilenene kadar
        // oynatıcı sessize alınır — görüntü kalır, yanlış ses gitmiş olur.
        .onChange(of: music?.id) { _, id in
            Analytics.shared.log(.musicSelected(trackID: id))
            silenceStalePreview()
            markDirty()
        }
        .onChange(of: useOriginalAudio) { _, _ in
            silenceStalePreview()
            markDirty()
        }
        .fullScreenCover(item: $result) { finished in
            ExportResultView(
                url: finished.url,
                templateID: project.id,
                templateName: project.template.name.resolved(languageCode: AppLanguage.code),
                duration: project.template.totalDuration,
                accentHex: tintHex,
                showsProUpsell: !store.entitlements.isPro,
                gotFirstFreeExport: finished.usedFirstFreeExport,
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
                                              texts: texts, accentHex: tintHex,
                                              player: player)
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
            // SIRA ÖNEMLİ: önce SES ve oynatıcı susar, sonra render iptal
            // edilir. Editörden çıkarken uygulamanın kapandığı cihazda
            // görüldü; arkada çalan oynatıcılar ve süren bir render bir arada
            // duruyordu (bkz. makeLoopingPlayer sızıntısı).
            previewMusic.stop()
            releasePlayer()
            previewPlayer = nil
            preview.cancel()
            saveDraft()
        }
        // Uygulama arka plana alınırken de yaz: `onDisappear` yalnız ekrandan
        // ÇIKINCA çalışıyor, kullanıcı ise çoğu zaman ana ekrana basıp gidiyor.
        .onChange(of: scenePhase) { _, phase in
            // EKRAN GİTTİĞİNDE VİDEO DA DURUR. Döngüye alınmış önizleme
            // oynatıcısı arka planda ve Control Center açıkken de kare
            // çözmeye devam ediyordu — kullanıcının göremediği bir video
            // için pil ve ısı.
            if phase != .active { previewPlayer?.pause() } else { previewPlayer?.play() }
            // Kaydetme YALNIZ `.background`'da. SwiftUI geçişi
            // `.active → .inactive → .background` diye veriyor; `!= .active`
            // demek tek çıkışta taslağı İKİ KEZ yazmak (her fotoğrafı iki kez
            // JPEG'e kodlamak) demekti. Üstelik bildirim çekmecesini açmak
            // gibi geri dönen `.inactive` anları da boşuna kayıt tetikliyordu.
            if phase == .background { saveDraft() }
        }
    }

    // MARK: - Taslak

    /// Bu şablonun yarım kalmış işi varsa geri yükler.
    ///
    /// Otomasyon yollarında (`--inject-*`, otomatik export) YAPILMAZ: duman
    /// testi ve ekran görüntüleri hep aynı temiz durumdan başlamalı.
    private func restoreDraftIfAvailable() {
        guard !autoExport, !hasMedia,
              !ProcessInfo.processInfo.arguments.contains("--inject-media"),
              Self.argument(after: "--inject-video") == nil,
              let draft = drafts.draft(for: project.id) else { return }

        for slot in draft.slots {
            switch slot.kind {
            case .photo:
                guard let image = drafts.photo(slot) else { continue }
                photos[slot.slot] = image
            case .video:
                let url = drafts.fileURL(slot.fileName)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                videos[slot.slot] = url
            }
            if !slot.crop.isIdentity { crops[slot.slot] = slot.crop }
            if slot.start > 0 { starts[slot.slot] = slot.start }
            if slot.speed != 1 { speeds[slot.slot] = slot.speed }
        }
        guard !photos.isEmpty || !videos.isEmpty else { return }

        // Metinler: taslakta olan alanlar; şablonun yeni eklediği alanlar
        // varsayılanıyla kalır (şablon güncellenmiş olabilir).
        for (key, value) in draft.texts where texts[key] != nil { texts[key] = value }
        textStyles = draft.textStyles
        accent = draft.accentHex
        useOriginalAudio = draft.useOriginalAudio
        if let trackID = draft.musicTrackID {
            music = MusicLibrary.track(id: trackID) ?? music
        } else if !draft.useOriginalAudio {
            music = nil
        }
        restoredDraft = true
        startPreview()
    }

    private func saveDraft() {
        drafts.save(templateID: project.id,
                    templateName: project.template.name.resolved(languageCode: AppLanguage.code),
                    texts: texts, textStyles: textStyles,
                    photos: photos, videos: videos,
                    crops: crops, starts: starts, speeds: speeds,
                    accentHex: accent, musicTrackID: music?.id,
                    useOriginalAudio: useOriginalAudio,
                    hasEdits: hasEdits)
    }

    /// Kullanıcı şablonun HAZIR halinden ayrıldı mı? Medyasız şablonlarda
    /// taslağın kaydedilip kaydedilmeyeceğini bu belirler: sadece açıp kapatan
    /// kullanıcının galerisi "Devam et" kartlarıyla dolmasın, ama yazdığı
    /// menüyü de kaybetmesin.
    private var hasEdits: Bool {
        texts != project.texts || !textStyles.isEmpty || accent != nil
            || music?.id != project.template.audio?.defaultTrackId || useOriginalAudio
    }

    /// Taslağı bırakıp şablonun temiz haline dön.
    ///
    /// SIRA ÖNEMLİ: taslağı silmek medyayı DİSKTEN de kaldırıyor (çöp toplama),
    /// bu yüzden önce ekrandaki her şey bırakılır, sonra taslak silinir —
    /// oynatıcı silinmiş bir dosyaya bakmasın.
    private func resetToTemplate() {
        preview.cancel()
        previewMusic.stop()
        releasePlayer()
        previewPlayer = nil
        previewURL = nil
        photos = [:]
        videos = [:]
        crops = [:]
        starts = [:]
        speeds = [:]
        textStyles = [:]
        texts = project.texts
        accent = nil
        useOriginalAudio = false
        music = MusicLibrary.defaultTrack(for: project.template)
        restoredDraft = false
        previewStale = false
        preview.phase = .idle
        drafts.remove(templateID: project.id)
    }

    /// "Kaldığın yerden devam" şeridi — alanların neden dolu olduğunu söyler ve
    /// tek dokunuşla temiz sayfa verir.
    private var draftBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .semibold))
            Text("Kaldığın yerden devam")
                .font(.system(size: 11, weight: .medium))
            Button {
                Haptics.warning()
                resetToTemplate()
            } label: {
                Text("Sıfırla")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: tintHex))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.black.opacity(0.55), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        .padding(.top, 10)
    }

    /// Panel yüksekliği ekran boyuna göre. SE gibi kısa cihazlarda panel
    /// küçülür ki sahne tamamen ezilmesin.
    ///
    /// METİN SEKMESİ İSTİSNADIR. Sabit 182 pt'lik panelde aynı anda YALNIZ ~2
    /// metin alanı görünüyordu; `playlist-card-01`'de 16, `class-schedule-01`'de
    /// 15 alan var — kullanıcı 500 pt'lik bir sahnenin altındaki iki satırlık
    /// gözetleme deliğinden sekiz kez kaydırarak yazıyordu. Panel alan sayısı
    /// kadar (bir yere kadar) büyür.
    ///
    /// SAHNENİN TABANI KORUNUR: bu düzende sahne ESNEK, kardeşleri SABİT
    /// yükseklikli — panel büyüdükçe sahne kendiliğinden küçülüyor. Tavan
    /// `available`'ın oranına bağlandı ki 9:16 kadraj hiçbir cihazda
    /// okunamayacak kadar ezilmesin (bu tuzağa bir kez düşüldü: kadraj 430 pt
    /// ekranda 174 pt'ye inmişti).
    private func panelHeight(for available: CGFloat) -> CGFloat {
        let base: CGFloat = available < 620 ? 148 : 182
        guard panel == .text, editableTextKeys.count > 2 else { return base }
        let wanted = base + CGFloat(min(editableTextKeys.count - 2, 4)) * 46
        return min(wanted, max(base, available * 0.40))
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
        // Sonuç ekranı açılırken duraklatılan önizleme geri döner.
        previewPlayer?.play()
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
                                // Rozet TEK SATIR: sıkışınca "5/" ve "5" diye
                                // ikiye bölünüyordu.
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(selected ? Color.black.opacity(0.12)
                                                     : Color.white.opacity(0.14),
                                            in: Capsule())
                        }
                    }
                    .foregroundStyle(selected ? .black : .white.opacity(0.75))
                    // Sekmeler eşit paylaşır, ROZETLİ medya sekmesi hariç:
                    // dört eşit dilime bölünen 393 pt'lik bir ekranda rozet
                    // yüzünden başlık "Med… 5/5" diye kırpılıyordu. Rozetli
                    // sekme SIKIŞMAYI REDDEDER (fixedSize), kalanlar geri
                    // kalanı eşit böler — etiketleri kısa, hepsi rahat sığıyor.
                    .frame(maxWidth: hugsContent(item) ? nil : .infinity)
                    .fixedSize(horizontal: hugsContent(item), vertical: false)
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

    /// Sekme eşit dilim yerine kendi genişliğini mi alsın (yalnız rozetli
    /// medya sekmesi).
    private func hugsContent(_ item: Panel) -> Bool {
        item == .media && filledSlotCount > 0
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
                        // DOLU kareye dokunmak medyayı DEĞİŞTİRMEZ, klip
                        // ayarlarını açar (kadraj / başlangıç / hız / sıra) —
                        // video editörlerinin alışılmış davranışı; değiştirme
                        // orada bir düğme. Boş kare doğrudan seçiciyi açar.
                        Button {
                            Haptics.tap()
                            if photos[slot] != nil || videos[slot] != nil {
                                sheet = .clip(slot: slot)
                            } else {
                                sheet = .picker(slot: slot, kind: pickerKind(forSlot: slot),
                                                limit: 1)
                            }
                        } label: {
                            MediaThumb(url: videos[slot], cgImage: photos[slot],
                                       index: displayIndex(of: slot),
                                       isPhoto: !slotAllowsVideo(slot),
                                       speed: speeds[slot],
                                       isTrimmed: (starts[slot] ?? 0) > 0.05,
                                       isCropped: !(crops[slot] ?? CropTransform()).isIdentity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mediaSlotLabel(slot))
                        .accessibilityHint(Text(photos[slot] != nil || videos[slot] != nil
                                                ? "Klibi ayarlamak için dokun"
                                                : "Fotoğraf veya video seçmek için dokun"))
                    }
                }
                .padding(.horizontal, 20)
            }
            Text(mediaHint)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(2)
                .padding(.horizontal, 20)
        }
    }

    private var mediaHint: String {
        if hasMedia {
            return String(localized: "Kadraj, başlangıç ve hız için bir kareye dokun")
        }
        return String(localized: "Kendi fotoğraf ve videolarını ekle")
    }

    // MARK: Klip hızı

    /// Seçilebilen hızlar. Üst/alt sınır motorunkiyle aynı
    /// (`SlotAssignment.speedRange`); aradaki basamaklar Reels/TikTok'ta
    /// alışılmış olanlar.
    static let speedChoices: [Double] = [0.25, 0.5, 1, 2, 3, 4]

    static func speedLabel(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...2)))
        return "\(number)×"
    }

    private func speedBinding(for slot: Int) -> Binding<Double> {
        Binding(get: { speeds[slot] ?? 1 },
                set: { value in
                    guard value != (speeds[slot] ?? 1) else { return }
                    Haptics.select()
                    if value == 1 { speeds[slot] = nil } else { speeds[slot] = value }
                    Analytics.shared.log(.clipSpeedChanged(slot: slot, speed: value))
                    markDirty()
                })
    }

    // MARK: Klip ayarları (kadraj / başlangıç / sıra)

    private func cropBinding(for slot: Int) -> Binding<CropTransform> {
        Binding(get: { crops[slot] ?? CropTransform() },
                set: { value in
                    guard value != (crops[slot] ?? CropTransform()) else { return }
                    crops[slot] = value.isIdentity ? nil : value
                    markDirty()
                })
    }

    private func startBinding(for slot: Int) -> Binding<Double> {
        Binding(get: { starts[slot] ?? 0 },
                set: { value in
                    let rounded = max(0, (value * 20).rounded() / 20)   // 0,05 sn ızgara
                    guard rounded != (starts[slot] ?? 0) else { return }
                    starts[slot] = rounded == 0 ? nil : rounded
                    markDirty()
                })
    }

    /// Şeritte kaçıncı kare olduğu (slotIndex ile aynı olmayabilir).
    private func displayIndex(of slot: Int) -> Int {
        templateSlots.firstIndex(of: slot) ?? slot
    }

    /// Slotun şablondaki kadraj oranı (genişlik / yükseklik). Kadraj ekranı
    /// kullanıcıya GERÇEK kadrajı göstermeli — 9:16 bir kutuda kadrajlanan
    /// fotoğraf, kare bir slotta bambaşka duruyor.
    private func slotAspect(_ slot: Int) -> Double {
        var best: NormalizedRect?
        func scan(_ layers: [Layer]) {
            for layer in layers {
                guard case .mediaSlot(let content) = layer.content,
                      content.slotIndex == slot else { continue }
                let area = layer.frame.width * layer.frame.height
                if area > (best.map { $0.width * $0.height } ?? 0) { best = layer.frame }
            }
        }
        project.template.scenes?.forEach { scan($0.layers) }
        scan(project.template.layers)
        guard let best, best.height > 0 else { return 9.0 / 16.0 }
        let canvas = project.template.canvas
        let width = best.width * Double(canvas.width)
        let height = best.height * Double(canvas.height)
        return height > 0 ? width / height : 9.0 / 16.0
    }

    /// Slotun ekranda kaç saniye göründüğü: montajda sahne penceresi, klasik
    /// şablonda tüm süre. "Klibin ne kadarı kullanılacak" hesabı buna dayanır.
    private func slotWindowDuration(_ slot: Int) -> Double {
        guard let scenes = project.template.scenes, !scenes.isEmpty else {
            return project.template.totalDuration
        }
        let timeline = MontageTimeline(scenes: scenes)
        for window in timeline.windows {
            let contains = scenes[window.index].layers.contains { layer in
                if case .mediaSlot(let content) = layer.content {
                    return content.slotIndex == slot
                }
                return false
            }
            if contains { return window.end - window.start }
        }
        return project.template.totalDuration
    }

    /// Klip ayarları ekranındaki "medyayı değiştir": sheet'ten sheet'e geçiş
    /// SwiftUI'da aynı karede yapılırsa yeni sheet açılmıyor — önce kapanır.
    private func replaceMedia(in slot: Int) {
        sheet = nil
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            sheet = .picker(slot: slot, kind: pickerKind(forSlot: slot), limit: 1)
        }
    }

    private func clearSlot(_ slot: Int) {
        photos[slot] = nil
        videos[slot] = nil
        speeds[slot] = nil
        crops[slot] = nil
        starts[slot] = nil
        markDirty()
    }

    private func canMove(_ slot: Int, by delta: Int) -> Bool {
        guard let index = templateSlots.firstIndex(of: slot) else { return false }
        let target = index + delta
        return target >= 0 && target < templateSlots.count
    }

    /// Klibi şeritte bir yana taşır. Medya YALNIZ BAŞINA taşınmaz: kadrajı,
    /// başlangıcı ve hızı da birlikte gider — yoksa kullanıcı sırayı
    /// düzelttiğinde ayarları karışıyor.
    private func move(_ slot: Int, by delta: Int) {
        guard let index = templateSlots.firstIndex(of: slot), canMove(slot, by: delta) else {
            return
        }
        let other = templateSlots[index + delta]
        // `swap(&photos[a], &photos[b])` derlenmiyor: @State sözlüğü hesaplanan
        // bir özellik, aynı çağrıda iki kez inout geçilemiyor.
        exchange(&photos, slot, other)
        exchange(&videos, slot, other)
        exchange(&speeds, slot, other)
        exchange(&crops, slot, other)
        exchange(&starts, slot, other)
        // Ayarlar ekranı taşınan klibi izlesin (kullanıcı aynı klibe bakmaya
        // devam ediyor, sabit bir slota değil).
        sheet = .clip(slot: other)
        markDirty()
    }

    /// İki slotun kaydını yer değiştirir (biri boşsa diğerine geçer).
    private func exchange<Value>(_ dictionary: inout [Int: Value], _ a: Int, _ b: Int) {
        let first = dictionary[a]
        dictionary[a] = dictionary[b]
        dictionary[b] = first
    }

    // MARK: Metin paneli

    @ViewBuilder private var textPanel: some View {
        if editableTextKeys.isEmpty {
            panelEmpty(icon: "textformat",
                       message: String(localized: "Bu şablonda düzenlenecek metin yok"))
        } else {
            ScrollView {
                // Başlıklar liste başına BİR KEZ: `fieldLabels` tüm alanları
                // birlikte çözüyor, satır satır sormak onu her satırda baştan
                // hesaplatırdı.
                let labels = fieldLabels
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(editableTextKeys.enumerated()), id: \.element) { index, key in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(labels[key] ?? String(localized: "Metin \(index + 1)"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                                Spacer()
                                // Stil ayrı bir ekranda: panel sabit yükseklikli,
                                // her alanın altına boyut/renk/font satırı
                                // sığdırmak metin alanlarını ezerdi.
                                Button {
                                    Haptics.tap()
                                    focusedField = nil
                                    sheet = .textStyle(key: key)
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "textformat")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text(styleBadgeText(key))
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundStyle(textStyles[key] == nil
                                                     ? .white.opacity(0.55)
                                                     : Color(hex: tintHex))
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(.white.opacity(0.09), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("Yazı stili"))
                            }
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

    /// Seçilen medyaları slotlara dağıtır: ilki `slot`'a, kalanlar sırayla BOŞ
    /// slotlara (dolu slotlar korunur — kullanıcı onları bilerek doldurdu).
    /// Boş slot kalmazsa fazlası sessizce yok sayılır.
    private func assign(_ media: [PickedMedia], startingAt slot: Int) {
        guard !media.isEmpty else { return }
        let wasEmpty = !hasMedia
        let targets = [slot] + templateSlots.filter {
            $0 != slot && photos[$0] == nil && videos[$0] == nil
        }
        for (target, picked) in zip(targets, media) { place(picked, in: target) }
        Haptics.select()
        // ÖNİZLEME KENDİLİĞİNDEN BAŞLAMAZ. Eskiden ilk medya gelince render
        // tetikleniyordu; cihazda bu, kullanıcı "Video Oluştur" demeden video
        // VE SESİN başlaması demek oluyordu — üstelik art arda eklenen her
        // fotoğraf yeni bir render kuyruğa atıyor, telefon ısınıyordu.
        // Kullanıcı seçtiği görüntüyü zaten statik sahnede görüyor; hareketli
        // hâlini isteyen "Önizle"ye basar.
        markDirty()
    }

    /// Medyayı slota yazar; aynı slottaki diğer türü temizler. Önizleme kararı
    /// çağırana ait (bkz. `assign`) — slot slot render tetiklenmemeli.
    private func place(_ media: PickedMedia, in slot: Int) {
        switch media {
        case .photo(let cg):
            photos[slot] = cg
            videos[slot] = nil
            // Fotoğrafın hızı yok; slot videodan fotoğrafa dönerse ayar da düşer.
            speeds[slot] = nil
            Analytics.shared.log(.mediaPicked(slot: slot, kind: "photo"))
        case .video(let url):
            videos[slot] = url
            photos[slot] = nil
            Analytics.shared.log(.mediaPicked(slot: slot, kind: "video"))
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
    /// Editör önizlemesi.
    ///
    /// ÖNEMLİ DAVRANIŞ: bir kez render alındıktan sonra oynatıcı EKRANDAN
    /// KALKMAZ. Kullanıcı metni değiştirdiğinde eldeki (bayat) video oynamaya
    /// devam eder; üstünde "Önizlemeyi yenile" belirir ve yeni render'ı
    /// KULLANICI başlatır. Arka planda kendiliğinden yenileme denendi ve
    /// cihazda geri alındı: her değişiklik bir render demekti, telefon
    /// ısınıyordu ve kullanıcı istemediği hâlde video+ses başlıyordu.
    @ViewBuilder private var previewStage: some View {
        ZStack {
            if let previewPlayer {
                PlayerScrubView(player: previewPlayer,
                                duration: project.template.totalDuration,
                                accentHex: tintHex) {
                    if needsTextOverlay {
                        MontagePreviewOverlay(template: project.template,
                                              texts: texts, accentHex: tintHex,
                                              player: previewPlayer)
                    }
                }
            } else if case .exporting(let progress) = preview.phase {
                // İLK render: gösterilecek bir video yok, ilerleme göster.
                renderProgress(progress, title: "Önizleme hazırlanıyor")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    staticPreview
                    if needsMedia, !hasMedia { emptyStageScrim }
                    // Hap SAHNENİN ORTASINDA DURMAZ: her şablonda kullanıcının
                    // gördüğü ilk karede şablonun kendi başlığını örtüyordu
                    // ("TAKİPTE KAL", "Mercimek Çorbası" okunmuyordu). Kart bir
                    // söz veriyor, editör o sözü kendi butonuyla kapatıyordu.
                    // Artık hap şablonun METİN BLOKLARINDAN uzak bir şeride durur.
                    if let anchor = stageActionAnchor {
                        GeometryReader { geo in
                            previewButton
                                .frame(maxWidth: .infinity)
                                .position(x: geo.size.width / 2,
                                          y: geo.size.height * anchor)
                        }
                    } else {
                        // Boş şerit yok: düğme tasarımın ÜSTÜNE binmek yerine
                        // alta demirler ve altına ince bir perde alır — böylece
                        // şablonun bir parçası değil, bir KONTROL gibi okunur.
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            previewButton
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 12)
                                .background {
                                    LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                                   startPoint: .top, endPoint: .bottom)
                                        .allowsHitTesting(false)
                                }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if isRenderingPreview, previewPlayer != nil {
                refreshingChip
            } else if previewStale, previewPlayer != nil, canExport {
                staleChip
            }
        }
        .task(id: previewURL) {
            guard let previewURL else { return }
            let player = makeLoopingPlayer(previewURL)
            previewPlayer = player
            player.play()
            if needsAudioOverlay, let music {
                previewMusic.toggle(track: music, duration: project.template.totalDuration)
            }
        }
    }

    private var isRenderingPreview: Bool {
        if case .exporting = preview.phase { return true }
        return false
    }

    /// "Yenileniyor" göstergesi: bayat video oynarken yeni render'ın sürdüğünü
    /// söyler. Taslak şeridiyle çakışmaması için taslak varken aşağı kaçar.
    private var refreshingChip: some View {
        HStack(spacing: 6) {
            ProgressView().tint(.white).scaleEffect(0.6)
            Text("Önizleme yenileniyor…")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
        .padding(.top, restoredDraft ? 52 : 10)
    }

    /// Bayat önizleme: eldeki video değiştirilen girdiyi göstermiyor.
    /// Yenilemeyi KULLANICI başlatır (bkz. markDirty).
    private var staleChip: some View {
        Button {
            Haptics.tap()
            startPreview()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                Text("Önizlemeyi yenile")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(.black.opacity(0.65), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, restoredDraft ? 52 : 10)
    }

    /// Hapın sahne yüksekliğinin kaçta kaçına yerleşeceği (0-1).
    ///
    /// Sırayla alt üçte bir → üst çeyrek → orta denenir; metin bloğuyla
    /// ÇAKIŞMAYAN ilki kazanır. Alt üçte bir başta çünkü şablon başlıkları
    /// neredeyse her zaman üstte/ortada duruyor. (Medya slotunun merkezine
    /// hizalamak denendi ve işe YARAMADI: slot çoğu şablonda tam kadraj,
    /// merkezi de tam başlığın üstüne düşüyor.)
    /// Boş şerit bulunamazsa `nil` — düğme o zaman sahnenin ALTINA demirler
    /// (bkz. `previewButton` kullanımı). Yazı tabanlı şablonlarda (menü, ders
    /// programı, liste) tasarım kadrajın tamamını dolduruyor: üç aday şeridin
    /// üçü de doluyken eskiden yine 0.78'e dönülüyordu ve düğme "Kestaneli
    /// Latte ₺120" satırının üstüne oturuyordu.
    private var stageActionAnchor: Double? {
        let bands = textBands
        let margin = 0.07
        for candidate in [0.78, 0.24, 0.5] {
            let clash = bands.contains { $0.min < candidate + margin && candidate - margin < $0.max }
            if !clash { return candidate }
        }
        return nil
    }

    /// İlk karede görünen metin katmanlarının dikey aralıkları (0-1).
    /// Statik önizleme montajın İLK sahnesini çiziyor (bkz. staticPreview),
    /// bakılan yer de orası.
    private var textBands: [(min: Double, max: Double)] {
        var bands: [(min: Double, max: Double)] = []
        func scan(_ layers: [Layer]) {
            for layer in layers {
                guard case .text = layer.content else { continue }
                bands.append((layer.frame.y - layer.frame.height / 2,
                              layer.frame.y + layer.frame.height / 2))
            }
        }
        scan(project.template.scenes?.first?.layers ?? [])
        scan(project.template.layers)
        return bands
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
                            textStyles: textStyles,
                            photos: photos, videos: videos, crops: crops,
                            // Boş projede montajın SON sahnesi çoğu şablonda
                            // yalnız kapanış yazısı taşıyor; ilk sahne düzeni
                            // daha iyi anlatır.
                            //
                            // AMA bu gerekçe yalnız MEDYA BEKLEYEN şablonlar
                            // için geçerli. Yazı tabanlı 17 şablonda (menü,
                            // ders programı, valiz listesi…) `hasMedia` HİÇ
                            // true olmuyor, yani sahne kalıcı olarak sürenin
                            // %15'inde donuyordu: `drinks-list-01` dört menü
                            // kaleminin ikisini gösterip altını boş bırakıyor,
                            // kullanıcı "Önizle"ye basıp render bekleyene kadar
                            // tasarımın doğru halini hiç görmüyordu. O
                            // şablonlarda beklenen kare, her şeyin sahnede
                            // olduğu geç andır.
                            progress: !needsMedia ? 0.9 : (hasMedia ? 0.75 : 0.15),
                            // Editörde boş slot bir EKSİKTİR: soyut bir sahneyle
                            // doluymuş gibi gösterilmemeli.
                            placeholder: .hint,
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

    /// Statik posterin üstündeki düğme. Yalnız HENÜZ RENDER YOKKEN görünür:
    /// ilk render alındıktan sonra yenileme kendiliğinden oluyor
    /// (bkz. scheduleAutoRefresh), düğmeye gerek kalmıyor.
    @ViewBuilder private var previewButton: some View {
        if canExport {
            Button {
                Haptics.tap()
                startPreview()
            } label: {
                Label("Önizle", systemImage: "play.fill")
                    .modifier(StageBadge())
            }
            .buttonStyle(.plain)
        } else if let first = templateSlots.first {
            VStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    sheet = .picker(slot: first, kind: pickerKind(forSlot: first),
                                    limit: emptySlotCount)
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

    /// Döngüye alınmış oynatıcı.
    ///
    /// SIZINTI (cihazda bulundu, simulator'da duyulmuyordu): gözlemcinin
    /// kapanışı `player`ı GÜÇLÜ tutuyordu ve kayıt editör kapanana kadar
    /// `loopTokens`ta duruyordu. Yenilemede `previewPlayer` yeni oynatıcıya
    /// geçiyor, eskisi serbest kalmıyor — gözlemci onu tutuyor ve video her
    /// bittiğinde `play()` diyordu. Üçüncü yenilemeden sonra arkada üç oynatıcı
    /// birden çalıyordu: "ses duplike oluyor", "müziği kapattım susmuyor"
    /// (susan yalnız EKRANDAKİ oynatıcıydı) ve telefonun ısınması hep buydu.
    ///
    /// Artık aynı anda TEK oynatıcı yaşar: yenisi kurulmadan önce eskisi
    /// durdurulup gözlemcisi bırakılır, kapanış da oynatıcıyı zayıf tutar.
    private func makeLoopingPlayer(_ url: URL) -> AVPlayer {
        releasePlayer()
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none
        let token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem, queue: .main) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        loopTokens.append(token)
        return player
    }

    /// Ekrandaki oynatıcıyı susturur ve gözlemcilerini bırakır.
    /// Yeni oynatıcı kurmadan ÖNCE ve editörden çıkarken çağrılır.
    private func releasePlayer() {
        previewPlayer?.pause()
        previewPlayer?.replaceCurrentItem(with: nil)
        loopTokens.forEach(NotificationCenter.default.removeObserver)
        loopTokens = []
    }

    /// Önizlemeyi (yeniden) üretir. Kullanıcının videosuyla aynı hat, yalnız
    /// küçük kadraj — bkz. `ExportFlow.Quality.preview`.
    private func startPreview() {
        previewMusic.stop()
        preview.run(project: project, texts: texts, photos: photos, videos: videos,
                    music: music, entitlements: store.entitlements,
                    accentOverride: accent, speeds: speeds,
                    crops: crops, starts: starts, textStyles: textStyles,
                    originalAudioFrom: originalAudioSource?.url,
                    originalAudioSpeed: originalAudioSource?.speed ?? 1)
    }

    /// Girdi değişti: eldeki ön-render artık ekrandakini göstermiyor.
    ///
    /// KENDİLİĞİNDEN YENİLEMEZ. Eskiden burada 1,5 sn'lik bir gecikmeyle yeni
    /// bir render planlanıyordu; simulator'da akıcı hissettiriyordu ama
    /// cihazda her değişiklik bir render demek oluyordu ve telefon ısınıyordu.
    /// Oynatıcı ekranda kalır (bayat da olsa bir şey görmek, hiçbir şey
    /// görmemekten iyidir), üstünde "Önizlemeyi yenile" çıkar; kararı
    /// kullanıcı verir.
    private func markDirty() {
        guard previewURL != nil || isRenderingPreview else { return }
        previewStale = true
    }

    /// Ekrandaki (artık bayat) önizlemenin sesini kes. Görüntü kalır.
    private func silenceStalePreview() {
        previewPlayer?.isMuted = true
        previewMusic.stop()
    }

    // MARK: - Alt aksiyon çubuğu

    private var actionBar: some View {
        VStack(spacing: 8) {
            // Ücretsiz kullanıcıya çıktının ne olacağını export'tan ÖNCE söyle
            // (sürpriz olmasın). İlk hak duruyorken bu bir HABERDİR, teklif
            // değil: kullanıcı henüz karşılığını görmediği bir şey için
            // paywall'a itilmemeli.
            if !store.entitlements.isPro {
                if store.entitlements.hasFirstFreeExport {
                    firstFreePill
                } else {
                    watermarkPill
                }
            }
            primaryButton
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    /// İlk hak duruyorken: iyi haber. Dokunulacak bir şey değil — burada
    /// satacak bir şey yok, kullanıcının yalnız devam etmesi isteniyor.
    private var firstFreePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "gift.fill").font(.system(size: 10))
            Text("Bu video filigransız").font(.system(size: 11, weight: .semibold))
            Text("· ilk videon bizden")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .foregroundStyle(Color(hex: "#F2C14E"))
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Color(hex: "#F2C14E").opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    /// Hak tükendikten sonraki hâl: filigran var, kaldırmanın yolu Pro.
    private var watermarkPill: some View {
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
                sheet = .picker(slot: first, kind: pickerKind(forSlot: first),
                                limit: emptySlotCount)
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

    /// Orijinal ses seçiliyse hangi klipten alınacağı (ilk video slotu) ve o
    /// klibin hızı — klip hızlandırıldıysa sesin de aynı oranda hızlanması
    /// gerekiyor, yoksa görüntüyle ses ayrışıyor.
    private var originalAudioSource: (url: URL, speed: Double)? {
        guard useOriginalAudio,
              let first = videos.sorted(by: { $0.key < $1.key }).first else { return nil }
        return (first.value, speeds[first.key] ?? 1)
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

    /// Seçicinin izin vereceği en fazla seçim: doldurulacak slot sayısı.
    private var emptySlotCount: Int {
        max(1, templateSlots.count - filledSlotCount)
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
        // Hakkı ŞİMDİ oku (tüketme): filigran kararı da bu anın durumuyla
        // veriliyor, sonuç ekranı aynı anı anlatsın.
        usedFirstFreeExport = store.entitlements.hasFirstFreeExport
        flow.run(project: project, texts: texts, photos: photos, videos: videos,
                 music: music, entitlements: store.entitlements,
                 accentOverride: accent, speeds: speeds,
                 crops: crops, starts: starts, textStyles: textStyles,
                 originalAudioFrom: originalAudioSource?.url,
                 originalAudioSpeed: originalAudioSource?.speed ?? 1)
    }

    /// --inject-media ile PHPicker seçimini programatik taklit eder: belirgin
    /// bir test fotosunu tüm slotlara koyar (assign() ile aynı yol). Böylece
    /// "kullanıcı kendi medyasını seçti → export onu kullandı" akışı screenshot'la
    /// doğrulanabilir (gerçek galeri dokunuşu simctl'de otomatikleştirilemiyor).
    private func injectMediaIfRequested() {
        // `--inject-video <yol>`: video kabul eden slotlara verilen klibi koyar.
        // Hız etiketi yalnız VİDEO slotunda çıktığı için otomasyonun (duman
        // testi, ekran görüntüsü) o yolu görmesinin tek yolu bu.
        if let path = Self.argument(after: "--inject-video") {
            let url = URL(fileURLWithPath: path)
            let slots = templateSlots.filter(slotAllowsVideo)
            if !slots.isEmpty, FileManager.default.fileExists(atPath: path) {
                assign(slots.map { _ in PickedMedia.video(url) }, startingAt: slots[0])
                return
            }
        }
        guard ProcessInfo.processInfo.arguments.contains("--inject-media"),
              let cg = EditorView.injectedTestPhoto() else { return }
        assign(templateSlots.map { _ in PickedMedia.photo(cg) },
               startingAt: templateSlots.first ?? 0)
    }

    /// `--bayrak <değer>` biçimindeki başlatma argümanının değeri.
    private static func argument(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.index(after: index) < arguments.endIndex else { return nil }
        let value = arguments[arguments.index(after: index)]
        return value.hasPrefix("--") ? nil : value
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
        let number = displayIndex(of: slot) + 1
        if videos[slot] != nil { return Text("Medya \(number), video seçili") }
        if photos[slot] != nil { return Text("Medya \(number), fotoğraf seçili") }
        return Text("Medya \(number), boş")
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

    /// Alan başlıkları TEK SEFERDE hesaplanır: sıralı bir alanın kaçıncı
    /// olduğu ve `a-label` gibi çift anlamlı id'lerin hangi işi anlattığı
    /// KOMŞU alanlara bakılarak çözülüyor (bkz. `TextFieldLabels.labels`).
    /// Alan alan sormak o bağlamı kaybettiriyordu.
    private var fieldLabels: [String: String] {
        TextFieldLabels.labels(forLayerIDs: editableTextKeys)
    }

    private func fieldLabel(_ key: String, index: Int) -> String {
        fieldLabels[key] ?? String(localized: "Metin \(index + 1)")
    }

    /// Stil düğmesinin etiketi: dokunulmuşsa neyin değiştiğini söyler.
    private func styleBadgeText(_ key: String) -> String {
        guard let style = textStyles[key] else { return String(localized: "Stil") }
        var parts: [String] = []
        if style.scale != 1 { parts.append("%\(Int((style.scale * 100).rounded()))") }
        if style.colorHex != nil { parts.append(String(localized: "renk")) }
        if let family = TextFontFamily.from(style.fontFamily) {
            parts.append(TextStyleView.title(for: family))
        }
        return parts.isEmpty ? String(localized: "Stil") : parts.joined(separator: " · ")
    }

    /// Katmanın şablondaki metin içeriği (font/renk varsayılanları için).
    private func textContent(_ key: String) -> TextContent? {
        var found: TextContent?
        func scan(_ layers: [Layer]) {
            for layer in layers {
                if case .text(let content) = layer.content, layer.id == key { found = content }
            }
        }
        project.template.scenes?.forEach { scan($0.layers) }
        scan(project.template.layers)
        return found
    }

    /// Şablonun bu metin için tasarladığı renk (palet rolünden çözülür).
    private func templateTextColorHex(_ key: String) -> String {
        guard let role = textContent(key)?.colorRole else { return "#FFFFFF" }
        if role == "accent" { return tintHex }
        return project.template.palette[role] ?? "#FFFFFF"
    }

    /// Şablonun paletindeki renkler — kullanıcı kendi şablonuna uyumlu kalsın.
    private var paletteHexes: [String] {
        let roles = ["accent", "primary", "secondary", "text", "surface", "background"]
        var result: [String] = []
        for role in roles {
            guard var hex = project.template.palette[role] else { continue }
            if role == "accent" { hex = tintHex }
            // Saydam roller (scrim uçları) metin rengi olarak işe yaramaz.
            if hex.count == 9, hex.uppercased().hasSuffix("00") { continue }
            result.append(String(hex.prefix(7)))
        }
        return result
    }

    private func textStyleBinding(for key: String) -> Binding<TextStyleOverride> {
        Binding(get: { textStyles[key] ?? TextStyleOverride() },
                set: { value in
                    let current = textStyles[key] ?? TextStyleOverride()
                    guard value != current else { return }
                    textStyles[key] = value.isEmpty ? nil : value
                    markDirty()
                })
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
    /// 1'den farklıysa hız etiketi gösterilir (nil = normal).
    var speed: Double?
    /// Klibin başı kırpıldı mı (makas göstergesi).
    var isTrimmed: Bool = false
    /// Kadraj değiştirildi mi (yakınlaştırma göstergesi).
    var isCropped: Bool = false
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
            badges
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

    /// Dolu slot: küçük bir "ayarla" işareti taşır — aksi halde seçilmiş kare,
    /// dokunulabilir olduğunu hiç belli etmiyor.
    private func filled(_ image: Image) -> some View {
        image.resizable().aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.black.opacity(0.55), in: Circle())
                    .padding(3)
            }
    }

    /// Kullanıcının bu klibe DOKUNDUĞUNU gösteren küçük etiketler: hız, kırpma,
    /// kadraj. Ayarlar başka bir ekranda olduğu için şeritte iz bırakmalı,
    /// yoksa kullanıcı hangi klibi ayarladığını hatırlamıyor.
    @ViewBuilder private var badges: some View {
        let speedText = speed.map { abs($0 - 1) < 0.001 ? nil : EditorView.speedLabel($0) } ?? nil
        if speedText != nil || isTrimmed || isCropped {
            HStack(spacing: 2) {
                if let speedText {
                    Text(speedText).font(.system(size: 9, weight: .heavy))
                }
                if isTrimmed { Image(systemName: "scissors").font(.system(size: 8, weight: .bold)) }
                if isCropped {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(.white.opacity(0.92), in: Capsule())
            .padding(4)
            .frame(width: size.width, height: size.height, alignment: .bottomTrailing)
        }
    }
}
