import SwiftUI
import Observation
import VocablyDomain
import SRSEngine
import VocablyPresentation
import VocablyServices

// View model: fetches profile/decks/activity and hands the tested `HomeState` to
// the view (MAC_DEV_GUIDE §3). No Home logic lives here — only loading + binding.
@MainActor @Observable
final class HomeModel {
    private(set) var state: HomeState?
    private(set) var decks: [Deck] = []

    private let decksRepo: any DeckRepository
    private let profilesRepo: any ProfileRepository
    private let activityRepo: any ActivityRepository

    init(decks: any DeckRepository, profiles: any ProfileRepository, activity: any ActivityRepository) {
        self.decksRepo = decks
        self.profilesRepo = profiles
        self.activityRepo = activity
    }

    func load() async {
        do {
            let profile = try await profilesRepo.load() ?? UserProfile()
            let allDecks = try await decksRepo.allDecks()
            let history = try await activityRepo.all()
            self.decks = allDecks
            self.state = HomeState(profile: profile, decks: allDecks, activity: history, now: .now)
        } catch {
            self.state = nil
        }
    }

    /// The deck to "continue": the most recently created deck that still has due cards.
    var continueDeck: Deck? {
        decks.filter { !$0.dueCards(on: .now).isEmpty }
             .max { $0.createdAt < $1.createdAt }
    }

    /// Due cards across every deck, review-first (SessionBuilder is the tested queue logic).
    func allDueCards() -> [Card] { SessionBuilder.dueCards(from: decks, on: .now) }

    /// Due cards for one deck, by display name.
    func dueCards(inDeckNamed name: String) -> [Card] {
        guard let deck = decks.first(where: { $0.name == name }) else { return [] }
        return SessionBuilder.dueCards(from: [deck], on: .now)
    }

    /// Persist a finished study pass, then refresh.
    func commit(_ result: StudySessionResult) async {
        await SessionCommit.apply(result, decks: decksRepo, profiles: profilesRepo, activity: activityRepo)
        await load()
    }
}

struct HomeView: View {
    @State private var model: HomeModel
    @State private var session: StudySessionCards?
    @State private var showingScan = false
    let repos: Repos

    init(model: HomeModel, repos: Repos) {
        _model = State(initialValue: model)
        self.repos = repos
    }

    var body: some View {
        ZStack {
            Color.vocably.background.ignoresSafeArea()
            ScrollView {
                if let s = model.state {
                    VStack(alignment: .leading, spacing: Space.s5) {
                        header(greeting: s.greeting, level: s.level)
                        StreakWeek(dots: s.weekDots, streak: s.streakCount)
                        if let deck = model.continueDeck {
                            continueCard(name: deck.name, due: deck.dueCards(on: .now).count, progress: deck.progress)
                        }
                        decksSection
                    }
                    .padding(.horizontal, Space.s6)
                    .padding(.vertical, Space.s4)
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
        }
        .task { await model.load() }
        .fullScreenCover(item: $session, onDismiss: { Task { await model.load() } }) { s in
            StudyView(cards: s.cards,
                      streak: model.state?.streakCount ?? 0,
                      onCommit: { await model.commit($0) })
        }
        .sheet(isPresented: $showingScan, onDismiss: { Task { await model.load() } }) {
            ScanView(repos: repos)
        }
    }

    // MARK: Sections

    private func header(greeting: String, level: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.display(30, .semibold)).foregroundStyle(Color.vocably.ink)
                Text("Level \(level)").font(.ui(14)).foregroundStyle(Color.vocably.muted)
            }
            Spacer()
            Button { showingScan = true } label: {
                Image(systemName: "text.viewfinder")
                    .font(.title3).foregroundStyle(Color.vocably.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.vocably.surface).clipShape(Circle())
                    .overlay(Circle().stroke(Color.vocably.line, lineWidth: 1))
            }
            Circle().fill(Color.vocably.primarySoft)
                .frame(width: 44, height: 44)
                .overlay(Text(String(greeting.dropFirst(6).prefix(1)))
                    .font(.ui(18, .semibold)).foregroundStyle(Color.vocably.primary))
        }
    }

    private func continueCard(name: String, due: Int, progress: Double) -> some View {
        Button {
            let cards = model.dueCards(inDeckNamed: name)
            if !cards.isEmpty { session = StudySessionCards(cards: cards) }
        } label: {
            VStack(alignment: .leading, spacing: Space.s3) {
                Text("CONTINUE")
                    .font(.ui(12, .semibold)).tracking(1.2)
                    .foregroundStyle(Color.vocably.onPrimary.opacity(0.7))
                Text(name).font(.display(24, .semibold)).foregroundStyle(Color.vocably.onPrimary)
                Text("\(due) cards due").font(.ui(15)).foregroundStyle(Color.vocably.onPrimary.opacity(0.85))
                ProgressBar(value: progress, tint: Color.vocably.onPrimary)
                    .padding(.top, Space.s1)
                HStack {
                    Spacer()
                    Label("Start session", systemImage: "play.fill")
                        .font(.ui(15, .semibold)).foregroundStyle(Color.vocably.primary)
                        .padding(.horizontal, Space.s4).padding(.vertical, Space.s2)
                        .background(Color.vocably.onPrimary)
                        .clipShape(Capsule())
                }
            }
            .padding(Space.s5)
            .background(Color.vocably.primary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var decksSection: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Your decks").font(.display(20, .semibold)).foregroundStyle(Color.vocably.ink)
            ForEach(model.decks) { deck in
                Button {
                    let cards = model.dueCards(inDeckNamed: deck.name)
                    if !cards.isEmpty { session = StudySessionCards(cards: cards) }
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
        }
    }
}
