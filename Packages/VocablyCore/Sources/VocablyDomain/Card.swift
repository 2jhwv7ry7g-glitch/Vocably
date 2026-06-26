import Foundation

/// Where a card came from.
public enum CardSource: String, Codable, Sendable {
    case manual, ai, scan, premade
}

/// A single vocabulary item.
public struct Card: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var term: String                 // e.g. "la mariposa"
    public var translation: String          // e.g. "butterfly"
    public var ipa: String?                 // e.g. "/ma.ɾiˈpo.sa/"
    public var partOfSpeech: String?        // e.g. "noun · feminine"
    public var example: String?
    public var exampleTranslation: String?
    public var mnemonic: String?            // AI memory hook
    public var source: CardSource
    public var review: Review

    public init(
        id: UUID = UUID(),
        term: String,
        translation: String,
        ipa: String? = nil,
        partOfSpeech: String? = nil,
        example: String? = nil,
        exampleTranslation: String? = nil,
        mnemonic: String? = nil,
        source: CardSource = .manual,
        review: Review = .new()
    ) {
        self.id = id
        self.term = term
        self.translation = translation
        self.ipa = ipa
        self.partOfSpeech = partOfSpeech
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.mnemonic = mnemonic
        self.source = source
        self.review = review
    }
}
