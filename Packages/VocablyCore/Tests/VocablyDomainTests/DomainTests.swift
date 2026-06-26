import XCTest
import VocablyDomain

final class DomainTests: XCTestCase {
    func testNewReviewIsNewAndDueNow() {
        let now = Date()
        let r = Review.new(now: now)
        XCTAssertTrue(r.isNew)
        XCTAssertEqual(r.due, now)
    }

    func testCardDraftMakesAICard() {
        let draft = CardDraft(term: "la cuenta", translation: "the bill", example: "La cuenta, por favor.")
        let card = draft.makeCard()
        XCTAssertEqual(card.term, "la cuenta")
        XCTAssertEqual(card.translation, "the bill")
        XCTAssertEqual(card.source, .ai)
        XCTAssertTrue(card.review.isNew)
    }

    func testDeckProgressAndCounts() {
        let now = Date()
        let learned = Card(term: "a", translation: "a",
                           review: Review(due: now, intervalDays: 6, ease: 2.5, reps: 2))
        let mastered = Card(term: "b", translation: "b",
                            review: Review(due: now, intervalDays: 30, ease: 2.6, reps: 6, masteryLevel: 3))
        let fresh = Card(term: "c", translation: "c", review: .new(now: now))
        let deck = Deck(name: "Test", languageCode: "es", cards: [learned, mastered, fresh])

        XCTAssertEqual(deck.learnedCount, 2)
        XCTAssertEqual(deck.masteredCount, 1)
        XCTAssertEqual(deck.progress, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(deck.dueCards(on: now).count, 3)
    }

    func testSubscriptionStatusIsPro() {
        XCTAssertTrue(SubscriptionStatus.trial.isPro)
        XCTAssertTrue(SubscriptionStatus.pro.isPro)
        XCTAssertFalse(SubscriptionStatus.free.isPro)
        XCTAssertFalse(SubscriptionStatus.unknown.isPro)
    }
}
