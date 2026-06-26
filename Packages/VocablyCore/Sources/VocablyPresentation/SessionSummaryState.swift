import Foundation
import SRSEngine

/// The "session complete" screen: a snapshot of a finished study pass,
/// derived from a ``StudySessionResult`` plus post-session gamification numbers.
public struct SessionSummaryState: Equatable, Sendable {
    /// Cards rated this session.
    public var reviewed: Int
    /// Cards rated `.good` or `.easy`.
    public var correct: Int
    /// Accuracy as a whole percentage, rounded (`accuracy * 100`).
    public var accuracyPercent: Int
    /// XP awarded across the session.
    public var xpEarned: Int
    /// The learner's streak after applying this session.
    public var streakAfter: Int
    /// Cards still due after this session.
    public var newDueCount: Int

    /// Build a summary from a finished session's result and the updated streak/due counts.
    /// - Parameters:
    ///   - result: The aggregated outcome of the study pass.
    ///   - streakAfter: The learner's streak after this session is applied.
    ///   - newDueCount: How many cards remain due afterward.
    public init(result: StudySessionResult, streakAfter: Int, newDueCount: Int) {
        self.reviewed = result.reviewed
        self.correct = result.correct
        self.accuracyPercent = Int((result.accuracy * 100).rounded())
        self.xpEarned = result.xpEarned
        self.streakAfter = streakAfter
        self.newDueCount = newDueCount
    }

    /// The screen headline.
    public var headline: String { "Session complete" }

    /// A celebratory subtitle.
    public var subtitle: String { "¡Bien hecho!" }
}
