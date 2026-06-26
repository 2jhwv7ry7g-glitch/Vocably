import XCTest
import Foundation
import VocablyDomain
import VocablyServices

final class RepositoryTests: XCTestCase {

    // MARK: - In-memory: decks

    func testInMemoryDeckRepositoryUpsertAndDelete() async throws {
        let repo = InMemoryDeckRepository(decks: SampleData.decks)
        let seeded = try await repo.allDecks()
        XCTAssertEqual(seeded.count, SampleData.decks.count)

        let newDeck = Deck(name: "Travel", languageCode: "es")
        try await repo.save(newDeck)
        let fetched = try await repo.deck(id: newDeck.id)
        XCTAssertEqual(fetched, newDeck)
        let afterAdd = try await repo.allDecks()
        XCTAssertEqual(afterAdd.count, SampleData.decks.count + 1)

        var updated = newDeck
        updated.name = "Travel & Transit"
        try await repo.save(updated)
        let afterUpdate = try await repo.allDecks()
        XCTAssertEqual(afterUpdate.count, SampleData.decks.count + 1)
        let renamed = try await repo.deck(id: newDeck.id)
        XCTAssertEqual(renamed?.name, "Travel & Transit")

        try await repo.delete(id: newDeck.id)
        let afterDeleteLookup = try await repo.deck(id: newDeck.id)
        XCTAssertNil(afterDeleteLookup)
        let afterDelete = try await repo.allDecks()
        XCTAssertEqual(afterDelete.count, SampleData.decks.count)
    }

    // MARK: - In-memory: profile

    func testInMemoryProfileRepositoryLoadAfterSave() async throws {
        let repo = InMemoryProfileRepository()
        let initial = try await repo.load()
        XCTAssertNil(initial)

        let profile = SampleData.profile
        try await repo.save(profile)
        let loaded = try await repo.load()
        XCTAssertEqual(loaded, profile)
    }

    // MARK: - In-memory: activity

    func testInMemoryActivityRepositoryUpsertsBySameDay() async throws {
        let repo = InMemoryActivityRepository()
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86_400)

        try await repo.record(DailyActivity(date: day1, wordsReviewed: 10, minutes: 5))
        try await repo.record(DailyActivity(date: day2, wordsReviewed: 20, minutes: 8))
        let twoDays = try await repo.all()
        XCTAssertEqual(twoDays.count, 2)

        // Same calendar day as day1, later in the day, different values -> replace.
        let day1Later = day1.addingTimeInterval(3_600)
        try await repo.record(DailyActivity(date: day1Later, wordsReviewed: 99, minutes: 30, goalMet: true))

        let all = try await repo.all()
        XCTAssertEqual(all.count, 2)
        let replaced = try XCTUnwrap(all.first { $0.wordsReviewed == 99 })
        XCTAssertEqual(replaced.minutes, 30)
        XCTAssertTrue(replaced.goalMet)
        XCTAssertNil(all.first { $0.wordsReviewed == 10 })
    }

    // MARK: - JSON round-trips (disk persistence)

    func testJSONDeckRepositoryPersistsAcrossInstances() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let writer = JSONDeckRepository(directory: dir)
        for deck in SampleData.decks {
            try await writer.save(deck)
        }

        let reader = JSONDeckRepository(directory: dir)
        let reloaded = try await reader.allDecks()
        XCTAssertEqual(reloaded.count, SampleData.decks.count)
    }

    func testJSONProfileRepositoryPersistsAcrossInstances() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let writer = JSONProfileRepository(directory: dir)
        let empty = try await writer.load()
        XCTAssertNil(empty)
        try await writer.save(SampleData.profile)

        let reader = JSONProfileRepository(directory: dir)
        let reloaded = try await reader.load()
        XCTAssertEqual(reloaded, SampleData.profile)
    }

    func testJSONActivityRepositoryPersistsAcrossInstances() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let writer = JSONActivityRepository(directory: dir)
        for activity in SampleData.weekActivity {
            try await writer.record(activity)
        }

        let reader = JSONActivityRepository(directory: dir)
        let reloaded = try await reader.all()
        XCTAssertEqual(reloaded.count, SampleData.weekActivity.count)
    }
}
