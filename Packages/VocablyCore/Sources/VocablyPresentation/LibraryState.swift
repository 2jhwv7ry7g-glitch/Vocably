import Foundation
import VocablyDomain

/// Read model for the Library screen: a searchable, filterable list of decks.
///
/// Decks are held privately; `visibleDecks` recomputes the shown subset from the
/// current `query` and `filter` each time it is read.
public struct LibraryState: Equatable, Sendable {
    /// Deck list filters surfaced as chips.
    public enum Filter: String, CaseIterable, Sendable {
        case all, learning, mastered, aiMade
    }

    /// Current case-insensitive search text.
    public private(set) var query: String
    /// Currently selected filter.
    public private(set) var filter: Filter

    private var decks: [Deck]

    public init(decks: [Deck]) {
        self.decks = decks
        self.query = ""
        self.filter = .all
    }

    /// Decks matching the current filter and search query.
    public var visibleDecks: [Deck] {
        var result = decks.filter { deck in
            switch filter {
            case .all:
                return true
            case .learning:
                return deck.learnedCount > 0 && deck.masteredCount < deck.cards.count
            case .mastered:
                return !deck.cards.isEmpty && deck.masteredCount == deck.cards.count
            case .aiMade:
                return deck.source == .ai
            }
        }

        if !query.isEmpty {
            let needle = query.lowercased()
            result = result.filter { deck in
                if deck.name.lowercased().contains(needle) { return true }
                return deck.cards.contains { card in
                    card.term.lowercased().contains(needle)
                        || card.translation.lowercased().contains(needle)
                }
            }
        }

        return result
    }

    /// Update the search query.
    public mutating func setQuery(_ q: String) {
        query = q
    }

    /// Update the active filter.
    public mutating func setFilter(_ f: Filter) {
        filter = f
    }
}
