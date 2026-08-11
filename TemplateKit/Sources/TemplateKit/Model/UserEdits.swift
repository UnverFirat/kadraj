import Foundation

/// Kullanıcının bir şablon üzerinde yaptığı tüm değişiklikler.
/// Şablonun kendisi asla mutate edilmez; taslak kaydetme = bu yapının serialize'ı.
public struct UserEdits: Codable, Equatable, Sendable {
    /// slotIndex -> atanan medya.
    public var slots: [Int: SlotAssignment]
    /// Katman id -> kullanıcı metni (şablondaki `default` yerine geçer).
    public var textOverrides: [String: String]
    /// Rol -> hex. Şablon paletinin üstüne merge edilir (renk şeması değiştirme).
    public var paletteOverride: [String: String]?
    public var music: MusicSelection?

    public init(slots: [Int: SlotAssignment] = [:],
                textOverrides: [String: String] = [:],
                paletteOverride: [String: String]? = nil,
                music: MusicSelection? = nil) {
        self.slots = slots
        self.textOverrides = textOverrides
        self.paletteOverride = paletteOverride
        self.music = music
    }
}

public struct SlotAssignment: Codable, Equatable, Sendable {
    /// PHAsset localIdentifier veya dosya URL string'i.
    public var assetIdentifier: String
    public var kind: AssignedMediaKind
    public var crop: CropTransform
    /// Video için kullanıcının seçtiği başlangıç saniyesi.
    public var videoStart: Double

    public init(assetIdentifier: String,
                kind: AssignedMediaKind,
                crop: CropTransform = CropTransform(),
                videoStart: Double = 0) {
        self.assetIdentifier = assetIdentifier
        self.kind = kind
        self.crop = crop
        self.videoStart = videoStart
    }
}

public enum AssignedMediaKind: String, Codable, Sendable {
    case photo, video
}

/// Slot içinde kullanıcı kadrajı. Medya önce aspect-fill yerleşir,
/// sonra bu transform uygulanır. Offset'ler slot boyutuna normalize.
public struct CropTransform: Codable, Equatable, Sendable {
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double

    public init(scale: Double = 1, offsetX: Double = 0, offsetY: Double = 0) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
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
