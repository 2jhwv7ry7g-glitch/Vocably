import XCTest
import VocablyDomain

final class CatalogTests: XCTestCase {
    func testLanguageCatalogLookup() {
        XCTAssertFalse(Language.catalog.isEmpty)
        XCTAssertEqual(Language.named("es")?.name, "Spanish")
        XCTAssertEqual(Language.named("ja")?.nativeName, "日本語")
        XCTAssertNil(Language.named("xx"))
    }

    func testDailyGoalMinutes() {
        XCTAssertEqual(DailyGoal.regular.minutes, 10)
        XCTAssertEqual(DailyGoal.intense.minutes, 30)
        XCTAssertEqual(DailyGoal.allCases.count, 4)
        XCTAssertEqual(DailyGoal.regular.dailyXPTarget, 100)
        XCTAssertEqual(DailyGoal.recommended, .regular)
    }

    func testMotivationsAndLevels() {
        XCTAssertEqual(Motivation.allCases.count, 6)
        XCTAssertFalse(Motivation.travel.title.isEmpty)
        XCTAssertEqual(ProficiencyLevel.new.bars, 1)
        XCTAssertEqual(ProficiencyLevel.advanced.bars, 4)
        XCTAssertLessThan(ProficiencyLevel.new.rawValue, ProficiencyLevel.advanced.rawValue)
    }

    func testAchievementCatalog() {
        XCTAssertFalse(Achievement.catalog.isEmpty)
        XCTAssertTrue(Achievement.catalog.contains { $0.isEarned })
        XCTAssertTrue(Achievement.catalog.contains { !$0.isEarned })
    }

    func testSampleData() {
        XCTAssertEqual(SampleData.decks.count, 2)
        XCTAssertFalse(SampleData.spanishDeck.cards.isEmpty)
        XCTAssertEqual(SampleData.profile.streakCount, 12)
        XCTAssertEqual(SampleData.weekActivity.count, 7)
        XCTAssertEqual(SampleData.weekActivity.filter { $0.goalMet }.count, 6)
        // The spanish deck has at least one mastered and one brand-new card.
        XCTAssertTrue(SampleData.spanishDeck.cards.contains { $0.review.masteryLevel >= 3 })
        XCTAssertTrue(SampleData.spanishDeck.cards.contains { $0.review.isNew })
    }
}
