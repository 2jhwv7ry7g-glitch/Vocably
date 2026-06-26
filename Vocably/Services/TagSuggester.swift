import Foundation

// Auto-categorisation for new words. Protocol-based so an on-device AI classifier
// (Apple FoundationModels, iOS 26) can replace the heuristic later without UI changes.
protocol TagSuggester {
    /// Best-guess category tags for a word, ordered most-likely first, excluding `existing`.
    func suggestions(term: String, translation: String, existing: [String]) -> [String]
}

/// Offline keyword/heuristic categoriser. Matches the term and translation (ES/EN/DE)
/// against a curated keyword map; instant and free, good enough to pre-fill a chip.
struct DictionaryTagSuggester: TagSuggester {
    // category -> trigger words (substring match, lowercased, accent-folded).
    private static let map: [String: [String]] = [
        "food": ["food", "eat", "drink", "comida", "comer", "beber", "essen", "trinken", "café", "coffee",
                 "agua", "water", "wasser", "pan", "bread", "brot", "wine", "vino", "bill", "cuenta",
                 "waiter", "camarero", "order", "pedir", "tip", "propina", "restaurant", "menu", "fruit",
                 "apple", "manzana", "apfel", "milk", "leche", "milch", "cheese", "queso"],
        "animals": ["animal", "dog", "cat", "perro", "gato", "hund", "katze", "bird", "pájaro", "vogel",
                    "fish", "pez", "fisch", "butterfly", "mariposa", "horse", "caballo", "pferd", "cow", "vaca"],
        "nature": ["nature", "tree", "árbol", "baum", "flower", "flor", "blume", "garden", "jardín", "garten",
                   "sun", "sol", "sonne", "moon", "luna", "mond", "sea", "mar", "meer", "mountain", "montaña",
                   "river", "río", "fluss", "dawn", "amanecer", "sky", "cielo", "rain", "lluvia", "leaf"],
        "travel": ["travel", "trip", "viaje", "viajar", "reise", "hotel", "airport", "aeropuerto", "flughafen",
                   "ticket", "billete", "train", "tren", "zug", "bus", "car", "coche", "auto", "map", "mapa",
                   "passport", "pasaporte", "luggage", "maleta", "beach", "playa", "bill", "cuenta"],
        "family": ["family", "familia", "familie", "mother", "madre", "mutter", "father", "padre", "vater",
                   "sister", "hermana", "brother", "hermano", "son", "hijo", "daughter", "hija", "child", "niño"],
        "people": ["people", "person", "man", "hombre", "mann", "woman", "mujer", "frau", "friend", "amigo",
                   "freund", "waiter", "camarero", "neighbour", "vecino", "teacher", "profesor", "boss", "jefe"],
        "body": ["body", "cuerpo", "körper", "hand", "mano", "head", "cabeza", "kopf", "eye", "ojo", "auge",
                 "foot", "pie", "fuß", "heart", "corazón", "herz", "hair", "pelo", "haar", "arm", "leg"],
        "colors": ["color", "colour", "red", "rojo", "rot", "blue", "azul", "blau", "green", "verde", "grün",
                   "yellow", "amarillo", "gelb", "black", "negro", "schwarz", "white", "blanco", "weiß"],
        "numbers": ["number", "número", "zahl", "one", "uno", "eins", "two", "dos", "zwei", "three", "tres",
                    "ten", "diez", "zehn", "hundred", "cien", "thousand", "mil"],
        "time": ["time", "tiempo", "zeit", "day", "día", "tag", "night", "noche", "nacht", "hour", "hora",
                 "week", "semana", "woche", "month", "mes", "monat", "year", "año", "jahr", "today", "dawn",
                 "morning", "mañana", "morgen", "yesterday", "tomorrow"],
        "home": ["home", "house", "casa", "haus", "room", "habitación", "zimmer", "door", "puerta", "tür",
                 "window", "ventana", "fenster", "kitchen", "cocina", "küche", "table", "mesa", "tisch",
                 "bed", "cama", "bett", "chair", "silla", "garden", "jardín"],
        "clothing": ["clothes", "ropa", "kleidung", "shirt", "camisa", "hemd", "shoe", "zapato", "schuh",
                     "hat", "sombrero", "hut", "dress", "vestido", "kleid", "coat", "abrigo", "jacke"],
        "work": ["work", "trabajo", "arbeit", "job", "office", "oficina", "büro", "meeting", "reunión",
                 "money", "dinero", "geld", "boss", "jefe", "company", "empresa", "email", "computer"],
        "money": ["money", "dinero", "geld", "price", "precio", "preis", "pay", "pagar", "zahlen", "tip",
                  "propina", "bill", "cuenta", "euro", "dollar", "bank", "card", "tarjeta"],
        "communication": ["say", "decir", "sagen", "speak", "hablar", "sprechen", "talk", "word", "palabra",
                          "whisper", "susurro", "listen", "escuchar", "hören", "read", "leer", "lesen",
                          "write", "escribir", "schreiben", "hello", "hola", "hallo", "thanks", "gracias"],
        "emotions": ["love", "amor", "liebe", "happy", "feliz", "glücklich", "sad", "triste", "traurig",
                     "angry", "enfadado", "wütend", "fear", "miedo", "angst", "joy", "alegría"],
        "weather": ["weather", "tiempo", "wetter", "rain", "lluvia", "regen", "snow", "nieve", "schnee",
                    "wind", "viento", "sun", "sol", "cloud", "nube", "wolke", "storm", "tormenta"],
    ]

    func suggestions(term: String, translation: String, existing: [String]) -> [String] {
        let haystack = (Self.fold(term) + " " + Self.fold(translation))
        let existingSet = Set(existing.map { $0.lowercased() })

        var scored: [(tag: String, score: Int)] = []
        for (tag, keywords) in Self.map where !existingSet.contains(tag) {
            let hits = keywords.reduce(0) { $0 + (haystack.contains(Self.fold($1)) ? 1 : 0) }
            if hits > 0 { scored.append((tag, hits)) }
        }

        // Heuristic: English "to …" translation → verb.
        if !existingSet.contains("verbs"),
           Self.fold(translation).hasPrefix("to ") || term.hasSuffix("ar") || term.hasSuffix("er") || term.hasSuffix("ir") {
            scored.append(("verbs", 1))
        }

        return scored.sorted { $0.score > $1.score }.map(\.tag).reduced(to: 3)
    }

    /// Lowercase + strip diacritics so "café"/"jardín" match plain keywords.
    private static func fold(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}

private extension Array where Element == String {
    /// First `n` unique elements preserving order.
    func reduced(to n: Int) -> [String] {
        var seen = Set<String>(); var out: [String] = []
        for e in self where !seen.contains(e) { seen.insert(e); out.append(e); if out.count == n { break } }
        return out
    }
}
