import Foundation
import VocablyDomain

/// Maps XP totals to user levels and supplies the XP awarded per review rating.
///
/// The curve grows quadratically so each level costs a little more than the last:
/// `xpForLevel(n) = 50 * (n - 1) * n` → L1 = 0, L2 = 100, L3 = 300, L4 = 600, …
public enum LevelCurve {
    /// Cumulative XP required to *reach* `level`. Level 1 is the floor (0 XP).
    public static func xpForLevel(_ level: Int) -> Int {
        let n = max(1, level)
        return 50 * (n - 1) * n
    }

    /// Highest level fully reached for a given XP total. Always at least 1.
    public static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpForLevel(level + 1) <= xp {
            level += 1
        }
        return level
    }

    /// Progress within the current level.
    ///
    /// - `level`: the current level.
    /// - `intoLevel`: XP earned past the current level's threshold.
    /// - `needed`: total XP spanning the current level to the next.
    /// - `fraction`: `intoLevel / needed`, clamped to `0...1` (0 when `needed == 0`).
    public static func progress(xp: Int) -> (level: Int, intoLevel: Int, needed: Int, fraction: Double) {
        let level = level(forXP: xp)
        let base = xpForLevel(level)
        let next = xpForLevel(level + 1)
        let intoLevel = xp - base
        let needed = next - base
        let fraction = needed == 0 ? 0 : min(1, max(0, Double(intoLevel) / Double(needed)))
        return (level, intoLevel, needed, fraction)
    }

    /// Canonical XP awarded for a single review of the given rating.
    public static func xp(for rating: Rating) -> Int {
        switch rating {
        case .again: return 2
        case .hard: return 8
        case .good: return 12
        case .easy: return 15
        }
    }
}
