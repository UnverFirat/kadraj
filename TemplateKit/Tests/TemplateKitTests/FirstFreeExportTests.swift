import XCTest
@testable import TemplateKit

/// Bir kerelik "ilk videon bizden" hakkı.
///
/// Bu davranış paranın DOĞRUDAN üstünde duruyor: kural gevşerse herkes sonsuz
/// filigransız export alır, sıkışırsa kullanıcı hediyeyi hiç göremez. Bu yüzden
/// hem karar (`Entitlements`) hem de defter (`FirstFreeExportLedger`) ayrı ayrı
/// sınanıyor.
final class FirstFreeExportTests: XCTestCase {

    private func makeLedger() -> (FirstFreeExportLedger, UserDefaults) {
        let suite = UserDefaults(suiteName: "first-free-export-\(UUID().uuidString)")!
        return (FirstFreeExportLedger(defaults: suite, key: "firstFree"), suite)
    }

    // MARK: - Karar

    func testFreeUserGetsFirstVideoWithoutWatermark() {
        let entitlements = Entitlements(status: .free, didUseFirstFreeExport: false)
        XCTAssertTrue(entitlements.hasFirstFreeExport)
        XCTAssertFalse(entitlements.includeWatermark, "ilk video filigransız olmalı")
    }

    func testFreeUserGetsWatermarkAfterTheGiftIsSpent() {
        let entitlements = Entitlements(status: .free, didUseFirstFreeExport: true)
        XCTAssertFalse(entitlements.hasFirstFreeExport)
        XCTAssertTrue(entitlements.includeWatermark, "ikinci videodan sonra filigran var")
    }

    func testMechanismNeverEngagesForProUser() {
        // Pro'nun çıktısı zaten filigransız; hakkı harcamanın da anlamı yok —
        // abonelik biterse kullanıcı hediyesini hâlâ elinde bulmalı.
        let fresh = Entitlements(status: .pro(), didUseFirstFreeExport: false)
        XCTAssertFalse(fresh.hasFirstFreeExport)
        XCTAssertFalse(fresh.includeWatermark)

        let spent = Entitlements(status: .pro(), didUseFirstFreeExport: true)
        XCTAssertFalse(spent.hasFirstFreeExport)
        XCTAssertFalse(spent.includeWatermark)
    }

    func testDefaultInitializerKeepsTheOldWatermarkBehaviour() {
        // Bayrağı bilmeyen bir çağıran sessizce bedava export dağıtmamalı.
        XCTAssertTrue(Entitlements(status: .free).includeWatermark)
        XCTAssertFalse(Entitlements(status: .free).hasFirstFreeExport)
    }

    func testLockRulesAreUnaffectedByTheGift() {
        // Hediye YALNIZ filigranı kapsar: Pro şablon ve Pro parça kilitli kalır,
        // yoksa ilk export'ta tüm katalog bedava açılırdı.
        let entitlements = Entitlements(status: .free, didUseFirstFreeExport: false)
        let template = Template(id: "t", name: LocalizedText(["en": "T"]),
                                category: "minimal", isPro: true, duration: 5,
                                palette: ["background": "#000000"])
        XCTAssertTrue(entitlements.isLocked(template))
        let proTrack = MusicLibrary.all.first { $0.isPro }!
        XCTAssertTrue(entitlements.isLocked(proTrack))
    }

    // MARK: - Defter

    func testLedgerStartsUnusedOnAFreshInstall() {
        let (ledger, _) = makeLedger()
        XCTAssertFalse(ledger.isUsed)
    }

    func testLedgerPersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "first-free-export-\(UUID().uuidString)")!
        FirstFreeExportLedger(defaults: suite, key: "firstFree").markUsed()
        // Uygulama yeniden açıldı: hak geri gelmemeli.
        XCTAssertTrue(FirstFreeExportLedger(defaults: suite, key: "firstFree").isUsed)
    }

    func testMarkingUsedTwiceIsHarmless() {
        let (ledger, _) = makeLedger()
        ledger.markUsed()
        ledger.markUsed()
        XCTAssertTrue(ledger.isUsed)
    }

    func testResetRestoresTheGiftForDemoRuns() {
        let (ledger, _) = makeLedger()
        ledger.markUsed()
        ledger.reset()
        XCTAssertFalse(ledger.isUsed)
    }

    /// Uçtan uca: defter kararı besliyor — ilk video temiz, ikincisi filigranlı.
    func testLedgerDrivesTheWatermarkDecision() {
        let (ledger, _) = makeLedger()

        var entitlements = Entitlements(status: .free,
                                        didUseFirstFreeExport: ledger.isUsed)
        XCTAssertFalse(entitlements.includeWatermark)

        // Export BAŞARIYLA bitti — hak ancak burada tükenir.
        ledger.markUsed()

        entitlements = Entitlements(status: .free,
                                    didUseFirstFreeExport: ledger.isUsed)
        XCTAssertTrue(entitlements.includeWatermark)
    }
}
