import Foundation

/// Spaced-repetition scheduling state for a single card.
/// Device-authoritative; conflict resolution is last-writer-wins by `due`.
public struct Review: Codable, Sendable, Equatable {
    /// When the card is next due for review.
    public var due: Date
    /// Current inter-repetition interval, in days.
    public var intervalDays: Double
    /// SM-2 easiness factor (>= 1.3).
    public var ease: Double
    /// Consecutive successful repetitions (reset to 0 on a lapse).
    public var reps: Int
    /// Total times the card was forgotten after being learned.
    public var lapses: Int
    /// The most recent rating, if any.
    public var lastRating: Rating?
    /// 0 new · 1 learning · 2 familiar · 3 mastered — maps to the mastery dots in Deck Detail.
    public var masteryLevel: Int

    public init(
        due: Date,
        intervalDays: Double = 0,
        ease: Double = 2.5,
        reps: Int = 0,
        lapses: Int = 0,
        lastRating: Rating? = nil,
        masteryLevel: Int = 0
    ) {
        self.due = due
        self.intervalDays = intervalDays
        self.ease = ease
        self.reps = reps
        self.lapses = lapses
        self.lastRating = lastRating
        self.masteryLevel = masteryLevel
    }

    /// A brand-new card, due immediately.
    public static func new(now: Date = Date()) -> Review {
        Review(due: now)
    }

    /// Whether this card is a fresh, never-reviewed card.
    public var isNew: Bool { reps == 0 && lastRating == nil }
}
