import Foundation
import VocablyDomain
import SRSEngine

/// Read model for the Deck Detail screen: deck header stats and the word list.
public struct DeckDetailState: Equatable, Sendable {
    /// One row in the word list.
    public struct WordRow: Equatable, Sendable {
        public var term: String
        public var translation: String
        /// Mastery dots filled, clamped to 0...3.
        public var masteryDots: Int

        public init(term: String, translation: String, masteryDots: Int) {
            self.term = term
            self.translation = translation
            self.masteryDots = masteryDots
        }
    }

    public var deckName: String
    public var languageCode: String
    public var level: String
    /// Learned share as a whole percentage.
    public var progressPercent: Int
    public var learned: Int
    public var dueToday: Int
    public var mastered: Int
    public var words: [WordRow]

    public init(deck: Deck, now: Date, calendar: Calendar = .current) {
        self.deckName = deck.name
        self.languageCode = deck.languageCode
        self.level = deck.level
        self.progressPercent = Int((deck.progress * 100).rounded())
        self.learned = deck.learnedCount
        self.dueToday = deck.cards.filter {
            DueQuery.isDue($0.review, on: now, calendar: calendar)
        }.count
        self.mastered = deck.masteredCount
        self.words = deck.cards.map { card in
            WordRow(
                term: card.term,
                translation: card.translation,
                masteryDots: min(3, max(0, card.review.masteryLevel))
            )
        }
    }

    /// Title for the primary study action.
    public var studyButtonTitle: String {
        dueToday > 0 ? "Study \(dueToday) due words" : "All caught up"
    }
}
