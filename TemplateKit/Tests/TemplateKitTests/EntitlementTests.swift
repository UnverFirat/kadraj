import XCTest
@testable import TemplateKit

final class EntitlementTests: XCTestCase {

    private func makeProvider() -> (LocalEntitlementProvider, UserDefaults) {
        let suite = UserDefaults(suiteName: "entitlement-test-\(UUID().uuidString)")!
        return (LocalEntitlementProvider(defaults: suite, key: "pro"), suite)
    }

    private func proTemplate(_ isPro: Bool) -> Template {
        Template(id: "t", name: LocalizedText(["en": "T"]), category: "minimal",
                 isPro: isPro, duration: 5, palette: ["background": "#000000"])
    }

    func testFreeUserIsLockedOutOfProContentAndGetsWatermark() {
        let entitlements = Entitlements(status: .free)
        XCTAssertTrue(entitlements.isLocked(proTemplate(true)))
        XCTAssertFalse(entitlements.isLocked(proTemplate(false)))
        XCTAssertTrue(entitlements.includeWatermark)

        let proTrack = MusicLibrary.all.first { $0.isPro }!
        XCTAssertTrue(entitlements.isLocked(proTrack))
        // Kilitli parça seçiliyse ücretsiz bir parçaya düşülür.
        let resolved = entitlements.resolvedTrack(proTrack)
        XCTAssertNotNil(resolved)
        XCTAssertFalse(resolved!.isPro)
    }

    func testProUserUnlocksEverythingAndLosesWatermark() {
        let entitlements = Entitlements(status: .pro())
        XCTAssertFalse(entitlements.isLocked(proTemplate(true)))
        XCTAssertFalse(entitlements.includeWatermark)
        let proTrack = MusicLibrary.all.first { $0.isPro }!
        XCTAssertEqual(entitlements.resolvedTrack(proTrack)?.id, proTrack.id)
    }

    func testPurchasePersistsAndYearlyStartsTrial() async throws {
        let (provider, _) = makeProvider()
        XCTAssertEqual(provider.status, .free)

        let yearly = try XCTUnwrap(provider.products.first { $0.plan == .yearly })
        XCTAssertEqual(yearly.trialDays, 3)
        let status = try await provider.purchase(yearly)
        XCTAssertTrue(status.isPro)
        XCTAssertTrue(status.inTrial)
        XCTAssertTrue(provider.status.isPro, "durum kalıcı olmalı")

        let restored = try await provider.restore()
        XCTAssertTrue(restored.isPro)

        provider.reset()
        XCTAssertEqual(provider.status, .free)
    }

    func testMonthlyPurchaseHasNoTrial() async throws {
        let (provider, _) = makeProvider()
        let monthly = try XCTUnwrap(provider.products.first { $0.plan == .monthly })
        let status = try await provider.purchase(monthly)
        XCTAssertTrue(status.isPro)
        XCTAssertFalse(status.inTrial)
    }

    func testExpiredSubscriptionFallsBackToFree() {
        let (provider, defaults) = makeProvider()
        defaults.set(["expires": Date().addingTimeInterval(-60), "trial": false], forKey: "pro")
        XCTAssertEqual(provider.status, .free, "süresi geçen abonelik Pro sayılmamalı")
    }

    func testRestoreWithoutPurchaseThrows() async {
        let (provider, _) = makeProvider()
        do {
            _ = try await provider.restore()
            XCTFail("geri yüklenecek abonelik yokken hata bekleniyordu")
        } catch {
            XCTAssertEqual(error as? EntitlementError, .nothingToRestore)
        }
    }

    func testCatalogHasBothFreeAndProTemplates() throws {
        let templates = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("templates")
        let manifest = try JSONDecoder().decode(
            TemplateManifest.self,
            from: Data(contentsOf: templates.appendingPathComponent("manifest.json")))
        let free = manifest.templates.filter { !$0.isPro }.count
        XCTAssertGreaterThanOrEqual(free, 5, "ücretsiz kullanıcıya en az 5 şablon kalmalı")
        XCTAssertGreaterThan(manifest.templates.count - free, 0, "hiç Pro şablon yok")
    }
}
