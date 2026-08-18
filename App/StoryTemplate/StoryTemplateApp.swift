import SwiftUI
import TemplateKit
import TemplateKitLottie

/// Uygulama giriş noktası. Uzun ömürlü durum sahipleri env'e konur:
/// `DemoLibrary` (katalog), `Store` (abonelik), `ExportLibrary` (kullanıcının
/// videoları), `DraftStore` (yarım kalmış işler). Hepsi sekmeler arasında
/// paylaşılır.
@main
struct StoryTemplateApp: App {
    @StateObject private var library = DemoLibrary()
    @StateObject private var store = Store()
    @StateObject private var exports = ExportLibrary()
    @StateObject private var drafts = DraftStore()

    init() {
        AppAnalytics.install()
        // Motor lottie katmanlarını bu adaptör üzerinden çizer; takılmazsa
        // lottie taşıyan şablonlar yer tutucuyla açılır (kırılmaz).
        LottieRendererRegistry.install(LottieAdapter.makeDefault())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(store)
                .environmentObject(exports)
                .environmentObject(drafts)
                // Galeri posterleri katalogla aynı kaynaktan gelir; store
                // library'ye ait, env'e ayrıca konur ki poster gelince yalnız
                // ilgili kart yeniden çizilsin.
                .environmentObject(library.thumbnails)
                .preferredColorScheme(.dark)
                .onAppear { Analytics.shared.log(.appOpened) }
                // Gerçek mağaza arka ucunda ürünler/haklar burada çekilir
                // (yerel sağlayıcıda anında döner).
                .task { await store.start() }
        }
    }
}

/// Analitiğin uygulama tarafındaki kurulumu.
///
/// Ürün sağlayıcısı (Firebase/PostHog/kendi backend'imiz) henüz seçilmedi;
/// seçildiğinde yapılacak tek şey `AnalyticsSink`'i uygulayan bir adaptör
/// yazıp buraya eklemek — olay çağrıları uygulamanın içinde zaten duruyor.
/// O güne kadar olaylar konsola ve (Ayarlar'da görülebilen) belleğe yazılır.
enum AppAnalytics {
    /// Ayarlar ekranındaki "son olaylar" listesi bunu okur.
    static let recent = BufferingAnalyticsSink(limit: 100)

    static func install() {
        var sinks: [AnalyticsSink] = [recent]
        #if DEBUG
        sinks.append(ConsoleAnalyticsSink())
        #endif
        Analytics.shared.install(sinks)
    }
}
