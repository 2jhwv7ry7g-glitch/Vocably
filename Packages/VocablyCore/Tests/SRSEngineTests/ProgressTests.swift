import XCTest
import VocablyDomain
import SRSEngine

final class ProgressTests: XCTestCase {
    private let today = Date(timeIntervalSince1970: 1_700_000_000)
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// Date `offset` whole days from `today` (negative = past), same time-of-day.
    private func day(_ offset: Int) -> Date {
        today.addingTimeInterval(Double(offset) * 86_400)
    }

    private func met(_ offset: Int) -> DailyActivity {
        DailyActivity(date: day(offset), wordsReviewed: 10, minutes: 5, goalMet: true)
    }

    // MARK: - currentStreak

    func testCurrentStreakThreeConsecutiveEndingToday() {
        let activities = [met(0), met(-1), met(-2)]
        XCTAssertEqual(
            StreakCalculator.currentStreak(activities: activities, today: today, calendar: calendar),
            3
        )
    }

    func testCurrentStreakSavableTodayCountsBackFromYesterday() {
        // Met yesterday and the day before, but not yet today.
        let activities = [met(-1), met(-2)]
        XCTAssertEqual(
            StreakCalculator.currentStreak(activities: activities, today: today, calendar: calendar),
            2
        )
    }

    func testCurrentStreakGapBreaksStreak() {
        // Met today, then a gap, then met three days ago.
        let activities = [met(0), met(-3)]
        XCTAssertEqual(
            StreakCalculator.currentStreak(activities: activities, today: today, calendar: calendar),
            1
        )
    }

    func testCurrentStreakDeDuplicatesByDayAndIgnoresOrder() {
        // Same day twice (one unmet, one met) plus an out-of-order entry.
        let activities = [
            DailyActivity(date: day(-1), wordsReviewed: 10, minutes: 5, goalMet: true),
            DailyActivity(date: day(0), wordsReviewed: 2, minutes: 1, goalMet: false),
            DailyActivity(date: day(0), wordsReviewed: 10, minutes: 5, goalMet: true),
        ]
        XCTAssertEqual(
            StreakCalculator.currentStreak(activities: activities, today: today, calendar: calendar),
            2
        )
    }

    func testCurrentStreakEmptyHistory() {
        XCTAssertEqual(
            StreakCalculator.currentStreak(activities: [], today: today, calendar: calendar),
            0
        )
    }

    // MARK: - bestStreak

    func testBestStreakFindsLongestRunAcrossGap() {
        // Run of 2 (-1, -2), gap at -3/-4, run of 4 (-5..-8). Input intentionally unsorted.
        let activities = [met(-6), met(-1), met(-8), met(-2), met(-7), met(-5)]
        XCTAssertEqual(
            StreakCalculator.bestStreak(activities: activities, calendar: calendar),
            4
        )
    }

    func testBestStreakEmptyHistory() {
        XCTAssertEqual(StreakCalculator.bestStreak(activities: [], calendar: calendar), 0)
    }

    // MARK: - applyingToday

    func testApplyingTodayConsecutiveDayIncrements() {
        let result = StreakCalculator.applyingToday(
            streak: 4, best: 4, lastActiveDay: day(-1), today: today, calendar: calendar
        )
        XCTAssertEqual(result.streak, 5)
        XCTAssertEqual(result.best, 5)
    }

    func testApplyingTodayAlreadyTodayUnchanged() {
        let result = StreakCalculator.applyingToday(
            streak: 4, best: 6, lastActiveDay: day(0), today: today, calendar: calendar
        )
        XCTAssertEqual(result.streak, 4)
        XCTAssertEqual(result.best, 6)
    }

    func testApplyingTodayGapResetsToOne() {
        let result = StreakCalculator.applyingToday(
            streak: 4, best: 4, lastActiveDay: day(-3), today: today, calendar: calendar
        )
        XCTAssertEqual(result.streak, 1)
        XCTAssertEqual(result.best, 4)
    }

    func testApplyingTodayNilStartsAtOne() {
        let result = StreakCalculator.applyingToday(
            streak: 0, best: 0, lastActiveDay: nil, today: today, calendar: calendar
        )
        XCTAssertEqual(result.streak, 1)
        XCTAssertEqual(result.best, 1)
    }

    // MARK: - LevelCurve

    func testXPForLevel() {
        XCTAssertEqual(LevelCurve.xpForLevel(1), 0)
        XCTAssertEqual(LevelCurve.xpForLevel(2), 100)
        XCTAssertEqual(LevelCurve.xpForLevel(3), 300)
        XCTAssertEqual(LevelCurve.xpForLevel(4), 600)
    }

    func testLevelForXP() {
        XCTAssertEqual(LevelCurve.level(forXP: 0), 1)
        XCTAssertEqual(LevelCurve.level(forXP: 100), 2)
        XCTAssertEqual(LevelCurve.level(forXP: 250), 2)
        XCTAssertEqual(LevelCurve.level(forXP: 300), 3)
    }

    func testProgressWithinLevel() {
        let progress = LevelCurve.progress(xp: 150)
        XCTAssertEqual(progress.level, 2)
        XCTAssertEqual(progress.intoLevel, 50)
        XCTAssertEqual(progress.needed, 200)
        XCTAssertEqual(progress.fraction, 0.25, accuracy: 0.0001)
    }

    func testXPForRating() {
        XCTAssertEqual(LevelCurve.xp(for: .good), 12)
        XCTAssertEqual(LevelCurve.xp(for: .again), 2)
    }
}
