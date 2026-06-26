import SwiftUI
import Observation
import VocablyDomain
import VocablyServices

// AI Generate (HANDOFF §11, node 7U-0): a topic prompt → a draft deck of words.
// Fastest possible word capture — type a theme, get a tagged deck.
@MainActor @Observable
final class AIStudioModel {
    var prompt = ""
    var language = "es"
    private(set) var drafts: [CardDraft] = []
    private(set) var isGenerating = false
    private(set) var savedDeckName: String?

    private let ai: any AIService
    private let decks: any DeckRepository
    private let suggester: TagSuggester

    init(decks: any DeckRepository, ai: any AIService = makeAIService(), suggester: TagSuggester = DictionaryTagSuggester()) {
        self.decks = decks
        self.ai = ai
        self.suggester = suggester
    }

    let suggestions = ["Café & restaurant", "Travel basics", "Family", "Animals", "Numbers", "Colors"]

    var canGenerate: Bool { !prompt.trimmingCharacters(in: .whitespaces).isEmpty && !isGenerating }

    func generate() async {
        guard canGenerate else { return }
        isGenerating = true
        savedDeckName = nil
        drafts = (try? await ai.generateDeck(prompt: prompt, language: language, level: "A2", count: 6)) ?? []
        isGenerating = false
    }

    /// The auto-detected category tag for a draft (the prompt topic, or a keyword guess).
    func tags(for draft: CardDraft) -> [String] {
        let auto = suggester.suggestions(term: draft.term, translation: draft.translation, existing: [])
        if !auto.isEmpty { return Array(auto.prefix(2)) }
        let topic = prompt.split(separator: " ").first.map { $0.lowercased() } ?? "ai"
        return [String(topic)]
    }

    /// Save the drafts as a new AI deck, auto-tagging each card.
    func saveDeck() async {
        guard !drafts.isEmpty else { return }
        let name = prompt.trimmingCharacters(in: .whitespaces).capitalized
        let cards = drafts.map { d in
            Card(term: d.term, translation: d.translation, example: d.example,
                 mnemonic: d.mnemonic, tags: tags(for: d), source: .ai)
        }
        let deck = Deck(name: name, languageCode: language, level: "A2",
                        colorTokenName: "accent", source: .ai, cards: cards)
        try? await decks.save(deck)
        savedDeckName = name
        drafts = []
        prompt = ""
    }
}

struct AIStudioView: View {
    @State private var model: AIStudioModel

    init(repos: Repos) {
        _model = State(initialValue: AIStudioModel(decks: repos.decks))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vocably.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s4) {
                        composer
                        if !model.suggestions.isEmpty && model.drafts.isEmpty { chips }
                        if model.isGenerating { generatingView }
                        if let name = model.savedDeckName { savedBanner(name) }
                        if !model.drafts.isEmpty { results }
                    }
                    .padding(Space.s6)
                }
            }
            .navigationTitle("AI Studio")
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s2) {
                Image(systemName: "sparkles").foregroundStyle(Color.vocably.accent)
                Text("Generate a deck from any topic").font(.ui(15, .semibold)).foregroundStyle(Color.vocably.ink)
            }
            HStack(spacing: Space.s2) {
                TextField("e.g. ordering at a café", text: $model.prompt)
                    .font(.ui(16)).padding(Space.s3)
                    .background(Color.vocably.surfaceBright)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Color.vocably.line, lineWidth: 1))
                    .onSubmit { Task { await model.generate() } }
                languageMenu
            }
            Button { Task { await model.generate() } } label: {
                Text(model.isGenerating ? "Generating…" : "Generate")
                    .font(.ui(17, .semibold)).foregroundStyle(Color.vocably.onPrimary)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.vocably.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.full, style: .continuous))
            }
            .opacity(model.canGenerate ? 1 : 0.5).disabled(!model.canGenerate)
        }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(Language.catalog) { lang in
                Button(lang.nativeName) { model.language = lang.code }
            }
        } label: {
            Text(Language.named(model.language)?.code.uppercased() ?? "ES")
                .font(.ui(15, .semibold)).foregroundStyle(Color.vocably.primary)
                .frame(width: 52, height: 52)
                .background(Color.vocably.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private var chips: some View {
        FlowLayout(spacing: Space.s2) {
            ForEach(model.suggestions, id: \.self) { s in
                Button {
                    model.prompt = s
                    Task { await model.generate() }
                } label: {
                    Text(s).font(.ui(13, .semibold)).foregroundStyle(Color.vocably.ink)
                        .padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
                        .background(Color.vocably.surface).clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.vocably.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var generatingView: some View {
        HStack(spacing: Space.s3) {
            ProgressView()
            Text("Thinking up words…").font(.ui(15)).foregroundStyle(Color.vocably.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Space.s8)
    }

    private func savedBanner(_ name: String) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.vocably.primary)
            Text("Added “\(name)” to your decks").font(.ui(15, .semibold)).foregroundStyle(Color.vocably.ink)
        }
        .padding(Space.s4).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.vocably.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("\(model.drafts.count) words").font(.display(20, .semibold)).foregroundStyle(Color.vocably.ink)
            ForEach(Array(model.drafts.enumerated()), id: \.offset) { _, draft in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Space.s2) {
                        HStack {
                            Text(draft.term).font(.ui(16, .semibold)).foregroundStyle(Color.vocably.ink)
                            Spacer()
                            Text(draft.translation).font(.ui(14)).foregroundStyle(Color.vocably.muted)
                        }
                        if let ex = draft.example, !ex.isEmpty {
                            Text(ex).font(.ui(13)).italic().foregroundStyle(Color.vocably.muted)
                        }
                        FlowLayout(spacing: 6) {
                            ForEach(model.tags(for: draft), id: \.self) { tag in
                                Text(tag).font(.ui(11, .semibold)).foregroundStyle(Color.vocably.accent)
                                    .padding(.horizontal, Space.s2).padding(.vertical, 3)
                                    .background(Color.vocably.accentSoft).clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            PrimaryButton(title: "Add \(model.drafts.count) to my decks", systemImage: "plus") {
                Task { await model.saveDeck() }
            }
            .padding(.top, Space.s2)
        }
    }
}
