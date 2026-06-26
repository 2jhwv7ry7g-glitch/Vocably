import Foundation
import VocablyDomain
import SRSEngine

/// Read model for the Home screen: greeting, streak strip, due summary, the
/// "continue studying" card, and the level progress bar.
///
/// Pure derivation from the profile, decks, and recent activity — the Mac view
/// model fetches those, this type turns them into displayable values.
public struct HomeState: Equatable, Sendable {
    /// One cell of the seven-day streak strip.
    public struct DayDot: Equatable, Sendable {
        /// How a day reads in the strip.
        public enum Mark: Sendable { case done, today, future }
        /// Single weekday initial, e.g. "M".
        public var letter: String
        /// Whether the day is today, completed, or missed/future.
        public var mark: Mark

        public init(letter: String, mark: Mark) {
            self.letter = letter
            self.mark = mark
        }
    }

    /// "Hola, " followed by the first word of the profile name (fallback "there").
    public var greeting: String
    /// Current study streak, in days.
    public var streakCount: Int
    /// Best study streak ever reached.
    public var bestStreak: Int
    /// Seven dots, oldest first, ending on today.
    public var weekDots: [DayDot]
    /// Total cards due right now across every deck.
    public var dueCount: Int
    /// Name of the deck with the most due cards, if any.
    public var continueDeckName: String?
    /// Due cards in the "continue" deck.
    public var continueDueCount: Int
    /// Learned-share progress of the "continue" deck (0...1).
    public var continueProgress: Double
    /// Current user level.
    public var level: Int
    /// Progress through the current level (0...1).
    public var levelFraction: Double

    public init(
        profile: UserProfile,
        decks: [Deck],
        activity: [DailyActivity],
        now: Date,
        calendar: Calendar = .current
    ) {
        let firstName = profile.name
            .split(separator: " ", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? "there"
        self.greeting = "Hola, \(firstName)"

        self.streakCount = profile.streakCount
        self.bestStreak = profile.bestStreak

        // Seven calendar days ending on today, oldest first.
        let today = calendar.startOfDay(for: now)
        let symbols = calendar.shortWeekdaySymbols
        var dots: [DayDot] = []
        dots.reserveCapacity(7)
        for offset in stride(from: 6, through: 0, by: -1) {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let dayStart = calendar.startOfDay(for: day)

            let idx = calendar.component(.weekday, from: day) - 1
            let symbol = (idx >= 0 && idx < symbols.count) ? symbols[idx] : ""
            let letter = symbol.first.map { String($0).uppercased() } ?? ""

            let mark: DayDot.Mark
            if dayStart == today {
                mark = .today
            } else if activity.contains(where: { calendar.isDate($0.date, inSameDayAs: day) && $0.goalMet }) {
                mark = .done
            } else {
                mark = .future
            }
            dots.append(DayDot(letter: letter, mark: mark))
        }
        self.weekDots = dots

        // Total due across all decks, and the deck carrying the most due work.
        var totalDue = 0
        var best: (name: String, due: Int, progress: Double)?
        for deck in decks {
            let deckDue = deck.cards.filter {
                DueQuery.isDue($0.review, on: now, calendar: calendar)
            }.count
            totalDue += deckDue
            if deckDue > 0, best == nil || deckDue > best!.due {
                best = (deck.name, deckDue, deck.progress)
            }
        }
        self.dueCount = totalDue
        self.continueDeckName = best?.name
        self.continueDueCount = best?.due ?? 0
        self.continueProgress = best?.progress ?? 0

        let progress = LevelCurve.progress(xp: profile.xp)
        self.level = progress.level
        self.levelFraction = progress.fraction
    }
}
