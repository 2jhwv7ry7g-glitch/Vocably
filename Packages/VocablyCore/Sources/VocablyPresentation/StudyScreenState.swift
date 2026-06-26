import Foundation
import VocablyDomain
import SRSEngine

/// Drives the Swipe Study screen: a flip-card face plus the underlying
/// ``StudySession`` review loop.
///
/// This type is intentionally **not** `Equatable` — it stores a ``StudySession``,
/// which holds an existential `any Scheduler` and cannot synthesize equality.
/// It is a plain value type that the Xcode app's `@Observable` view model wraps.
public struct StudyScreenState {
    /// Which side of the current card is showing.
    public enum Face: Sendable, Equatable {
        /// The term side — what the learner is quizzed on.
        case prompt
        /// The answer side — translation and details.
        case revealed
    }

    /// The currently visible card face. Starts at ``Face/prompt``.
    public private(set) var face: Face

    /// The review loop over the due cards.
    private var session: StudySession

    /// Number of cards in this study pass, fixed at init.
    public let total: Int

    /// Build a study screen over `cards`, starting on the prompt face.
    /// - Parameters:
    ///   - cards: The due cards to review, in order.
    ///   - scheduler: The spaced-repetition scheduler applied on each rating.
    ///   - startedAt: When the session began, used for duration in ``result(now:)``.
    public init(cards: [Card], scheduler: Scheduler = SM2Scheduler(), startedAt: Date = Date()) {
        self.session = StudySession(cards: cards, scheduler: scheduler, startedAt: startedAt)
        self.total = cards.count
        self.face = .prompt
    }

    /// The card currently being reviewed, or `nil` once finished.
    public var currentCard: Card? { session.currentCard }

    /// Cards rated so far.
    public var reviewedCount: Int { session.reviewedCount }

    /// Cards not yet rated.
    public var remainingCount: Int { session.remainingCount }

    /// `true` once every card has been rated.
    public var isFinished: Bool { session.isFinished }

    /// A "current / total" progress label. While studying, the current card is
    /// 1-based and clamped to `total`; once finished it reads "total / total".
    public var progressText: String {
        let current = isFinished ? total : min(reviewedCount + 1, total)
        return "\(current) / \(total)"
    }

    /// Fraction of the pass completed, in `0...1`. An empty pass is fully done.
    public var progressFraction: Double {
        total == 0 ? 1 : Double(reviewedCount) / Double(total)
    }

    /// Toggle between the prompt and revealed faces.
    public mutating func flip() {
        face = (face == .prompt) ? .revealed : .prompt
    }

    /// Force the revealed face.
    public mutating func reveal() {
        face = .revealed
    }

    /// Rate the current card and advance, resetting the next card to its prompt face.
    public mutating func rate(_ rating: Rating, now: Date) {
        session.rate(rating, now: now)
        face = .prompt
    }

    /// Rate the current card from a swipe gesture, then advance.
    public mutating func swipe(_ direction: SwipeDirection, now: Date) {
        rate(Rating.from(swipe: direction), now: now)
    }

    /// Revert the most recent rating, restoring the previous card on its prompt face.
    public mutating func undo() {
        session.undo()
        face = .prompt
    }

    /// Aggregate the session so far into a persistable result.
    public func result(now: Date) -> StudySessionResult {
        session.result(now: now)
    }
}
