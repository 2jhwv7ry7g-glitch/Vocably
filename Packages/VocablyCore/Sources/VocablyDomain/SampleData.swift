import Foundation

/// Deterministic sample content for tests, the CLI demo, and SwiftUI previews.
/// Mirrors the words and decks used in the Paper designs.
public enum SampleData {
    public static let languages = Language.catalog

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static func days(_ d: Double) -> Date { now.addingTimeInterval(d * 86_400) }

    /// Spanish "Everyday Essentials" — a mix of mastered, learning, and new cards.
    public static var spanishDeck: Deck {
        Deck(
            name: "Everyday Essentials",
            languageCode: "es",
            level: "A2",
            colorTokenName: "primary",
            source: .manual,
            createdAt: days(-30),
            cards: [
                Card(term: "la mariposa", translation: "butterfly", ipa: "/ma.ɾiˈpo.sa/",
                     partOfSpeech: "noun · feminine", example: "Una mariposa azul cruzó el jardín.",
                     exampleTranslation: "A blue butterfly crossed the garden.",
                     review: Review(due: days(-1), intervalDays: 30, ease: 2.6, reps: 6, masteryLevel: 3)),
                Card(term: "el jardín", translation: "garden", partOfSpeech: "noun · masculine",
                     example: "El jardín al amanecer.",
                     review: Review(due: days(0), intervalDays: 6, ease: 2.5, reps: 2, masteryLevel: 1)),
                Card(term: "amanecer", translation: "dawn",
                     review: Review(due: days(0), intervalDays: 1, ease: 2.5, reps: 1, masteryLevel: 1)),
                Card(term: "susurro", translation: "whisper",
                     review: Review(due: days(0), intervalDays: 0, ease: 2.5, reps: 0, masteryLevel: 0)),
                Card(term: "la cuenta", translation: "the bill", example: "La cuenta, por favor.",
                     review: Review(due: days(-2), intervalDays: 15, ease: 2.5, reps: 3, masteryLevel: 2)),
            ]
        )
    }

    /// Café & restaurant deck (matches the AI Generate result in the designs).
    public static var cafeDeck: Deck {
        Deck(
            name: "Café & Restaurant",
            languageCode: "es",
            level: "A2",
            colorTokenName: "accent",
            source: .ai,
            createdAt: days(-3),
            cards: [
                Card(term: "el camarero", translation: "the waiter", example: "¿Nos atiende el camarero?", source: .ai),
                Card(term: "pedir", translation: "to order", example: "Vamos a pedir unas tapas.", source: .ai),
                Card(term: "la propina", translation: "the tip", example: "Dejé una buena propina.", source: .ai),
            ]
        )
    }

    public static var decks: [Deck] { [spanishDeck, cafeDeck] }

    public static var profile: UserProfile {
        UserProfile(
            name: "Mara Ortiz", avatarInitial: "M",
            learningLanguage: "es", nativeLanguage: "en",
            dailyGoalMinutes: DailyGoal.regular.minutes,
            motivations: [Motivation.travel.rawValue, Motivation.culture.rawValue],
            startingLevel: ProficiencyLevel.fewWords.rawValue,
            streakCount: 12, bestStreak: 21, xp: 320, level: 7, proEntitlement: true
        )
    }

    /// Last 7 days of activity (6 completed days + today in progress) — feeds the streak strip.
    public static var weekActivity: [DailyActivity] {
        (1...7).map { i in
            let goalMet = i > 1   // every day but "today" met the goal
            return DailyActivity(date: days(Double(-(i - 1))),
                                 wordsReviewed: goalMet ? 22 : 18,
                                 minutes: goalMet ? 11 : 6,
                                 goalMet: goalMet)
        }
    }

    public static var achievements: [Achievement] { Achievement.catalog }
}
