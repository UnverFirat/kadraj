import Foundation
import QuartzCore
import Lottie
import TemplateKit

/// `LottieRendering`'in gerçek uygulaması: şablondaki `lottie` katmanını
/// lottie-ios ile CALayer'a çevirir.
///
/// AYRI HEDEFTE (`TemplateKitLottie`) OLMASININ NEDENİ: `TemplateKit`
/// bağımlılıksız kalmalı (bkz. `LottieRendering`) — motor bir animasyon
/// kütüphanesine zincirlenmesin. Ama adaptör uygulamanın İÇİNDE kalsaydı
/// galeri varlık üreteci (`templatekit-assets`) ile motor CLI'ı
/// (`templatekit-demo`) lottie taşıyan şablonları çizemezdi: poster ve
/// önizleme animasyonsuz çıkardı, macOS'taki kare kare doğrulama da
/// yapılamazdı. Bu yüzden lottie-ios'a dokunan tek yer bu küçük hedef;
/// uygulama, CLI'lar ve testler aynı adaptörü paylaşır.
///
/// ÜÇ KRİTİK AYAR (export hattı bunları affetmiyor):
/// 1. **CoreAnimation rendering engine.** Main Thread engine `displayLink` ile
///    çizer; `AVVideoCompositionCoreAnimationTool` ise katman ağacını ekran
///    dışında, kendi zamanında örnekler → Main Thread engine boş kare verir.
///    CoreAnimation engine animasyonu saf `CAAnimation` ağacına çevirdiği için
///    tool onu örnekleyebiliyor. (Aynı ders CATextLayer'da alınmıştı.)
/// 2. **beginTime kaydırması.** lottie `play()` çağrısında animasyonları
///    `beginTime = 0` ile ekler; CoreAnimation'da 0 "ŞİMDİ" demektir, export'ta
///    ise zaman sıfırdan başlar. `retime(...)` tüm alt ağacı gezip
///    `baseTime + startTime`e (`AVCoreAnimationBeginTimeAtZero` + katmanın
///    sahneye girdiği an) kaydırır — yoksa animasyon export'ta ya hiç görünmez
///    ya da ilk karede bitmiş olur.
/// 3. **Ölçekleme elle.** Aspect-fit'i `LottieAnimationView` yapar,
///    `LottieAnimationLayer` yapmaz; katmanı doğrudan kullandığımız için
///    ölçek + ortalama burada uygulanır.
public final class LottieAdapter: LottieRendering {

    /// Varlığın aranacağı klasörler, öncelik sırasıyla.
    private let searchDirectories: [URL]

    public init(searchDirectories: [URL]) {
        self.searchDirectories = searchDirectories
    }

    /// Şablonların geldiği yerlerin aynısı: önce katalog önbelleği (CDN'den
    /// inen paketler — şablon içeriğiyle aynı öncelik), sonra uygulama paketi.
    public static func makeDefault() -> LottieAdapter {
        var directories: [URL] = [TemplateCatalog.defaultCacheDirectory()]
        if let resources = Bundle.main.resourceURL { directories.append(resources) }
        return LottieAdapter(searchDirectories: directories)
    }

    public func makeLayer(for request: LottieRequest) -> CALayer? {
        guard let data = assetData(named: request.asset) else { return nil }
        // Şablonun paleti animasyonun içine burada işlenir; eşleşme olmasa da
        // varlık kendi renkleriyle oynamalı, o yüzden hata yutuluyor.
        let payload = (try? LottieAssetRewriter.apply(request.colorOverrides, to: data).data) ?? data
        guard let animation = try? LottieAnimation.from(data: payload) else { return nil }

        let layer = LottieAnimationLayer(
            animation: animation,
            configuration: LottieConfiguration(renderingEngine: .coreAnimation))

        let natural = animation.size
        guard natural.width > 0, natural.height > 0 else { return nil }
        layer.frame = CGRect(origin: .zero, size: request.size)
        layer.masksToBounds = false

        layer.play(fromProgress: 0, toProgress: 1,
                   loopMode: request.loopMode == .loop ? .loop : .playOnce)
        // `play()` animasyonları HEMEN kurmaz; kurulum `display()` anına ertelenir
        // (lottie ekrandaki katman için bunu CoreAnimation'dan bekler). Export
        // ağacı ekrana hiç çıkmadığı için tetiklemek bize kalıyor — bu satır
        // olmadan ağaçta sıfır animasyon olur, `retime` boş ağacı gezer ve
        // videoda hiçbir şey görünmez.
        layer.layoutIfNeeded()
        layer.animationLayer?.displayIfNeeded()

        // Aspect fit: ölçek + ortalama İÇ katmana uygulanır, dışa değil.
        // `LottieAnimationView` de bunu yapıyor (`layoutAnimation`); biz view'ı
        // değil katmanı kullandığımız için elimizde kalıyor. Dış katmanı
        // ölçeklemek işe YARAMAZ: iç katman kendi konumunu animasyonun
        // kanvasına göre kuruyor, sonuç yarım kanvas kadar kayıyor (bu hata
        // export'ta "animasyon geç başlıyor" gibi görünüyordu — aslında
        // içerik ekranın dışındaydı).
        if let root = layer.animationLayer {
            let scale = min(request.size.width / natural.width,
                            request.size.height / natural.height)
            root.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            root.position = CGPoint(x: request.size.width / 2, y: request.size.height / 2)
            root.transform = CATransform3DMakeScale(scale, scale, 1)
        }

        LottieAdapter.retime(layer, to: request.baseTime + request.startTime)
        return layer
    }

    // MARK: - Varlık çözümü

    private func assetData(named asset: String) -> Data? {
        for directory in searchDirectories {
            let candidates = [
                directory.appendingPathComponent(asset),
                // Şablon yalnız dosya adı verdiyse (`confetti.json`) da bulunsun.
                directory.appendingPathComponent("assets").appendingPathComponent(
                    (asset as NSString).lastPathComponent)
            ]
            for url in candidates {
                if let data = try? Data(contentsOf: url) { return data }
            }
        }
        return nil
    }

    // MARK: - Zamanlama

    /// Alt ağaçtaki HER animasyonu verilen başlangıç anına kaydırır.
    ///
    /// lottie animasyonları tek bir yere değil, ağaçtaki onlarca alt katmana
    /// ekliyor (her özellik kendi katmanında) — o yüzden gezinti özyinelemeli.
    /// `layer.animation(forKey:)` salt-okunur kopya döndürür; değiştirmek için
    /// `copy()` alıp AYNI anahtarla yeniden eklemek gerekir.
    private static func retime(_ layer: CALayer, to beginTime: CFTimeInterval) {
        for key in layer.animationKeys() ?? [] {
            guard let animation = layer.animation(forKey: key)?.copy() as? CAAnimation else { continue }
            // Var olan göreli kaymayı (varsa) koru, mutlak başlangıcı ekle.
            animation.beginTime += beginTime
            // Export'ta katman ağacı tek seferde örneklenir: biten animasyon
            // ağaçtan düşerse o karelerde katman ilk hâline döner.
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: key)
        }
        for sublayer in layer.sublayers ?? [] {
            retime(sublayer, to: beginTime)
        }
    }
}
