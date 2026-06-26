import Foundation

/// A profile achievement/badge.
public struct Achievement: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var iconName: String     // SF Symbol name the Mac layer renders
    public var isEarned: Bool

    public init(id: String, title: String, iconName: String, isEarned: Bool = false) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.isEarned = isEarned
    }

    /// All available badges (earned flags reflect the design's sample state).
    public static let catalog: [Achievement] = [
        Achievement(id: "streak10",  title: "10-day",    iconName: "flame.fill",          isEarned: true),
        Achievement(id: "words100",  title: "100 words", iconName: "book.fill",           isEarned: true),
        Achievement(id: "flawless",  title: "Flawless",  iconName: "rosette",             isEarned: true),
        Achievement(id: "nightowl",  title: "Night owl", iconName: "moon.stars.fill",     isEarned: false),
        Achievement(id: "streak30",  title: "30-day",    iconName: "flame.fill",          isEarned: false),
        Achievement(id: "scholar",   title: "Scholar",   iconName: "graduationcap.fill",  isEarned: false),
    ]
}
