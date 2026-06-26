import Foundation
import VocablyDomain

/// Computes day-streak statistics from a history of `DailyActivity` records.
///
/// A calendar day "counts" toward a streak only if at least one activity on that
/// day has `goalMet == true`. Multiple activities on the same day collapse to a
/// single met/unmet day, and input order is irrelevant.
public enum StreakCalculator {
    /// Current consecutive met-goal-day streak ending at `today`.
    ///
    /// The streak counts back from today. If today has no met-goal activity yet,
    /// it counts back from yesterday instead — today is still "savable", so an
    /// in-progress day never breaks an existing streak.
    public static func currentStreak(
        activities: [DailyActivity],
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let metDays = metDaySet(activities, calendar: calendar)
        guard !metDays.isEmpty else { return 0 }

        let todayStart = calendar.startOfDay(for: today)
        var cursor = todayStart
        // Today's goal isn't met yet: it's still savable, so begin from yesterday.
        if !metDays.contains(todayStart) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while metDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Longest run of consecutive met-goal days anywhere in the history.
    public static func bestStreak(
        activities: [DailyActivity],
        calendar: Calendar = .current
    ) -> Int {
        let sortedDays = metDaySet(activities, calendar: calendar).sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for index in 1..<sortedDays.count {
            let gap = calendar.dateComponents([.day], from: sortedDays[index - 1], to: sortedDays[index]).day ?? 0
            run = (gap == 1) ? run + 1 : 1
            best = max(best, run)
        }
        return best
    }

    /// Applies completing today's goal to an existing streak.
    ///
    /// - If `lastActiveDay` was yesterday, the streak grows by one.
    /// - If `lastActiveDay` was already today, the streak is unchanged.
    /// - Otherwise (a gap, no prior day, or a stale value) the streak resets to 1.
    ///
    /// `best` is bumped to the larger of the old best and the new streak.
    public static func applyingToday(
        streak: Int,
        best: Int,
        lastActiveDay: Date?,
        today: Date,
        calendar: Calendar = .current
    ) -> (streak: Int, best: Int) {
        let todayStart = calendar.startOfDay(for: today)
        let newStreak: Int
        if let lastActiveDay {
            let lastStart = calendar.startOfDay(for: lastActiveDay)
            let gap = calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0
            switch gap {
            case 0: newStreak = streak       // already counted today
            case 1: newStreak = streak + 1   // consecutive day
            default: newStreak = 1           // gap (or out-of-order) resets
            }
        } else {
            newStreak = 1
        }
        return (newStreak, max(best, newStreak))
    }

    /// Set of distinct calendar-day starts that have at least one met-goal activity.
    private static func metDaySet(_ activities: [DailyActivity], calendar: Calendar) -> Set<Date> {
        var days = Set<Date>()
        for activity in activities where activity.goalMet {
            days.insert(calendar.startOfDay(for: activity.date))
        }
        return days
    }
}
