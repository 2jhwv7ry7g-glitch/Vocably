import Foundation

/// A draft card produced by the AI Generate flow before it's saved.
public struct CardDraft: Codable, Sendable, Equatable {
    public var term: String
    public var translation: String
    public var example: String?
    public var mnemonic: String?

    public init(term: String, translation: String, example: String? = nil, mnemonic: String? = nil) {
        self.term = term
        self.translation = translation
        self.example = example
        self.mnemonic = mnemonic
    }

    /// Promote a draft into a real card.
    public func makeCard(source: CardSource = .ai) -> Card {
        Card(term: term, translation: translation, example: example, mnemonic: mnemonic, source: source)
    }
}

/// An example sentence with optional translation.
public struct Sentence: Codable, Sendable, Equatable {
    public var text: String
    public var translation: String?
    public init(text: String, translation: String? = nil) {
        self.text = text
        self.translation = translation
    }
}

/// Normalised (0–1) rectangle, independent of CoreGraphics so it stays portable.
public struct BoundingBox: Codable, Sendable, Equatable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// A word detected by the OCR scanner.
public struct RecognizedWord: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var text: String
    public var box: BoundingBox?
    public init(id: UUID = UUID(), text: String, box: BoundingBox? = nil) {
        self.id = id
        self.text = text
        self.box = box
    }
}
