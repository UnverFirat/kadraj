import SwiftUI
import TemplateKit

/// Uygulama kabuğu: üç sekme + her yerden açılabilen paywall.
///
/// Şablon sekmesi kendi `NavigationStack`'ini taşır (galeri → editör). Yığın
/// burada tutulur ki hem launch bayrakları (`--route`) hem de deep link
/// (`kadraj://sablon/<id>`) aynı yoldan editöre gidebilsin.
struct RootView: View {
    @EnvironmentObject var library: DemoLibrary
    @EnvironmentObject var store: Store

    @State private var tab: Tab = .templates
    @State private var path: [Route] = []
    /// Karar AÇILIŞTA BİR KEZ verilir (bkz. `OnboardingGate.shouldPresent`).
    /// `onAppear` içinde hesaplamak, kapatıldıktan sonra sekme değişimiyle
    /// yeniden tetiklenme riski taşıyordu.
    @State private var showOnboarding = OnboardingGate.shouldPresent()

    enum Tab: Hashable { case templates, videos, settings }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $path) {
                GalleryView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .editor(let id, let autoExport):
                            if let project = library.project(templateID: id) {
                                EditorView(project: project, autoExport: autoExport)
                            } else {
                                MissingTemplateView(templateID: id)
                            }
                        }
                    }
            }
            .tabItem { Label("Şablonlar", systemImage: "square.grid.2x2") }
            .tag(Tab.templates)

            NavigationStack {
                MyVideosView(onBrowseTemplates: { tab = .templates })
            }
            .tabItem { Label("Videolarım", systemImage: "play.rectangle.on.rectangle") }
            .tag(Tab.videos)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Ayarlar", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(.white)
        // Paywall uygulamanın her yerinden aynı yoldan açılır (Store.showPaywall).
        .sheet(isPresented: Binding(get: { store.paywallReason != nil },
                                    set: { if !$0 { store.paywallReason = nil } })) {
            PaywallView(reason: store.paywallReason)
        }
        // İLK AÇILIŞ KARŞILAMASI. Sekmelerin ÜSTÜNDE durur, yerine geçmez:
        // kapandığı anda kullanıcı zaten galeriye bakıyor olur, yeniden
        // yönlendirme (ve o yönlendirmenin gecikmesi) yok.
        //
        // Bitirince ne olur: "Hadi başlayalım" da "Atla" da yalnız örtüyü
        // kaldırır — `tab`/`path` ELLENMEZ. Kullanıcıyı önerilen bir şablonun
        // editörüne düşürmek denendi ama iki sebeple bırakıldı: (1) uygulamanın
        // ilk vaadi "işine uyanı seç", onu bizim seçmemiz karşılamada anlatılan
        // adımı hemen yalanlıyor; (2) editör açılır açılmaz medya istiyor, yani
        // kullanıcı daha ne olduğunu görmeden fotoğraf izni istemiyle
        // karşılaşıyor. Ayrıca örtü açıkken gelen bir deep link (`kadraj://`)
        // yığını çoktan kurmuş olabilir — burada `path`'i sıfırlamak onu ezerdi.
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                OnboardingGate().markSeen()
                showOnboarding = false
            }
        }
        .onOpenURL { open($0) }
        .onAppear {
            applyLaunchRoute()
            if ProcessInfo.processInfo.arguments.contains("--open-paywall") {
                store.showPaywall(reason: String(localized: "Bu şablon Pro"))
            }
        }
    }

    /// `kadraj://sablon/<id>` → şablon sekmesinde o şablonun editörü.
    /// Katalog henüz yüklenmediyse yığına yine de itilir; hedef ekran şablonu
    /// bulamazsa `MissingTemplateView` gösterir.
    private func open(_ url: URL) {
        guard url.scheme == "kadraj", url.host == "sablon" else { return }
        let id = url.pathComponents.filter { $0 != "/" }.first
        guard let id, !id.isEmpty else { return }
        tab = .templates
        path = [.editor(templateID: id, autoExport: false)]
    }

    /// Screenshot otomasyonu: belirli bir ekranla başlat.
    ///   --route editor:<templateId>   editörü o şablonla aç
    ///   --route preview:<templateId>  otomatik "Video Oluştur" + önizleme
    ///
    /// Karşılama ekranının bayrakları (`--onboarding` / `--skip-onboarding`) ve
    /// bu bayrakların otomasyonla ilişkisi `OnboardingGate.shouldPresent`'ta:
    /// buradaki `--route` gibi bir otomasyon bayrağı verildiğinde karşılama
    /// hiç gösterilmez, yani yığın kurulduktan sonra önüne bir örtü gelmez.
    private func applyLaunchRoute() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--open-videos") { tab = .videos }
        if args.contains("--open-settings") { tab = .settings }
        guard let idx = args.firstIndex(of: "--route"), idx + 1 < args.count else { return }
        let parts = args[idx + 1].split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        switch parts[0] {
        case "editor": path = [.editor(templateID: parts[1], autoExport: false)]
        case "preview": path = [.editor(templateID: parts[1], autoExport: true)]
        default: break
        }
    }
}

enum Route: Hashable {
    case editor(templateID: String, autoExport: Bool)
}

/// Deep link / launch bayrağı katalogda olmayan bir şablonu işaret ettiğinde.
/// (Şablon CDN'den kaldırılmış ya da `minAppVersion` süzgecine takılmış olabilir.)
struct MissingTemplateView: View {
    let templateID: String
    @EnvironmentObject var library: DemoLibrary

    var body: some View {
        VStack(spacing: 10) {
            if case .loading = library.status {
                ProgressView()
                Text("Şablonlar yükleniyor…")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            } else {
                Image(systemName: "questionmark.square.dashed").font(.largeTitle)
                Text("Şablon bulunamadı").font(.system(size: 17, weight: .semibold))
                Text(templateID).font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
