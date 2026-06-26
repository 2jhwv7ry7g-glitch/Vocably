import Foundation
import VocablyDomain

// Volatile, in-process repository implementations. Backed by actors so they are
// `Sendable` and concurrency-safe; ideal for previews, the CLI demo, and tests.

/// In-memory `DeckRepository`. Preserves insertion order; `save` upserts by `id`.
public actor InMemoryDeckRepository: DeckRepository {
    private var decks: [Deck]

    /// Creates a repository seeded with `decks` (default empty).
    public init(decks: [Deck] = []) {
        self.decks = decks
    }

    public func allDecks() async throws -> [Deck] {
        decks
    }

    public func deck(id: UUID) async throws -> Deck? {
        decks.first { $0.id == id }
    }

    public func save(_ deck: Deck) async throws {
        if let index = decks.firstIndex(where: { $0.id == deck.id }) {
            decks[index] = deck
        } else {
            decks.append(deck)
        }
    }

    public func delete(id: UUID) async throws {
        decks.removeAll { $0.id == id }
    }
}

/// In-memory `ProfileRepository` holding at most one profile.
public actor InMemoryProfileRepository: ProfileRepository {
    private var profile: UserProfile?

    /// Creates a repository optionally seeded with `profile` (default `nil`).
    public init(profile: UserProfile? = nil) {
        self.profile = profile
    }

    public func load() async throws -> UserProfile? {
        profile
    }

    public func save(_ profile: UserProfile) async throws {
        self.profile = profile
    }
}

/// In-memory `ActivityRepository`. `record` upserts by UTC calendar day.
public actor InMemoryActivityRepository: ActivityRepository {
    private var activities: [DailyActivity]

    /// Creates a repository seeded with `activities` (default empty).
    public init(activities: [DailyActivity] = []) {
        self.activities = activities
    }

    public func all() async throws -> [DailyActivity] {
        activities
    }

    public func record(_ activity: DailyActivity) async throws {
        let day = ActivityCalendar.startOfDay(activity.date)
        if let index = activities.firstIndex(where: { ActivityCalendar.startOfDay($0.date) == day }) {
            activities[index] = activity
        } else {
            activities.append(activity)
        }
    }
}

/// Shared calendar used to collapse activity entries onto a single day.
/// UTC + gregorian so "same day" is deterministic regardless of host time zone.
enum ActivityCalendar {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    /// Midnight (UTC) of the day containing `date`.
    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
