import XCTest
import VocablyDomain
import SRSEngine

final class SessionBuilderTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        return c
    }()
    // Well after the SampleData epoch so every sample card is due.
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    func testDueCardsMatchesDueCount() {
        let decks = SampleData.decks
        let cards = SessionBuilder.dueCards(from: decks, on: now, calendar: cal)
        let count = SessionBuilder.dueCount(from: decks, on: now, calendar: cal)
        XCTAssertEqual(cards.count, count)
        XCTAssertGreaterThan(cards.count, 0)
    }

    func testReviewsSortedBeforeNew() {
        let cards = SessionBuilder.dueCards(from: SampleData.decks, on: now, calendar: cal)
        let firstNewIndex = cards.firstIndex { $0.review.isNew }
        let lastReviewIndex = cards.lastIndex { !$0.review.isNew }
        if let firstNewIndex, let lastReviewIndex {
            XCTAssertLessThan(lastReviewIndex, firstNewIndex, "all reviews should precede all new cards")
        }
        // Non-new portion is ascending by due date.
        let reviews = cards.filter { !$0.review.isNew }
        for i in 1..<max(reviews.count, 1) where reviews.count > 1 {
            XCTAssertLessThanOrEqual(reviews[i - 1].review.due, reviews[i].review.due)
        }
    }

    func testLimitCapsQueue() {
        let limited = SessionBuilder.dueCards(from: SampleData.decks, on: now, calendar: cal, limit: 3)
        XCTAssertEqual(limited.count, 3)
    }

    func testNothingDueWhenFarInPast() {
        // A date before any sample due date -> only brand-new cards (due == construction time) may appear.
        let past = Date(timeIntervalSince1970: 1_600_000_000)
        let count = SessionBuilder.dueCount(from: [SampleData.spanishDeck], on: past, calendar: cal)
        // The spanish deck's scheduled cards are due in 2023+, so none are due in 2020.
        XCTAssertEqual(count, 0)
    }
}
