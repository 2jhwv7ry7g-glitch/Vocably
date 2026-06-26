import Foundation
import VocablyDomain

/// Assembles a study queue from one or more decks.
/// Overdue reviews come first (most overdue first), then brand-new cards — the order
/// the Home "Start session" and Deck Detail "Study N due" flows feed into `StudySession`.
public enum SessionBuilder {
    /// All due cards across `decks`, ordered review-first (by due date ascending) then new,
    /// optionally filtered to cards carrying at least one of `tags`, optionally capped at `limit`.
    public static func dueCards(
        from decks: [Deck],
        on date: Date = Date(),
        calendar: Calendar = .current,
        tags: Set<String>? = nil,
        limit: Int? = nil
    ) -> [Card] {
        var reviews: [Card] = []
        var fresh: [Card] = []
        for deck in decks {
            for card in deck.cards where DueQuery.isDue(card.review, on: date, calendar: calendar) {
                if let tags, !tags.isEmpty, Set(card.tags).isDisjoint(with: tags) { continue }
                if card.review.isNew { fresh.append(card) } else { reviews.append(card) }
            }
        }
        reviews.sort { $0.review.due < $1.review.due }
        var result = reviews + fresh
        if let limit, result.count > limit {
            result = Array(result.prefix(limit))
        }
        return result
    }

    /// Total number of due cards across `decks`.
    public static func dueCount(
        from decks: [Deck],
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        decks.reduce(0) { total, deck in
            total + deck.cards.reduce(0) { $0 + (DueQuery.isDue($1.review, on: date, calendar: calendar) ? 1 : 0) }
        }
    }
}
