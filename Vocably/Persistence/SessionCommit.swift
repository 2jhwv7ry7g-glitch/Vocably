import Foundation
import VocablyDomain
import SRSEngine
import VocablyServices

// Persists the outcome of a finished study pass through the repository protocols.
// The scheduling already happened in SRSEngine (StudySessionResult.updatedCards carry
// the new Review state) — this just writes it back and bumps gamification counters.
enum SessionCommit {
    static func apply(
        _ result: StudySessionResult,
        decks: any DeckRepository,
        profiles: any ProfileRepository,
        activity: any ActivityRepository,
        now: Date = .now
    ) async {
        guard result.reviewed > 0 else { return }
        do {
            // 1. Write updated review state back into whichever deck holds each card.
            let updatedByID = Dictionary(uniqueKeysWithValues: result.updatedCards.map { ($0.id, $0) })
            var allDecks = try await decks.allDecks()
            for index in allDecks.indices {
                var changed = false
                for cardIndex in allDecks[index].cards.indices {
                    let id = allDecks[index].cards[cardIndex].id
                    if let updated = updatedByID[id] {
                        allDecks[index].cards[cardIndex] = updated
                        changed = true
                    }
                }
                if changed { try await decks.save(allDecks[index]) }
            }

            // 2. Bump XP / level on the profile.
            if var profile = try await profiles.load() {
                profile.xp += result.xpEarned
                profile.level = LevelCurve.progress(xp: profile.xp).level
                try await profiles.save(profile)
            }

            // 3. Record today's activity (feeds the streak strip + widgets).
            let minutes = max(1, Int((result.duration / 60).rounded()))
            try await activity.record(DailyActivity(
                date: now, wordsReviewed: result.reviewed, minutes: minutes, goalMet: true
            ))
        } catch {
            // Non-fatal: a failed write just means progress isn't saved this pass.
        }
    }
}
