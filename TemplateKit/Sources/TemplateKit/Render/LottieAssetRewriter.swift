#if canImport(QuartzCore)
import Foundation

/// Bir Lottie (bodymovin) JSON'undaki SABİT renkleri şablonun paletiyle
/// değiştirir.
///
/// TASARIM — neden JSON'u biz yeniden yazıyoruz: `lottie-ios`'un renk değiştirme
/// yolu (`setValueProvider(_:keypath:)`) KEYPATH ister — "Shape Layer 1.Group
/// 1.Fill 1.Color" gibi, yani animasyonun iç yapısını bilmeyi. Bizim sözleşmemiz
/// (`colorRemap`) ise "şu HAM RENK, şu palet rolü olsun" diyor; tasarımcı
/// animasyonu yeniden export ettiğinde katman adları değişse bile çalışması
/// gereken bir sözleşme bu. Renk eşlemesi keypath'e değil renge bağlı olduğu için
/// dönüşümü kaynak JSON üzerinde yapmak hem daha sağlam hem de test edilebilir:
/// bu dosya lottie-ios'a HİÇ bağımlı değil, TemplateKit bağımlılıksız kalıyor.
///
/// Kapsam: `fl` (fill) ve `st` (stroke) katmanlarının `c` renk özelliği — hem
/// sabit (`"a": 0`) hem keyframe'li (`"a": 1`) hali. Gradyanlar (`gf`/`gs`, `g`
/// içinde düzleştirilmiş dizi) BİLEREK dışarıda: orada renk ile durak konumu iç
/// içe yazılır, yanlış eşleşme animasyonu bozar; gradyanlı varlıkta remap
/// istenirse varlık düz renkle export edilmeli.
public enum LottieAssetRewriter {

    public struct Result: Sendable {
        public let data: Data
        /// Kaç renk gerçekten değiştirildi — çağıran taraf sıfır sonucu
        /// "eşleşme yok" diye günlüğe yazabilsin (varlık yine de oynar).
        public let replacements: Int
    }

    public enum Failure: Error {
        case invalidJSON
    }

    /// - Parameter overrides: `LottieContent.resolvedColors(palette:)` çıktısı —
    ///   anahtar normalize hex ("#RRGGBB"), değer yeni renk.
    /// - Returns: değiştirilmiş JSON. `overrides` boşsa veri OLDUĞU GİBİ döner
    ///   (gereksiz serialize/deserialize turu yok).
    public static func apply(_ overrides: [String: RGBAColor], to data: Data) throws -> Result {
        guard !overrides.isEmpty else { return Result(data: data, replacements: 0) }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.invalidJSON
        }
        var count = 0
        let rewritten = rewrite(root, overrides: overrides, replacements: &count)
        guard let output = try? JSONSerialization.data(withJSONObject: rewritten) else {
            throw Failure.invalidJSON
        }
        return Result(data: output, replacements: count)
    }

    // MARK: - Ağaç gezintisi

    private static func rewrite(_ value: Any, overrides: [String: RGBAColor],
                                replacements: inout Int) -> Any {
        if let dictionary = value as? [String: Any] {
            var result = dictionary
            for (key, child) in dictionary {
                // Renk özelliği yalnız "c" anahtarı altında durur (fl/st).
                if key == "c", let property = child as? [String: Any] {
                    result[key] = rewriteColorProperty(property, overrides: overrides,
                                                       replacements: &replacements)
                } else {
                    result[key] = rewrite(child, overrides: overrides, replacements: &replacements)
                }
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map { rewrite($0, overrides: overrides, replacements: &replacements) }
        }
        return value
    }

    /// `{"a": 0, "k": [r,g,b,a]}` veya `{"a": 1, "k": [ {..., "s": [...], "e": [...]}, ... ]}`
    private static func rewriteColorProperty(_ property: [String: Any],
                                             overrides: [String: RGBAColor],
                                             replacements: inout Int) -> [String: Any] {
        var result = property
        if let components = property["k"] as? [Any], let replaced = replacedComponents(
            components, overrides: overrides, replacements: &replacements) {
            result["k"] = replaced
            return result
        }
        // Keyframe'li: her karede "s" (ve eski formatta "e") birer renk.
        if let keyframes = property["k"] as? [[String: Any]] {
            result["k"] = keyframes.map { keyframe -> [String: Any] in
                var frame = keyframe
                for field in ["s", "e"] {
                    if let components = keyframe[field] as? [Any],
                       let replaced = replacedComponents(components, overrides: overrides,
                                                         replacements: &replacements) {
                        frame[field] = replaced
                    }
                }
                return frame
            }
            return result
        }
        return result
    }

    /// - Returns: yeni bileşenler; dizi renk değilse ya da eşleşme yoksa nil.
    private static func replacedComponents(_ components: [Any], overrides: [String: RGBAColor],
                                           replacements: inout Int) -> [Any]? {
        guard let numbers = components as? [Double] ?? (components as? [NSNumber])?.map({ $0.doubleValue }),
              numbers.count == 3 || numbers.count == 4 else { return nil }
        // Bodymovin renkleri 0–1 yazar; eski araçlar 0–255 yazabiliyor.
        let scale: Double = numbers.prefix(3).contains(where: { $0 > 1.0001 }) ? 255 : 1
        let hex = self.hex(red: numbers[0] / scale, green: numbers[1] / scale, blue: numbers[2] / scale)
        guard let color = overrides[hex] else { return nil }
        replacements += 1
        // Alfa bileşenini varlığın kendi değeriyle bırakıyoruz: palet rolü
        // rengi taşır, saydamlığı animasyonun tasarımı belirler.
        var output: [Any] = [color.red * scale, color.green * scale, color.blue * scale]
        if numbers.count == 4 { output.append(numbers[3]) }
        return output
    }

    private static func hex(red: Double, green: Double, blue: Double) -> String {
        func channel(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
    }
}
#endif
