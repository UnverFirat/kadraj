import Foundation

/// Uygulamanın müzik kütüphanesindeki bir parça.
///
/// Parçanın kendisi dosya değil, tariftir (`score`); istenen uzunlukta
/// çalışma anında sentezlenir. Şablonların `audio.defaultTrackId` alanı
/// buradaki `id`'leri referanslar.
public struct MusicTrack: Identifiable, Equatable, Sendable {
    public enum Mood: String, CaseIterable, Sendable {
        case calm, warm, cinematic, energetic, playful, dramatic

        public var label: LocalizedText {
            switch self {
            case .calm:      return LocalizedText(["en": "Calm", "tr": "Sakin"])
            case .warm:      return LocalizedText(["en": "Warm", "tr": "Sıcak"])
            case .cinematic: return LocalizedText(["en": "Cinematic", "tr": "Sinematik"])
            case .energetic: return LocalizedText(["en": "Energetic", "tr": "Enerjik"])
            case .playful:   return LocalizedText(["en": "Playful", "tr": "Neşeli"])
            case .dramatic:  return LocalizedText(["en": "Dramatic", "tr": "Dramatik"])
            }
        }
    }

    public let id: String
    public let title: LocalizedText
    public let mood: Mood
    /// Ücretsiz kullanıcıya kilitli mi (paywall bunu okur; motor umursamaz).
    public let isPro: Bool
    public let score: MusicScore

    public var bpm: Int { Int(score.bpm.rounded()) }
}

/// Telifsiz müzik kütüphanesi.
///
/// TASARIM KARARI (telif): hazır müzik lisanslamak yerine parçaları kendimiz
/// sentezliyoruz (`AudioSynth`). Böylece lisans/atıf zinciri, dağıtım kısıtı ve
/// uygulama boyutu sorunu ortadan kalkar; her parça istenen süreye birebir
/// üretilir. İleride lisanslı katalog eklenirse `MusicTrack` aynı kalır, yalnız
/// `materialize` dosyayı indirir.
///
/// BESTE NOTU: desenler bilerek seyrek — sürekli 16'lık arpej ve her adımda
/// nota, sentezi "alarm" gibi duyuruyor. Uzun notalar (`-`), sus payları,
/// 7'li akorlar ve reverb ("space") parçaları müzik gibi tınlatan şeyler.
public enum MusicLibrary {

    // MARK: - Katalog

    public static let all: [MusicTrack] = [
        // --- Sakin ---
        MusicTrack(id: "calm-01", title: LocalizedText(["en": "Still Morning", "tr": "Sakin Sabah"]),
                   mood: .calm, isPro: false,
                   score: MusicScore(bpm: 72, rootMIDI: 60, scale: .major,
                                     progression: [0, 3, 5, 4], texture: .pad,
                                     bassPattern: "x-------x-------",
                                     leadPattern: "....2-------....",
                                     brightness: 0.32, space: 0.7)),
        MusicTrack(id: "ambient-01", title: LocalizedText(["en": "Open Sky", "tr": "Açık Gökyüzü"]),
                   mood: .calm, isPro: false,
                   score: MusicScore(bpm: 60, rootMIDI: 57, scale: .minor,
                                     progression: [0, 5, 3, 4], texture: .pad,
                                     bassPattern: "x---------------",
                                     leadPattern: "........4-------",
                                     brightness: 0.22, space: 0.85)),
        MusicTrack(id: "smooth-01", title: LocalizedText(["en": "Slow Drift", "tr": "Yavaş Akış"]),
                   mood: .calm, isPro: true,
                   score: MusicScore(bpm: 84, rootMIDI: 58, scale: .dorian,
                                     progression: [0, 3, 4, 3], texture: .keys,
                                     bassPattern: "x-------x---x---",
                                     leadPattern: "..2-----4-------",
                                     drums: .init(kick: "x.......x.......",
                                                  snare: "....x.......x...",
                                                  hat: "..x...x...x...x.", level: 0.45),
                                     brightness: 0.38, swing: 0.24, space: 0.55)),
        MusicTrack(id: "typewriter-01", title: LocalizedText(["en": "Quiet Desk", "tr": "Sessiz Masa"]),
                   mood: .calm, isPro: false,
                   score: MusicScore(bpm: 86, rootMIDI: 60, scale: .major,
                                     progression: [0, 4, 3, 4], texture: .keys,
                                     bassPattern: "x-------x-------",
                                     leadPattern: "0-------2-------",
                                     drums: .init(kick: "................",
                                                  hat: "..x.......x.....", level: 0.3),
                                     brightness: 0.3, space: 0.5)),

        // --- Sıcak ---
        MusicTrack(id: "warm-01", title: LocalizedText(["en": "Golden Hour", "tr": "Altın Saat"]),
                   mood: .warm, isPro: false,
                   score: MusicScore(bpm: 88, rootMIDI: 60, scale: .major,
                                     progression: [0, 5, 3, 4], texture: .keys,
                                     bassPattern: "x-------x---x---",
                                     leadPattern: "..2---4---------",
                                     drums: .init(kick: "x.......x.......",
                                                  snare: "....x.......x...",
                                                  hat: "..x...x...x...x.", level: 0.4),
                                     brightness: 0.42, space: 0.5)),
        MusicTrack(id: "acoustic-01", title: LocalizedText(["en": "Porch Light", "tr": "Veranda Işığı"]),
                   mood: .warm, isPro: false,
                   score: MusicScore(bpm: 94, rootMIDI: 62, scale: .major,
                                     progression: [0, 4, 5, 3], texture: .pluck,
                                     bassPattern: "x-------x-------",
                                     leadPattern: "0-----2---------",
                                     drums: .init(kick: "x.......x.......",
                                                  snare: "....x.......x...", level: 0.35),
                                     brightness: 0.5, space: 0.45)),
        MusicTrack(id: "sweet-01", title: LocalizedText(["en": "Little Things", "tr": "Küçük Şeyler"]),
                   mood: .warm, isPro: false,
                   score: MusicScore(bpm: 90, rootMIDI: 60, scale: .pentatonic,
                                     progression: [0, 2, 3, 1], texture: .pluck,
                                     bassPattern: "x-------x-------",
                                     leadPattern: "..1-----2-------",
                                     drums: .init(kick: "x.......x.......",
                                                  hat: "..x...x...x...x.", level: 0.32),
                                     brightness: 0.52, space: 0.5)),
        MusicTrack(id: "chill-01", title: LocalizedText(["en": "Late Study", "tr": "Geç Saat"]),
                   mood: .warm, isPro: true,
                   score: MusicScore(bpm: 76, rootMIDI: 58, scale: .minor,
                                     progression: [0, 5, 3, 4], texture: .keys,
                                     bassPattern: "x-----x-x-------",
                                     leadPattern: "....3-------....",
                                     drums: .init(kick: "x.....x.x.......",
                                                  snare: "....x.......x...",
                                                  hat: "..x...x...x...x.", level: 0.42),
                                     brightness: 0.32, swing: 0.3, space: 0.6)),

        // --- Sinematik / dramatik ---
        MusicTrack(id: "cinematic-01", title: LocalizedText(["en": "Wide Frame", "tr": "Geniş Kadraj"]),
                   mood: .cinematic, isPro: false,
                   score: MusicScore(bpm: 66, rootMIDI: 55, scale: .minor,
                                     progression: [0, 0, 5, 3], texture: .pad,
                                     bassPattern: "x-------x-------",
                                     leadPattern: "........4-------",
                                     drums: .init(kick: "x.......x.......", level: 0.3),
                                     brightness: 0.26, space: 0.9)),
        MusicTrack(id: "dreamy-01", title: LocalizedText(["en": "Night Drive", "tr": "Gece Yolculuğu"]),
                   mood: .cinematic, isPro: false,
                   score: MusicScore(bpm: 80, rootMIDI: 60, scale: .lydian,
                                     progression: [0, 3, 1, 4], texture: .keys,
                                     bassPattern: "x-------x-------",
                                     leadPattern: "..4-------2-----",
                                     drums: .init(kick: "x.......x.......",
                                                  hat: "..x...x...x...x.", level: 0.3),
                                     brightness: 0.58, space: 0.75)),
        MusicTrack(id: "impact-01", title: LocalizedText(["en": "Breaking Point", "tr": "Kırılma Anı"]),
                   mood: .dramatic, isPro: true,
                   score: MusicScore(bpm: 92, rootMIDI: 53, scale: .minor,
                                     progression: [0, 0, 4, 4], texture: .pad,
                                     bassPattern: "x---x---x---x---",
                                     leadPattern: "0-------........",
                                     drums: .init(kick: "x...x...x...x...",
                                                  snare: "........x.......", level: 0.75),
                                     brightness: 0.34, space: 0.7)),
        MusicTrack(id: "anticipation-01", title: LocalizedText(["en": "Countdown", "tr": "Geri Sayım"]),
                   mood: .dramatic, isPro: false,
                   // Gerilim yükselen gam DEĞİL, ısrarlı nabız + açılan filtre ile
                   // kurulur (yükselen dizi kelimenin tam anlamıyla alarm sesi).
                   score: MusicScore(bpm: 98, rootMIDI: 57, scale: .minor,
                                     progression: [0, 0, 0, 4], texture: .pad,
                                     bassPattern: "x---x---x---x---",
                                     leadPattern: "....4-------....",
                                     drums: .init(kick: "x.......x.......",
                                                  hat: "x.x.x.x.x.x.x.x.", level: 0.5),
                                     brightness: 0.42, space: 0.6)),

        // --- Enerjik ---
        MusicTrack(id: "upbeat-01", title: LocalizedText(["en": "City Run", "tr": "Şehir Koşusu"]),
                   mood: .energetic, isPro: false,
                   score: MusicScore(bpm: 116, rootMIDI: 60, scale: .major,
                                     progression: [0, 4, 5, 3], texture: .pluck,
                                     bassPattern: "x---x---x---x---",
                                     leadPattern: "0---2---4-------",
                                     drums: .init(kick: "x...x...x...x...",
                                                  snare: "....x.......x...",
                                                  hat: "..x...x...x...x.", level: 0.85),
                                     brightness: 0.55, space: 0.4)),
        MusicTrack(id: "energetic-01", title: LocalizedText(["en": "Push", "tr": "İvme"]),
                   mood: .energetic, isPro: false,
                   score: MusicScore(bpm: 124, rootMIDI: 57, scale: .minor,
                                     progression: [0, 0, 5, 4], texture: .pluck,
                                     bassPattern: "x---x---x-x-x---",
                                     leadPattern: "0---3-------2---",
                                     drums: .init(kick: "x...x...x...x...",
                                                  snare: "....x.......x...",
                                                  hat: "x.x.x.x.x.x.x.x.", level: 0.9),
                                     brightness: 0.55, space: 0.35)),
        MusicTrack(id: "beat-01", title: LocalizedText(["en": "Cutting Room", "tr": "Kurgu Odası"]),
                   mood: .energetic, isPro: true,
                   // Yalnız bas+davul bırakılınca mixte orta bölge boş kalıyordu
                   // (ölçüm: 300-800 Hz %0.6) — seyrek keys akoru gövde veriyor.
                   score: MusicScore(bpm: 128, rootMIDI: 55, scale: .minor,
                                     progression: [0, 0, 3, 4], texture: .keys,
                                     bassPattern: "x-x---x-x---x---",
                                     leadPattern: "0-------3-------",
                                     drums: .init(kick: "x...x...x..x.x..",
                                                  snare: "....x.......x...",
                                                  hat: "x.xx..xxx.xx.xxx", level: 0.95),
                                     brightness: 0.48, space: 0.3)),
        MusicTrack(id: "punchy-01", title: LocalizedText(["en": "Headline", "tr": "Manşet"]),
                   mood: .energetic, isPro: false,
                   score: MusicScore(bpm: 120, rootMIDI: 58, scale: .minor,
                                     progression: [0, 4, 0, 5], texture: .none,
                                     bassPattern: "x---x---x---x---",
                                     leadPattern: "0-------4-------",
                                     drums: .init(kick: "x...x...x...x...",
                                                  snare: "....x.......x...",
                                                  hat: "..x...x...x...x.", level: 0.9),
                                     brightness: 0.5, space: 0.35)),
        MusicTrack(id: "groovy-01", title: LocalizedText(["en": "Top Five", "tr": "İlk Beş"]),
                   mood: .energetic, isPro: true,
                   score: MusicScore(bpm: 102, rootMIDI: 58, scale: .dorian,
                                     progression: [0, 3, 4, 3], texture: .keys,
                                     bassPattern: "x--x--x---x--x--",
                                     leadPattern: "..2-----4-------",
                                     drums: .init(kick: "x..x....x..x....",
                                                  snare: "....x.......x...",
                                                  hat: "..x...x...x...x.", level: 0.8),
                                     brightness: 0.46, swing: 0.2, space: 0.45)),

        // --- Neşeli ---
        MusicTrack(id: "playful-01", title: LocalizedText(["en": "Confetti", "tr": "Konfeti"]),
                   mood: .playful, isPro: false,
                   score: MusicScore(bpm: 108, rootMIDI: 62, scale: .pentatonic,
                                     progression: [0, 1, 3, 2], texture: .pluck,
                                     bassPattern: "x---x---x---x---",
                                     leadPattern: "0---1-------3---",
                                     drums: .init(kick: "x...x...x...x...",
                                                  snare: "....x.......x...",
                                                  hat: "..x...x...x...x.", level: 0.75),
                                     brightness: 0.62, space: 0.45)),
        MusicTrack(id: "bright-01", title: LocalizedText(["en": "Good Days", "tr": "Güzel Günler"]),
                   mood: .playful, isPro: false,
                   score: MusicScore(bpm: 104, rootMIDI: 60, scale: .major,
                                     progression: [0, 3, 4, 4], texture: .pluck,
                                     bassPattern: "x---x---x-------",
                                     leadPattern: "2---4-------2---",
                                     drums: .init(kick: "x.......x.......",
                                                  snare: "....x.......x...",
                                                  hat: "..x...x...x...x.", level: 0.6),
                                     brightness: 0.6, space: 0.5)),
        MusicTrack(id: "wanderlust-01", title: LocalizedText(["en": "Somewhere New", "tr": "Yeni Bir Yer"]),
                   mood: .playful, isPro: true,
                   score: MusicScore(bpm: 106, rootMIDI: 62, scale: .mixolydian,
                                     progression: [0, 4, 5, 3], texture: .pluck,
                                     bassPattern: "x---x---x---x---",
                                     leadPattern: "0---2-----4-----",
                                     drums: .init(kick: "x...x...x...x...",
                                                  snare: "....x.......x...",
                                                  hat: "x.x.x.x.x.x.x.x.", level: 0.72),
                                     brightness: 0.58, space: 0.5)),
        MusicTrack(id: "clean-01", title: LocalizedText(["en": "Showroom", "tr": "Vitrin"]),
                   mood: .playful, isPro: false,
                   score: MusicScore(bpm: 98, rootMIDI: 60, scale: .major,
                                     progression: [0, 4, 0, 4], texture: .keys,
                                     bassPattern: "x-------x-------",
                                     leadPattern: "4-------2-------",
                                     drums: .init(kick: "x.......x.......",
                                                  hat: "..x...x...x...x.", level: 0.45),
                                     brightness: 0.52, space: 0.5))
    ]

    public static func track(id: String) -> MusicTrack? {
        all.first { $0.id == id }
    }

    public static func tracks(mood: MusicTrack.Mood) -> [MusicTrack] {
        all.filter { $0.mood == mood }
    }

    /// Şablonun önerdiği parça (yoksa katalogun ilk sakin parçası).
    public static func defaultTrack(for template: Template) -> MusicTrack? {
        if let id = template.audio?.defaultTrackId, let track = track(id: id) { return track }
        return all.first
    }

    // MARK: - Dosyaya alma (cache)

    public enum MusicError: Error {
        case unknownTrack(String)
    }

    /// Parçayı `duration` saniyelik WAV olarak `directory` altına yazar ve URL
    /// döner. Aynı (parça, süre) ikilisi için dosya varsa yeniden üretilmez —
    /// sentez her seferinde birkaç yüz ms, boşuna ödemeyelim.
    @discardableResult
    public static func materialize(trackID: String,
                                   duration: Double,
                                   in directory: URL) throws -> URL {
        guard let track = track(id: trackID) else { throw MusicError.unknownTrack(trackID) }
        let seconds = max(1, (duration * 10).rounded() / 10)
        // Dosya adında sentez sürümü var: motor değişince eski cache kendiliğinden
        // geçersizleşir (yoksa kullanıcı eski, kötü tınlayan parçayı duymaya
        // devam ederdi).
        let file = directory.appendingPathComponent(
            "\(track.id)-s\(AudioSynth.version)-\(Int(seconds * 10)).wav")
        if FileManager.default.fileExists(atPath: file.path) { return file }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Seed parça kimliğinden türetilir: aynı parça her cihazda birebir aynı,
        // farklı parçaların gürültüsü birbirini tekrar etmez.
        let seed = track.id.unicodeScalars.reduce(UInt64(0x5EED)) { $0 &* 131 &+ UInt64($1.value) }
        let buffer = AudioSynth.render(score: track.score, duration: seconds, seed: seed)
        try AudioSynth.wavData(buffer).write(to: file, options: .atomic)
        return file
    }

    /// Uygulamanın müzik cache dizini (Caches altında; sistem gerekirse siler).
    public static func defaultCacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("music", isDirectory: true)
    }
}
