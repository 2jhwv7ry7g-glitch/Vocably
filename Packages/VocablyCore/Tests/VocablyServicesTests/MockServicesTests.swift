import XCTest
import VocablyDomain
import VocablyServices

final class MockServicesTests: XCTestCase {
    func testMockAIGeneratesRequestedCount() async throws {
        let ai = MockAIService()
        let drafts = try await ai.generateDeck(prompt: "café spanish", language: "es", level: "A2", count: 6)
        XCTAssertEqual(drafts.count, 6)
        XCTAssertFalse(drafts[0].term.isEmpty)
        XCTAssertEqual(ai.recordedPrompts, ["café spanish"])
    }

    func testMockScanYieldsWordBatch() async {
        let scan = MockScanService()
        var batches: [[RecognizedWord]] = []
        for await batch in scan.scanText() { batches.append(batch) }
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches.first?.count, MockScanService.sampleBatch.count)
    }

    func testMockStorePurchaseStartsTrial() async throws {
        let store = MockStoreService()
        let ok = try await store.purchase(productID: "pro.yearly")
        XCTAssertTrue(ok)
        let status = await store.currentStatus()
        XCTAssertEqual(status, .trial)
    }

    func testMockTranslateUsesDictionary() async throws {
        let t = MockTranslateService()
        let out = try await t.translate("mariposa", from: "es", to: "en")
        XCTAssertEqual(out, "butterfly")
    }

    func testMockReminderRecordsSchedule() async {
        let r = MockReminderService()
        await r.scheduleDailyReminder(at: DateComponents(hour: 21, minute: 0))
        XCTAssertEqual(r.dailyTimes.count, 1)
        XCTAssertEqual(r.dailyTimes.first?.hour, 21)
    }
}
