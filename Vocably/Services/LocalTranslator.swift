import Foundation

// Lightweight offline translation hints for the Add-Word flow. Covers common words so the
// app can pre-suggest a translation as you type. The general case (any word, any language)
// is handled on device by Apple's Translation framework / FoundationModels — this is the
// instant offline starter that needs no model download.
enum LocalTranslator {
    /// Suggest a translation for `term` written in `from`, into `to`. Nil if unknown.
    static func suggest(term: String, from: String, to: String) -> String? {
        let key = normalize(term)
        guard !key.isEmpty else { return nil }
        // Try direct (from→en) then reverse (en→from) lookups against the curated table.
        if to.hasPrefix("en"), let en = toEnglish[from.prefix(2).description]?[key] { return en }
        if from.hasPrefix("en") {
            if let table = toEnglish[to.prefix(2).description],
               let match = table.first(where: { normalize($0.value) == key }) { return match.key }
        }
        return nil
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "^(el |la |los |las |un |una |der |die |das )",
                                  with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    // lang → (normalized term → English). Articles are stripped by normalize().
    private static let toEnglish: [String: [String: String]] = [
        "es": [
            "gato": "the cat", "perro": "the dog", "pajaro": "the bird", "caballo": "the horse",
            "vaca": "the cow", "mariposa": "the butterfly", "jardin": "the garden", "cuenta": "the bill",
            "camarero": "the waiter", "propina": "the tip", "agua": "water", "pan": "bread",
            "leche": "milk", "casa": "the house", "coche": "the car", "playa": "the beach",
            "amanecer": "dawn", "niebla": "fog", "susurrar": "to whisper", "pedir": "to order",
            "comer": "to eat", "beber": "to drink", "hablar": "to speak", "rojo": "red",
            "azul": "blue", "verde": "green", "madre": "mother", "padre": "father",
        ],
        "de": [
            "katze": "cat", "hund": "dog", "vogel": "bird", "haus": "house", "auto": "car",
            "wasser": "water", "brot": "bread", "milch": "milk", "essen": "to eat",
            "trinken": "to drink", "sprechen": "to speak", "rot": "red", "blau": "blue",
            "grun": "green", "mutter": "mother", "vater": "father", "garten": "garden",
        ],
    ]
}
