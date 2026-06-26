import Foundation
import VocablyDomain

// Deterministic mocks for previews and tests. Safe to use on Windows/Linux.
// Recording mocks are reference types flagged @unchecked Sendable (test-only).

public final class MockAIService: AIService, @unchecked Sendable {
    public var recordedPrompts: [String] = []
    public init() {}

    private static let base: [CardDraft] = [
        .init(term: "el camarero", translation: "the waiter", example: "¿Nos atiende el camarero?"),
        .init(term: "la cuenta", translation: "the bill", example: "La cuenta, por favor."),
        .init(term: "pedir", translation: "to order", example: "Vamos a pedir unas tapas."),
        .init(term: "la propina", translation: "the tip", example: "Dejé una buena propina."),
    ]

    public func generateDeck(prompt: String, language: String, level: String, count: Int) async throws -> [CardDraft] {
        recordedPrompts.append(prompt)
        guard count > 0 else { return [] }
        return (0..<count).map { Self.base[$0 % Self.base.count] }
    }

    public func mnemonic(term: String, translation: String) async throws -> String {
        "Picture the word “\(term)” to remember “\(translation)”."
    }

    public func examples(term: String, language: String) async throws -> [Sentence] {
        [Sentence(text: "Una \(term) azul cruzó el jardín.", translation: "A blue \(term) crossed the garden.")]
    }
}

public final class MockScanService: ScanService, @unchecked Sendable {
    public init() {}
    public static let sampleBatch: [RecognizedWord] = [
        .init(text: "mariposa"), .init(text: "jardín"), .init(text: "amanecer"),
        .init(text: "susurro"), .init(text: "niebla"),
    ]
    public func scanText() -> AsyncStream<[RecognizedWord]> {
        AsyncStream { continuation in
            continuation.yield(Self.sampleBatch)
            continuation.finish()
        }
    }
}

public final class MockTranslateService: TranslateService, @unchecked Sendable {
    public init() {}
    private let dictionary: [String: String] = [
        "mariposa": "butterfly", "jardín": "garden", "amanecer": "dawn",
        "susurro": "whisper", "niebla": "mist",
    ]
    public func translate(_ text: String, from source: String, to target: String) async throws -> String {
        dictionary[text.lowercased()] ?? text
    }
    public func lemmatize(_ text: String, language: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "," })
            .map { String($0).lowercased() }
    }
}

public final class MockSpeechService: SpeechService, @unchecked Sendable {
    public private(set) var spoken: [(text: String, language: String)] = []
    public init() {}
    public func speak(_ text: String, language: String) {
        spoken.append((text, language))
    }
}

public final class MockStoreService: StoreService, @unchecked Sendable {
    public var status: SubscriptionStatus
    public init(status: SubscriptionStatus = .free) { self.status = status }

    public func products() async throws -> [SubscriptionProduct] {
        [
            .init(id: "pro.yearly", displayName: "Yearly", formattedPrice: "$39.99", period: .yearly, hasFreeTrial: true),
            .init(id: "pro.monthly", displayName: "Monthly", formattedPrice: "$7.99", period: .monthly, hasFreeTrial: false),
        ]
    }
    public func purchase(productID: String) async throws -> Bool {
        status = .trial
        return true
    }
    public func restore() async throws { status = .pro }
    public func currentStatus() async -> SubscriptionStatus { status }
}

public final class MockReminderService: ReminderService, @unchecked Sendable {
    public private(set) var dailyTimes: [DateComponents] = []
    public private(set) var streakNudges = 0
    public init() {}
    public func scheduleDailyReminder(at time: DateComponents) async { dailyTimes.append(time) }
    public func scheduleStreakNudge() async { streakNudges += 1 }
}
