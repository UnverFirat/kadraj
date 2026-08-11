#if canImport(CoreImage)
import Foundation
import CoreImage

/// Medyaya uygulanan renk gradasyonu presetleri. Tamamen kendi CIFilter
/// kombinasyonlarımız — jenerik, telifsiz look'lar. `intensity` (0–1) orijinal
/// ile derecelenmiş görüntü arasında karışım oranıdır.
///
/// Preset'ler slot bazlı çalışır (her medya slotu kendi look'una sahip olabilir),
/// hem montaj (CoreImage compositor) hem klasik foto yolunda uygulanır.
public enum ColorGrade {

    /// Bilinen preset adları (validasyon/uyarı için). Tanınmayan preset yok
    /// sayılır (görüntü değişmez) — ileri uyumluluk.
    public static let presets: Set<String> = [
        "warm", "cool", "vintage", "mono", "vivid", "cinematic", "fade"
    ]

    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// Klasik yol (CALayer): foto CGImage'ına preset uygulayıp yeni CGImage döner.
    /// Filtre geçersiz/nil ise orijinali döner.
    public static func applyToCGImage(_ cgImage: CGImage, preset: String?,
                                      intensity: Double) -> CGImage {
        guard let preset, presets.contains(preset), intensity > 0 else { return cgImage }
        let input = CIImage(cgImage: cgImage)
        let output = apply(input, preset: preset, intensity: intensity)
        return context.createCGImage(output, from: input.extent) ?? cgImage
    }

    /// Görüntüye preset'i uygular ve `intensity` ile orijinale karıştırır.
    public static func apply(_ image: CIImage, preset: String,
                             intensity: Double) -> CIImage {
        let t = CGFloat(min(max(intensity, 0), 1))
        guard t > 0, presets.contains(preset) else { return image }
        let graded = grade(image, preset: preset)
        // intensity=1 ise tam derece; ara değerlerde orijinalle harmanla.
        if t >= 0.999 { return graded }
        return graded.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: image,   // hedef: orijinal
            kCIInputTimeKey: 1 - t            // t=1 → tamamen graded
        ])
    }

    private static func grade(_ image: CIImage, preset: String) -> CIImage {
        switch preset {
        case "warm":
            return image
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 4700, y: 10)])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 1.12, kCIInputContrastKey: 1.03])

        case "cool":
            return image
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 8600, y: -8)])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 1.05])

        case "vintage":
            return image
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.68, kCIInputContrastKey: 0.94,
                    kCIInputBrightnessKey: 0.02])
                .applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.28])

        case "mono":
            return image.applyingFilter("CIPhotoEffectMono")

        case "vivid":
            return image.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.35, kCIInputContrastKey: 1.12])

        case "cinematic":
            // Teal gölge / sıcak ışık hissi + hafif kontrast.
            return image
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 1.05, kCIInputContrastKey: 1.14])
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 5200, y: -6)])

        case "fade":
            // Matte/soluk film hissi: düşük kontrast + kaldırılmış siyahlar.
            return image.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.85, kCIInputContrastKey: 0.88,
                kCIInputBrightnessKey: 0.04])

        default:
            return image
        }
    }
}
#endif
