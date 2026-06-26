import Foundation
import VocablyDomain

/// The outcome of one Swipe Study pass, ready to persist and feed gamification.
public struct StudySessionResult: Sendable, Equatable {
    /// Number of cards rated this session.
    public var reviewed: Int
    /// Cards rated `.good` or `.easy`.
    public var correct: Int
    /// Cards rated `.again`.
    public var again: Int
    /// `reviewed == 0 ? 0 : Double(correct) / Double(reviewed)`.
    public var accuracy: Double
    /// Total XP awarded across the rated cards.
    public var xpEarned: Int
    /// The rated cards carrying their NEW review state — persist these.
    public var updatedCards: [Card]
    /// Wall-clock time from `startedAt` to the moment `result` was requested.
    public var duration: TimeInterval

    public init(
        reviewed: Int,
        correct: Int,
        again: Int,
        accuracy: Double,
        xpEarned: Int,
        updatedCards: [Card],
        duration: TimeInterval
    ) {
        self.reviewed = reviewed
        self.correct = correct
        self.again = again
        self.accuracy = accuracy
        self.xpEarned = xpEarned
        self.updatedCards = updatedCards
        self.duration = duration
    }
}

/// Drives the Swipe Study screen's review loop over a fixed list of due cards.
///
/// Cards are reviewed exactly once each, in order — there is no requeue. Each
/// `rate` applies the `Scheduler` to the current card, records the updated copy,
/// and advances. `undo` reverts the most recent rating so the card can be rated
/// again. Aggregate `result` whenever you need to persist progress.
public struct StudySession {
    /// XP awarded per rating during a session.
    public struct Config: Sendable, Equatable {
        public var xpAgain: Int
        public var xpHard: Int
        public var xpGood: Int
        public var xpEasy: Int

        public init(xpAgain: Int = 2, xpHard: Int = 8, xpGood: Int = 12, xpEasy: Int = 15) {
            self.xpAgain = xpAgain
            self.xpHard = xpHard
            self.xpGood = xpGood
            self.xpEasy = xpEasy
        }

        /// XP awarded for a given rating.
        public func xp(for rating: Rating) -> Int {
            switch rating {
            case .again: return xpAgain
            case .hard: return xpHard
            case .good: return xpGood
            case .easy: return xpEasy
            }
        }
    }

    /// A card that has been rated, paired with the rating that produced its new state.
    private struct Entry {
        var card: Card
        var rating: Rating
    }

    private let cards: [Card]
    private let scheduler: any Scheduler
    private let config: Config
    private let startedAt: Date

    /// Rated cards, in the order they were rated. `entries.count` is the cursor.
    private var entries: [Entry] = []

    public init(
        cards: [Card],
        scheduler: Scheduler = SM2Scheduler(),
        config: Config = .init(),
        startedAt: Date = Date()
    ) {
        self.cards = cards
        self.scheduler = scheduler
        self.config = config
        self.startedAt = startedAt
    }

    /// The next unrated card, or `nil` once every card has been rated.
    public var currentCard: Card? {
        entries.count < cards.count ? cards[entries.count] : nil
    }

    /// Cards not yet rated.
    public var remainingCount: Int {
        cards.count - entries.count
    }

    /// Cards rated so far.
    public var reviewedCount: Int {
        entries.count
    }

    /// `true` once every card has been rated.
    public var isFinished: Bool {
        entries.count == cards.count
    }

    /// Rate the current card: schedule its next review, record the updated copy,
    /// and advance. A no-op when the session is already finished.
    public mutating func rate(_ rating: Rating, now: Date) {
        guard let card = currentCard else { return }
        var updated = card
        updated.review = scheduler.schedule(card.review, rating: rating, now: now)
        entries.append(Entry(card: updated, rating: rating))
    }

    /// Revert the most recent rating, restoring the card to unrated. A no-op when
    /// nothing has been rated yet.
    public mutating func undo() {
        guard !entries.isEmpty else { return }
        entries.removeLast()
    }

    /// Aggregate the session so far. `updatedCards` holds only the rated cards.
    public func result(now: Date) -> StudySessionResult {
        let reviewed = entries.count
        let correct = entries.filter { $0.rating == .good || $0.rating == .easy }.count
        let again = entries.filter { $0.rating == .again }.count
        let xpEarned = entries.reduce(0) { $0 + config.xp(for: $1.rating) }
        let accuracy = reviewed == 0 ? 0 : Double(correct) / Double(reviewed)
        return StudySessionResult(
            reviewed: reviewed,
            correct: correct,
            again: again,
            accuracy: accuracy,
            xpEarned: xpEarned,
            updatedCards: entries.map { $0.card },
            duration: now.timeIntervalSince(startedAt)
        )
    }
}
