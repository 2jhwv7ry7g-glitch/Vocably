import Foundation
import FoundationModels
import VocablyDomain

// General word translation for the Add-Word suggestion. Tries Apple's on-device
// FoundationModels (iOS 26, any language) and falls back to the curated offline table.
// The Apple Translation framework path (iOS 18+) is wired separately as a SwiftUI
// `.translationTask` bridge, since it's view-lifecycle bound.
protocol Translator: Sendable {
    func translate(_ term: String, from: String, to: String) async -> String?
}

struct HybridTranslator: Translator {
    func translate(_ term: String, from: String, to: String) async -> String? {
        if #available(iOS 26.0, *) {
            if let s = try? await FoundationModelsTranslator().translate(term, from: from, to: to),
               !s.isEmpty { return s }
        }
        return LocalTranslator.suggest(term: term, from: from, to: to)
    }
}

@available(iOS 26.0, *)
struct FoundationModelsTranslator {
    func translate(_ term: String, from: String, to: String) async throws -> String {
        guard case .available = SystemLanguageModel.default.availability else { return "" }
        let fromName = Language.named(from)?.name ?? from
        let toName = Language.named(to)?.name ?? to
        let session = LanguageModelSession(instructions:
            "You are a translation engine. Reply with ONLY the translation — no quotes, no notes, no extra words.")
        let response = try await session.respond(
            to: "Translate the \(fromName) word \"\(term)\" into \(toName).")
        return response.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'.“”"))
    }
}
