import XCTest
import VocablyDomain
import VocablyPresentation

final class LibraryStateTests: XCTestCase {
    func testAllFilterShowsEveryDeck() {
        let state = LibraryState(decks: SampleData.decks)
        XCTAssertEqual(state.filter, .all)
        XCTAssertEqual(state.visibleDecks.count, SampleData.decks.count)
    }

    func testAiMadeFilterShowsOnlyAIDecks() {
        var state = LibraryState(decks: SampleData.decks)
        state.setFilter(.aiMade)
        let names = state.visibleDecks.map(\.name)
        XCTAssertEqual(names, [SampleData.cafeDeck.name])
        for deck in state.visibleDecks {
            XCTAssertEqual(deck.source, .ai)
        }
    }

    func testQueryMatchesDeckName() {
        var state = LibraryState(decks: SampleData.decks)
        state.setQuery("every")
        let names = state.visibleDecks.map(\.name)
        XCTAssertTrue(names.contains(SampleData.spanishDeck.name))
        // "Café & Restaurant" does not contain the query in name or any card.
        XCTAssertFalse(names.contains(SampleData.cafeDeck.name))
    }

    func testQueryMatchesCardTerm() {
        var state = LibraryState(decks: SampleData.decks)
        state.setQuery("mariposa")
        let names = state.visibleDecks.map(\.name)
        XCTAssertEqual(names, [SampleData.spanishDeck.name])
    }

    func testQueryIsCaseInsensitive() {
        var state = LibraryState(decks: SampleData.decks)
        state.setQuery("MARIPOSA")
        XCTAssertEqual(state.visibleDecks.map(\.name), [SampleData.spanishDeck.name])
    }

    func testFilterAndQueryCombine() {
        var state = LibraryState(decks: SampleData.decks)
        state.setFilter(.aiMade)
        state.setQuery("mariposa")
        // mariposa lives in the manual Spanish deck, excluded by the AI filter.
        XCTAssertTrue(state.visibleDecks.isEmpty)
    }
}
