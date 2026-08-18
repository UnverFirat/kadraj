import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import CoreGraphics
import TemplateKit

/// Kullanıcının bir slot için seçtiği medya.
enum PickedMedia {
    case photo(CGImage)
    case video(URL)   // kalıcı geçici dizine kopyalanmış
}

/// PHPicker'ı SwiftUI'ya saran seçici. Sistemin foto/video kütüphanesine
/// güvenli erişim (kullanıcı yalnızca seçtiğini paylaşır, uygulama tüm
/// kütüphaneye erişmez — bu yüzden Info.plist izni gerekmez).
struct MediaPicker: UIViewControllerRepresentable {
    enum Kind { case photo, video, any }

    let kind: Kind
    /// Kaç medya birden seçilebilir. 5 klipli bir şablonda seçiciyi beş kez
    /// açıp kapatmak (her seferinde tam ekran sheet) gereksiz bir sürtünmeydi;
    /// çoklu seçim rakiplerde standart. Tek slot düzenlemede 1 kalır.
    var selectionLimit: Int = 1
    /// Seçilenler, kullanıcının seçtiği SIRAYLA.
    let onPick: ([PickedMedia]) -> Void
    /// Seçim yapıldı, dosya HENÜZ hazır değil. iCloud'daki bir video birkaç
    /// saniye sürebiliyor; o sırada editör "alınıyor" göstersin.
    var onStart: () -> Void = {}
    /// Dosya okunamadı (iCloud'dan inemedi, biçim desteklenmiyor, kopyalama
    /// başarısız). Eskiden bu yolda HİÇBİR ŞEY olmuyordu: seçici kapanıyor,
    /// slot boş kalıyor, kullanıcı uygulamanın bozuk olduğunu düşünüyordu.
    var onError: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        switch kind {
        case .photo: config.filter = .images
        case .video: config.filter = .videos
        case .any: config.filter = .any(of: [.images, .videos])
        }
        config.selectionLimit = max(1, selectionLimit)
        // Çoklu seçimde kullanıcının dokunma SIRASI korunsun: slotlara o sırayla
        // dağıtacağız, alfabetik/tarih sırası kullanıcının kurduğu anlatıyı bozar.
        if selectionLimit > 1 { config.selection = .ordered }
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// EXIF dönüşünü PİKSELLERE uygular.
    ///
    /// `UIImage` yönü ayrı bir alanda (`imageOrientation`) taşır; `.cgImage`
    /// ise HAM piksel tamponudur ve o alanı bilmez. Telefonla dikey çekilmiş
    /// bir fotoğraf sensörden yatay geldiği için, doğrudan `.cgImage` almak
    /// görüntüyü 90° YAN gösteriyordu — motor da onu öyle render ediyordu.
    /// (İndirilmiş test görselleri EXIF dönüşü taşımadığından bu hata ancak
    /// gerçek bir iPhone fotoğrafıyla ortaya çıktı; gerçek kullanıcıların
    /// neredeyse tamamını etkilerdi.)
    static func upright(_ image: UIImage) -> CGImage? {
        guard image.imageOrientation != .up else { return image.cgImage }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1          // nokta değil PİKSEL çalışıyoruz
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MediaPicker
        init(_ parent: MediaPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController,
                    didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            // Kullanıcı "İptal"e bastı: hata değil, sessizce çık.
            guard !results.isEmpty else { return }
            let providers = results.map(\.itemProvider)
            Task { @MainActor in
                self.parent.onStart()
                // SIRAYLA yükle: seçim sırası slot sırası olacak. (Paralel
                // yüklemede sıra kaybolur; üstelik birden çok iCloud videosunu
                // aynı anda indirmek belleği de zorluyor.)
                var picked: [PickedMedia] = []
                for provider in providers {
                    if let media = await Self.load(provider) { picked.append(media) }
                }
                // Hiçbiri okunamadıysa hata; bir kısmı okunduysa onlarla devam
                // et — kullanıcı 5 seçtiyse 4'ü için akış durmasın.
                if picked.isEmpty { self.parent.onError() } else { self.parent.onPick(picked) }
            }
        }

        /// Tek bir seçimi `PickedMedia`'ya çevirir (okunamazsa nil).
        private static func load(_ provider: NSItemProvider) async -> PickedMedia? {
            if provider.canLoadObject(ofClass: UIImage.self) {
                return await withCheckedContinuation { continuation in
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        guard let image = object as? UIImage,
                              let cg = MediaPicker.upright(image) else {
                            return continuation.resume(returning: nil)
                        }
                        continuation.resume(returning: .photo(cg))
                    }
                }
            }
            guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                return nil
            }
            // loadFileRepresentation geçici URL verir ve callback dönünce siler;
            // kalıcı bir konuma kopyalarız.
            return await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(
                    forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url else { return continuation.resume(returning: nil) }
                    let dest = FileManager.default.temporaryDirectory
                        .appendingPathComponent("picked-\(UUID().uuidString).mov")
                    do {
                        try FileManager.default.copyItem(at: url, to: dest)
                    } catch {
                        return continuation.resume(returning: nil)
                    }
                    continuation.resume(returning: .video(dest))
                }
            }
        }
    }
}
