import Foundation
import VocablyDomain
import VocablyServices
import FoundationModels

// AI deck generation (HANDOFF §7/§8). Hybrid: Apple's on-device FoundationModels when
// available (iOS 26 + Apple-Intelligence device), else a curated offline generator so the
// feature always works (e.g. in the Simulator, where the system model is unavailable).
func makeAIService() -> any AIService { HybridAIService() }

struct HybridAIService: AIService {
    private let local = LocalAIService()

    func generateDeck(prompt: String, language: String, level: String, count: Int) async throws -> [CardDraft] {
        if #available(iOS 26.0, *) {
            if let drafts = try? await FoundationModelsAIService().generateDeck(
                prompt: prompt, language: language, level: level, count: count), !drafts.isEmpty {
                return drafts
            }
        }
        return try await local.generateDeck(prompt: prompt, language: language, level: level, count: count)
    }

    func mnemonic(term: String, translation: String) async throws -> String {
        if #available(iOS 26.0, *),
           let m = try? await FoundationModelsAIService().mnemonic(term: term, translation: translation) {
            return m
        }
        return try await local.mnemonic(term: term, translation: translation)
    }

    func examples(term: String, language: String) async throws -> [Sentence] {
        try await local.examples(term: term, language: language)
    }
}

// MARK: - On-device Apple Intelligence

@available(iOS 26.0, *)
struct FoundationModelsAIService: AIService {
    @Generable struct GenCard {
        @Guide(description: "the vocabulary word in the target language, with article if a noun")
        var term: String
        @Guide(description: "the English translation")
        var translation: String
        @Guide(description: "a short natural example sentence in the target language")
        var example: String
    }

    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func generateDeck(prompt: String, language: String, level: String, count: Int) async throws -> [CardDraft] {
        guard isAvailable else { return [] }
        let langName = Language.named(language)?.name ?? language
        let session = LanguageModelSession(instructions:
            "You are a language tutor. Create concise \(langName) vocabulary flashcards for a \(level) learner.")
        let ask = "Generate \(count) useful \(langName) words about \"\(prompt)\". " +
                  "For each: the word in \(langName) (with article if a noun), its English translation, and a short example sentence in \(langName)."
        let response = try await session.respond(to: ask, generating: [GenCard].self)
        return response.content.map {
            CardDraft(term: $0.term, translation: $0.translation, example: $0.example)
        }
    }

    func mnemonic(term: String, translation: String) async throws -> String {
        guard isAvailable else { return "" }
        let session = LanguageModelSession(instructions: "You create vivid one-sentence mnemonics.")
        return try await session.respond(to: "A memory hook to remember that \"\(term)\" means \"\(translation)\".").content
    }

    func examples(term: String, language: String) async throws -> [Sentence] { [] }
}

// MARK: - Offline curated fallback

struct LocalAIService: AIService {
    func generateDeck(prompt: String, language: String, level: String, count: Int) async throws -> [CardDraft] {
        try? await Task.sleep(for: .milliseconds(500))   // feel of "thinking"
        let set = LocalContent.match(prompt: prompt)
        guard !set.isEmpty else { return Array(LocalContent.essentials.prefix(count)) }
        if set.count >= count { return Array(set.prefix(count)) }
        return set   // return what we curated even if fewer than requested
    }

    func mnemonic(term: String, translation: String) async throws -> String {
        "Picture “\(term)” vividly to lock in “\(translation)”."
    }

    func examples(term: String, language: String) async throws -> [Sentence] {
        [Sentence(text: "\(term) …", translation: nil)]
    }
}

/// Small curated Spanish content so the offline generator returns real vocabulary.
private enum LocalContent {
    typealias D = CardDraft

    static let essentials: [D] = [
        D(term: "hola", translation: "hello", example: "¡Hola! ¿Cómo estás?"),
        D(term: "gracias", translation: "thank you", example: "Muchas gracias por todo."),
        D(term: "por favor", translation: "please", example: "Un café, por favor."),
        D(term: "sí", translation: "yes", example: "Sí, me gusta mucho."),
        D(term: "no", translation: "no", example: "No, gracias."),
        D(term: "adiós", translation: "goodbye", example: "Adiós, hasta mañana."),
    ]

    private static let topics: [(keys: [String], drafts: [D])] = [
        (["food", "restaurant", "café", "cafe", "eat", "essen", "comida", "comer", "restaurante"], [
            D(term: "el camarero", translation: "the waiter", example: "¿Nos atiende el camarero?"),
            D(term: "la cuenta", translation: "the bill", example: "La cuenta, por favor."),
            D(term: "pedir", translation: "to order", example: "Vamos a pedir unas tapas."),
            D(term: "la propina", translation: "the tip", example: "Dejé una buena propina."),
            D(term: "el plato", translation: "the dish", example: "Este plato está delicioso."),
            D(term: "la bebida", translation: "the drink", example: "¿Qué bebida quieres?"),
        ]),
        (["travel", "trip", "viaje", "viajar", "reise", "airport", "hotel"], [
            D(term: "el aeropuerto", translation: "the airport", example: "Llegamos al aeropuerto temprano."),
            D(term: "el billete", translation: "the ticket", example: "Compré un billete de tren."),
            D(term: "la maleta", translation: "the suitcase", example: "Mi maleta es muy pesada."),
            D(term: "el hotel", translation: "the hotel", example: "El hotel está cerca de la playa."),
            D(term: "el mapa", translation: "the map", example: "Necesito un mapa de la ciudad."),
            D(term: "la playa", translation: "the beach", example: "Vamos a la playa mañana."),
        ]),
        (["family", "familia", "familie"], [
            D(term: "la madre", translation: "the mother", example: "Mi madre cocina muy bien."),
            D(term: "el padre", translation: "the father", example: "Su padre es profesor."),
            D(term: "la hermana", translation: "the sister", example: "Tengo una hermana mayor."),
            D(term: "el hermano", translation: "the brother", example: "Mi hermano vive en Madrid."),
            D(term: "el hijo", translation: "the son", example: "Su hijo tiene cinco años."),
            D(term: "la hija", translation: "the daughter", example: "Mi hija estudia música."),
        ]),
        (["animal", "animals", "animales", "tiere"], [
            D(term: "el perro", translation: "the dog", example: "El perro corre en el parque."),
            D(term: "el gato", translation: "the cat", example: "El gato duerme todo el día."),
            D(term: "el pájaro", translation: "the bird", example: "El pájaro canta por la mañana."),
            D(term: "el caballo", translation: "the horse", example: "El caballo es muy fuerte."),
            D(term: "la vaca", translation: "the cow", example: "La vaca está en el campo."),
        ]),
        (["number", "numbers", "números", "numeros", "zahlen"], [
            D(term: "uno", translation: "one", example: "Quiero uno, por favor."),
            D(term: "dos", translation: "two", example: "Tengo dos hermanos."),
            D(term: "tres", translation: "three", example: "Son las tres de la tarde."),
            D(term: "cuatro", translation: "four", example: "Hay cuatro sillas."),
            D(term: "cinco", translation: "five", example: "Cuesta cinco euros."),
        ]),
        (["color", "colors", "colours", "colores", "farben"], [
            D(term: "rojo", translation: "red", example: "El coche es rojo."),
            D(term: "azul", translation: "blue", example: "El cielo está azul."),
            D(term: "verde", translation: "green", example: "Me gusta el té verde."),
            D(term: "amarillo", translation: "yellow", example: "El sol es amarillo."),
            D(term: "negro", translation: "black", example: "Llevo un abrigo negro."),
        ]),
    ]

    static func match(prompt: String) -> [D] {
        let p = prompt.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        for topic in topics where topic.keys.contains(where: { p.contains($0) }) {
            return topic.drafts
        }
        return []
    }
}
