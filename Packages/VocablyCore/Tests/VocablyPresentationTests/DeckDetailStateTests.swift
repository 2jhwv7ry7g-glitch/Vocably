import XCTest
import VocablyDomain
import SRSEngine
import VocablyPresentation

final class DeckDetailStateTests: XCTestCase {
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return cal
    }

    /// Well after the Spanish deck's due dates, so every card is due.
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    func testHeaderAndWordsFromDeck() {
        let deck = SampleData.spanishDeck
        let state = DeckDetailState(deck: deck, now: now, calendar: utcCalendar())

        XCTAssertEqual(state.deckName, deck.name)
        XCTAssertEqual(state.languageCode, deck.languageCode)
        XCTAssertEqual(state.level, deck.level)
        XCTAssertEqual(state.words.count, deck.cards.count)
        XCTAssertEqual(state.learned, deck.learnedCount)
        XCTAssertEqual(state.mastered, deck.masteredCount)
        XCTAssertGreaterThanOrEqual(state.mastered, 1)
        XCTAssertEqual(state.progressPercent, Int((deck.progress * 100).rounded()))
    }

    func testMasteryDotsClampedToRange() {
        let state = DeckDetailState(deck: SampleData.spanishDeck, now: now, calendar: utcCalendar())
        for row in state.words {
            XCTAssertTrue((0...3).contains(row.masteryDots))
        }
    }

    func testStudyButtonReflectsDueCount() {
        let state = DeckDetailState(deck: SampleData.spanishDeck, now: now, calendar: utcCalendar())
        XCTAssertGreaterThan(state.dueToday, 0)
        XCTAssertEqual(state.studyButtonTitle, "Study \(state.dueToday) due words")
    }

    func testStudyButtonWhenCaughtUp() {
        // A now before every due date leaves nothing due.
        let early = Date(timeIntervalSince1970: 0)
        let state = DeckDetailState(deck: SampleData.spanishDeck, now: early, calendar: utcCalendar())
        XCTAssertEqual(state.dueToday, 0)
        XCTAssertEqual(state.studyButtonTitle, "All caught up")
    }
}
