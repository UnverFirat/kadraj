import UIKit

/// Dokunsal geri bildirim — uygulamanın "canlı" hissettiği yer.
///
/// Neden ayrı bir sarmalayıcı: uygulama boyunca aynı olay aynı hissi versin:
///
/// - `tap`      — seçim/sekme değişimi gibi hafif onaylar
/// - `select`   — medya/parça seçildi
/// - `success`  — video hazır, satın alma tamam
/// - `warning`  — engellenen eylem (kilitli şablon, eksik medya)
/// - `error`    — export hatası
///
/// ÜRETEÇLER UZUN ÖMÜRLÜ (2026-08-27'de düzeltildi). Eskiden her çağrıda yeni
/// bir üreteç kuruluyor, `prepare()` ediliyor ve HEMEN ardından tetikleniyordu.
/// `prepare()` eşzamansızdır: Taptic Engine'i uyandırmaya zaman ister, aynı
/// runloop turunda tetiklenince o ısınmanın hiçbir faydası olmaz. Sonuç, motor
/// her dokunuşta boştan kalkıyor ve titreşim geç düşüyordu — 57 çağrı yerinin
/// hepsinde, yani uygulamanın HER düğmesinde. Geç düşen titreşim kullanıcıya
/// "düğme kastı" diye okunur; oysa geciken görüntü değil dokunuştu.
///
/// Doğrusu: üreteci bir kez kur, tetikledikten SONRA yeniden `prepare()` et —
/// motor bir sonraki dokunuş için sıcak kalır. `warmUp()` de ilk dokunuşu
/// kurtarır: ekran açılırken motor zaten uyanmış olur.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// İLK dokunuşu kurtarır: motor soğukken ilk titreşim en geç düşendir.
    /// Etkileşimli bir ekran açılırken çağır (bkz. `RootView`).
    static func warmUp() {
        light.prepare()
        selection.prepare()
    }

    static func tap() {
        light.impactOccurred()
        light.prepare()
    }

    static func select() {
        selection.selectionChanged()
        selection.prepare()
    }

    static func success() { notify(.success) }
    static func warning() { notify(.warning) }
    static func error() { notify(.error) }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
        notification.prepare()
    }
}
