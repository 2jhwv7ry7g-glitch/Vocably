import Foundation
import VocablyDomain

// On-disk JSON repositories. Each persists to a single pretty-printed, sorted-keys
// file in the supplied directory, using ISO-8601 dates so files are portable and
// human-readable. Writes are full-file atomic rewrites. Backed by actors for
// Sendable, concurrency-safe access.

/// Builds the shared encoder: pretty-printed, sorted keys, ISO-8601 dates.
private func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}

/// Builds the matching decoder: ISO-8601 dates.
private func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}

/// JSON-file `DeckRepository`. Persists to `decks.json` (an array of `Deck`).
public actor JSONDeckRepository: DeckRepository {
    private let fileURL: URL
    private let encoder = makeEncoder()
    private let decoder = makeDecoder()

    /// Creates a repository writing to `decks.json` inside `directory`,
    /// creating the directory if it does not exist.
    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("decks.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func read() throws -> [Deck] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try decoder.decode([Deck].self, from: Data(contentsOf: fileURL))
    }

    private func write(_ decks: [Deck]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(decks).write(to: fileURL, options: .atomic)
    }

    public func allDecks() async throws -> [Deck] {
        try read()
    }

    public func deck(id: UUID) async throws -> Deck? {
        try read().first { $0.id == id }
    }

    public func save(_ deck: Deck) async throws {
        var decks = try read()
        if let index = decks.firstIndex(where: { $0.id == deck.id }) {
            decks[index] = deck
        } else {
            decks.append(deck)
        }
        try write(decks)
    }

    public func delete(id: UUID) async throws {
        var decks = try read()
        decks.removeAll { $0.id == id }
        try write(decks)
    }
}

/// JSON-file `ProfileRepository`. Persists to `profile.json` (a single `UserProfile`).
public actor JSONProfileRepository: ProfileRepository {
    private let fileURL: URL
    private let encoder = makeEncoder()
    private let decoder = makeDecoder()

    /// Creates a repository writing to `profile.json` inside `directory`,
    /// creating the directory if it does not exist.
    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("profile.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func load() async throws -> UserProfile? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decoder.decode(UserProfile.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ profile: UserProfile) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(profile).write(to: fileURL, options: .atomic)
    }
}

/// JSON-file `ActivityRepository`. Persists to `activity.json` (an array of
/// `DailyActivity`); `record` upserts by UTC calendar day.
public actor JSONActivityRepository: ActivityRepository {
    private let fileURL: URL
    private let encoder = makeEncoder()
    private let decoder = makeDecoder()

    /// Creates a repository writing to `activity.json` inside `directory`,
    /// creating the directory if it does not exist.
    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("activity.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func read() throws -> [DailyActivity] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try decoder.decode([DailyActivity].self, from: Data(contentsOf: fileURL))
    }

    private func write(_ activities: [DailyActivity]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(activities).write(to: fileURL, options: .atomic)
    }

    public func all() async throws -> [DailyActivity] {
        try read()
    }

    public func record(_ activity: DailyActivity) async throws {
        var activities = try read()
        let day = ActivityCalendar.startOfDay(activity.date)
        if let index = activities.firstIndex(where: { ActivityCalendar.startOfDay($0.date) == day }) {
            activities[index] = activity
        } else {
            activities.append(activity)
        }
        try write(activities)
    }
}
