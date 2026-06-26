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
    public var tags: [String]               // user/auto categories, e.g. ["food", "travel"]
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
        tags: [String] = [],
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
        self.tags = tags
        self.source = source
        self.review = review
    }

    // Tolerant decoding: cards persisted before tags existed decode to an empty tag list.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        term = try c.decode(String.self, forKey: .term)
        translation = try c.decode(String.self, forKey: .translation)
        ipa = try c.decodeIfPresent(String.self, forKey: .ipa)
        partOfSpeech = try c.decodeIfPresent(String.self, forKey: .partOfSpeech)
        example = try c.decodeIfPresent(String.self, forKey: .example)
        exampleTranslation = try c.decodeIfPresent(String.self, forKey: .exampleTranslation)
        mnemonic = try c.decodeIfPresent(String.self, forKey: .mnemonic)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        source = try c.decode(CardSource.self, forKey: .source)
        review = try c.decode(Review.self, forKey: .review)
    }
}
