import UIKit

/// Dokunsal geri bildirim — uygulamanın "canlı" hissettiği yer.
///
/// Neden ayrı bir sarmalayıcı: `UIImpactFeedbackGenerator`'ı çağrı yerinde
/// kurmak her seferinde bir nesne yaratıp ısıtma (`prepare`) adımını atlıyor,
/// o da ilk dokunuşta gecikmeli/zayıf bir titreşim veriyor. Burada tek tip
/// bir sözlük tutuyoruz ki uygulama boyunca aynı olay aynı hissi versin:
///
/// - `tap`      — seçim/sekme değişimi gibi hafif onaylar
/// - `select`   — medya/parça seçildi
/// - `success`  — video hazır, satın alma tamam
/// - `warning`  — engellenen eylem (kilitli şablon, eksik medya)
/// - `error`    — export hatası
enum Haptics {
    static func tap() { impact(.light) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }

    static func success() { notify(.success) }
    static func warning() { notify(.warning) }
    static func error() { notify(.error) }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
