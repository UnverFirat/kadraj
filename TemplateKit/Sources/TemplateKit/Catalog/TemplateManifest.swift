import Foundation

/// CDN'deki galeri manifesti (`docs/template-format.md` → "Paketleme ve CDN
/// manifesti"). Galeri TEK bu dosyayla beslenir: şablon listesi, rozetler ve
/// sürümler tamamen sunucudan yönetilir, uygulama güncellemesi gerekmez.
public struct TemplateManifest: Codable, Equatable, Sendable {
    public var manifestVersion: Int
    public var templates: [Entry]

    public struct Entry: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        /// Şablon içeriğinin sürümü. Artınca uygulama dosyayı yeniden indirir
        /// (cache anahtarı `id-vN`).
        public var version: Int
        public var category: String
        public var isPro: Bool
        /// `new` / `popular` — galeri rozetleri.
        public var tags: [String]
        /// Bu şablonu açabilen en düşük uygulama sürümü. Küçük sürümler
        /// şablonu hiç görmez (yeni preset yayınlamak eski sürümü kırmaz).
        public var minAppVersion: String
        /// Şablon JSON'unun manifest'e göreli yolu (MVP dağıtım biçimi).
        public var template: String?
        /// Zip paket yolu — ileride (lottie/asset taşıyan şablonlar için).
        public var package: String?
        public var thumbnail: String?
        public var preview: String?
        public var name: LocalizedText

        public init(id: String, version: Int, category: String, isPro: Bool = false,
                    tags: [String] = [], minAppVersion: String = "1.0.0",
                    template: String? = nil, package: String? = nil,
                    thumbnail: String? = nil, preview: String? = nil,
                    name: LocalizedText) {
            self.id = id
            self.version = version
            self.category = category
            self.isPro = isPro
            self.tags = tags
            self.minAppVersion = minAppVersion
            self.template = template
            self.package = package
            self.thumbnail = thumbnail
            self.preview = preview
            self.name = name
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
            category = try c.decodeIfPresent(String.self, forKey: .category) ?? "minimal"
            isPro = try c.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
            tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
            minAppVersion = try c.decodeIfPresent(String.self, forKey: .minAppVersion) ?? "1.0.0"
            template = try c.decodeIfPresent(String.self, forKey: .template)
            package = try c.decodeIfPresent(String.self, forKey: .package)
            thumbnail = try c.decodeIfPresent(String.self, forKey: .thumbnail)
            preview = try c.decodeIfPresent(String.self, forKey: .preview)
            name = try c.decode(LocalizedText.self, forKey: .name)
        }

        /// Cache dosya adı — sürüm değişince anahtar da değişir, eski dosya
        /// kendiliğinden geçersizleşir.
        public var cacheKey: String { "\(id)-v\(version)" }

        /// Şablon JSON'unun manifest'e göreli yolu (verilmediyse sözleşme yolu).
        public var templatePath: String { template ?? "templates/\(id).json" }

        /// Galeri posterinin manifest'e göreli yolu (verilmediyse sözleşme yolu).
        public var thumbnailPath: String { thumbnail ?? "thumbs/\(id).jpg" }
    }

    public init(manifestVersion: Int = 1, templates: [Entry]) {
        self.manifestVersion = manifestVersion
        self.templates = templates
    }

    /// Uygulama sürümünün açabildiği şablonlar (`minAppVersion` süzgeci).
    public func entries(forAppVersion appVersion: String) -> [Entry] {
        templates.filter { AppVersion.compare($0.minAppVersion, appVersion) != .orderedDescending }
    }
}

/// Noktalı sürüm karşılaştırması ("1.2" < "1.10"). Foundation'ın
/// `compare(options: .numeric)`'i "1.10" vs "1.9"da doğru çalışır ama eksik
/// bileşende ("1.2" vs "1.2.0") yanılır; bu yüzden kendi karşılaştırmamız.
public enum AppVersion {
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = parts(lhs), b = parts(rhs)
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left < right ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}
