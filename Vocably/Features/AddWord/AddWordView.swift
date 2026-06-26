import SwiftUI
import Observation
import VocablyDomain
import VocablyServices

// Fast word capture. The whole point is speed: type term + translation, the suggester
// pre-offers a category chip, "Add & next" keeps the sheet open and refocuses the field.
@MainActor @Observable
final class AddWordModel {
    var term = ""
    var translation = ""
    var example = ""
    var selectedTags: [String] = []
    var newTag = ""
    private(set) var addedCount = 0
    private(set) var deck: Deck

    private let repo: any DeckRepository
    private let suggester: TagSuggester
    let onChange: () -> Void

    init(deck: Deck, repo: any DeckRepository, suggester: TagSuggester = DictionaryTagSuggester(), onChange: @escaping () -> Void) {
        self.deck = deck
        self.repo = repo
        self.suggester = suggester
        self.onChange = onChange
    }

    var canSave: Bool {
        !term.trimmingCharacters(in: .whitespaces).isEmpty &&
        !translation.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Auto-suggested categories for the word being typed (excludes ones already chosen).
    var suggestions: [String] {
        guard !term.isEmpty || !translation.isEmpty else { return [] }
        return suggester.suggestions(term: term, translation: translation, existing: selectedTags)
    }

    /// Language codes for the two fields.
    var wordLanguage: String { deck.languageCode }
    var translationLanguage: String { deck.translationLanguageCode ?? "en" }

    /// Current translation suggestion (instant offline guess, upgraded by on-device AI /
    /// Apple Translation when available).
    var autoTranslation: String?
    private let translator: any Translator = HybridTranslator()

    var showSuggestion: Bool {
        translation.trimmingCharacters(in: .whitespaces).isEmpty && !(autoTranslation ?? "").isEmpty
    }

    func acceptSuggestion() {
        if let s = autoTranslation, !s.isEmpty { translation = s; autoTranslation = nil }
    }

    /// Offer a suggestion from any source, but only while the field is still empty.
    func applyAutoTranslation(_ s: String) {
        let clean = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              !term.trimmingCharacters(in: .whitespaces).isEmpty,
              translation.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        autoTranslation = clean
    }

    /// Instant local guess, then upgrade via the hybrid (FoundationModels) translator.
    func refreshSuggestion() async {
        let snapshot = term
        guard term.trimmingCharacters(in: .whitespaces).count >= 2,
              translation.trimmingCharacters(in: .whitespaces).isEmpty else {
            autoTranslation = nil; return
        }
        autoTranslation = LocalTranslator.suggest(term: term, from: wordLanguage, to: translationLanguage)
        if let s = await translator.translate(term, from: wordLanguage, to: translationLanguage),
           snapshot == term { applyAutoTranslation(s) }
    }

    /// Tags already used elsewhere in this deck, for one-tap reuse.
    var deckTags: [String] {
        let used = Set(deck.cards.flatMap(\.tags))
        return used.subtracting(selectedTags).sorted()
    }

    func toggle(_ tag: String) {
        if let i = selectedTags.firstIndex(of: tag) { selectedTags.remove(at: i) }
        else { selectedTags.append(tag) }
    }

    func addCustomTag() {
        let t = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty, !selectedTags.contains(t) else { newTag = ""; return }
        selectedTags.append(t)
        newTag = ""
    }

    /// Save the current word into the deck and reset the form for the next entry.
    func addAndNext() async {
        guard canSave else { return }
        let card = Card(
            term: term.trimmingCharacters(in: .whitespaces),
            translation: translation.trimmingCharacters(in: .whitespaces),
            example: example.isEmpty ? nil : example,
            tags: selectedTags
        )
        deck.cards.append(card)
        try? await repo.save(deck)
        addedCount += 1
        onChange()
        term = ""; translation = ""; example = ""; selectedTags = []; newTag = ""; autoTranslation = nil
    }
}

struct AddWordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: AddWordModel
    @State private var focus: Field?
    private enum Field { case term, translation }

    init(deck: Deck, repo: any DeckRepository, onChange: @escaping () -> Void) {
        _model = State(initialValue: AddWordModel(deck: deck, repo: repo, onChange: onChange))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vocably.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s5) {
                        // Type the word → Enter → translation (keyboard prefers each field's
                        // language if installed) → Enter saves & jumps back to the word field.
                        langField("WORD", language: model.wordLanguage, text: $model.term,
                                  field: .term, returnKey: .next) { focus = .translation }
                        translationField
                        exampleField
                        tagSection
                    }
                    .padding(Space.s6)
                }
            }
            .navigationTitle(model.deck.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(model.addedCount > 0 ? "Done (\(model.addedCount))" : "Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Add & next", systemImage: "plus") {
                    Task { await model.addAndNext(); focus = .term }
                }
                .opacity(model.canSave ? 1 : 0.5).disabled(!model.canSave)
                .padding(.horizontal, Space.s6).padding(.bottom, Space.s3)
                .background(.ultraThinMaterial)
            }
            .onAppear { focus = .term }
            .onChange(of: model.term) { Task { await model.refreshSuggestion() } }
            .background {
                if #available(iOS 18.0, *) {
                    TranslationBridge(term: model.term,
                                      from: model.wordLanguage, to: model.translationLanguage) {
                        model.applyAutoTranslation($0)
                    }
                }
            }
        }
    }

    @ViewBuilder private var translationField: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            langField("TRANSLATION", language: model.translationLanguage, text: $model.translation,
                      field: .translation, returnKey: .done) {
                Task { await model.addAndNext(); focus = .term }
            }
            if model.showSuggestion, let suggestion = model.autoTranslation {
                Button { model.acceptSuggestion() } label: {
                    HStack(spacing: Space.s2) {
                        Image(systemName: "sparkles").font(.ui(12))
                        Text("Suggested: \(suggestion)").font(.ui(13, .semibold))
                        Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.vocably.accent)
                    .padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
                    .background(Color.vocably.accentSoft).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var exampleField: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("EXAMPLE (OPTIONAL)").font(.ui(12, .semibold)).tracking(1).foregroundStyle(Color.vocably.muted)
            TextField("", text: $model.example)
                .font(.ui(16)).foregroundStyle(Color.vocably.ink)
                .padding(Space.s3)
                .background(Color.vocably.surfaceBright)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Color.vocably.line, lineWidth: 1))
        }
    }

    private func langField(_ label: String, language: String, text: Binding<String>,
                           field f: Field, returnKey: UIReturnKeyType, onReturn: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                Text(label).font(.ui(12, .semibold)).tracking(1).foregroundStyle(Color.vocably.muted)
                Text(language.uppercased()).font(.ui(10, .bold)).foregroundStyle(Color.vocably.primary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Color.vocably.primarySoft).clipShape(Capsule())
            }
            LanguageTextField(text: text, language: language, isFocused: focus == f,
                              returnKey: returnKey, fontSize: 22,
                              onReturn: onReturn, onFocus: { focus = f })
                .frame(height: 30)
                .padding(Space.s3)
                .background(Color.vocably.surfaceBright)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Color.vocably.line, lineWidth: 1))
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("CATEGORIES").font(.ui(12, .semibold)).tracking(1).foregroundStyle(Color.vocably.muted)

            // Auto-suggested (the "app recognises it" part)
            if !model.suggestions.isEmpty {
                HStack(spacing: Space.s2) {
                    Image(systemName: "sparkles").font(.ui(12)).foregroundStyle(Color.vocably.accent)
                    Text("Suggested").font(.ui(12, .semibold)).foregroundStyle(Color.vocably.accent)
                }
                FlowChips(tags: model.suggestions, style: .suggested) { model.toggle($0) }
            }

            // Currently chosen
            if !model.selectedTags.isEmpty {
                FlowChips(tags: model.selectedTags, style: .selected) { model.toggle($0) }
            }

            // Reuse existing deck tags
            if !model.deckTags.isEmpty {
                Text("In this deck").font(.ui(11)).foregroundStyle(Color.vocably.faint)
                FlowChips(tags: model.deckTags, style: .plain) { model.toggle($0) }
            }

            // Custom tag entry
            HStack(spacing: Space.s2) {
                TextField("Add a tag…", text: $model.newTag)
                    .font(.ui(14))
                    .submitLabel(.done).onSubmit { model.addCustomTag() }
                    .padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
                    .background(Color.vocably.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.vocably.line, lineWidth: 1))
                Button { model.addCustomTag() } label: {
                    Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Color.vocably.primary)
                }
            }
            .padding(.top, Space.s1)
        }
    }
}

// MARK: - Chip flow layout

enum ChipStyle { case suggested, selected, plain }

struct FlowChips: View {
    let tags: [String]
    var style: ChipStyle = .plain
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: Space.s2) {
            ForEach(tags, id: \.self) { tag in
                Button { onTap(tag) } label: { chip(tag) }.buttonStyle(.plain)
            }
        }
    }

    private func chip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag).font(.ui(13, .semibold))
            if style == .selected { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
            else if style == .suggested { Image(systemName: "plus").font(.system(size: 9, weight: .bold)) }
        }
        .foregroundStyle(fg).padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
        .background(bg).clipShape(Capsule())
        .overlay(Capsule().stroke(border, lineWidth: 1))
    }

    private var fg: Color {
        switch style {
        case .suggested: return Color.vocably.accent
        case .selected:  return Color.vocably.onPrimary
        case .plain:     return Color.vocably.ink
        }
    }
    private var bg: Color {
        switch style {
        case .suggested: return Color.vocably.accentSoft
        case .selected:  return Color.vocably.primary
        case .plain:     return Color.vocably.surface
        }
    }
    private var border: Color { style == .plain ? Color.vocably.line : .clear }
}

/// Minimal wrapping HStack (chips flow to the next line when they run out of width).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]; var x: CGFloat = 0; var totalHeight: CGFloat = 0; var rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, !rows[rows.count - 1].isEmpty {
                totalHeight += rowHeight + spacing; rows.append([]); x = 0; rowHeight = 0
            }
            rows[rows.count - 1].append(s); x += s.width + spacing; rowHeight = max(rowHeight, s.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowHeight = max(rowHeight, s.height)
        }
    }
}
