import Foundation

/// The learner. Mirrors the onboarding choices and the Profile screen.
public struct UserProfile: Codable, Sendable, Equatable {
    public var name: String
    public var avatarInitial: String
    public var learningLanguage: String     // "es"
    public var nativeLanguage: String       // "en"
    public var dailyGoalMinutes: Int        // 5 / 10 / 15 / 30
    public var motivations: [String]        // travel, career, culture, …
    public var startingLevel: Int           // 0 new … 3 advanced
    public var streakCount: Int
    public var bestStreak: Int
    public var xp: Int
    public var level: Int
    public var proEntitlement: Bool

    public init(
        name: String = "",
        avatarInitial: String = "",
        learningLanguage: String = "es",
        nativeLanguage: String = "en",
        dailyGoalMinutes: Int = 10,
        motivations: [String] = [],
        startingLevel: Int = 0,
        streakCount: Int = 0,
        bestStreak: Int = 0,
        xp: Int = 0,
        level: Int = 1,
        proEntitlement: Bool = false
    ) {
        self.name = name
        self.avatarInitial = avatarInitial
        self.learningLanguage = learningLanguage
        self.nativeLanguage = nativeLanguage
        self.dailyGoalMinutes = dailyGoalMinutes
        self.motivations = motivations
        self.startingLevel = startingLevel
        self.streakCount = streakCount
        self.bestStreak = bestStreak
        self.xp = xp
        self.level = level
        self.proEntitlement = proEntitlement
    }
}

/// One day's study activity — powers the streak calendar and widgets.
public struct DailyActivity: Identifiable, Codable, Sendable, Equatable {
    public var id: Date { date }
    public var date: Date
    public var wordsReviewed: Int
    public var minutes: Int
    public var goalMet: Bool

    public init(date: Date, wordsReviewed: Int = 0, minutes: Int = 0, goalMet: Bool = false) {
        self.date = date
        self.wordsReviewed = wordsReviewed
        self.minutes = minutes
        self.goalMet = goalMet
    }
}
