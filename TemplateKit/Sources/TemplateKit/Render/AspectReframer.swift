#if canImport(AVFoundation) && canImport(CoreImage)
import Foundation
import AVFoundation
import CoreImage

/// Biten bir 9:16 videoyu **gönderi (4:5)** ya da **kare (1:1)** oranına
/// çevirir.
///
/// NEDEN ŞABLONU YENİDEN DİZMİYORUZ: şablonların tamamı 9:16 için tasarlandı ve
/// koordinatlar normalize. Kanvası 4:5 yapmak metinleri/şekilleri dikeyde
/// sıkıştırır — başlıklar üst üste biner, kompozisyon çöker. Gerçek uygulamalar
/// bu yüzden her oran için AYRI şablon varyantı tutar; tek tek 127 şablonu
/// yeniden dizmek de bu işin kapsamı değil.
///
/// Bunun yerine BİTMİŞ video hiç bozulmadan yeni kadraja OTURTULUYOR: tasarım
/// tam olarak göründüğü gibi kalır, artan alan aynı karenin bulanık ve
/// büyütülmüş kopyasıyla dolar (Instagram'da herkesin tanıdığı "story → post"
/// görünümü). Tasarım riski sıfır, kazanç gerçek: kullanıcı aynı işi hem
/// hikâyede hem gönderide/karede paylaşabiliyor.
public enum AspectReframer {

    public enum Preset: String, CaseIterable, Sendable {
        /// Instagram/Facebook gönderisi.
        case post
        /// Kare (gönderi, LinkedIn, X).
        case square

        /// Hedef oran (genişlik / yükseklik).
        public var ratio: Double {
            switch self {
            case .post: return 4.0 / 5.0
            case .square: return 1
            }
        }

        /// Dosya adı eki: "story-post.mp4".
        public var fileSuffix: String { rawValue }
    }

    /// - Parameters:
    ///   - source: bitmiş video (ses varsa korunur).
    ///   - preset: hedef oran.
    ///   - blurRadius: dolgu bulanıklığı (kaynak genişliğine göre normalize).
    /// - Returns: yazılan dosyanın URL'i.
    @discardableResult
    public static func render(source: URL,
                              preset: Preset,
                              outputURL: URL,
                              blurRadius: Double = 0.06,
                              progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw TemplateExportError.missingVideoTrack
        }
        let natural = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let oriented = natural.applying(transform)
        let sourceSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))

        // Hedef: kaynak GENİŞLİĞİNİ koru, yüksekliği orandan türet. H.264 tek
        // sayı kenar sevmiyor, ikiye yuvarlanır.
        let width = even(Int(sourceSize.width))
        let height = even(Int((Double(width) / preset.ratio).rounded()))
        let target = CGSize(width: width, height: height)
        let canvas = CGRect(origin: .zero, size: target)
        let sigma = Double(width) * blurRadius

        let composition = AVMutableVideoComposition(asset: asset) { request in
            let source = request.sourceImage
            let extent = source.extent
            guard extent.width > 0, extent.height > 0 else {
                request.finish(with: source, context: nil)
                return
            }

            // ARKA PLAN: kadrajı DOLDURACAK şekilde büyüt (taşan kısım kırpılır),
            // sonra bulanıklaştır. clampedToExtent olmadan bulanıklık kenarlarda
            // şeffaflığa doğru soluyor ve çerçevede koyu bir çizgi bırakıyor.
            let fill = max(target.width / extent.width, target.height / extent.height)
            let background = source
                .transformed(by: CGAffineTransform(scaleX: fill, y: fill))
                .transformed(by: CGAffineTransform(
                    translationX: (target.width - extent.width * fill) / 2,
                    y: (target.height - extent.height * fill) / 2))
                .clampedToExtent()
                .applyingGaussianBlur(sigma: sigma)
                // Dolgu, tasarımla yarışmasın: hafifçe koyulaştırılır.
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputBrightnessKey: -0.12,
                    kCIInputSaturationKey: 0.9
                ])
                .cropped(to: canvas)

            // ÖN PLAN: tasarım TAMAMEN görünmeli — sığdır (contain), kırpma yok.
            let fit = min(target.width / extent.width, target.height / extent.height)
            let foreground = source
                .transformed(by: CGAffineTransform(scaleX: fit, y: fit))
                .transformed(by: CGAffineTransform(
                    translationX: (target.width - extent.width * fit) / 2,
                    y: (target.height - extent.height * fit) / 2))

            request.finish(with: foreground.composited(over: background).cropped(to: canvas),
                           context: nil)
        }
        composition.renderSize = target

        try? FileManager.default.removeItem(at: outputURL)
        guard let session = AVAssetExportSession(asset: asset,
                                                presetName: AVAssetExportPresetHighestQuality) else {
            throw TemplateExportError.exportSessionCreationFailed
        }
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = composition

        let progressTask: Task<Void, Never>? = progress.map { report in
            Task {
                while !Task.isCancelled {
                    report(Double(session.progress))
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }
        defer { progressTask?.cancel() }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        switch session.status {
        case .completed:
            progress?(1)
            return outputURL
        case .cancelled:
            throw TemplateExportError.cancelled
        default:
            throw TemplateExportError.failed(underlying: session.error)
        }
    }

    private static func even(_ value: Int) -> Int { value % 2 == 0 ? value : value + 1 }
}
#endif
