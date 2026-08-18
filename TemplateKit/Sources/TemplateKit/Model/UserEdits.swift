import Foundation

/// Kullanıcının bir şablon üzerinde yaptığı tüm değişiklikler.
/// Şablonun kendisi asla mutate edilmez; taslak kaydetme = bu yapının serialize'ı.
public struct UserEdits: Codable, Equatable, Sendable {
    /// slotIndex -> atanan medya.
    public var slots: [Int: SlotAssignment]
    /// Katman id -> kullanıcı metni (şablondaki `default` yerine geçer).
    public var textOverrides: [String: String]
    /// Katman id -> kullanıcının metin STİLİ değişikliği (boyut/renk/yazı tipi).
    /// Şablonun tipografisi varsayılan kalır; burası yalnız kullanıcının
    /// dokunduğu alanları taşır.
    public var textStyles: [String: TextStyleOverride]
    /// Rol -> hex. Şablon paletinin üstüne merge edilir (renk şeması değiştirme).
    public var paletteOverride: [String: String]?
    public var music: MusicSelection?

    public init(slots: [Int: SlotAssignment] = [:],
                textOverrides: [String: String] = [:],
                textStyles: [String: TextStyleOverride] = [:],
                paletteOverride: [String: String]? = nil,
                music: MusicSelection? = nil) {
        self.slots = slots
        self.textOverrides = textOverrides
        self.textStyles = textStyles
        self.paletteOverride = paletteOverride
        self.music = music
    }

    private enum CodingKeys: String, CodingKey {
        case slots, textOverrides, textStyles, paletteOverride, music
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slots = try c.decodeIfPresent([Int: SlotAssignment].self, forKey: .slots) ?? [:]
        textOverrides = try c.decodeIfPresent([String: String].self,
                                              forKey: .textOverrides) ?? [:]
        // Stil alanı taşımayan eski taslaklar şablonun tipografisiyle açılır.
        textStyles = try c.decodeIfPresent([String: TextStyleOverride].self,
                                           forKey: .textStyles) ?? [:]
        paletteOverride = try c.decodeIfPresent([String: String].self, forKey: .paletteOverride)
        music = try c.decodeIfPresent(MusicSelection.self, forKey: .music)
    }
}

/// Kullanıcının bir metin katmanına uyguladığı stil. Hepsi opsiyonel: yalnız
/// dokunulan şey değişir, gerisi şablonun tasarımı olarak kalır.
///
/// NEDEN VAR: editörde metnin yalnız İÇERİĞİ değiştirilebiliyordu. Kullanıcı
/// "şablonun dışına çıkamıyorum" hissi yaşıyor ve kendi markasının yazısını
/// kuramıyordu; oysa motor tipografiyi zaten parametrik çiziyor.
public struct TextStyleOverride: Codable, Equatable, Sendable {
    /// Şablonun font boyutuna uygulanan çarpan.
    public var scale: Double
    /// "#RRGGBB" / "#RRGGBBAA" — palet rolünün YERİNE geçer. nil = şablonunki.
    public var colorHex: String?
    /// Yazı tipi ailesi anahtarı (`TextFontFamily`). nil = şablonun fontu.
    public var fontFamily: String?

    public static let scaleRange: ClosedRange<Double> = 0.6...1.8

    public init(scale: Double = 1, colorHex: String? = nil, fontFamily: String? = nil) {
        self.scale = Self.clampScale(scale)
        self.colorHex = colorHex
        self.fontFamily = fontFamily
    }

    private enum CodingKeys: String, CodingKey { case scale, colorHex, fontFamily }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scale = Self.clampScale(try c.decodeIfPresent(Double.self, forKey: .scale) ?? 1)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily)
    }

    public var isEmpty: Bool { self == TextStyleOverride() }

    /// 0 ya da NaN bir boyut metni tümden yok eder.
    public static func clampScale(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(max(value, scaleRange.lowerBound), scaleRange.upperBound)
    }
}

/// Kullanıcının seçebileceği yazı tipi aileleri.
///
/// Şablonun fontu PostScript adıyla yazılıyor ("HelveticaNeue-Bold", "Didot").
/// Kullanıcıya PostScript adı sorulamaz; bunun yerine dört AİLE sunulur ve
/// şablondaki KALINLIK korunur — kullanıcı yazı tipini değiştirince başlığın
/// ağırlığı da kaybolursa tasarım çöküyor.
public enum TextFontFamily: String, CaseIterable, Sendable {
    case sans, serif, round, display

    /// Ailenin (kalın / normal) PostScript adları. Bulunmayan ad CoreText'te
    /// sistem fontuna düşer, yani hiçbir seçim render'ı kırmaz.
    public var postScriptNames: (bold: String, regular: String) {
        switch self {
        case .sans:    return ("HelveticaNeue-Bold", "HelveticaNeue-Medium")
        case .serif:   return ("Didot-Bold", "Didot")
        case .round:   return ("AvenirNext-Bold", "AvenirNext-Medium")
        case .display: return ("Futura-CondensedExtraBold", "Futura-Medium")
        }
    }

    /// Şablonun font adını bu aileye çevirir, kalınlığı koruyarak.
    public func postScriptName(preservingWeightOf original: String) -> String {
        let heavy = ["Bold", "Heavy", "Black", "ExtraBold", "Semibold", "DemiBold"]
        let isHeavy = heavy.contains { original.localizedCaseInsensitiveContains($0) }
        let names = postScriptNames
        return isHeavy ? names.bold : names.regular
    }

    public static func from(_ raw: String?) -> TextFontFamily? {
        guard let raw else { return nil }
        return TextFontFamily(rawValue: raw)
    }
}

public struct SlotAssignment: Codable, Equatable, Sendable {
    /// PHAsset localIdentifier veya dosya URL string'i.
    public var assetIdentifier: String
    public var kind: AssignedMediaKind
    public var crop: CropTransform
    /// Video için kullanıcının seçtiği başlangıç saniyesi.
    public var videoStart: Double
    /// Klip oynatma hızı çarpanı. 1 = normal, 2 = iki kat hızlı,
    /// 0,5 = ağır çekim. `Self.speedRange` ile sınırlanır.
    ///
    /// ŞABLONUN RİTMİ SABİT KALIR: hız, klibin sahne penceresini DEĞİŞTİRMEZ —
    /// pencereye sığdırılan KAYNAK bölümünü değiştirir. 3 sn'lik bir sahnede
    /// 2x, klibin 6 saniyesini o 3 saniyeye sığdırır; 0,5x ise 1,5 saniyesini
    /// yayar. Böylece kullanıcı aynı şablonda bazı klipleri hızlandırıp
    /// bazılarını yavaşlatabilir ve video süresi ile müzik hizası bozulmaz.
    public var speed: Double

    /// Kabul edilen hız aralığı. Üst sınır kaynak klibin tükenmesiyle de
    /// kısıtlıdır (klip yetmezse motor eldeki bölümü pencereye yayar).
    public static let speedRange: ClosedRange<Double> = 0.25...4

    public init(assetIdentifier: String,
                kind: AssignedMediaKind,
                crop: CropTransform = CropTransform(),
                videoStart: Double = 0,
                speed: Double = 1) {
        self.assetIdentifier = assetIdentifier
        self.kind = kind
        self.crop = crop
        self.videoStart = videoStart
        self.speed = Self.clampSpeed(speed)
    }

    private enum CodingKeys: String, CodingKey {
        case assetIdentifier, kind, crop, videoStart, speed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        assetIdentifier = try c.decode(String.self, forKey: .assetIdentifier)
        kind = try c.decode(AssignedMediaKind.self, forKey: .kind)
        crop = try c.decodeIfPresent(CropTransform.self, forKey: .crop) ?? CropTransform()
        videoStart = try c.decodeIfPresent(Double.self, forKey: .videoStart) ?? 0
        // Hız alanı taşımayan eski taslak = normal hız.
        speed = Self.clampSpeed(try c.decodeIfPresent(Double.self, forKey: .speed) ?? 1)
    }

    /// Aralık dışı (ya da bozuk: 0, negatif, NaN) hızı güvenli hale getirir —
    /// 0 bir zaman aralığını sıfıra ölçekler ve AVFoundation kompozisyonu
    /// reddeder.
    public static func clampSpeed(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(max(value, speedRange.lowerBound), speedRange.upperBound)
    }
}

public enum AssignedMediaKind: String, Codable, Sendable {
    case photo, video
}

/// Slot içinde kullanıcı kadrajı. Medya önce aspect-fill yerleşir,
/// sonra bu transform uygulanır. Offset'ler slot boyutuna normalize.
///
/// YÖN SÖZLEŞMESİ (iki export yolunda da aynı, `CropAndTrimTests` ile kilitli):
/// - `offsetY` büyüdükçe görüntü kadrajda **AŞAĞI** kayar (ekran yönü),
/// - `offsetX` büyüdükçe **SAĞA**,
/// - `scale` 1'den büyükse yakınlaştırır (kadrajda kaynağın daha azı görünür).
///
/// Montaj yolu CoreImage'da (y yukarı), klasik yol `CGAffineTransform` ile
/// çalışıyor; ikisinin aynı anlama geldiği ölçülerek doğrulandı — parmağı aşağı
/// sürükleyince şablon türüne göre farklı yöne kayan bir kadraj en sinir bozucu
/// hata türü olurdu.
public struct CropTransform: Codable, Equatable, Sendable {
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double

    public init(scale: Double = 1, offsetX: Double = 0, offsetY: Double = 0) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    /// Kullanıcının yakınlaştırma aralığı. Üstü yok: 4x'ten sonra 1080p kaynak
    /// bile blok blok görünür.
    public static let scaleRange: ClosedRange<Double> = 1...4

    public var isIdentity: Bool { self == CropTransform() }
}

public struct MusicSelection: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        /// Telifsiz kütüphanemizden (identifier = trackId).
        case library
        /// Kullanıcının kendi dosyası (identifier = dosya URL string'i).
        case userFile
    }

    public var source: Source
    public var identifier: String
    /// Parçanın hangi saniyesinden başlanacağı.
    public var start: Double

    public init(source: Source, identifier: String, start: Double = 0) {
        self.source = source
        self.identifier = identifier
        self.start = start
    }
}
