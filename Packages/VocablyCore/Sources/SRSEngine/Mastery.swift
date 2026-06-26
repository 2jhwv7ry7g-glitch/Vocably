import Foundation

/// Maps raw review counters to a 0–3 mastery level.
/// This is the value the Deck Detail screen renders as filled "mastery dots".
public enum Mastery {
    /// - 0 new (never passed)
    /// - 1 learning (1–2 reps)
    /// - 2 familiar (3+ reps)
    /// - 3 mastered (5+ reps and a long interval)
    public static func level(reps: Int, intervalDays: Double, masteredIntervalDays: Double = 21) -> Int {
        if reps == 0 { return 0 }
        if reps >= 5 && intervalDays >= masteredIntervalDays { return 3 }
        if reps >= 3 { return 2 }
        return 1
    }
}
