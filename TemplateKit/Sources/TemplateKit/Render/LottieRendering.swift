#if canImport(QuartzCore)
import Foundation
import QuartzCore
import CoreGraphics

/// Bir `lottie` katmanının render edilmesi için gereken her şey.
public struct LottieRequest: Sendable {
    /// Şablon paketindeki dosya adı (`assets/confetti.json`).
    public let asset: String
    public let loopMode: LottieLoopMode
    /// Animasyondaki ham renklerin (`#RRGGBB`) alacağı YENİ renkler —
    /// `colorRemap` palet rolleri üzerinden çözülmüş hali.
    public let colorOverrides: [String: RGBAColor]
    /// Katmanın kanvastaki boyutu (nokta).
    public let size: CGSize
    /// Animasyonun oynayacağı süre (katmanın presence penceresi).
    public let duration: Double
    /// Export'ta `AVCoreAnimationBeginTimeAtZero`, önizlemede 0.
    public let baseTime: CFTimeInterval
    /// Katmanın sahneye girdiği an (saniye).
    public let startTime: Double

    public init(asset: String, loopMode: LottieLoopMode,
                colorOverrides: [String: RGBAColor], size: CGSize,
                duration: Double, baseTime: CFTimeInterval, startTime: Double) {
        self.asset = asset
        self.loopMode = loopMode
        self.colorOverrides = colorOverrides
        self.size = size
        self.duration = duration
        self.baseTime = baseTime
        self.startTime = startTime
    }
}

/// Lottie animasyonunu CALayer'a çeviren taraf.
///
/// TASARIM — neden protokol: `lottie-ios` bir üçüncü parti bağımlılık ve
/// TemplateKit bilinçli olarak BAĞIMLILIKSIZ (motor bir animasyon kütüphanesine
/// zincirlenmemeli; şablon formatı da lottie olmadan tam çalışıyor). Uygulama
/// tarafı lottie-ios'u ekleyip bu protokolü uygulayan ~40 satırlık bir adaptör
/// yazar ve `LottieRendererRegistry.install(...)` der; motorun geri kalanı
/// değişmez. Renderer takılı değilse katman yer tutucu olarak çizilir —
/// lottie taşıyan bir şablon indirilse bile uygulama kırılmaz.
///
/// Adaptörün uyması gerekenler (export hattının kısıtları):
/// - Dönen katman `AVVideoCompositionCoreAnimationTool` altında render
///   edilebilmeli → lottie-ios'un **CoreAnimation** rendering engine'i
///   kullanılmalı (Main Thread engine export'ta boş kare verir; CATextLayer'ın
///   aynı hattaki davranışı bunun kanıtı).
/// - Animasyon `beginTime`'ı `request.baseTime + request.startTime` olmalı,
///   yoksa katman sahneye girmeden oynamaya başlar.
public protocol LottieRendering: Sendable {
    /// - Returns: hazır katman; asset bulunamazsa/desteklenmiyorsa nil
    ///   (çağıran yer tutucuya düşer).
    func makeLayer(for request: LottieRequest) -> CALayer?
}

/// Takılı Lottie renderer'ı tutan tek nokta.
///
/// Global durum tercih edilmesinin nedeni: katman ağacı senkron ve saf bir
/// fonksiyonla (`TemplateLayerBuilder.build`) kuruluyor; renderer'ı oradan
/// parametre olarak taşımak, çağıran her yeri (exporter, montaj compositor'ı,
/// varlık üreteci, testler) lottie'den haberdar etmek demekti.
public enum LottieRendererRegistry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var renderer: LottieRendering?

    /// Uygulama açılışında bir kez çağrılır.
    public static func install(_ renderer: LottieRendering?) {
        lock.lock(); defer { lock.unlock() }
        self.renderer = renderer
    }

    public static var current: LottieRendering? {
        lock.lock(); defer { lock.unlock() }
        return renderer
    }
}

public extension LottieContent {
    /// `colorRemap` (ham hex → palet rolü) haritasını gerçek renklere çevirir.
    ///
    /// Şablonun renk şeması değiştiğinde lottie varlığını yeniden üretmek
    /// gerekmesin diye vardır: animasyonun içindeki sabit renk, şablonun
    /// paletindeki role bağlanır.
    ///
    /// Bilinmeyen rol sessizce ATLANIR (varlık kendi rengiyle kalır) —
    /// eksik bir rol yüzünden animasyonun kaybolması daha kötü.
    func resolvedColors(palette: [String: RGBAColor]) -> [String: RGBAColor] {
        var result: [String: RGBAColor] = [:]
        for (rawHex, role) in colorRemap ?? [:] {
            guard let color = palette[role] else { continue }
            result[LottieContent.normalizedHex(rawHex)] = color
        }
        return result
    }

    /// Anahtarları karşılaştırılabilir kılar: "#ff0000", "FF0000" ve "#FF0000"
    /// aynı rengi gösteriyor; adaptör tek biçim görsün.
    static func normalizedHex(_ hex: String) -> String {
        var value = hex.uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        return "#" + value
    }
}
#endif
