import XCTest
import SRSEngine

final class MasteryTests: XCTestCase {
    func testLevels() {
        XCTAssertEqual(Mastery.level(reps: 0, intervalDays: 0), 0)   // new
        XCTAssertEqual(Mastery.level(reps: 1, intervalDays: 1), 1)   // learning
        XCTAssertEqual(Mastery.level(reps: 2, intervalDays: 6), 1)
        XCTAssertEqual(Mastery.level(reps: 3, intervalDays: 15), 2)  // familiar
        XCTAssertEqual(Mastery.level(reps: 5, intervalDays: 10), 2)  // long reps, short interval
        XCTAssertEqual(Mastery.level(reps: 5, intervalDays: 21), 3)  // mastered
    }
}
