import Foundation
import VocablyDomain

// Protocols only. Live implementations (FoundationModels, VisionKit, Translation,
// AVSpeech, StoreKit 2, UserNotifications) are Apple-only and live in the Xcode app.
// Mocks in `Mocks.swift` make every feature buildable & testable off-device.

/// AI deck generation, mnemonics, example sentences.
public protocol AIService: Sendable {
    func generateDeck(prompt: String, language: String, level: String, count: Int) async throws -> [CardDraft]
    func mnemonic(term: String, translation: String) async throws -> String
    func examples(term: String, language: String) async throws -> [Sentence]
}

/// Live OCR word detection. Live impl wraps VisionKit `DataScannerViewController`.
public protocol ScanService: Sendable {
    func scanText() -> AsyncStream<[RecognizedWord]>
}

/// On-device translation + lemmatization. Live impl wraps Translation + NaturalLanguage.
public protocol TranslateService: Sendable {
    func translate(_ text: String, from source: String, to target: String) async throws -> String
    func lemmatize(_ text: String, language: String) -> [String]
}

/// Text-to-speech pronunciation. Live impl wraps AVSpeechSynthesizer.
public protocol SpeechService: Sendable {
    func speak(_ text: String, language: String)
}

/// Subscriptions / entitlement. Live impl wraps StoreKit 2.
public protocol StoreService: Sendable {
    func products() async throws -> [SubscriptionProduct]
    func purchase(productID: String) async throws -> Bool
    func restore() async throws
    func currentStatus() async -> SubscriptionStatus
}

/// Local notifications. Live impl wraps UserNotifications.
public protocol ReminderService: Sendable {
    func scheduleDailyReminder(at time: DateComponents) async
    func scheduleStreakNudge() async
}

/// Errors a service may surface to the UI.
public enum ServiceError: Error, Sendable, Equatable {
    case unavailable
    case network
    case notEntitled
    case cancelled
}
