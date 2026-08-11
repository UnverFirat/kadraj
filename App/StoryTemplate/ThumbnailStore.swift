import Foundation
import SwiftUI
import ImageIO
import TemplateKit

/// Galeri posterlerinin (`templates/thumbs/*.jpg`) yükleyicisi.
///
/// Poster katalogdan gelir — yani CDN → disk cache → uygulama paketi sırasıyla,
/// şablon JSON'uyla aynı yoldan ve aynı `id-vN` sürümlemesiyle. Kart posteri
/// bulamazsa `TemplatePreview`'a düşer (şablonu kendi katmanlarından çizer),
/// bu yüzden eksik/bozuk poster galeriyi asla boş bırakmaz.
///
/// Neden ayrı bir nesne: poster yüklemek `DemoLibrary`'nin `projects`
/// dizisini değiştirmemeli — yoksa her poster gelişinde tüm galeri yeniden
/// kurulur.
@MainActor
final class ThumbnailStore: ObservableObject {
    /// Anahtar `entry.cacheKey` (`id-vN`): sürüm artınca yeni poster gelir.
    @Published private(set) var images: [String: CGImage] = [:]

    private let catalog: TemplateCatalog
    private var inFlight: Set<String> = []
    /// En son kullanılan anahtarlar, eskiden yeniye. Kapasite dolunca baştan atılır.
    private var recentlyUsed: [String] = []

    /// Kart genişliği 2 sütunlu ızgarada ~190 pt; 3x ekranda ~570 px eder.
    /// Tam çözünürlüklü poster (1080 px) bellekte gereksiz yer kaplıyor.
    private let maxPixelSize = 512

    /// Bellekte tutulan en fazla poster sayısı.
    ///
    /// KATALOG BÜYÜDÜ (29 → 100 şablon) ve bu sözlük eskiden HİÇ boşalmıyordu:
    /// galeriyi sonuna kadar kaydıran kullanıcıda 100 × ~2 MB'lık çözülmüş
    /// bitmap birikiyor, uygulama bellek baskısıyla sistem tarafından
    /// kapatılıyordu. Sınır, ekranda görünen ~6 kartın çok üstünde; atılan
    /// poster kart yeniden göründüğünde disk önbelleğinden anında geri gelir
    /// (o arada kart `TemplatePreview`'a düşer, boş kalmaz).
    private let capacity = 32

    init(catalog: TemplateCatalog) {
        self.catalog = catalog
    }

    func image(for entry: TemplateManifest.Entry) -> CGImage? {
        let key = key(for: entry)
        guard let image = images[key] else { return nil }
        touch(key)
        return image
    }

    private func touch(_ key: String) {
        if let index = recentlyUsed.firstIndex(of: key) {
            recentlyUsed.remove(at: index)
        }
        recentlyUsed.append(key)
    }

    private func evictIfNeeded() {
        while recentlyUsed.count > capacity {
            let oldest = recentlyUsed.removeFirst()
            images[oldest] = nil
        }
    }

    /// Poster dile bağlı (şablonun metinlerini gösteriyor) — anahtar da öyle.
    private func key(for entry: TemplateManifest.Entry) -> String {
        "\(entry.cacheKey)-\(AppLanguage.code)"
    }

    /// Posteri (varsa) yükler. Aynı şablon için ikinci çağrı iş açmaz —
    /// galeri kaydırmada `task` defalarca tetiklenir.
    func load(_ entry: TemplateManifest.Entry) async {
        let key = key(for: entry)
        guard images[key] == nil, !inFlight.contains(key) else { return }
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        guard let data = await catalog.thumbnail(for: entry,
                                                 languageCode: AppLanguage.code) else { return }
        let size = maxPixelSize
        // Çözme + küçültme ana iş parçacığından uzakta.
        let decoded = await Task.detached(priority: .userInitiated) {
            ThumbnailStore.decode(data, maxPixelSize: size)
        }.value
        guard let decoded else { return }
        images[key] = decoded
        touch(key)
        evictIfNeeded()
    }

    /// JPEG/PNG → küçültülmüş CGImage. `kCGImageSourceCreateThumbnail*`
    /// tam boyu belleğe açmadan doğrudan küçük halini üretir.
    nonisolated private static func decode(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
