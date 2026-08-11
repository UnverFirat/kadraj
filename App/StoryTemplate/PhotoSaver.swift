import Foundation
import Photos

/// Oluşturulan videoyu kullanıcının Fotoğraflar kitaplığına kaydeder.
///
/// İZİN: yalnız **ekleme** izni istenir (`.addOnly`). Kütüphaneyi okumuyoruz —
/// medya seçimi PHPicker ile yapılıyor ve o hiç izin gerektirmiyor. Ekleme
/// izni, kullanıcının bir sistem penceresinde tek seferde verdiği en dar izin;
/// `Info.plist`'teki `NSPhotoLibraryAddUsageDescription` bunun karşılığı.
enum PhotoSaver {
    enum Outcome: Equatable {
        case saved
        /// Kullanıcı izni reddetti — Ayarlar'a yönlendirme metni gösterilir.
        case denied
        case failed
    }

    static func save(videoAt url: URL) async -> Outcome {
        let status = await requestAddPermission()
        guard status == .authorized || status == .limited else { return .denied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            return .saved
        } catch {
            return .failed
        }
    }

    private static func requestAddPermission() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    static func message(for outcome: Outcome) -> String {
        switch outcome {
        case .saved:  return String(localized: "Video Fotoğraflar'a kaydedildi.")
        case .denied: return String(localized: "Fotoğraflar izni kapalı. Ayarlar → Gizlilik'ten açabilirsin.")
        case .failed: return String(localized: "Video kaydedilemedi. Tekrar dener misin?")
        }
    }
}
