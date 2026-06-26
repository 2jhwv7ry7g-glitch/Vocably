import XCTest
import Foundation
import VocablyDomain
import SRSEngine
import VocablyPresentation

final class SessionSummaryStateTests: XCTestCase {
    private func makeResult(
        reviewed: Int = 5,
        correct: Int = 4,
        again: Int = 1,
        accuracy: Double = 0.8,
        xpEarned: Int = 53,
        duration: TimeInterval = 180
    ) -> StudySessionResult {
        StudySessionResult(
            reviewed: reviewed,
            correct: correct,
            again: again,
            accuracy: accuracy,
            xpEarned: xpEarned,
            updatedCards: [],
            duration: duration
        )
    }

    func testFieldsMapFromResult() {
        let summary = SessionSummaryState(result: makeResult(), streakAfter: 7, newDueCount: 12)
        XCTAssertEqual(summary.reviewed, 5)
        XCTAssertEqual(summary.correct, 4)
        XCTAssertEqual(summary.accuracyPercent, 80)
        XCTAssertEqual(summary.xpEarned, 53)
        XCTAssertEqual(summary.streakAfter, 7)
        XCTAssertEqual(summary.newDueCount, 12)
    }

    func testAccuracyPercentRounds() {
        let twoThirds = SessionSummaryState(
            result: makeResult(reviewed: 3, correct: 2, again: 1, accuracy: 2.0 / 3.0),
            streakAfter: 1,
            newDueCount: 0
        )
        XCTAssertEqual(twoThirds.accuracyPercent, 67)

        let zero = SessionSummaryState(
            result: makeResult(reviewed: 0, correct: 0, again: 0, accuracy: 0),
            streakAfter: 0,
            newDueCount: 0
        )
        XCTAssertEqual(zero.accuracyPercent, 0)
    }

    func testHeadlineAndSubtitleNonEmpty() {
        let summary = SessionSummaryState(result: makeResult(), streakAfter: 1, newDueCount: 0)
        XCTAssertFalse(summary.headline.isEmpty)
        XCTAssertFalse(summary.subtitle.isEmpty)
    }

    func testEquatable() {
        let a = SessionSummaryState(result: makeResult(), streakAfter: 3, newDueCount: 4)
        let b = SessionSummaryState(result: makeResult(), streakAfter: 3, newDueCount: 4)
        XCTAssertEqual(a, b)
        let c = SessionSummaryState(result: makeResult(), streakAfter: 5, newDueCount: 4)
        XCTAssertNotEqual(a, c)
    }
}
