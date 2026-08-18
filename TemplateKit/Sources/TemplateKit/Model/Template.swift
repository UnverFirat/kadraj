import Foundation

// MARK: - Template

/// Bir şablonun tip güvenli hali. `docs/template-format.md`'deki sözleşmenin
/// birebir karşılığıdır. Saf Foundation — render katmanı ayrı dosyalarda.
public struct Template: Codable, Equatable, Sendable, Identifiable {
    public var schemaVersion: Int
    public var id: String
    public var name: LocalizedText
    public var category: String
    public var isPro: Bool
    public var canvas: Canvas
    /// v1 (sahnesiz) şablonlarda zorunlu toplam süre. Sahneli şablonlarda
    /// opsiyoneldir ve yok sayılır — süre sahnelerden hesaplanır.
    /// JSON anahtarı: "duration". Kod içinde her zaman `totalDuration` kullanın.
    public var explicitDuration: Double?
    /// Renk rolü -> hex ("#RRGGBB" veya "#RRGGBBAA").
    public var palette: [String: String]
    public var audio: AudioDefaults?
    /// Sinematik overlay (vignette/grain) — tüm kareye, en üstte. nil = yok.
    public var overlay: OverlaySpec?
    /// Medyanın üstüne düşen metinlerin okunabilirlik koruması.
    /// nil = alan JSON'da yok = `.auto` (güvenli varsayılan). Bu yüzden
    /// OPSİYONEL: 127 şablonun hiçbirine dokunmadan davranış devreye girer,
    /// dokunmak isteyen şablon `"textLegibility": "off"` yazar.
    public var textLegibility: TextLegibility?
    /// Çizim sırasına göre; ilk eleman en altta. Sahneli şablonlarda bunlar
    /// TÜM video boyunca görünen global overlay katmanlarıdır (en üst z'de).
    public var layers: [Layer]
    /// v2: ardışık sahneler (montaj). nil = tek sahneli klasik şablon.
    public var scenes: [TemplateScene]?

    public static let supportedSchemaVersions = 1...2

    /// Alan yoksa geçerli olan mod. Kod her yerde bunu okur, ham alanı değil.
    public var legibility: TextLegibility { textLegibility ?? .auto }

    /// Şablonun gerçek toplam süresi. Sahneli şablonlarda geçiş örtüşmeleri
    /// düşülmüş montaj süresi; klasikte `explicitDuration`.
    public var totalDuration: Double {
        if let scenes, !scenes.isEmpty {
            return MontageTimeline(scenes: scenes).totalDuration
        }
        return explicitDuration ?? 0
    }

    /// Şablondaki medya slotları: (slot indeksi, video kabul ediyor mu),
    /// slot indeksine göre sıralı ve tekil. Sahneli şablonda aynı slot birden
    /// çok sahnede geçebilir — burada bir kez döner.
    ///
    /// Editör, galeri ve varlık üreteci aynı sırayı görsün diye tek yerde.
    public var mediaSlots: [(slot: Int, allowsVideo: Bool)] {
        var map: [Int: Bool] = [:]
        func scan(_ layers: [Layer]) {
            for layer in layers {
                if case .mediaSlot(let content) = layer.content {
                    map[content.slotIndex] = content.media.allowsVideo
                }
            }
        }
        scenes?.forEach { scan($0.layers) }
        scan(layers)
        return map.map { (slot: $0.key, allowsVideo: $0.value) }.sorted { $0.slot < $1.slot }
    }

    /// Metin katmanlarının varsayılan içerikleri (katman id → metin), katman
    /// sırasına göre. `UserEdits.textOverrides` ile aynı anahtar uzayı.
    public func defaultTexts(languageCode: String? = nil) -> [String: String] {
        var texts: [String: String] = [:]
        func scan(_ layers: [Layer]) {
            for layer in layers {
                if case .text(let content) = layer.content {
                    texts[layer.id] = content.default.resolved(languageCode: languageCode)
                }
            }
        }
        scenes?.forEach { scan($0.layers) }
        scan(layers)
        return texts
    }

    public init(schemaVersion: Int = 1,
                id: String,
                name: LocalizedText,
                category: String,
                isPro: Bool = false,
                canvas: Canvas = .story,
                duration: Double? = nil,
                palette: [String: String],
                audio: AudioDefaults? = nil,
                overlay: OverlaySpec? = nil,
                textLegibility: TextLegibility? = nil,
                layers: [Layer] = [],
                scenes: [TemplateScene]? = nil) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.category = category
        self.isPro = isPro
        self.canvas = canvas
        self.explicitDuration = duration
        self.palette = palette
        self.audio = audio
        self.overlay = overlay
        self.textLegibility = textLegibility
        self.layers = layers
        self.scenes = scenes
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, category, isPro, canvas
        case explicitDuration = "duration"
        case palette, audio, overlay, textLegibility, layers, scenes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(LocalizedText.self, forKey: .name)
        category = try c.decode(String.self, forKey: .category)
        isPro = try c.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        canvas = try c.decodeIfPresent(Canvas.self, forKey: .canvas) ?? .story
        explicitDuration = try c.decodeIfPresent(Double.self, forKey: .explicitDuration)
        palette = try c.decode([String: String].self, forKey: .palette)
        audio = try c.decodeIfPresent(AudioDefaults.self, forKey: .audio)
        overlay = try c.decodeIfPresent(OverlaySpec.self, forKey: .overlay)
        textLegibility = try c.decodeIfPresent(TextLegibility.self, forKey: .textLegibility)
        layers = try c.decodeIfPresent([Layer].self, forKey: .layers) ?? []
        scenes = try c.decodeIfPresent([TemplateScene].self, forKey: .scenes)
    }

    /// Render için düzleştirilmiş katman listesi.
    ///
    /// Sahneli şablonlarda: her sahnenin katmanları, sahnenin mutlak
    /// başlangıcına ötelenmiş timing ile döner; TÜM medya slotları (video ve
    /// foto) HARİÇ tutulur — onlar 1. geçişte montaj videosuna yakılır (kolaj +
    /// geçiş). Global `layers` en üste (sona) eklenir. Sahnesiz şablonlarda
    /// `layers` olduğu gibi döner.
    public func flattenedLayersForRender(edits: UserEdits) -> [Layer] {
        guard let scenes, !scenes.isEmpty else { return Layer.bindingPlatesToLabels(layers) }
        let timeline = MontageTimeline(scenes: scenes)
        var result: [Layer] = []
        for window in timeline.windows {
            // Plaka/etiket eşleşmesi SAHNE İÇİNDE aranır: farklı sahnelerin
            // katmanları aynı kadrajda olsa bile aynı nesne değildir.
            for var layer in Layer.bindingPlatesToLabels(scenes[window.index].layers) {
                // Montaj sahnelerindeki her medya slotu 1. geçişe gider; burada
                // yalnız grafik/metin katmanları bırakılır.
                if case .mediaSlot = layer.content { continue }
                let local = layer.timing.window(templateDuration: scenes[window.index].duration)
                layer.timing = Timing(start: window.start + local.start,
                                      duration: local.end - local.start)
                result.append(layer)
            }
        }
        result.append(contentsOf: Layer.bindingPlatesToLabels(layers))
        return result
    }

    /// TABAN VİDEOYA yakılmış kullanıcı medyasının kadrajda durduğu
    /// dikdörtgenler, mutlak şablon zamanıyla. Klasik şablonda boştur — orada
    /// medya slotu render listesinde gerçek bir katman olarak durur ve
    /// z-sırası kendi başına anlamlıdır.
    ///
    /// NEDEN GEREKLİ: montaj yolunda sahnelerin medya slotları
    /// `flattenedLayersForRender`'dan ÇIKARILIR (1. geçişte tek videoya
    /// yakılırlar), yani render listesine bakan kod medyanın nerede olduğunu
    /// göremez. Taban videonun tüm kanvası kaplaması "her yer medya" DEMEK
    /// DEĞİLDİR — slot dışında kalan alanı sahne arka plan rengi doldurur
    /// (`spa-calm-01`: medya üstteki %56, alt yarısı krem zemin).
    public func prerenderedMediaRegions() -> [MediaRegion] {
        guard let scenes, !scenes.isEmpty else { return [] }
        var result: [MediaRegion] = []
        for window in MontageTimeline(scenes: scenes).windows {
            let scene = scenes[window.index]
            for layer in scene.layers {
                guard case .mediaSlot = layer.content else { continue }
                let local = layer.timing.window(templateDuration: scene.duration)
                result.append(MediaRegion(frame: layer.frame,
                                          start: window.start + local.start,
                                          end: window.start + local.end))
            }
        }
        return result
    }

    /// Paleti (varsa kullanıcı override'ı ile) çözümlenmiş renklere çevirir.
    /// Geçersiz hex değerleri atlanır; validator bunları yükleme anında yakalar.
    public func resolvedPalette(override: [String: String]? = nil) -> [String: RGBAColor] {
        var merged = palette
        if let override {
            merged.merge(override) { _, new in new }
        }
        return merged.compactMapValues(RGBAColor.init(hex:))
    }
}

/// Kullanıcı medyasının kadrajda durduğu bir dikdörtgen + zaman aralığı.
public struct MediaRegion: Equatable, Sendable {
    public var frame: NormalizedRect
    public var start: Double
    public var end: Double

    public init(frame: NormalizedRect, start: Double, end: Double) {
        self.frame = frame
        self.start = start
        self.end = end
    }
}

// MARK: - Scenes (v2)

/// Montaj şablonunun bir sahnesi: kendi süresi, kendi katmanları
/// (katman timing'leri SAHNE zamanına görelidir) ve bir sonraki sahneye geçişi.
public struct TemplateScene: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var duration: Double
    public var layers: [Layer]
    /// Bir SONRAKİ sahneye geçiş; son sahnede yok sayılır.
    public var transition: TransitionSpec?

    public init(id: String, duration: Double, layers: [Layer] = [],
                transition: TransitionSpec? = nil) {
        self.id = id
        self.duration = duration
        self.layers = layers
        self.transition = transition
    }

    private enum CodingKeys: String, CodingKey { case id, duration, layers, transition }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        duration = try c.decode(Double.self, forKey: .duration)
        layers = try c.decodeIfPresent([Layer].self, forKey: .layers) ?? []
        transition = try c.decodeIfPresent(TransitionSpec.self, forKey: .transition)
    }
}

public struct TransitionSpec: Codable, Equatable, Sendable {
    /// "cut" | "crossDissolve" | "blurDissolve". Bilerek String: motor
    /// tanımadığı stili cut'a düşürür (preset'lerle aynı ileri uyumluluk kuralı).
    public var style: String
    /// Geçiş penceresi (saniye). İki sahne bu süre kadar örtüşür;
    /// toplam süre = sahne sürelerinin toplamı - geçiş süreleri.
    public var duration: Double

    public init(style: String, duration: Double) {
        self.style = style
        self.duration = duration
    }
}

// MARK: - Building blocks

/// Dil kodu -> metin. `en` her şablonda zorunlu (validator kontrol eder).
public struct LocalizedText: Codable, Equatable, Sendable {
    public var values: [String: String]

    public init(_ values: [String: String]) { self.values = values }

    public init(from decoder: Decoder) throws {
        values = try decoder.singleValueContainer().decode([String: String].self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(values)
    }

    public func resolved(languageCode: String? = nil) -> String {
        let code = languageCode ?? Locale.current.language.languageCode?.identifier ?? "en"
        return values[code] ?? values["en"] ?? values.values.first ?? ""
    }
}

public struct Canvas: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var fps: Int

    public init(width: Int, height: Int, fps: Int) {
        self.width = width
        self.height = height
        self.fps = fps
    }

    /// MVP'nin tek kanvası: 1080x1920 @30fps.
    public static let story = Canvas(width: 1080, height: 1920, fps: 30)
}

/// Normalize dikdörtgen: `x`/`y` MERKEZ noktasıdır, tüm değerler kanvas oranı (0-1).
public struct NormalizedRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x - width / 2 }
    public var maxX: Double { x + width / 2 }
    public var minY: Double { y - height / 2 }
    public var maxY: Double { y + height / 2 }

    /// `other` bu dikdörtgenin içinde mi (normalize kanvas oranında pay ile)?
    public func contains(_ other: NormalizedRect, tolerance: Double = 0) -> Bool {
        other.minX >= minX - tolerance && other.maxX <= maxX + tolerance
            && other.minY >= minY - tolerance && other.maxY <= maxY + tolerance
    }

    /// Kesişen alan (normalize birim kare oranında). 0 = değmiyor.
    public func intersectionArea(_ other: NormalizedRect) -> Double {
        let w = min(maxX, other.maxX) - max(minX, other.minX)
        let h = min(maxY, other.maxY) - max(minY, other.minY)
        return w > 0 && h > 0 ? w * h : 0
    }
}

// MARK: - Okunabilirlik

/// Medyanın üstüne düşen metinlerin okunabilirlik koruması (bkz.
/// `TemplateLayerBuilder` — koyu/açık yarı saydam hap + tam opak yazı).
public enum TextLegibility: String, Codable, Sendable {
    /// Varsayılan: YALNIZ altında kullanıcı medyası kalan metinlere uygulanır.
    case auto
    /// Motor hiç dokunmaz — korumayı kendi tasarımıyla çözen şablonlar için.
    case off
    /// Zeminden bağımsız her metne uygulanır (bilinçli "sticker" tipografisi).
    case always

    /// Bilinmeyen değer `.auto`'ya düşer: preset/geçiş stilleriyle aynı ileri
    /// uyumluluk kuralı — yeni bir mod eklenirse eski uygulama çökmez, güvenli
    /// davranışa döner.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TextLegibility(rawValue: raw) ?? .auto
    }
}

/// Katmanın sahnede olduğu zaman aralığı (saniye).
/// `duration` yoksa şablon sonuna kadar görünür.
public struct Timing: Codable, Equatable, Sendable {
    public var start: Double
    public var duration: Double?

    public init(start: Double = 0, duration: Double? = nil) {
        self.start = start
        self.duration = duration
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = try c.decodeIfPresent(Double.self, forKey: .start) ?? 0
        duration = try c.decodeIfPresent(Double.self, forKey: .duration)
    }

    public func window(templateDuration: Double) -> (start: Double, end: Double) {
        let end = duration.map { min(start + $0, templateDuration) } ?? templateDuration
        return (start, end)
    }
}

/// Sinematik overlay efektleri (tüm kareye, en üstte). Şablon geneli.
public struct OverlaySpec: Codable, Equatable, Sendable {
    /// Kenar karartma gücü (0–1).
    public var vignette: Double
    /// Film tanesi yoğunluğu (0–1).
    public var grain: Double

    public init(vignette: Double = 0, grain: Double = 0) {
        self.vignette = vignette
        self.grain = grain
    }

    private enum CodingKeys: String, CodingKey { case vignette, grain }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vignette = try c.decodeIfPresent(Double.self, forKey: .vignette) ?? 0
        grain = try c.decodeIfPresent(Double.self, forKey: .grain) ?? 0
    }
}

public struct AudioDefaults: Codable, Equatable, Sendable {
    public var defaultTrackId: String?
    public var volume: Double

    public init(defaultTrackId: String? = nil, volume: Double = 1.0) {
        self.defaultTrackId = defaultTrackId
        self.volume = volume
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultTrackId = try c.decodeIfPresent(String.self, forKey: .defaultTrackId)
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 1.0
    }
}

// MARK: - Animation

public enum AnimationRole: String, Codable, Sendable {
    case `in`, out, loop
}

public enum Easing: String, Codable, Sendable {
    case linear, easeIn, easeOut, easeInOut, spring
}

public struct AnimationSpec: Codable, Equatable, Sendable {
    public var role: AnimationRole
    /// Bilerek String (enum değil): motor tanımadığı preset'i atlar,
    /// eski uygulama yeni şablonda çökmez.
    public var preset: String
    public var delay: Double
    public var duration: Double
    public var easing: Easing
    public var params: [String: JSONValue]

    public init(role: AnimationRole,
                preset: String,
                delay: Double = 0,
                duration: Double,
                easing: Easing = .easeOut,
                params: [String: JSONValue] = [:]) {
        self.role = role
        self.preset = preset
        self.delay = delay
        self.duration = duration
        self.easing = easing
        self.params = params
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        role = try c.decode(AnimationRole.self, forKey: .role)
        preset = try c.decode(String.self, forKey: .preset)
        delay = try c.decodeIfPresent(Double.self, forKey: .delay) ?? 0
        duration = try c.decode(Double.self, forKey: .duration)
        easing = try c.decodeIfPresent(Easing.self, forKey: .easing) ?? .easeOut
        params = try c.decodeIfPresent([String: JSONValue].self, forKey: .params) ?? [:]
    }
}

// MARK: - Layer

public struct Layer: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var frame: NormalizedRect
    /// Derece cinsinden, saat yönü.
    public var rotation: Double
    public var opacity: Double
    public var timing: Timing
    public var animations: [AnimationSpec]
    public var content: LayerContent

    public init(id: String,
                frame: NormalizedRect,
                rotation: Double = 0,
                opacity: Double = 1,
                timing: Timing = Timing(),
                animations: [AnimationSpec] = [],
                content: LayerContent) {
        self.id = id
        self.frame = frame
        self.rotation = rotation
        self.opacity = opacity
        self.timing = timing
        self.animations = animations
        self.content = content
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, frame, rotation, opacity, timing, animations
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        frame = try c.decode(NormalizedRect.self, forKey: .frame)
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        timing = try c.decodeIfPresent(Timing.self, forKey: .timing) ?? Timing()
        animations = try c.decodeIfPresent([AnimationSpec].self, forKey: .animations) ?? []

        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "shape":
            content = .shape(try ShapeContent(from: decoder))
        case "mediaSlot":
            content = .mediaSlot(try MediaSlotContent(from: decoder))
        case "text":
            content = .text(try TextContent(from: decoder))
        case "lottie":
            content = .lottie(try LottieContent(from: decoder))
        default:
            // Bilinmeyen katman tipi decode hatasıdır; manifest'teki minAppVersion
            // bu duruma hiç düşülmemesini garanti eder.
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "Unknown layer type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(content.typeName, forKey: .type)
        try c.encode(frame, forKey: .frame)
        try c.encode(rotation, forKey: .rotation)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(timing, forKey: .timing)
        try c.encode(animations, forKey: .animations)
        switch content {
        case .shape(let value): try value.encode(to: encoder)
        case .mediaSlot(let value): try value.encode(to: encoder)
        case .text(let value): try value.encode(to: encoder)
        case .lottie(let value): try value.encode(to: encoder)
        }
    }
}

// MARK: - Plaka / etiket bağı

extension Layer {

    /// Bir "plaka" ile onun etiketi TEK NESNEDİR; iki ayrı katman olmaları bir
    /// uygulama detayı. Motor bunu bilmediği için her katman kendi
    /// `timing.start`'ına göre giriyordu ve şablon yazarının 0,1–0,3 sn'lik
    /// kademesi ekranda BOŞ bir renkli kutu olarak görünüyordu
    /// (`sale-promo-01`: `cta-pill` 2,1 sn — `cta` 2,3 sn; ölçülen export'ta
    /// hap tamamen doldururken yazı henüz yoktu).
    ///
    /// Bu, tek bir şablonun hatası DEĞİL: katalogdaki 136 dar plaka/etiket
    /// çiftinin 135'inde plaka etiketinden önce giriyor (medyan 0,12 sn).
    /// 127 JSON'a dokunmadan düzeltilebilecek tek yer motor.
    ///
    /// Kural: plaka etiketiyle AYNI ANDA girer (`plaka.start = etiket.start`).
    /// Etiketi öne çekmek DEĞİL — çünkü etiket plakanın dönüşümünü miras
    /// almaz (ayrı container'lar); plaka `bounce` ile 0,4 ölçekten büyürken
    /// yazı tam boyda durur ve hapın dışına taşar. Plakayı beklettiğimizde
    /// ikisi de kendi giriş animasyonunu aynı anda oynar ve tek parça okunur.
    ///
    /// "Plaka" DAR olmak zorunda: metni saran ama ondan belirgin büyük bir
    /// kart (davetiye kartı, not kâğıdı) sahne dekorudur, etiketini beklerse
    /// tasarım çöker — bu yüzden boyut farkı ve mutlak yükseklik sınırlanır.
    static func bindingPlatesToLabels(_ layers: [Layer]) -> [Layer] {
        /// Plakanın gireceği yeni an: kendisine bağlı EN ERKEN etiket.
        var bound: [Int: Double] = [:]
        for (index, label) in layers.enumerated() {
            guard case .text = label.content else { continue }
            // Metnin ALTINDAKİ en yakın plaka: çizim sırasında geriye doğru
            // ilk eşleşen. (Aynı kadrajda birden çok plaka varsa metne en
            // yakın olan onun plakasıdır.)
            guard let plate = (0..<index).reversed().first(where: {
                layers[$0].isPlate(for: label)
            }) else { continue }
            let gap = abs(label.timing.start - layers[plate].timing.start)
            // Saniyeler süren bir fark kademe değil, bilinçli bir kurgudur
            // (önce boş çerçeve, sonra yazı); motor ona karışmaz.
            guard gap <= 1.0 else { continue }
            bound[plate] = min(bound[plate] ?? .greatestFiniteMagnitude,
                               label.timing.start)
        }
        guard !bound.isEmpty else { return layers }

        return layers.enumerated().map { index, layer in
            guard let start = bound[index], start != layer.timing.start else { return layer }
            var copy = layer
            // Pencerenin SONU korunur: plaka geç girer, erken çıkmaz.
            let end = layer.timing.duration.map { layer.timing.start + $0 }
            copy.timing = Timing(start: start,
                                 duration: end.map { max($0 - start, 0.01) })
            return copy
        }
    }

    /// Bu katman, verilen metin katmanının plakası mı?
    private func isPlate(for label: Layer) -> Bool {
        guard case .shape = content else { return false }
        // Eğik plaka yalnız aynı açıdaki etiketle eşleşir: normalize
        // çerçeveler dönüş ÖNCESİ olduğu için farklı açılarda kapsama testi
        // ekranda gördüğümüz şeyi anlatmaz.
        guard rotation == label.rotation else { return false }
        guard frame.height <= 0.25 else { return false }
        guard frame.width - label.frame.width <= 0.12,
              frame.height - label.frame.height <= 0.09 else { return false }
        return frame.contains(label.frame, tolerance: 0.01)
    }
}

public enum LayerContent: Equatable, Sendable {
    case shape(ShapeContent)
    case mediaSlot(MediaSlotContent)
    case text(TextContent)
    case lottie(LottieContent)

    public var typeName: String {
        switch self {
        case .shape: return "shape"
        case .mediaSlot: return "mediaSlot"
        case .text: return "text"
        case .lottie: return "lottie"
        }
    }
}

// MARK: - Layer contents

/// İki renk rolü arasında doğrusal geçiş. Palet rolleri alfa taşıyabildiği için
/// (#RRGGBBAA) "şeffaftan siyaha" scrim'ler de bununla yazılır — düz renkli
/// scrim şeridi kadrajı sert bir bantla kesiyordu.
public struct GradientSpec: Codable, Equatable, Sendable {
    public var from: String
    public var to: String
    /// `down` (varsayılan), `up`, `left`, `right`, `diagonal`.
    public var direction: String

    public init(from: String, to: String, direction: String = "down") {
        self.from = from
        self.to = to
        self.direction = direction
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        from = try c.decode(String.self, forKey: .from)
        to = try c.decode(String.self, forKey: .to)
        direction = try c.decodeIfPresent(String.self, forKey: .direction) ?? "down"
    }
}

public struct ShapeContent: Codable, Equatable, Sendable {
    public var colorRole: String
    /// Kanvas yüksekliğine normalize.
    public var cornerRadius: Double
    /// Varsa düz rengin yerine doğrusal geçiş çizilir.
    public var gradient: GradientSpec?

    public init(colorRole: String, cornerRadius: Double = 0, gradient: GradientSpec? = nil) {
        self.colorRole = colorRole
        self.cornerRadius = cornerRadius
        self.gradient = gradient
    }

    private enum CodingKeys: String, CodingKey { case colorRole, cornerRadius, gradient }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        colorRole = try c.decode(String.self, forKey: .colorRole)
        cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0
        gradient = try c.decodeIfPresent(GradientSpec.self, forKey: .gradient)
    }
}

public enum MediaKind: String, Codable, Sendable {
    case photo, video, photoOrVideo

    public var allowsVideo: Bool { self != .photo }
}

public enum MaskKind: String, Codable, Sendable {
    case rect, circle, star, heart
}

public struct MediaSlotContent: Codable, Equatable, Sendable {
    public var slotIndex: Int
    public var media: MediaKind
    /// MVP'de tek değer: "fill" (aspect-fill).
    public var contentMode: String
    public var mask: MaskKind
    public var cornerRadius: Double
    /// Renk gradasyonu preset adı (ColorGrade); nil ise ham medya.
    public var filter: String?
    /// Filtre yoğunluğu (0–1). filter nil ise yok sayılır.
    public var filterIntensity: Double

    public init(slotIndex: Int,
                media: MediaKind = .photoOrVideo,
                contentMode: String = "fill",
                mask: MaskKind = .rect,
                cornerRadius: Double = 0,
                filter: String? = nil,
                filterIntensity: Double = 1.0) {
        self.slotIndex = slotIndex
        self.media = media
        self.contentMode = contentMode
        self.mask = mask
        self.cornerRadius = cornerRadius
        self.filter = filter
        self.filterIntensity = filterIntensity
    }

    private enum CodingKeys: String, CodingKey {
        case slotIndex, media, contentMode, mask, cornerRadius, filter, filterIntensity
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slotIndex = try c.decode(Int.self, forKey: .slotIndex)
        media = try c.decodeIfPresent(MediaKind.self, forKey: .media) ?? .photoOrVideo
        contentMode = try c.decodeIfPresent(String.self, forKey: .contentMode) ?? "fill"
        mask = try c.decodeIfPresent(MaskKind.self, forKey: .mask) ?? .rect
        cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0
        filter = try c.decodeIfPresent(String.self, forKey: .filter)
        filterIntensity = try c.decodeIfPresent(Double.self, forKey: .filterIntensity) ?? 1.0
    }
}

public enum TextAlignment: String, Codable, Sendable {
    case left, center, right
}

public struct FontSpec: Codable, Equatable, Sendable {
    /// PostScript adı; bulunamazsa motor sistem fontuna düşer.
    public var name: String
    /// Kanvas yüksekliğine normalize (0.045 x 1920 ≈ 86pt).
    public var size: Double

    public init(name: String, size: Double) {
        self.name = name
        self.size = size
    }
}

public struct TextContent: Codable, Equatable, Sendable {
    /// Editör etiketi ve analytics için stabil alan kimliği.
    public var key: String
    public var `default`: LocalizedText
    public var font: FontSpec
    public var colorRole: String
    public var alignment: TextAlignment
    public var maxLines: Int
    /// Kanvas yüksekliğine normalize ek harf aralığı.
    public var letterSpacing: Double
    public var allCaps: Bool
    /// Metnin arkasına satır bazlı renkli vurgu (palet rolü). nil = düz metin.
    public var highlightColorRole: String?

    public init(key: String,
                default defaultText: LocalizedText,
                font: FontSpec,
                colorRole: String,
                alignment: TextAlignment = .center,
                maxLines: Int = 1,
                letterSpacing: Double = 0,
                allCaps: Bool = false,
                highlightColorRole: String? = nil) {
        self.key = key
        self.default = defaultText
        self.font = font
        self.colorRole = colorRole
        self.alignment = alignment
        self.maxLines = maxLines
        self.letterSpacing = letterSpacing
        self.allCaps = allCaps
        self.highlightColorRole = highlightColorRole
    }

    private enum CodingKeys: String, CodingKey {
        case key, `default` = "default", font, colorRole, alignment
        case maxLines, letterSpacing, allCaps, highlightColorRole
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        `default` = try c.decode(LocalizedText.self, forKey: .default)
        font = try c.decode(FontSpec.self, forKey: .font)
        colorRole = try c.decode(String.self, forKey: .colorRole)
        alignment = try c.decodeIfPresent(TextAlignment.self, forKey: .alignment) ?? .center
        maxLines = try c.decodeIfPresent(Int.self, forKey: .maxLines) ?? 1
        letterSpacing = try c.decodeIfPresent(Double.self, forKey: .letterSpacing) ?? 0
        allCaps = try c.decodeIfPresent(Bool.self, forKey: .allCaps) ?? false
        highlightColorRole = try c.decodeIfPresent(String.self, forKey: .highlightColorRole)
    }
}

public enum LottieLoopMode: String, Codable, Sendable {
    case once, loop
}

public struct LottieContent: Codable, Equatable, Sendable {
    /// Şablon paketi içindeki dosya adı (assets/).
    public var asset: String
    public var loopMode: LottieLoopMode
    /// Lottie içindeki ham hex -> palet rolü.
    public var colorRemap: [String: String]?

    public init(asset: String, loopMode: LottieLoopMode = .once, colorRemap: [String: String]? = nil) {
        self.asset = asset
        self.loopMode = loopMode
        self.colorRemap = colorRemap
    }

    private enum CodingKeys: String, CodingKey { case asset, loopMode, colorRemap }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        asset = try c.decode(String.self, forKey: .asset)
        loopMode = try c.decodeIfPresent(LottieLoopMode.self, forKey: .loopMode) ?? .once
        colorRemap = try c.decodeIfPresent([String: String].self, forKey: .colorRemap)
    }
}

// MARK: - Color

/// Platformdan bağımsız renk (0-1 aralığında sRGB bileşenleri).
public struct RGBAColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// "#RRGGBB" veya "#RRGGBBAA" (baştaki # opsiyonel).
    public init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8,
              let bits = UInt64(value, radix: 16) else { return nil }
        if value.count == 6 {
            red = Double((bits >> 16) & 0xFF) / 255
            green = Double((bits >> 8) & 0xFF) / 255
            blue = Double(bits & 0xFF) / 255
            alpha = 1
        } else {
            red = Double((bits >> 24) & 0xFF) / 255
            green = Double((bits >> 16) & 0xFF) / 255
            blue = Double((bits >> 8) & 0xFF) / 255
            alpha = Double(bits & 0xFF) / 255
        }
    }
}
