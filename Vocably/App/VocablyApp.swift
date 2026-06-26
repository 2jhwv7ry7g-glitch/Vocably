import SwiftUI
import VocablyDomain
import VocablyServices
import SRSEngine

/// The three persistence protocols passed together to feature views.
struct Repos {
    let decks: any DeckRepository
    let profiles: any ProfileRepository
    let activity: any ActivityRepository
}

// Composition root. Repositories are now the SwiftData adapters (MAC_DEV_GUIDE §6),
// seeded from SampleData on first launch — swapped in behind the same protocols the
// views already use, so nothing else changed.
@MainActor
final class AppContainer {
    let repos: Repos

    init() {
        let container = VocablyStore.makeContainer()
        repos = Repos(
            decks: SwiftDataDeckRepository(modelContainer: container),
            profiles: SwiftDataProfileRepository(modelContainer: container),
            activity: SwiftDataActivityRepository(modelContainer: container)
        )
    }
}

@main
struct VocablyApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .tint(Color.vocably.primary)
        }
    }
}

// Tabs per §10 (Home · Decks · Study · AI · Profile). Home + Study are wired in this
// increment; the rest are placeholders until their phases land.
struct RootView: View {
    let container: AppContainer
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    // Debug-only: launch straight into a study session for screenshot/UI verification.
    private var startInStudy: Bool {
        ProcessInfo.processInfo.arguments.contains("-startStudy")
    }
    @State private var showDebugStudy = false

    var body: some View {
        Group {
            if (hasOnboarded || ProcessInfo.processInfo.arguments.contains("-skipOnboarding"))
                && !ProcessInfo.processInfo.arguments.contains("-onboarding") {
                appTabs
            } else {
                OnboardingView(profiles: container.repos.profiles) {
                    withAnimation { hasOnboarded = true }
                }
            }
        }
    }

    private var appTabs: some View {
        TabView {
            HomeView(model: HomeModel(
                decks: container.repos.decks,
                profiles: container.repos.profiles,
                activity: container.repos.activity
            ), repos: container.repos)
            .tabItem { Label("Home", systemImage: "house.fill") }
            .onAppear { if startInStudy { showDebugStudy = true } }
            .fullScreenCover(isPresented: $showDebugStudy) {
                StudyView(cards: SessionBuilder.dueCards(from: SampleData.decks, on: .now), streak: 12)
            }

            LibraryView(repos: container.repos)
                .tabItem { Label("Decks", systemImage: "rectangle.stack.fill") }

            AIStudioView(repos: container.repos)
                .tabItem { Label("AI", systemImage: "sparkles") }

            ProfileView(repos: container.repos)
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}

struct ComingSoon: View {
    let title: String
    var body: some View {
        ZStack {
            Color.vocably.background.ignoresSafeArea()
            VStack(spacing: Space.s3) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 40)).foregroundStyle(Color.vocably.faint)
                Text(title).font(.display(24)).foregroundStyle(Color.vocably.ink)
                Text("Coming in a later phase").font(.ui(14)).foregroundStyle(Color.vocably.muted)
            }
        }
    }
}
