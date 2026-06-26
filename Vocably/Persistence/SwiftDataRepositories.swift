import Foundation
import SwiftData
import VocablyDomain
import VocablyServices

// SwiftData persistence (MAC_DEV_GUIDE §6 / HANDOFF §7). Entities mirror the domain
// structs; @ModelActor repositories conform to the same protocols the views already
// use, so swapping these in for the in-memory actors touches nothing else.
// All scheduling stays in SRSEngine — entities are dumb storage.

// MARK: - Entities

@Model
final class DeckEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var languageCode: String
    var translationLanguageCode: String?
    var level: String
    var colorTokenName: String
    var sourceRaw: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \CardEntity.deck) var cards: [CardEntity]

    init(_ deck: Deck) {
        id = deck.id
        name = deck.name
        languageCode = deck.languageCode
        translationLanguageCode = deck.translationLanguageCode
        level = deck.level
        colorTokenName = deck.colorTokenName
        sourceRaw = deck.source.rawValue
        createdAt = deck.createdAt
        cards = deck.cards.map(CardEntity.init)
    }

    func update(from deck: Deck) {
        name = deck.name
        languageCode = deck.languageCode
        translationLanguageCode = deck.translationLanguageCode
        level = deck.level
        colorTokenName = deck.colorTokenName
        sourceRaw = deck.source.rawValue
        createdAt = deck.createdAt
        cards = deck.cards.map(CardEntity.init)
    }

    func toDomain() -> Deck {
        Deck(
            id: id, name: name, languageCode: languageCode,
            translationLanguageCode: translationLanguageCode, level: level,
            colorTokenName: colorTokenName,
            source: CardSource(rawValue: sourceRaw) ?? .manual,
            createdAt: createdAt,
            cards: cards.map { $0.toDomain() }
        )
    }
}

@Model
final class CardEntity {
    @Attribute(.unique) var id: UUID
    var term: String
    var translation: String
    var ipa: String?
    var partOfSpeech: String?
    var example: String?
    var exampleTranslation: String?
    var mnemonic: String?
    var tags: [String] = []
    var sourceRaw: String
    // Flattened Review (SRS state)
    var due: Date
    var intervalDays: Double
    var ease: Double
    var reps: Int
    var lapses: Int
    var lastRatingRaw: Int?
    var masteryLevel: Int
    var deck: DeckEntity?

    init(_ card: Card) {
        id = card.id
        term = card.term
        translation = card.translation
        ipa = card.ipa
        partOfSpeech = card.partOfSpeech
        example = card.example
        exampleTranslation = card.exampleTranslation
        mnemonic = card.mnemonic
        tags = card.tags
        sourceRaw = card.source.rawValue
        due = card.review.due
        intervalDays = card.review.intervalDays
        ease = card.review.ease
        reps = card.review.reps
        lapses = card.review.lapses
        lastRatingRaw = card.review.lastRating?.rawValue
        masteryLevel = card.review.masteryLevel
    }

    func toDomain() -> Card {
        Card(
            id: id, term: term, translation: translation, ipa: ipa,
            partOfSpeech: partOfSpeech, example: example,
            exampleTranslation: exampleTranslation, mnemonic: mnemonic,
            tags: tags,
            source: CardSource(rawValue: sourceRaw) ?? .manual,
            review: Review(
                due: due, intervalDays: intervalDays, ease: ease, reps: reps,
                lapses: lapses, lastRating: lastRatingRaw.flatMap(Rating.init(rawValue:)),
                masteryLevel: masteryLevel
            )
        )
    }
}

@Model
final class ProfileEntity {
    var name: String
    var avatarInitial: String
    var learningLanguage: String
    var nativeLanguage: String
    var dailyGoalMinutes: Int
    var motivations: [String]
    var startingLevel: Int
    var streakCount: Int
    var bestStreak: Int
    var xp: Int
    var level: Int
    var proEntitlement: Bool

    init(_ p: UserProfile) {
        name = p.name; avatarInitial = p.avatarInitial
        learningLanguage = p.learningLanguage; nativeLanguage = p.nativeLanguage
        dailyGoalMinutes = p.dailyGoalMinutes; motivations = p.motivations
        startingLevel = p.startingLevel; streakCount = p.streakCount
        bestStreak = p.bestStreak; xp = p.xp; level = p.level
        proEntitlement = p.proEntitlement
    }

    func update(from p: UserProfile) {
        name = p.name; avatarInitial = p.avatarInitial
        learningLanguage = p.learningLanguage; nativeLanguage = p.nativeLanguage
        dailyGoalMinutes = p.dailyGoalMinutes; motivations = p.motivations
        startingLevel = p.startingLevel; streakCount = p.streakCount
        bestStreak = p.bestStreak; xp = p.xp; level = p.level
        proEntitlement = p.proEntitlement
    }

    func toDomain() -> UserProfile {
        UserProfile(
            name: name, avatarInitial: avatarInitial,
            learningLanguage: learningLanguage, nativeLanguage: nativeLanguage,
            dailyGoalMinutes: dailyGoalMinutes, motivations: motivations,
            startingLevel: startingLevel, streakCount: streakCount,
            bestStreak: bestStreak, xp: xp, level: level, proEntitlement: proEntitlement
        )
    }
}

@Model
final class ActivityEntity {
    @Attribute(.unique) var date: Date
    var wordsReviewed: Int
    var minutes: Int
    var goalMet: Bool

    init(_ a: DailyActivity) {
        date = a.date; wordsReviewed = a.wordsReviewed
        minutes = a.minutes; goalMet = a.goalMet
    }

    func toDomain() -> DailyActivity {
        DailyActivity(date: date, wordsReviewed: wordsReviewed, minutes: minutes, goalMet: goalMet)
    }
}

// MARK: - Container + first-launch seeding

enum VocablyStore {
    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([DeckEntity.self, CardEntity.self, ProfileEntity.self, ActivityEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema changed during dev — fall back to a fresh in-memory store rather than crash.
            container = try! ModelContainer(for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
        seedIfNeeded(container)
        return container
    }

    @MainActor
    private static func seedIfNeeded(_ container: ModelContainer) {
        let ctx = container.mainContext
        let existing = (try? ctx.fetchCount(FetchDescriptor<DeckEntity>())) ?? 0
        guard existing == 0 else { return }
        for deck in SampleData.decks { ctx.insert(DeckEntity(deck)) }
        ctx.insert(ProfileEntity(SampleData.profile))
        for activity in SampleData.weekActivity { ctx.insert(ActivityEntity(activity)) }
        try? ctx.save()
    }
}

// MARK: - Repositories

@ModelActor
actor SwiftDataDeckRepository: DeckRepository {
    func allDecks() async throws -> [Deck] {
        try modelContext.fetch(FetchDescriptor<DeckEntity>(sortBy: [.init(\.createdAt)]))
            .map { $0.toDomain() }
    }

    func deck(id: UUID) async throws -> Deck? {
        try fetchEntity(id: id)?.toDomain()
    }

    func save(_ deck: Deck) async throws {
        if let existing = try fetchEntity(id: deck.id) {
            for card in existing.cards { modelContext.delete(card) }
            existing.update(from: deck)
        } else {
            modelContext.insert(DeckEntity(deck))
        }
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        if let existing = try fetchEntity(id: id) {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }

    private func fetchEntity(id: UUID) throws -> DeckEntity? {
        try modelContext.fetch(FetchDescriptor<DeckEntity>(predicate: #Predicate { $0.id == id })).first
    }
}

@ModelActor
actor SwiftDataProfileRepository: ProfileRepository {
    func load() async throws -> UserProfile? {
        try modelContext.fetch(FetchDescriptor<ProfileEntity>()).first?.toDomain()
    }

    func save(_ profile: UserProfile) async throws {
        if let existing = try modelContext.fetch(FetchDescriptor<ProfileEntity>()).first {
            existing.update(from: profile)
        } else {
            modelContext.insert(ProfileEntity(profile))
        }
        try modelContext.save()
    }
}

@ModelActor
actor SwiftDataActivityRepository: ActivityRepository {
    func all() async throws -> [DailyActivity] {
        try modelContext.fetch(FetchDescriptor<ActivityEntity>(sortBy: [.init(\.date)]))
            .map { $0.toDomain() }
    }

    func record(_ activity: DailyActivity) async throws {
        let day = Calendar.current.startOfDay(for: activity.date)
        let next = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let descriptor = FetchDescriptor<ActivityEntity>(
            predicate: #Predicate { $0.date >= day && $0.date < next }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.wordsReviewed = activity.wordsReviewed
            existing.minutes = activity.minutes
            existing.goalMet = activity.goalMet
        } else {
            modelContext.insert(ActivityEntity(activity))
        }
        try modelContext.save()
    }
}
