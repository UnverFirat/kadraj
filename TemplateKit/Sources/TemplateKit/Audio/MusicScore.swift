import Foundation

/// Bir parçanın "notası" — telifsizliğin kaynağı burası: kütüphanedeki her parça
/// bu tarifle ÇALIŞMA ANINDA sentezlenir. Depoda ses dosyası yok, lisanslı
/// kütüphane yok; müzik bizim kodumuzun deterministik çıktısı.
///
/// Bir bar = 4/4, 16 adım (onaltılık). Desenler 16 karakterlik string'ler:
///   `x` vur, `.` sus, `-` önceki notayı uzat, `0-9` gam derecesi (melodi).
public struct MusicScore: Sendable, Equatable {

    public enum Scale: String, Sendable, Equatable {
        case major, minor, dorian, pentatonic, lydian, mixolydian

        /// Kök nota üstündeki yarım ton adımları.
        var steps: [Int] {
            switch self {
            case .major:      return [0, 2, 4, 5, 7, 9, 11]
            case .minor:      return [0, 2, 3, 5, 7, 8, 10]
            case .dorian:     return [0, 2, 3, 5, 7, 9, 10]
            case .pentatonic: return [0, 3, 5, 7, 10]
            case .lydian:     return [0, 2, 4, 6, 7, 9, 11]
            case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
            }
        }
    }

    /// Akor katmanının tınısı (her biri ayrı bir synth patch'i).
    public enum Texture: String, Sendable, Equatable {
        /// Yavaş açılan, filtreli yumuşak ped (ambient/sinematik).
        case pad
        /// Parmakla çalınan kısa akor (akustik/temiz).
        case pluck
        /// Elektrik piyano (lo-fi/chill/sıcak).
        case keys
        /// Akor yok — yalnız bas + davul + melodi (vurucu/ritmik).
        case none
    }

    public struct DrumKit: Sendable, Equatable {
        public var kick: String
        public var snare: String
        /// `x` kapalı hat, `o` açık hat.
        public var hat: String
        /// 0-1; davul katmanının genel seviyesi.
        public var level: Double

        public init(kick: String, snare: String = "................",
                    hat: String = "................", level: Double = 1) {
            self.kick = kick
            self.snare = snare
            self.hat = hat
            self.level = level
        }

        public static let none = DrumKit(kick: "................", level: 0)
    }

    public var bpm: Double
    /// Kök notanın MIDI numarası (60 = orta Do).
    public var rootMIDI: Int
    public var scale: Scale
    /// Bar başına akor derecesi (gam derecesi, 0 tabanlı). Bar sayısı bunun
    /// uzunluğunca döner.
    public var progression: [Int]
    public var texture: Texture
    /// Bas deseni (16 adım): `x` = akorun kökü, `.` sus, `-` uzat.
    public var bassPattern: String
    /// Melodi deseni (16 adım): rakam = akorun kökü üstündeki gam derecesi.
    public var leadPattern: String
    public var drums: DrumKit
    /// 0-1; filtre kesim frekansını açar (parlaklık). Düşük = yumuşak/koyu.
    public var brightness: Double
    /// Onaltılık swing miktarı (0 = düz, 0.2 ≈ hafif groove).
    public var swing: Double
    /// 0-1; reverb (mekân) miktarı. Ped/sinematik parçalarda yüksek.
    public var space: Double
    /// Akorlara 7'li ekler — üçlü akorun "çocuksu" tınısını yumuşatır.
    public var seventhChords: Bool
    /// Melodinin oktavı (0 = kök oktav, 1 = bir üst).
    public var leadOctave: Int

    public init(bpm: Double,
                rootMIDI: Int,
                scale: Scale,
                progression: [Int],
                texture: Texture,
                bassPattern: String = "x.......x.......",
                leadPattern: String = "................",
                drums: DrumKit = .none,
                brightness: Double = 0.5,
                swing: Double = 0,
                space: Double = 0.35,
                seventhChords: Bool = true,
                leadOctave: Int = 1) {
        self.bpm = bpm
        self.rootMIDI = rootMIDI
        self.scale = scale
        self.progression = progression
        self.texture = texture
        self.bassPattern = bassPattern
        self.leadPattern = leadPattern
        self.drums = drums
        self.brightness = brightness
        self.swing = swing
        self.space = space
        self.seventhChords = seventhChords
        self.leadOctave = leadOctave
    }

    /// Bir barın saniye cinsinden süresi.
    public var barDuration: Double { 4 * 60 / bpm }

    /// Gam derecesinden (oktav taşmaları dahil) MIDI notası.
    public func midi(degree: Int, octave: Int = 0) -> Int {
        let steps = scale.steps
        let count = steps.count
        // Swift'in % operatörü negatifte negatif döner; gam sarmasında kaymayı
        // önlemek için pozitif kalıntı hesaplanır.
        let index = ((degree % count) + count) % count
        let octaveShift = Int(floor(Double(degree) / Double(count)))
        return rootMIDI + steps[index] + 12 * (octaveShift + octave)
    }

    /// Akor sesleri (1-3-5, istenirse 7). Ped/keys için "close voicing":
    /// notalar tek oktava toplanır ve 60-79 aralığına yerleştirilir — pes
    /// üçlüler çamur yapar, bu yüzden akor bas bölgesinde çalınmaz.
    public func chordVoicing(degree: Int) -> [Int] {
        var degrees = [degree, degree + 2, degree + 4]
        if seventhChords { degrees.append(degree + 6) }
        return degrees.map { raw -> Int in
            var note = midi(degree: raw)
            while note < 60 { note += 12 }
            while note > 79 { note -= 12 }
            return note
        }
    }

    /// MIDI -> frekans (A4 = 440 Hz).
    public static func frequency(midi: Int) -> Double {
        440 * pow(2, Double(midi - 69) / 12)
    }

    /// MIDI -> frekans, sent cinsinden detune ile.
    public static func frequency(midi: Int, cents: Double) -> Double {
        frequency(midi: midi) * pow(2, cents / 1200)
    }
}
