import Foundation

/// How well the learner recalled a card. Drives spaced-repetition scheduling.
public enum Rating: Int, Codable, Sendable, CaseIterable {
    case again = 0   // forgot — "Still learning" / swipe left
    case hard  = 1   // recalled with difficulty
    case good  = 2   // recalled — "I know it" / swipe right
    case easy  = 3   // trivial

    /// SuperMemo SM-2 quality score (0–5) for this rating.
    public var sm2Quality: Int {
        switch self {
        case .again: return 1
        case .hard:  return 3
        case .good:  return 4
        case .easy:  return 5
        }
    }
}

/// The gesture a learner makes on a flashcard in the Swipe Study screen.
public enum SwipeDirection: Sendable, Equatable {
    case left, right, up, down
}

public extension Rating {
    /// Maps a flashcard swipe to a rating.
    /// left = still learning, right = I know it, up = easy, down = hard.
    static func from(swipe direction: SwipeDirection) -> Rating {
        switch direction {
        case .left:  return .again
        case .down:  return .hard
        case .right: return .good
        case .up:    return .easy
        }
    }

    /// Maps a button label used in the designs to a rating (case-insensitive).
    init?(buttonLabel label: String) {
        switch label.lowercased() {
        case "again", "still learning":               self = .again
        case "hard":                                   self = .hard
        case "good", "i know it", "got it", "known":   self = .good
        case "easy":                                   self = .easy
        default:                                       return nil
        }
    }
}
