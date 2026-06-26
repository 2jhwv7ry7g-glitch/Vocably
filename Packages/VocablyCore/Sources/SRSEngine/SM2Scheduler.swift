import Foundation
import VocablyDomain

/// Classic SuperMemo SM-2 scheduler.
///
/// Ratings map to SM-2 quality via `Rating.sm2Quality` (again=1, hard=3, good=4, easy=5).
/// A rating of `.again` is treated as a lapse: reps reset, the card re-enters learning,
/// and a lapse is recorded. Easiness is always nudged and clamped to `minimumEase`.
public struct SM2Scheduler: Scheduler {
    public struct Config: Sendable, Equatable {
        public var minimumEase: Double
        public var firstIntervalDays: Double
        public var secondIntervalDays: Double
        /// Interval multiplier applied to a "hard" pass (slower growth than "good").
        public var hardIntervalFactor: Double

        public init(
            minimumEase: Double = 1.3,
            firstIntervalDays: Double = 1,
            secondIntervalDays: Double = 6,
            hardIntervalFactor: Double = 1.2
        ) {
            self.minimumEase = minimumEase
            self.firstIntervalDays = firstIntervalDays
            self.secondIntervalDays = secondIntervalDays
            self.hardIntervalFactor = hardIntervalFactor
        }
    }

    public let config: Config

    public init(config: Config = .init()) {
        self.config = config
    }

    public func schedule(_ review: Review, rating: Rating, now: Date) -> Review {
        var r = review

        // 1. Update easiness factor (applies to every rating), then clamp.
        let q = Double(rating.sm2Quality)
        let delta = 0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)
        r.ease = max(config.minimumEase, r.ease + delta)

        // 2. Update interval & reps.
        if rating == .again {
            r.reps = 0
            r.lapses += 1
            r.intervalDays = config.firstIntervalDays
        } else {
            let previousInterval = r.intervalDays
            r.reps += 1
            switch r.reps {
            case 1:
                r.intervalDays = config.firstIntervalDays
            case 2:
                r.intervalDays = config.secondIntervalDays
            default:
                let multiplier = (rating == .hard) ? config.hardIntervalFactor : r.ease
                r.intervalDays = (previousInterval * multiplier).rounded()
            }
        }

        // 3. Derived fields.
        r.lastRating = rating
        r.masteryLevel = Mastery.level(reps: r.reps, intervalDays: r.intervalDays)
        r.due = now.addingTimeInterval(r.intervalDays * 86_400)
        return r
    }
}
