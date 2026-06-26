import XCTest
import VocablyDomain
import VocablyPresentation

final class OnboardingFlowStateTests: XCTestCase {

    func testInitialStepIsWelcome() {
        let state = OnboardingFlowState()
        XCTAssertEqual(state.step, .welcome)
        XCTAssertNil(state.selectedLanguage)
        XCTAssertTrue(state.motivations.isEmpty)
        XCTAssertNil(state.dailyGoal)
        XCTAssertNil(state.level)
    }

    func testAdvanceFromWelcomeWorks() {
        var state = OnboardingFlowState()
        XCTAssertTrue(state.canAdvance)
        state.advance()
        XCTAssertEqual(state.step, .language)
    }

    func testCannotAdvanceLanguageWithoutSelection() {
        var state = OnboardingFlowState()
        state.advance() // -> language
        XCTAssertEqual(state.step, .language)
        XCTAssertFalse(state.canAdvance)

        state.advance() // no-op: no language selected
        XCTAssertEqual(state.step, .language)

        state.selectedLanguage = .named("es")
        XCTAssertTrue(state.canAdvance)
        state.advance()
        XCTAssertEqual(state.step, .motivation)
    }

    func testToggleAddsAndRemovesMotivations() {
        var state = OnboardingFlowState()
        state.toggle(.travel)
        XCTAssertEqual(state.motivations, [.travel])
        state.toggle(.career)
        XCTAssertEqual(state.motivations, [.travel, .career])
        state.toggle(.travel) // remove
        XCTAssertEqual(state.motivations, [.career])
    }

    func testFullHappyPathReachesDone() {
        var state = OnboardingFlowState()
        state.advance() // welcome -> language
        state.selectedLanguage = .named("es")
        state.advance() // -> motivation
        state.toggle(.travel)
        state.advance() // -> goal
        state.dailyGoal = .regular
        state.advance() // -> level
        state.level = .conversational
        state.advance() // -> paywall
        XCTAssertEqual(state.step, .paywall)
        state.advance() // -> done
        XCTAssertEqual(state.step, .done)

        XCTAssertFalse(state.canAdvance)
        state.advance() // no-op on done
        XCTAssertEqual(state.step, .done)
        XCTAssertEqual(state.progressFraction, 1.0, accuracy: 0.0001)
    }

    func testProgressFraction() {
        var state = OnboardingFlowState()
        XCTAssertEqual(state.progressFraction, 0.0, accuracy: 0.0001)
        state.advance() // language (1 of 6)
        XCTAssertEqual(state.progressFraction, 1.0 / 6.0, accuracy: 0.0001)
    }

    func testMakeProfileReturnsNilBeforeSelectionsComplete() {
        var state = OnboardingFlowState()
        XCTAssertNil(state.makeProfile(name: "Ada"))

        state.selectedLanguage = .named("es")
        XCTAssertNil(state.makeProfile(name: "Ada")) // goal + level missing

        state.dailyGoal = .regular
        XCTAssertNil(state.makeProfile(name: "Ada")) // level missing
    }

    func testMakeProfileMapsSelections() {
        var state = OnboardingFlowState()
        state.selectedLanguage = .named("fr")
        state.toggle(.travel)
        state.toggle(.career)
        state.dailyGoal = .serious        // 15 minutes
        state.level = .conversational     // raw value 2

        let profile = state.makeProfile(name: "ada")
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.learningLanguage, "fr")
        XCTAssertEqual(profile?.dailyGoalMinutes, 15)
        XCTAssertEqual(profile?.startingLevel, 2)
        XCTAssertEqual(profile?.motivations, ["career", "travel"]) // sorted
        XCTAssertEqual(profile?.avatarInitial, "A")
        XCTAssertEqual(profile?.name, "ada")
    }

    func testMakeProfileWithEmptyNameHasEmptyInitial() {
        var state = OnboardingFlowState()
        state.selectedLanguage = .named("es")
        state.dailyGoal = .casual
        state.level = .new
        let profile = state.makeProfile(name: "")
        XCTAssertEqual(profile?.avatarInitial, "")
    }

    func testBackDecrementsStep() {
        var state = OnboardingFlowState()
        state.advance() // -> language
        state.back()
        XCTAssertEqual(state.step, .welcome)
        state.back() // no-op at first step
        XCTAssertEqual(state.step, .welcome)
    }
}
