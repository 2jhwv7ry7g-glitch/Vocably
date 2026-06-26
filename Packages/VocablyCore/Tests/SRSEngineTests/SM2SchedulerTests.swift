import XCTest
import VocablyDomain
import SRSEngine

final class SM2SchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let sut = SM2Scheduler()

    func testNewCardGoodGivesFirstInterval() {
        let r = sut.schedule(.new(now: now), rating: .good, now: now)
        XCTAssertEqual(r.reps, 1)
        XCTAssertEqual(r.intervalDays, 1, accuracy: 0.0001)
        XCTAssertEqual(r.ease, 2.5, accuracy: 0.0001)            // "good" leaves ease unchanged
        XCTAssertEqual(r.due.timeIntervalSince(now), 86_400, accuracy: 1)
        XCTAssertEqual(r.lastRating, .good)
    }

    func testTwoGoodsGiveSixDayInterval() {
        var r = sut.schedule(.new(now: now), rating: .good, now: now)
        r = sut.schedule(r, rating: .good, now: now)
        XCTAssertEqual(r.reps, 2)
        XCTAssertEqual(r.intervalDays, 6, accuracy: 0.0001)
    }

    func testThirdGoodScalesByEase() {
        var r = sut.schedule(.new(now: now), rating: .good, now: now)
        r = sut.schedule(r, rating: .good, now: now)
        r = sut.schedule(r, rating: .good, now: now)
        XCTAssertEqual(r.reps, 3)
        XCTAssertEqual(r.intervalDays, 15, accuracy: 0.0001)     // round(6 * 2.5)
    }

    func testEasyRaisesEase() {
        let r = sut.schedule(.new(now: now), rating: .easy, now: now)
        XCTAssertEqual(r.ease, 2.6, accuracy: 0.0001)            // +0.1
    }

    func testAgainResetsRepsAndRecordsLapse() {
        let mature = Review(due: now, intervalDays: 15, ease: 2.5, reps: 3)
        let r = sut.schedule(mature, rating: .again, now: now)
        XCTAssertEqual(r.reps, 0)
        XCTAssertEqual(r.lapses, 1)
        XCTAssertEqual(r.intervalDays, 1, accuracy: 0.0001)
        XCTAssertEqual(r.ease, 1.96, accuracy: 0.0001)           // 2.5 - 0.54
        XCTAssertEqual(r.masteryLevel, 0)
        XCTAssertEqual(r.due.timeIntervalSince(now), 86_400, accuracy: 1)
    }

    func testEaseClampedAtMinimum() {
        let low = Review(due: now, intervalDays: 1, ease: 1.5)
        let r = sut.schedule(low, rating: .again, now: now)      // 1.5 - 0.54 = 0.96 -> clamp
        XCTAssertEqual(r.ease, 1.3, accuracy: 0.0001)
    }

    func testHardGrowsSlowerThanGood() {
        let base = Review(due: now, intervalDays: 6, ease: 2.5, reps: 2)
        let hard = sut.schedule(base, rating: .hard, now: now)   // round(6 * 1.2) = 7
        let good = sut.schedule(base, rating: .good, now: now)   // round(6 * 2.5) = 15
        XCTAssertEqual(hard.intervalDays, 7, accuracy: 0.0001)
        XCTAssertEqual(good.intervalDays, 15, accuracy: 0.0001)
        XCTAssertLessThan(hard.intervalDays, good.intervalDays)
    }

    func testDueAdvancesByComputedInterval() {
        let r = sut.schedule(.new(now: now), rating: .good, now: now)
        XCTAssertEqual(r.due.timeIntervalSince(now), r.intervalDays * 86_400, accuracy: 1)
    }
}
