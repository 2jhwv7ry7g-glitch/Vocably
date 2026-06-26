import SwiftUI
import Observation
import VocablyDomain
import SRSEngine
import VocablyPresentation
import VocablyServices

// MARK: - Library

@MainActor @Observable
final class LibraryModel {
    private(set) var state = LibraryState(decks: [])
    private let decksRepo: any DeckRepository

    init(decks: any DeckRepository) { self.decksRepo = decks }

    func load() async {
        let all = (try? await decksRepo.allDecks()) ?? []
        var next = LibraryState(decks: all)
        next.setQuery(state.query)
        next.setFilter(state.filter)
        state = next
    }

    func setQuery(_ q: String) { state.setQuery(q) }
    func setFilter(_ f: LibraryState.Filter) { state.setFilter(f) }
}

struct LibraryView: View {
    let repos: Repos
    @State private var model: LibraryModel
    @State private var showingAddDeck = false

    init(repos: Repos) {
        self.repos = repos
        _model = State(initialValue: LibraryModel(decks: repos.decks))
    }

    private let filters: [LibraryState.Filter] = [.all, .learning, .mastered, .aiMade]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vocably.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s4) {
                        chips
                        ForEach(model.state.visibleDecks) { deck in
                            NavigationLink {
                                DeckDetailView(deckID: deck.id, repos: repos)
                            } label: {
                                DeckRow(
                                    name: deck.name,
                                    subtitle: "\(deck.languageCode.uppercased()) · \(deck.level)",
                                    dueCount: deck.dueCards(on: .now).count,
                                    progress: deck.progress,
                                    colorToken: deck.colorTokenName
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        if model.state.visibleDecks.isEmpty {
                            Text("No decks match.").font(.ui(15))
                                .foregroundStyle(Color.vocably.muted)
                                .frame(maxWidth: .infinity).padding(.top, Space.s10)
                        }
                    }
                    .padding(.horizontal, Space.s6).padding(.vertical, Space.s4)
                }
            }
            .navigationTitle("Decks")
            .searchable(text: Binding(get: { model.state.query }, set: { model.setQuery($0) }),
                        prompt: "Search words or decks")
            .background(Color.vocably.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddDeck = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAddDeck) {
                AddDeckView(repos: repos) { Task { await model.load() } }
            }
        }
        .task { await model.load() }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s2) {
                ForEach(filters, id: \.self) { filter in
                    let selected = model.state.filter == filter
                    Button { model.setFilter(filter) } label: {
                        Text(label(filter))
                            .font(.ui(14, .semibold))
                            .foregroundStyle(selected ? Color.vocably.onPrimary : Color.vocably.ink)
                            .padding(.horizontal, Space.s4).padding(.vertical, Space.s2)
                            .background(selected ? Color.vocably.primary : Color.vocably.surface)
                            .overlay(Capsule().stroke(Color.vocably.line, lineWidth: selected ? 0 : 1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func label(_ f: LibraryState.Filter) -> String {
        switch f {
        case .all: return "All"
        case .learning: return "Learning"
        case .mastered: return "Mastered"
        case .aiMade: return "AI-made"
        }
    }
}

// MARK: - Deck Detail

@MainActor @Observable
final class DeckDetailModel {
    private(set) var state: DeckDetailState?
    private(set) var deck: Deck?
    private let repos: Repos
    let deckID: UUID

    init(deckID: UUID, repos: Repos) {
        self.deckID = deckID
        self.repos = repos
    }

    func load() async {
        guard let d = try? await repos.decks.deck(id: deckID) else { return }
        deck = d
        state = DeckDetailState(deck: d, now: .now)
    }

    /// Distinct tags used across the deck, for the study filter.
    var allTags: [String] {
        guard let deck else { return [] }
        return Set(deck.cards.flatMap(\.tags)).sorted()
    }

    /// Due cards, optionally restricted to the selected tags (the "quiz filter").
    func studyCards(tags: Set<String> = []) -> [Card] {
        guard let deck else { return [] }
        return SessionBuilder.dueCards(from: [deck], on: .now, tags: tags.isEmpty ? nil : tags)
    }

    var repos_: Repos { repos }

    func commit(_ result: StudySessionResult) async {
        await SessionCommit.apply(result, decks: repos.decks, profiles: repos.profiles, activity: repos.activity)
        await load()
    }
}

struct DeckDetailView: View {
    @State private var model: DeckDetailModel
    @State private var session: StudySessionCards?
    @State private var filterTags: Set<String> = []
    @State private var showingAdd = false
    @State private var selectedWord: Card?

    init(deckID: UUID, repos: Repos) {
        _model = State(initialValue: DeckDetailModel(deckID: deckID, repos: repos))
    }

    private var filteredDueCount: Int { model.studyCards(tags: filterTags).count }

    var body: some View {
        ZStack {
            Color.vocably.background.ignoresSafeArea()
            if let s = model.state {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s5) {
                        hero(s)
                        statStrip(s)
                        if !model.allTags.isEmpty { tagFilter }
                        wordList
                    }
                    .padding(.horizontal, Space.s6).padding(.vertical, Space.s4)
                }
                .safeAreaInset(edge: .bottom) {
                    if filteredDueCount > 0 {
                        PrimaryButton(title: studyTitle, systemImage: "play.fill") {
                            let cards = model.studyCards(tags: filterTags)
                            if !cards.isEmpty { session = StudySessionCards(cards: cards) }
                        }
                        .padding(.horizontal, Space.s6).padding(.bottom, Space.s4)
                        .background(.ultraThinMaterial)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(model.state?.deckName ?? "Deck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $showingAdd) {
            if let deck = model.deck {
                AddWordView(deck: deck, repo: model.repos_.decks) { Task { await model.load() } }
            }
        }
        .sheet(item: $selectedWord) { card in
            WordDetailView(card: card, languageCode: model.deck?.languageCode ?? "en")
        }
        .fullScreenCover(item: $session) { s in
            StudyView(cards: s.cards, streak: 0, onCommit: { await model.commit($0) })
        }
    }

    private var studyTitle: String {
        filterTags.isEmpty ? "Study \(filteredDueCount) due words"
                           : "Study \(filteredDueCount) · \(filterTags.sorted().joined(separator: ", "))"
    }

    private var tagFilter: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Quiz filter").font(.ui(13, .semibold)).foregroundStyle(Color.vocably.muted)
            FlowLayout(spacing: Space.s2) {
                ForEach(model.allTags, id: \.self) { tag in
                    let on = filterTags.contains(tag)
                    Button {
                        if on { filterTags.remove(tag) } else { filterTags.insert(tag) }
                    } label: {
                        Text(tag).font(.ui(13, .semibold))
                            .foregroundStyle(on ? Color.vocably.onPrimary : Color.vocably.ink)
                            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
                            .background(on ? Color.vocably.primary : Color.vocably.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.vocably.line, lineWidth: on ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func hero(_ s: DeckDetailState) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(s.deckName).font(.display(28, .semibold)).foregroundStyle(Color.vocably.onPrimary)
            Text("\(s.languageCode.uppercased()) · \(s.level) · \(s.progressPercent)% learned")
                .font(.ui(14)).foregroundStyle(Color.vocably.onPrimary.opacity(0.85))
            ProgressBar(value: Double(s.progressPercent) / 100, tint: Color.vocably.onPrimary)
                .padding(.top, Space.s2)
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.vocably.primary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func statStrip(_ s: DeckDetailState) -> some View {
        HStack(spacing: Space.s3) {
            stat("\(s.learned)", "Learned")
            stat("\(s.dueToday)", "Due today")
            stat("\(s.mastered)", "Mastered")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        SurfaceCard {
            VStack(spacing: 4) {
                Text(value).font(.display(22, .semibold)).foregroundStyle(Color.vocably.ink)
                Text(label).font(.ui(12)).foregroundStyle(Color.vocably.muted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var wordList: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Words").font(.display(20, .semibold)).foregroundStyle(Color.vocably.ink)
            ForEach(model.deck?.cards ?? []) { card in
                Button { selectedWord = card } label: {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: Space.s2) {
                            HStack(spacing: Space.s3) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.term).font(.ui(16, .semibold)).foregroundStyle(Color.vocably.ink)
                                    Text(card.translation).font(.ui(13)).foregroundStyle(Color.vocably.muted)
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    ForEach(0..<3, id: \.self) { dot in
                                        Circle()
                                            .fill(dot < min(3, max(0, card.review.masteryLevel)) ? Color.vocably.primary : Color.vocably.line)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                Image(systemName: "chevron.right").font(.ui(12)).foregroundStyle(Color.vocably.faint)
                            }
                            if !card.tags.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(card.tags, id: \.self) { tag in
                                        Text(tag).font(.ui(11, .semibold)).foregroundStyle(Color.vocably.primary)
                                            .padding(.horizontal, Space.s2).padding(.vertical, 3)
                                            .background(Color.vocably.primarySoft).clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
