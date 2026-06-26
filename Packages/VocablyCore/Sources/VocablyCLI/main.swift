import Foundation
import VocablyDomain
import SRSEngine
import VocablyServices

// vocably-cli — runs the whole learning loop in the terminal against JSON-on-disk repos.
// Proves the portable core works as a system: seed -> review (SM-2) -> score -> persist.
// Re-run it: XP grows, the streak ticks up, and due intervals push out.

func rule() { print(String(repeating: "-", count: 46)) }
func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? s : s + String(repeating: " ", count: n - s.count)
}

func run() async throws {
    let dataDir = URL(fileURLWithPath: ".vocably-cli-data", isDirectory: true)
    let decksRepo = JSONDeckRepository(directory: dataDir)
    let profileRepo = JSONProfileRepository(directory: dataDir)
    let activityRepo = JSONActivityRepository(directory: dataDir)

    print("\nVocably - study session\n")

    // 1. Seed on first run.
    var decks = try await decksRepo.allDecks()
    if decks.isEmpty {
        for deck in SampleData.decks { try await decksRepo.save(deck) }
        decks = try await decksRepo.allDecks()
        print("Seeded \(decks.count) decks into \(dataDir.path)\n")
    }
    var profile = try await profileRepo.load() ?? SampleData.profile

    guard var deck = decks.first else { print("No decks to study."); return }
    let now = Date()
    let due = deck.dueCards(on: now)

    // 2. Before snapshot.
    let beforeLevel = LevelCurve.progress(xp: profile.xp)
    rule()
    print("Deck:    \(deck.name) (\(deck.languageCode.uppercased()))")
    print("Due:     \(due.count) / \(deck.cards.count) cards")
    print("Streak:  \(profile.streakCount) days   Best: \(profile.bestStreak)")
    print("Level:   \(beforeLevel.level)  (\(profile.xp) XP)")
    rule()

    guard !due.isEmpty else { print("\nNothing due - come back later!\n"); return }

    // 3. Run the session. (Deterministic rating pattern; a real app reads swipes.)
    var session = StudySession(cards: due, scheduler: SM2Scheduler(), startedAt: now)
    let pattern: [Rating] = [.good, .good, .again, .easy, .good]
    var i = 0
    print()
    while let card = session.currentCard {
        let rating = pattern[i % pattern.count]
        let mark: String
        switch rating {
        case .again: mark = "again"
        case .hard:  mark = "hard"
        case .good:  mark = "good"
        case .easy:  mark = "easy"
        }
        print("  \(pad(card.term, 18)) -> \(mark)")
        session.rate(rating, now: now)
        i += 1
    }

    let result = session.result(now: now.addingTimeInterval(180))

    // 4. Persist updated cards back into the deck.
    for updated in result.updatedCards {
        if let idx = deck.cards.firstIndex(where: { $0.id == updated.id }) {
            deck.cards[idx] = updated
        }
    }
    try await decksRepo.save(deck)

    // 5. Update profile XP / level / streak and record today's activity.
    let xpBefore = profile.xp
    profile.xp += result.xpEarned
    let afterLevel = LevelCurve.progress(xp: profile.xp)
    profile.level = afterLevel.level
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
    let streak = StreakCalculator.applyingToday(
        streak: profile.streakCount, best: profile.bestStreak,
        lastActiveDay: yesterday, today: now
    )
    profile.streakCount = streak.streak
    profile.bestStreak = streak.best
    try await profileRepo.save(profile)
    try await activityRepo.record(
        DailyActivity(date: now, wordsReviewed: result.reviewed, minutes: 6,
                      goalMet: result.reviewed >= 1)
    )

    // 6. After snapshot.
    let acc = Int((result.accuracy * 100).rounded())
    print()
    rule()
    print("Reviewed \(result.reviewed) - \(result.correct) correct - \(acc)% accuracy")
    print("XP:      \(xpBefore) -> \(profile.xp)  (+\(result.xpEarned))")
    print("Level:   \(afterLevel.level)  [\(afterLevel.intoLevel) / \(afterLevel.needed) to next]")
    print("Streak:  \(streak.streak) days")
    print("Due now: \(deck.dueCards(on: now).count) cards left in \(deck.name)")
    rule()
    print("\nSaved to \(dataDir.path) - run again to continue.\n")
}

do {
    try await run()
} catch {
    print("error: \(error)")
}
