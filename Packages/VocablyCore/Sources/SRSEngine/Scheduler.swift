import Foundation
import VocablyDomain

/// Computes the next review state for a card given a rating.
/// Implemented by `SM2Scheduler`; swap for an FSRS scheduler later without touching callers.
public protocol Scheduler: Sendable {
    func schedule(_ review: Review, rating: Rating, now: Date) -> Review
}

public extension Scheduler {
    func schedule(_ review: Review, rating: Rating) -> Review {
        schedule(review, rating: rating, now: Date())
    }
}

/// Helpers for "due" queries that the Home counts and reminder scheduling rely on.
public enum DueQuery {
    /// Due if the card's `due` date falls before the end of `date`'s calendar day.
    public static func isDue(_ review: Review, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let endOfDay = calendar.startOfDay(for: date).addingTimeInterval(86_400)
        return review.due < endOfDay
    }

    public static func dueCount(_ reviews: [Review], on date: Date = Date(), calendar: Calendar = .current) -> Int {
        reviews.filter { isDue($0, on: date, calendar: calendar) }.count
    }
}
