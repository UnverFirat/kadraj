import Foundation

// MARK: - Olaylar

/// Ürün hunisinin ölçüm noktaları: **şablon seç → medya koy → export → öde**.
/// Tek enum olması, olay adlarının ve parametrelerin tek yerde durmasını sağlar
/// (sağlayıcı değişirse — Firebase, PostHog, kendi backend'imiz — yalnız bir
/// `AnalyticsSink` yazılır, çağrı yerleri değişmez).
///
/// GİZLİLİK KURALI: buraya yalnız şablon/parça/ürün **kimlikleri** ve sayısal
/// ölçüler girer. Kullanıcının yazdığı metin, dosya yolu, medya içeriği ve
/// cihaz kimliği HİÇBİR olayda taşınmaz — hesap zorunluluğu olmayan bir
/// uygulamada analitik de kimliksiz kalmalı.
public enum AnalyticsEvent: Equatable, Sendable {
    case appOpened
    /// Galeri doldu: liste nereden geldi (paket/önbellek/CDN) ve kaç şablon.
    case catalogLoaded(origin: String, count: Int)
    case templateOpened(id: String, isPro: Bool)
    /// Kullanıcı bir slota kendi medyasını koydu (`photo` / `video`).
    case mediaPicked(slot: Int, kind: String)
    /// nil = "Müziksiz" seçildi.
    case musicSelected(trackID: String?)
    case exportStarted(templateID: String, isPro: Bool)
    case exportFinished(templateID: String, seconds: Double, watermark: Bool)
    /// `reason` hata TÜRÜdür (mesaj değil) — serbest metin sızdırmamak için.
    case exportFailed(templateID: String, reason: String)
    case videoShared(templateID: String)
    case paywallShown(reason: String)
    case purchaseStarted(productID: String)
    case purchaseCompleted(productID: String, plan: String, trial: Bool)
    case purchaseFailed(productID: String, reason: String)
    case restoreCompleted(success: Bool)

    /// Sağlayıcıya gidecek olay adı (snake_case — çoğu SDK'nın sözleşmesi).
    public var name: String {
        switch self {
        case .appOpened:          return "app_opened"
        case .catalogLoaded:      return "catalog_loaded"
        case .templateOpened:     return "template_opened"
        case .mediaPicked:        return "media_picked"
        case .musicSelected:      return "music_selected"
        case .exportStarted:      return "export_started"
        case .exportFinished:     return "export_finished"
        case .exportFailed:       return "export_failed"
        case .videoShared:        return "video_shared"
        case .paywallShown:       return "paywall_shown"
        case .purchaseStarted:    return "purchase_started"
        case .purchaseCompleted:  return "purchase_completed"
        case .purchaseFailed:     return "purchase_failed"
        case .restoreCompleted:   return "restore_completed"
        }
    }

    public var parameters: [String: String] {
        switch self {
        case .appOpened:
            return [:]
        case .catalogLoaded(let origin, let count):
            return ["origin": origin, "count": String(count)]
        case .templateOpened(let id, let isPro):
            return ["template": id, "pro": String(isPro)]
        case .mediaPicked(let slot, let kind):
            return ["slot": String(slot), "kind": kind]
        case .musicSelected(let trackID):
            return ["track": trackID ?? "none"]
        case .exportStarted(let templateID, let isPro):
            return ["template": templateID, "pro": String(isPro)]
        case .exportFinished(let templateID, let seconds, let watermark):
            return ["template": templateID,
                    "seconds": String(format: "%.2f", seconds),
                    "watermark": String(watermark)]
        case .exportFailed(let templateID, let reason):
            return ["template": templateID, "reason": reason]
        case .videoShared(let templateID):
            return ["template": templateID]
        case .paywallShown(let reason):
            return ["reason": reason]
        case .purchaseStarted(let productID):
            return ["product": productID]
        case .purchaseCompleted(let productID, let plan, let trial):
            return ["product": productID, "plan": plan, "trial": String(trial)]
        case .purchaseFailed(let productID, let reason):
            return ["product": productID, "reason": reason]
        case .restoreCompleted(let success):
            return ["success": String(success)]
        }
    }

    /// `name key=value key=value` — konsol sink'i ve testler için.
    public var line: String {
        let params = parameters.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return params.isEmpty ? name : "\(name) \(params)"
    }
}

// MARK: - Sink

/// Olayı bir yere yazan taraf. Üretimde SDK adaptörü, testlerde tampon.
/// Çağrı yerleri `Analytics.log` çağırır; hangi sink'in takılı olduğunu bilmez.
public protocol AnalyticsSink: Sendable {
    func record(_ event: AnalyticsEvent, at date: Date)
}

/// Geliştirme sink'i: olayları konsola basar (`[analytics] export_started ...`).
public struct ConsoleAnalyticsSink: AnalyticsSink {
    public init() {}

    public func record(_ event: AnalyticsEvent, at date: Date) {
        print("[analytics] \(event.line)")
    }
}

/// Olayları bellekte tutar. Testler ve "Ayarlar → son olaylar" ekranı bunu
/// kullanır; `limit` aşılınca en eski olay düşer (sınırsız büyümesin).
public final class BufferingAnalyticsSink: AnalyticsSink, @unchecked Sendable {
    private let limit: Int
    private let lock = NSLock()
    private var storage: [(event: AnalyticsEvent, date: Date)] = []

    public init(limit: Int = 200) {
        self.limit = limit
    }

    public func record(_ event: AnalyticsEvent, at date: Date) {
        lock.lock(); defer { lock.unlock() }
        storage.append((event, date))
        if storage.count > limit { storage.removeFirst(storage.count - limit) }
    }

    public var events: [AnalyticsEvent] {
        lock.lock(); defer { lock.unlock() }
        return storage.map(\.event)
    }

    /// En yeni olaydan başlayarak `name key=value` satırları.
    public func lines(limit: Int = 50) -> [String] {
        lock.lock(); defer { lock.unlock() }
        return storage.suffix(limit).reversed().map(\.event.line)
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        storage.removeAll()
    }
}

// MARK: - Cephe

/// Uygulamanın tek analitik giriş noktası. Sink takılmadıysa `log` hiçbir şey
/// yapmaz — yani analitik hiçbir zaman uygulamanın çalışmasının koşulu değildir
/// (testler ve CLI'lar sink'siz koşar).
public final class Analytics: @unchecked Sendable {
    public static let shared = Analytics()

    private let lock = NSLock()
    private var sinks: [AnalyticsSink] = []

    public init() {}

    /// Takılı sink listesini değiştirir (uygulama açılışında bir kez).
    public func install(_ sinks: [AnalyticsSink]) {
        lock.lock(); defer { lock.unlock() }
        self.sinks = sinks
    }

    public func add(_ sink: AnalyticsSink) {
        lock.lock(); defer { lock.unlock() }
        sinks.append(sink)
    }

    public func log(_ event: AnalyticsEvent, at date: Date = Date()) {
        lock.lock()
        let current = sinks
        lock.unlock()
        for sink in current { sink.record(event, at: date) }
    }
}
