import Foundation

/// A collection of cards in one language.
public struct Deck: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var languageCode: String         // e.g. "es"
    public var level: String                // e.g. "A2"
    public var colorTokenName: String       // "primary" / "accent" / "rose" — the deck mark colour
    public var source: CardSource
    public var createdAt: Date
    public var cards: [Card]

    public init(
        id: UUID = UUID(),
        name: String,
        languageCode: String,
        level: String = "",
        colorTokenName: String = "primary",
        source: CardSource = .manual,
        createdAt: Date = Date(),
        cards: [Card] = []
    ) {
        self.id = id
        self.name = name
        self.languageCode = languageCode
        self.level = level
        self.colorTokenName = colorTokenName
        self.source = source
        self.createdAt = createdAt
        self.cards = cards
    }

    /// Cards whose review is due on or before `date`.
    public func dueCards(on date: Date = Date()) -> [Card] {
        cards.filter { $0.review.due <= date }
    }

    /// Cards that have been reviewed at least once.
    public var learnedCount: Int { cards.filter { !$0.review.isNew }.count }

    /// Cards at full mastery (all dots filled).
    public var masteredCount: Int { cards.filter { $0.review.masteryLevel >= 3 }.count }

    /// 0.0–1.0 share of cards learned, for progress rings/bars.
    public var progress: Double {
        cards.isEmpty ? 0 : Double(learnedCount) / Double(cards.count)
    }
}
