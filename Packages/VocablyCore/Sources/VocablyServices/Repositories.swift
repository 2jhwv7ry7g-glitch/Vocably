import Foundation
import VocablyDomain

// Persistence protocols. Implementations live in `InMemoryRepositories.swift`
// (volatile, test/preview) and `JSONRepositories.swift` (on-disk JSON files).
// All are `Sendable` so they can be shared across actors and the CLI.

/// Stores and retrieves decks. `save` upserts by `id`.
public protocol DeckRepository: Sendable {
    /// All decks in insertion order.
    func allDecks() async throws -> [Deck]
    /// The deck with the given `id`, or `nil` if none exists.
    func deck(id: UUID) async throws -> Deck?
    /// Inserts a new deck or replaces the existing one with the same `id`.
    func save(_ deck: Deck) async throws
    /// Removes the deck with the given `id`. No-op if absent.
    func delete(id: UUID) async throws
}

/// Stores the single user profile.
public protocol ProfileRepository: Sendable {
    /// The saved profile, or `nil` if none has been saved yet.
    func load() async throws -> UserProfile?
    /// Persists the profile, replacing any previous one.
    func save(_ profile: UserProfile) async throws
}

/// Stores per-day study activity. `record` upserts by calendar day.
public protocol ActivityRepository: Sendable {
    /// All recorded activity entries.
    func all() async throws -> [DailyActivity]
    /// Inserts the activity, replacing any existing entry on the same calendar day.
    func record(_ activity: DailyActivity) async throws
}
