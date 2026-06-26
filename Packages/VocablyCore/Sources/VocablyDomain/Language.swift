import Foundation

/// A learnable language and the app's supported catalog (onboarding picker, deck headers).
public struct Language: Identifiable, Codable, Sendable, Equatable {
    public var id: String { code }
    public var code: String          // ISO code, e.g. "es"
    public var name: String          // English name, e.g. "Spanish"
    public var nativeName: String    // endonym, e.g. "Español"
    public var learners: String?     // marketing blurb, e.g. "14M learners"

    public init(code: String, name: String, nativeName: String, learners: String? = nil) {
        self.code = code
        self.name = name
        self.nativeName = nativeName
        self.learners = learners
    }

    /// Languages offered on the onboarding picker (mirrors the design).
    public static let catalog: [Language] = [
        Language(code: "es", name: "Spanish",    nativeName: "Español",   learners: "14M learners"),
        Language(code: "fr", name: "French",     nativeName: "Français",  learners: "9M learners"),
        Language(code: "ja", name: "Japanese",   nativeName: "日本語",     learners: "7M learners"),
        Language(code: "de", name: "German",     nativeName: "Deutsch",   learners: "5M learners"),
        Language(code: "it", name: "Italian",    nativeName: "Italiano",  learners: "4M learners"),
        Language(code: "pt", name: "Portuguese", nativeName: "Português", learners: "3M learners"),
        Language(code: "en", name: "English",    nativeName: "English",   learners: "20M learners"),
    ]

    /// Look up a catalog language by ISO code.
    public static func named(_ code: String) -> Language? {
        catalog.first { $0.code == code }
    }
}
