import Foundation

/// Why the learner is studying (multi-select on the Motivation step).
public enum Motivation: String, Codable, Sendable, CaseIterable, Identifiable {
    case travel, career, culture, family, brain, fun
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .travel: return "Travel"
        case .career: return "Career"
        case .culture: return "Culture"
        case .family: return "Family"
        case .brain:  return "Brain training"
        case .fun:    return "For fun"
        }
    }

    public var subtitle: String {
        switch self {
        case .travel: return "Order, ask, explore"
        case .career: return "Work & business"
        case .culture: return "Film, music, books"
        case .family: return "Connect with people"
        case .brain:  return "Stay sharp"
        case .fun:    return "Just enjoy it"
        }
    }
}

/// Daily study commitment (Daily Goal step). Raw value is minutes/day.
public enum DailyGoal: Int, Codable, Sendable, CaseIterable, Identifiable {
    case casual = 5, regular = 10, serious = 15, intense = 30
    public var id: Int { rawValue }

    public var minutes: Int { rawValue }

    public var title: String {
        switch self {
        case .casual: return "Casual"
        case .regular: return "Regular"
        case .serious: return "Serious"
        case .intense: return "Intense"
        }
    }

    public var subtitle: String {
        switch self {
        case .casual:  return "5 min a day · relaxed"
        case .regular: return "10 min a day · ~20 words"
        case .serious: return "15 min a day · fast progress"
        case .intense: return "30 min a day · all in"
        }
    }

    /// The XP target that counts as meeting the daily goal.
    public var dailyXPTarget: Int { minutes * 10 }

    public static let recommended: DailyGoal = .regular
}

/// Self-reported starting ability (Level step). Raw value is the level index.
public enum ProficiencyLevel: Int, Codable, Sendable, CaseIterable, Identifiable {
    case new = 0, fewWords = 1, conversational = 2, advanced = 3
    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .new:            return "I'm brand new"
        case .fewWords:       return "I know a few words"
        case .conversational: return "I can get by"
        case .advanced:       return "I'm advanced"
        }
    }

    public var subtitle: String {
        switch self {
        case .new:            return "Starting from zero"
        case .fewWords:       return "Some basics stick"
        case .conversational: return "Simple conversations"
        case .advanced:       return "Polishing fluency"
        }
    }

    /// Number of filled bars shown in the design (1...4).
    public var bars: Int { rawValue + 1 }
}
