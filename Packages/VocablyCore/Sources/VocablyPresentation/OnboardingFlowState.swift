import Foundation
import VocablyDomain

/// Drives the multi-step onboarding flow (welcome → language → motivation → goal → level → paywall → done).
///
/// Pure presentation logic: holds the user's in-progress selections, gates forward navigation,
/// and converts a completed flow into a `UserProfile`. No I/O — the platform view model owns persistence.
public struct OnboardingFlowState: Equatable, Sendable {
    /// Ordered onboarding screens. Raw values define both order and `progressFraction`.
    public enum Step: Int, CaseIterable, Sendable {
        case welcome, language, motivation, goal, level, paywall, done
    }

    /// The screen currently shown. Mutated only through `advance()` / `back()`.
    public private(set) var step: Step
    /// Language chosen on the language step.
    public var selectedLanguage: Language?
    /// Motivations chosen on the motivation step (multi-select).
    public var motivations: Set<Motivation>
    /// Daily commitment chosen on the goal step.
    public var dailyGoal: DailyGoal?
    /// Self-reported ability chosen on the level step.
    public var level: ProficiencyLevel?

    /// A fresh flow positioned on the welcome step with no selections.
    public init() {
        self.step = .welcome
        self.selectedLanguage = nil
        self.motivations = []
        self.dailyGoal = nil
        self.level = nil
    }

    /// Whether the current step's requirement is satisfied and forward navigation is allowed.
    public var canAdvance: Bool {
        switch step {
        case .welcome: return true
        case .language: return selectedLanguage != nil
        case .motivation: return !motivations.isEmpty
        case .goal: return dailyGoal != nil
        case .level: return level != nil
        case .paywall: return true
        case .done: return false
        }
    }

    /// Progress through the flow in `0...1`, where `done` is `1`.
    public var progressFraction: Double {
        Double(step.rawValue) / Double(Step.done.rawValue)
    }

    /// Insert `m` if absent, otherwise remove it.
    public mutating func toggle(_ m: Motivation) {
        if motivations.contains(m) {
            motivations.remove(m)
        } else {
            motivations.insert(m)
        }
    }

    /// Move to the next step when the current step's requirement is met. No-op on `done`.
    public mutating func advance() {
        guard canAdvance, step != .done,
              let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    /// Move to the previous step. No-op on the first step.
    public mutating func back() {
        guard step.rawValue > 0, let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    /// Build a `UserProfile` from the collected selections.
    ///
    /// Returns `nil` until language, goal, and level are all chosen.
    /// - Parameter name: the learner's name; its first letter (uppercased) becomes `avatarInitial`.
    public func makeProfile(name: String) -> UserProfile? {
        guard let selectedLanguage, let dailyGoal, let level else { return nil }
        let initial = name.first.map { String($0).uppercased() } ?? ""
        return UserProfile(
            name: name,
            avatarInitial: initial,
            learningLanguage: selectedLanguage.code,
            dailyGoalMinutes: dailyGoal.minutes,
            motivations: motivations.map(\.rawValue).sorted(),
            startingLevel: level.rawValue
        )
    }
}
