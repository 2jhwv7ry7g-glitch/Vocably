import XCTest
import VocablyDomain
import SRSEngine
import VocablyPresentation

final class HomeStateTests: XCTestCase {
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return cal
    }

    /// Well after the sample epoch, so every sample card reads as due.
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    func testGreetingUsesFirstNameOnly() {
        let state = HomeState(
            profile: SampleData.profile,
            decks: SampleData.decks,
            activity: SampleData.weekActivity,
            now: now,
            calendar: utcCalendar()
        )
        XCTAssertEqual(state.greeting, "Hola, Mara")
    }

    func testGreetingFallsBackToThere() {
        let blank = UserProfile(name: "")
        let state = HomeState(profile: blank, decks: [], activity: [], now: now, calendar: utcCalendar())
        XCTAssertEqual(state.greeting, "Hola, there")
    }

    func testWeekDotsHaveSevenEntriesEndingToday() {
        let state = HomeState(
            profile: SampleData.profile,
            decks: SampleData.decks,
            activity: SampleData.weekActivity,
            now: now,
            calendar: utcCalendar()
        )
        XCTAssertEqual(state.weekDots.count, 7)
        XCTAssertEqual(state.weekDots.last?.mark, .today)
        // Past days carry a single uppercase weekday initial.
        for dot in state.weekDots.dropLast() {
            XCTAssertEqual(dot.letter.count, 1)
            XCTAssertEqual(dot.letter, dot.letter.uppercased())
        }
    }

    func testDueAndContinueDeck() {
        let cal = utcCalendar()
        let state = HomeState(
            profile: SampleData.profile,
            decks: SampleData.decks,
            activity: SampleData.weekActivity,
            now: now,
            calendar: cal
        )
        XCTAssertGreaterThan(state.dueCount, 0)
        // Spanish deck has the most due cards, so it is the continue target.
        XCTAssertEqual(state.continueDeckName, SampleData.spanishDeck.name)
        XCTAssertGreaterThan(state.continueDueCount, 0)
        XCTAssertEqual(state.continueProgress, SampleData.spanishDeck.progress, accuracy: 0.0001)
    }

    func testNoDueDecksClearsContinue() {
        // A now far before any card is due leaves nothing to continue.
        let early = Date(timeIntervalSince1970: 0)
        let state = HomeState(
            profile: SampleData.profile,
            decks: SampleData.decks,
            activity: SampleData.weekActivity,
            now: early,
            calendar: utcCalendar()
        )
        XCTAssertEqual(state.dueCount, 0)
        XCTAssertNil(state.continueDeckName)
        XCTAssertEqual(state.continueDueCount, 0)
        XCTAssertEqual(state.continueProgress, 0)
    }

    func testLevelMatchesLevelCurve() {
        let state = HomeState(
            profile: SampleData.profile,
            decks: SampleData.decks,
            activity: SampleData.weekActivity,
            now: now,
            calendar: utcCalendar()
        )
        let expected = LevelCurve.progress(xp: SampleData.profile.xp)
        XCTAssertEqual(state.level, expected.level)
        XCTAssertEqual(state.levelFraction, expected.fraction, accuracy: 0.0001)
    }

    func testStreakFromProfile() {
        let state = HomeState(
            profile: SampleData.profile,
            decks: SampleData.decks,
            activity: SampleData.weekActivity,
            now: now,
            calendar: utcCalendar()
        )
        XCTAssertEqual(state.streakCount, SampleData.profile.streakCount)
        XCTAssertEqual(state.bestStreak, SampleData.profile.bestStreak)
    }
}
