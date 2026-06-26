import XCTest
import VocablyDomain
import SRSEngine

final class StudySessionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let now = Date(timeIntervalSince1970: 1_000_300)   // start + 5 minutes

    /// Three fresh, deterministic cards.
    private func makeCards(_ count: Int = 3) -> [Card] {
        (0..<count).map { i in
            Card(term: "term\(i)", translation: "trans\(i)", review: .new(now: start))
        }
    }

    func testEmptySessionIsImmediatelyFinished() {
        let session = StudySession(cards: [], startedAt: start)
        XCTAssertTrue(session.isFinished)
        XCTAssertNil(session.currentCard)
        XCTAssertEqual(session.remainingCount, 0)
        XCTAssertEqual(session.reviewedCount, 0)

        let result = session.result(now: now)
        XCTAssertEqual(result.reviewed, 0)
        XCTAssertEqual(result.correct, 0)
        XCTAssertEqual(result.again, 0)
        XCTAssertEqual(result.accuracy, 0, accuracy: 0.0001)
        XCTAssertEqual(result.xpEarned, 0)
        XCTAssertTrue(result.updatedCards.isEmpty)
        XCTAssertEqual(result.duration, 300, accuracy: 0.0001)
    }

    func testRatingAllGoodFinishesWithPerfectAccuracy() {
        let cards = makeCards(3)
        var session = StudySession(cards: cards, startedAt: start)

        XCTAssertEqual(session.currentCard?.term, "term0")
        session.rate(.good, now: now)
        XCTAssertEqual(session.currentCard?.term, "term1")
        session.rate(.good, now: now)
        session.rate(.good, now: now)

        XCTAssertTrue(session.isFinished)
        XCTAssertNil(session.currentCard)
        XCTAssertEqual(session.remainingCount, 0)

        let result = session.result(now: now)
        XCTAssertEqual(result.reviewed, 3)
        XCTAssertEqual(result.correct, 3)
        XCTAssertEqual(result.again, 0)
        XCTAssertEqual(result.accuracy, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.updatedCards.count, 3)
        XCTAssertEqual(result.xpEarned, 3 * 12)

        // Each updated card carries advanced review state.
        for (input, updated) in zip(cards, result.updatedCards) {
            XCTAssertEqual(updated.review.reps, input.review.reps + 1)
            XCTAssertEqual(updated.review.lastRating, .good)
        }
    }

    func testMixedRatingsTallyCorrectly() {
        var session = StudySession(cards: makeCards(3), startedAt: start)
        session.rate(.good, now: now)
        session.rate(.again, now: now)
        session.rate(.easy, now: now)

        let result = session.result(now: now)
        XCTAssertEqual(result.reviewed, 3)
        XCTAssertEqual(result.correct, 2)
        XCTAssertEqual(result.again, 1)
        XCTAssertEqual(result.accuracy, 2.0 / 3.0, accuracy: 0.0001)

        let config = StudySession.Config()
        XCTAssertEqual(result.xpEarned, config.xpGood + config.xpAgain + config.xpEasy)
    }

    func testRateIsNoOpWhenFinished() {
        var session = StudySession(cards: makeCards(1), startedAt: start)
        session.rate(.good, now: now)
        XCTAssertTrue(session.isFinished)

        session.rate(.again, now: now)   // ignored
        let result = session.result(now: now)
        XCTAssertEqual(result.reviewed, 1)
        XCTAssertEqual(result.correct, 1)
        XCTAssertEqual(result.again, 0)
    }

    func testUndoRestoresPreviousCardAndCounters() {
        let cards = makeCards(3)
        var session = StudySession(cards: cards, startedAt: start)

        session.rate(.good, now: now)
        XCTAssertEqual(session.reviewedCount, 1)
        XCTAssertEqual(session.currentCard?.term, "term1")

        session.undo()
        XCTAssertEqual(session.reviewedCount, 0)
        XCTAssertEqual(session.remainingCount, 3)
        XCTAssertEqual(session.currentCard?.term, "term0")

        let afterUndo = session.result(now: now)
        XCTAssertEqual(afterUndo.reviewed, 0)
        XCTAssertEqual(afterUndo.correct, 0)
        XCTAssertEqual(afterUndo.xpEarned, 0)
        XCTAssertTrue(afterUndo.updatedCards.isEmpty)

        // Re-rate the same card differently; result stays consistent.
        session.rate(.again, now: now)
        let reRated = session.result(now: now)
        XCTAssertEqual(reRated.reviewed, 1)
        XCTAssertEqual(reRated.correct, 0)
        XCTAssertEqual(reRated.again, 1)
        XCTAssertEqual(reRated.updatedCards.first?.review.lastRating, .again)
    }

    func testUndoIsNoOpWhenNothingRated() {
        var session = StudySession(cards: makeCards(2), startedAt: start)
        session.undo()
        XCTAssertEqual(session.reviewedCount, 0)
        XCTAssertEqual(session.remainingCount, 2)
        XCTAssertEqual(session.currentCard?.term, "term0")
    }

    func testConfigXPForRatingReturnsConfiguredValues() {
        let config = StudySession.Config(xpAgain: 1, xpHard: 5, xpGood: 9, xpEasy: 20)
        XCTAssertEqual(config.xp(for: .again), 1)
        XCTAssertEqual(config.xp(for: .hard), 5)
        XCTAssertEqual(config.xp(for: .good), 9)
        XCTAssertEqual(config.xp(for: .easy), 20)
    }

    func testCustomConfigDrivesXPEarned() {
        let config = StudySession.Config(xpAgain: 1, xpHard: 5, xpGood: 9, xpEasy: 20)
        var session = StudySession(cards: makeCards(2), config: config, startedAt: start)
        session.rate(.hard, now: now)
        session.rate(.easy, now: now)
        XCTAssertEqual(session.result(now: now).xpEarned, 5 + 20)
    }

    func testRunsOverSampleDeck() {
        let cards = SampleData.spanishDeck.cards
        var session = StudySession(cards: cards, startedAt: start)
        XCTAssertEqual(session.remainingCount, cards.count)

        for _ in cards { session.rate(.good, now: now) }
        XCTAssertTrue(session.isFinished)

        let result = session.result(now: now)
        XCTAssertEqual(result.reviewed, cards.count)
        XCTAssertEqual(result.correct, cards.count)
        XCTAssertEqual(result.accuracy, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.updatedCards.count, cards.count)
    }
}
