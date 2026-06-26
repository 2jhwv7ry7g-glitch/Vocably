import XCTest
import Foundation
import VocablyDomain
import SRSEngine
import VocablyPresentation

final class StudyScreenStateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// Three deterministic, immediately-due cards.
    private func makeCards() -> [Card] {
        let now = self.now
        return [
            Card(term: "uno", translation: "one", review: .new(now: now)),
            Card(term: "dos", translation: "two", review: .new(now: now)),
            Card(term: "tres", translation: "three", review: .new(now: now)),
        ]
    }

    func testStartsOnPromptFace() {
        let state = StudyScreenState(cards: makeCards(), startedAt: now)
        XCTAssertEqual(state.face, .prompt)
        XCTAssertEqual(state.total, 3)
        XCTAssertEqual(state.reviewedCount, 0)
        XCTAssertEqual(state.remainingCount, 3)
        XCTAssertFalse(state.isFinished)
        XCTAssertEqual(state.currentCard?.term, "uno")
    }

    func testFlipTogglesFace() {
        var state = StudyScreenState(cards: makeCards(), startedAt: now)
        state.flip()
        XCTAssertEqual(state.face, .revealed)
        state.flip()
        XCTAssertEqual(state.face, .prompt)
    }

    func testRevealForcesRevealedFace() {
        var state = StudyScreenState(cards: makeCards(), startedAt: now)
        state.reveal()
        XCTAssertEqual(state.face, .revealed)
        state.reveal()
        XCTAssertEqual(state.face, .revealed)
    }

    func testRateAdvancesAndResetsFace() {
        var state = StudyScreenState(cards: makeCards(), startedAt: now)
        state.reveal()
        state.rate(.good, now: now)
        XCTAssertEqual(state.face, .prompt)
        XCTAssertEqual(state.reviewedCount, 1)
        XCTAssertEqual(state.remainingCount, 2)
        XCTAssertEqual(state.currentCard?.term, "dos")
    }

    func testSwipeRightCountsAsCorrect() {
        var state = StudyScreenState(cards: makeCards(), startedAt: now)
        state.reveal()
        state.swipe(.right, now: now)
        XCTAssertEqual(state.face, .prompt)
        XCTAssertEqual(state.reviewedCount, 1)
        let result = state.result(now: now)
        XCTAssertEqual(result.correct, 1)
        XCTAssertEqual(result.again, 0)
    }

    func testSwipeLeftCountsAsAgain() {
        var state = StudyScreenState(cards: makeCards(), startedAt: now)
        state.swipe(.left, now: now)
        let result = state.result(now: now)
        XCTAssertEqual(result.correct, 0)
        XCTAssertEqual(result.again, 1)
    }

    func testProgressAtStartMidAndFinish() {
        var state = StudyScreenState(cards: makeCards(), startedAt: now)
        // Start.
        XCTAssertEqual(state.progressText, "1 / 3")
        XCTAssertEqual(state.progressFraction, 0, accuracy: 1e-9)
        // Mid.
        state.rate(.good, now: now)
        XCTAssertEqual(state.progressText, "2 / 3")
        XCTAssertEqual(state.progressFraction, 1.0 / 3.0, accuracy: 1e-9)
        // Finish.
        state.rate(.good, now: now)
        state.rate(.good, now: now)
        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.progressText, "3 / 3")
        XCTAssertEqual(state.progressFraction, 1, accuracy: 1e-9)
        XCTAssertNil(state.currentCard)
    }

    func testEmptyDeckProgressIsComplete() {
        let state = StudyScreenState(cards: [], startedAt: now)
        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.progressText, "0 / 0")
        XCTAssertEqual(state.progressFraction, 1, accuracy: 1e-9)
    }

    func testUndoRestoresPreviousCardAndResetsFace() {
        var state = StudyScreenState(cards: makeCards(), startedAt: now)
        state.rate(.good, now: now)
        XCTAssertEqual(state.currentCard?.term, "dos")
        state.reveal()
        state.undo()
        XCTAssertEqual(state.face, .prompt)
        XCTAssertEqual(state.reviewedCount, 0)
        XCTAssertEqual(state.currentCard?.term, "uno")
    }

    func testResultReviewedMatchesRatings() {
        var state = StudyScreenState(cards: makeCards(), startedAt: now)
        state.rate(.good, now: now)
        state.rate(.again, now: now)
        let result = state.result(now: now)
        XCTAssertEqual(result.reviewed, 2)
        XCTAssertEqual(result.correct, 1)
        XCTAssertEqual(result.again, 1)
        XCTAssertEqual(result.updatedCards.count, 2)
    }

    func testWorksWithSampleData() {
        let due = SampleData.spanishDeck.dueCards(on: now)
        var state = StudyScreenState(cards: due, startedAt: now)
        XCTAssertEqual(state.total, due.count)
        XCTAssertEqual(state.face, .prompt)
        if !due.isEmpty {
            state.swipe(.right, now: now)
            XCTAssertEqual(state.reviewedCount, 1)
            XCTAssertEqual(state.face, .prompt)
        }
    }
}
