import XCTest
@testable import TemplateKit

/// RevenueCat sağlayıcısının SDK'sız testi: köprü taklit edilir, sağlayıcının
/// `CustomerInfo` → `EntitlementStatus` çevirisi ve hata yolları doğrulanır.
/// (StoreKit sağlayıcısı gerçek App Store hesabı istediği için burada değil;
/// onun testi StoreKit Testing configuration'ıyla uygulama hedefinde koşar.)
final class PurchasesBridgeTests: XCTestCase {

    /// Taklit köprü: hangi cevabı döneceği testte kurulur.
    private final class FakeBridge: PurchasesBridge, @unchecked Sendable {
        var offeringsResult: [RemoteOffering] = [
            RemoteOffering(productID: "pro.monthly", plan: .monthly, priceText: "₺79,99"),
            RemoteOffering(productID: "pro.yearly", plan: .yearly, priceText: "₺399,99",
                           periodText: "yıllık · ayda ₺33", trialDays: 3)
        ]
        var info: RemoteCustomerInfo = .none
        var purchaseError: Error?
        var restoreError: Error?
        private(set) var purchasedIDs: [String] = []

        func offerings() async throws -> [RemoteOffering] { offeringsResult }
        func customerInfo() async throws -> RemoteCustomerInfo { info }

        func purchase(productID: String) async throws -> RemoteCustomerInfo {
            purchasedIDs.append(productID)
            if let purchaseError { throw purchaseError }
            return info
        }

        func restore() async throws -> RemoteCustomerInfo {
            if let restoreError { throw restoreError }
            return info
        }
    }

    private func makeProvider(_ bridge: FakeBridge)
        -> (RevenueCatEntitlementProvider, BufferingAnalyticsSink) {
        let suite = UserDefaults(suiteName: "rc-test-\(UUID().uuidString)")!
        let sink = BufferingAnalyticsSink()
        let analytics = Analytics()
        analytics.install([sink])
        let provider = RevenueCatEntitlementProvider(
            bridge: bridge, entitlementID: "pro",
            cache: EntitlementCache(defaults: suite, key: "cache"),
            analytics: analytics)
        return (provider, sink)
    }

    func testOfferingsBecomePaywallProducts() async {
        let bridge = FakeBridge()
        let (provider, _) = makeProvider(bridge)
        await provider.loadOfferings()
        XCTAssertEqual(provider.products.map(\.id), ["pro.monthly", "pro.yearly"])
        XCTAssertEqual(provider.products.first?.periodText, "aylık",
                       "köprü periodText vermezse plana göre varsayılan yazılmalı")
        XCTAssertEqual(provider.products.last?.trialDays, 3)
    }

    func testPurchaseGrantsProAndLogsAnalytics() async throws {
        let bridge = FakeBridge()
        let (provider, sink) = makeProvider(bridge)
        await provider.loadOfferings()
        bridge.info = RemoteCustomerInfo(activeEntitlements: ["pro"],
                                         expirationDate: Date().addingTimeInterval(3600),
                                         isInTrial: true)

        let yearly = try XCTUnwrap(provider.products.first { $0.plan == .yearly })
        let status = try await provider.purchase(yearly)
        XCTAssertTrue(status.isPro)
        XCTAssertTrue(status.inTrial)
        XCTAssertEqual(bridge.purchasedIDs, ["pro.yearly"])
        XCTAssertEqual(provider.status, status, "durum sağlayıcıda kalmalı")
        XCTAssertEqual(sink.events.map(\.name),
                       ["purchase_started", "purchase_completed"])
    }

    /// Yanlış entitlement eşlemesi: satın alma başarılı döner ama hak gelmez.
    /// Sessizce Pro sayılırsa kullanıcı ödediği halde kilitli kalır ve biz
    /// bunu göremeyiz — hata fırlatılıp olay kaydedilmeli.
    func testPurchaseWithoutEntitlementFails() async throws {
        let bridge = FakeBridge()
        let (provider, sink) = makeProvider(bridge)
        await provider.loadOfferings()
        bridge.info = RemoteCustomerInfo(activeEntitlements: ["baska_hak"])

        let monthly = try XCTUnwrap(provider.products.first)
        do {
            _ = try await provider.purchase(monthly)
            XCTFail("hak gelmeyince hata bekleniyordu")
        } catch {
            XCTAssertEqual(error as? EntitlementError, .unavailable)
        }
        XCTAssertFalse(provider.status.isPro)
        XCTAssertTrue(sink.events.contains(.purchaseFailed(productID: "pro.monthly",
                                                           reason: "no_entitlement")))
    }

    func testCancelledPurchaseMapsToCancelled() async throws {
        let bridge = FakeBridge()
        bridge.purchaseError = RemotePurchaseError.cancelled
        let (provider, sink) = makeProvider(bridge)
        await provider.loadOfferings()

        do {
            _ = try await provider.purchase(try XCTUnwrap(provider.products.first))
            XCTFail("iptal hatası bekleniyordu")
        } catch {
            XCTAssertEqual(error as? EntitlementError, .cancelled)
        }
        XCTAssertTrue(sink.events.contains(.purchaseFailed(productID: "pro.monthly",
                                                           reason: "cancelled")))
    }

    func testExpiredEntitlementIsNotPro() async {
        let bridge = FakeBridge()
        bridge.info = RemoteCustomerInfo(activeEntitlements: ["pro"],
                                         expirationDate: Date().addingTimeInterval(-60))
        let (provider, _) = makeProvider(bridge)
        let status = await provider.refresh()
        XCTAssertEqual(status, .free, "süresi geçmiş hak Pro sayılmamalı")
    }

    func testRestoreWithoutSubscriptionThrows() async {
        let bridge = FakeBridge()
        let (provider, sink) = makeProvider(bridge)
        do {
            _ = try await provider.restore()
            XCTFail("geri yüklenecek abonelik yokken hata bekleniyordu")
        } catch {
            XCTAssertEqual(error as? EntitlementError, .nothingToRestore)
        }
        XCTAssertTrue(sink.events.contains(.restoreCompleted(success: false)))
    }

    /// Mağaza cevabı gecikirken uygulamanın Pro açılması: durum diskte.
    func testCachedStatusSurvivesRelaunch() async {
        let suite = UserDefaults(suiteName: "rc-cache-\(UUID().uuidString)")!
        let cache = EntitlementCache(defaults: suite, key: "cache")
        let bridge = FakeBridge()
        bridge.info = RemoteCustomerInfo(activeEntitlements: ["pro"],
                                         expirationDate: Date().addingTimeInterval(86400))
        let first = RevenueCatEntitlementProvider(bridge: bridge, cache: cache,
                                                  analytics: Analytics())
        _ = await first.refresh()
        XCTAssertTrue(first.status.isPro)

        // "Uygulama yeniden açıldı": ağa çıkmadan durum bilinmeli.
        let second = RevenueCatEntitlementProvider(bridge: FakeBridge(), cache: cache,
                                                   analytics: Analytics())
        XCTAssertTrue(second.status.isPro, "son bilinen durum diskten okunmalı")

        // Abonelik bittiyse mağaza cevabı önbelleği ezer.
        let ended = FakeBridge()
        ended.info = .none
        let third = RevenueCatEntitlementProvider(bridge: ended, cache: cache,
                                                  analytics: Analytics())
        let refreshed = await third.refresh()
        XCTAssertEqual(refreshed, .free)
        XCTAssertEqual(EntitlementCache(defaults: suite, key: "cache").status, .free)
    }

    // MARK: Analytics

    func testAnalyticsEventsCarryNoFreeText() {
        let sink = BufferingAnalyticsSink(limit: 3)
        let analytics = Analytics()
        analytics.install([sink])
        analytics.log(.exportFinished(templateID: "quote-01", seconds: 4.25, watermark: true))
        analytics.log(.mediaPicked(slot: 1, kind: "photo"))
        analytics.log(.musicSelected(trackID: nil))
        analytics.log(.templateOpened(id: "quote-01", isPro: false))

        XCTAssertEqual(sink.events.count, 3, "tampon limiti aşılınca en eski olay düşmeli")
        XCTAssertEqual(sink.events.first?.name, "media_picked")
        let line = AnalyticsEvent.exportFinished(templateID: "quote-01", seconds: 4.25,
                                                 watermark: true).line
        XCTAssertEqual(line, "export_finished seconds=4.25 template=quote-01 watermark=true")
        XCTAssertEqual(AnalyticsEvent.musicSelected(trackID: nil).parameters["track"], "none")
    }

    /// Sink takılı değilken log çağrısı sessizce yutulmalı — analitik hiçbir
    /// zaman uygulamanın çalışmasının koşulu olmamalı.
    func testLoggingWithoutSinkIsHarmless() {
        Analytics().log(.appOpened)
    }
}
