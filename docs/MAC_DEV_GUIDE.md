# Vocably — Mac / iOS Developer Guide

You're picking up a project whose **entire non-UI core is already written and tested** (`Packages/VocablyCore`, 113 passing tests, built on Windows). Your job: build the **native SwiftUI app** on top of it — full iOS-native UI, Apple frameworks, App Store ship.

**Read order:** this guide → `STATUS.md` (checkpoint) → `docs/IOS_BUILD_HANDOFF.md` (full spec: design tokens §5, components §6, screens + Paper node IDs §11, integrations §12).
**Designs:** Paper file `https://app.paper.design/file/01KW03XFEJP9EVDNM2VYTC9SH4/1-0` (21 pixel-accurate screens). Use Paper MCP `get_jsx` / `get_computed_styles` for exact values; never read sizes off screenshots.

---

## 0. The golden rule

**Never re-implement logic in the UI.** Every screen already has a tested state machine in `VocablyPresentation`, every algorithm in `SRSEngine`, every model in `VocablyDomain`. A SwiftUI view = a thin `@Observable` view model wrapping one `Vocably*State` + drawing the design. If you find yourself writing scheduling, streak, filtering, or onboarding logic in a View, stop — it already exists.

---

## 1. Day 1 (≈30 min)

1. Open the repo on a Mac with Xcode 16+.
2. `cd Packages/VocablyCore && swift test` → confirm **113 tests pass** on macOS too (the package is portable).
3. New Xcode project → **App**, SwiftUI lifecycle, name `Vocably`, bundle id `app.vocably`, min iOS **17** (see §11 decision 1).
4. **File ▸ Add Package Dependencies… ▸ Add Local…** → select `Packages/VocablyCore`. Add the `VocablyDomain`, `SRSEngine`, `VocablyServices`, `VocablyPresentation` library products to the app target. (This is the entire "port" — the engine comes with its tests.)
5. Build & run the empty app on the simulator. You now have the foundation.

Capabilities to add as you go: **iCloud (CloudKit)**, **Sign in with Apple**, **Push** (for ActivityKit), **App Groups** (widgets), and a **StoreKit configuration file** for local purchase testing.

---

## 2. Recommended Xcode target layout

```
Vocably (app target)
  App/            VocablyApp.swift, AppContainer (DI), RootView (tabs + onboarding gate)
  DesignSystem/   Colors.xcassets, Fonts, Theme.swift, Components/  (or a local SPM target)
  Features/       Home/ Study/ Scan/ AIStudio/ Library/ WordDetail/ Profile/ Onboarding/ Paywall/
  Persistence/    SwiftData models + repository adapters
  Services/       Live service implementations
VocablyWidgets (widget extension)
Tests / UITests
```
Keep `DesignSystem` and feature folders as **local SPM targets** if you want previews to build fast and stay isolated. They depend on `VocablyCore` products.

---

## 3. The view-model pattern (do this for every screen)

```swift
import Observation
import VocablyDomain
import SRSEngine
import VocablyPresentation
import VocablyServices

@MainActor @Observable
final class HomeModel {
    private(set) var state: HomeState?          // the tested type — UI just reads it
    private let decks: any DeckRepository
    private let profiles: any ProfileRepository
    private let activity: any ActivityRepository

    init(decks: any DeckRepository, profiles: any ProfileRepository, activity: any ActivityRepository) {
        self.decks = decks; self.profiles = profiles; self.activity = activity
    }

    func load() async {
        do {
            let profile = try await profiles.load() ?? UserProfile()
            let allDecks = try await decks.allDecks()
            let history = try await activity.all()
            state = HomeState(profile: profile, decks: allDecks, activity: history, now: .now)
        } catch {
            // surface to an error banner; never crash
        }
    }
}

struct HomeView: View {
    @State private var model: HomeModel
    init(model: HomeModel) { _model = State(initialValue: model) }

    var body: some View {
        ScrollView {
            if let s = model.state {
                VStack(alignment: .leading, spacing: 18) {
                    HomeHeader(greeting: s.greeting)
                    StreakStrip(dots: s.weekDots, streak: s.streakCount)
                    ContinueCard(name: s.continueDeckName, due: s.continueDueCount, progress: s.continueProgress)
                    DeckList(/* from decks */)
                }
                .padding(.horizontal, 24)
            } else {
                ProgressView()
            }
        }
        .background(Color.vocably.background)
        .task { await model.load() }
    }
}
```

**Mutating screens (Study, Onboarding, Paywall)** hold the state machine as `var` and call its methods, then re-publish. Example for Study:

```swift
@MainActor @Observable
final class StudyModel {
    private var state: StudyScreenState
    let total: Int
    var face: StudyScreenState.Face { state.face }
    var currentCard: Card? { state.currentCard }
    var progressText: String { state.progressText }
    var isFinished: Bool { state.isFinished }

    init(cards: [Card]) { state = StudyScreenState(cards: cards); total = cards.count }

    func flip() { state.flip() }
    func swipe(_ d: SwipeDirection) { state.swipe(d, now: .now) }   // .left=again, .right=know
    func undo() { state.undo() }
    func finish() -> StudySessionResult { state.result(now: .now) }
}
```

---

## 4. DesignSystem (handoff §5/§6)

**Colors** → an asset catalog `Colors.xcassets` with a color set per token, each having a **Light** and **Dark** appearance (hex values in handoff §5.1 / §5.2). Expose semantically:

```swift
extension Color {
    enum vocably {
        static let background   = Color("background")
        static let surface      = Color("surface")
        static let surfaceBright = Color("surfaceBright")
        static let ink          = Color("ink")
        static let muted        = Color("muted")
        static let faint        = Color("faint")
        static let line         = Color("line")
        static let primary      = Color("primary")        // moss
        static let primarySoft  = Color("primarySoft")
        static let onPrimary    = Color("onPrimary")
        static let accent       = Color("accent")         // honey
        static let accentSoft   = Color("accentSoft")
        static let rose         = Color("rose")
    }
}
```

**Fonts** — bundle Fraunces + Inter (Add to target, list in Info.plist `UIAppFonts`), wrap for **Dynamic Type** with `relativeTo:`:

```swift
extension Font {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .custom("Fraunces", size: size, relativeTo: .title).weight(weight)
    }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size, relativeTo: .body).weight(weight)
    }
}
```
(Or substitute SF Pro for `ui` and keep Fraunces for `display` — decision §11.4.)

**Components** to build first (specs in handoff §6): `PrimaryButton`, `Chip`, `DeckRow`, `ProgressRing`, `ProgressBar`, `SegmentedProgress`, `StatStrip`, `SurfaceCard`, `Flashcard`, `TabBar`, `OptionRow`, `PlanCard`, `FormField`, `StreakWeek`. Build them with `#Preview` first, against `SampleData`.

---

## 5. Screen → state machine → design

| Screen | View model wraps | Paper node | Native bits |
|---|---|---|---|
| Home | `HomeState` | `1-0` (alt `VQ-0`/`Y0-0`) | `ScrollView`, Swift Charts ring, `StreakWeek` |
| Swipe Study | `StudyScreenState` | `3H-0` (alt `SK-0`/`U6-0`) | `DragGesture` + `rotationEffect`/`offset`, `matchedGeometryEffect` stack, `.sensoryFeedback` on commit; map drag end → `swipe(.left/.right)` |
| Session Complete | `SessionSummaryState` | `R1-0` | confetti, haptic, `.transition` |
| OCR Scan | live `ScanService` → words | `5J-0` | `DataScannerViewController` via `UIViewControllerRepresentable`; results in a `.sheet` with `.presentationDetents` |
| AI Generate | `AIService` → `[CardDraft]` | `7U-0` | streamed rows; `.textField` composer |
| Word Detail | `Card` + `SpeechService` | `AD-0` | `AVSpeechSynthesizer` "Listen", AI memory hook |
| Library | `LibraryState` | `H2-0` | `.searchable`, filter chips, `Core Spotlight` index |
| Deck Detail | `DeckDetailState` | `KC-0` | word list, pinned study CTA |
| Profile | `UserProfile` + `Achievement` | `NE-0` | **Swift Charts**, level ring |
| Onboarding (8) | `OnboardingFlowState` | `10Q-0,EL-0,11U-0,14B-0,180-0` | paged flow, `SegmentedProgress`, Sign in with Apple |
| Paywall | `PaywallState` | `1B6-0` | `StoreKit 2`; plan cards |
| Checkout | — | `1DN-0` | **use StoreKit's native purchase sheet — not the custom card form** (App Store rule, §11.5) |
| All Set | `OnboardingFlowState.makeProfile` | `1FV-0` | celebration → enter app |

Tab bar (handoff §6): Home · Decks · Study(center FAB) · AI · Profile. Use `TabView`; Scan/Study/WordDetail/Paywall present modally (`.sheet`/`.fullScreenCover`).

---

## 6. Persistence — SwiftData adapter

Mirror the domain structs as `@Model`s and implement the repository protocols. Use `@ModelActor` to keep the `ModelContext` off the main actor.

```swift
import SwiftData
import VocablyDomain
import VocablyServices

@Model final class DeckEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var languageCode: String
    var level: String
    var colorTokenName: String
    var sourceRaw: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var cards: [CardEntity] = []
    init(_ d: Deck) { /* copy fields */ }
    func toDomain() -> Deck { /* build Deck(...) incl. cards.map { $0.toDomain() } */ }
}

@ModelActor
actor SwiftDataDeckRepository: DeckRepository {
    func allDecks() async throws -> [Deck] {
        try modelContext.fetch(FetchDescriptor<DeckEntity>()).map { $0.toDomain() }
    }
    func deck(id: UUID) async throws -> Deck? { /* fetch by #Predicate */ }
    func save(_ deck: Deck) async throws { /* upsert entity, modelContext.save() */ }
    func delete(id: UUID) async throws { /* delete + save */ }
}
```
Same for `Profile`/`Activity`. Enable CloudKit on the `ModelContainer` for free sync (decision §11.2). The `Review` struct is the SRS state — store it on `CardEntity` (flatten its fields or hold as Codable data). **Keep all scheduling logic in `SRSEngine`** — entities are dumb storage.

Seed on first launch from `SampleData` (or your premade-deck bundle).

---

## 7. Live services — implement each protocol

Swap the mocks (`VocablyServices`) for real Apple-framework impls. Gate the iOS-26 ones with `#available` + fallback.

**SpeechService** (AVFoundation):
```swift
import AVFoundation
final class LiveSpeechService: SpeechService {
    private let synth = AVSpeechSynthesizer()
    func speak(_ text: String, language: String) {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: language)   // e.g. "es-ES"
        synth.speak(u)
    }
}
```

**StoreService** (StoreKit 2):
```swift
import StoreKit
final class LiveStoreService: StoreService {
    let ids = ["pro.monthly", "pro.yearly"]
    func products() async throws -> [SubscriptionProduct] {
        try await Product.products(for: ids).map { p in
            SubscriptionProduct(id: p.id, displayName: p.displayName,
                formattedPrice: p.displayPrice,
                period: p.id.contains("year") ? .yearly : .monthly,
                hasFreeTrial: p.subscription?.introductoryOffer?.paymentMode == .freeTrial)
        }
    }
    func purchase(productID: String) async throws -> Bool {
        guard let p = try await Product.products(for: [productID]).first else { return false }
        if case .success(let v) = try await p.purchase(), case .verified = v { return true }
        return false
    }
    func restore() async throws { try await AppStore.sync() }
    func currentStatus() async -> SubscriptionStatus {
        for await e in Transaction.currentEntitlements { if case .verified = e { return .pro } }
        return .free
    }
}
```

**ScanService** (VisionKit): wrap `DataScannerViewController` (recognizedDataTypes `.text()`) in `UIViewControllerRepresentable`; push recognized strings into the `AsyncStream<[RecognizedWord]>`. Translate captured words with **TranslateService**.

**TranslateService** (Translation + NaturalLanguage): `TranslationSession` (iOS 18) for `translate`; `NLTagger`/`NLTokenizer` for `lemmatize`. Bundle a fallback dictionary for unsupported language pairs.

**AIService** (Foundation Models + fallback):
```swift
import FoundationModels   // iOS 26+
@Generable struct GeneratedCard { let term: String; let translation: String; let example: String }

func makeAIService() -> any AIService {
    if #available(iOS 26, *) { return AppleIntelligenceAIService() }   // LanguageModelSession + guided generation
    return ServerAIService()                                          // REST fallback (the optional Vapor AIProxy)
}
```

**ReminderService** (UserNotifications): schedule the daily-goal reminder at the onboarding time; actionable "Review now"; request auth.

---

## 8. System integrations (handoff §12)

- **WidgetKit + App Intents** — streak / words-due / word-of-day; interactive "Start review". Share data via App Group (write a small snapshot the widget reads, or read SwiftData via shared container).
- **ActivityKit** — Live Activity + Dynamic Island for an in-progress session.
- **App Intents / Siri** — "Start my Spanish review", "Scan a word"; donate for Spotlight.
- **Core Spotlight** — index decks + words; deep-link in.
- **Sign in with Apple** — on Welcome; store token in Keychain.
- **Swift Charts** — Profile stats + Home ring.

---

## 9. Native-feel & accessibility (non-negotiable, handoff §13)

- **Dynamic Type** everywhere (use the `relativeTo:` fonts; verify at XXL — no clipping).
- **Dark Mode** parity — `Y0-0`/`U6-0` show the intended dark treatment; all colors are asset-catalog light+dark.
- **Haptics** — `.sensoryFeedback(.impact, trigger:)` on swipe commit; `.success` on streak milestone.
- **VoiceOver** — label cards; expose swipe outcomes as `.accessibilityAction(named:)` ("Mark known"/"Still learning").
- **Reduce Motion** → cross-fade instead of card-throw; honor **Reduce Transparency / Increase Contrast / Bold Text**.
- **Localization** — String Catalogs (`.xcstrings`); RTL-ready (fitting for a language app).

---

## 10. Build order (milestones)

1. **DesignSystem** — tokens, fonts, components; preview gallery (light+dark).
2. **Persistence** — SwiftData models + repos; seed `SampleData`; confirm Home loads.
3. **Core loop** — Home + Swipe Study + Session Complete (wire `StudyScreenState` + `SessionBuilder`). This is the app's spine; ship it first.
4. **Library + Deck Detail + Word Detail** (+ SpeechService).
5. **Onboarding (8) + Paywall + StoreKit** + Sign in with Apple.
6. **Scan + AI** (VisionKit, Translation, FoundationModels + fallback).
7. **Widgets / Live Activity / App Intents / Notifications / Spotlight.**
8. **A11y, localization, Swift Charts profile, polish, TestFlight, App Store.**

---

## 11. Decisions to confirm + gotchas

1. **Min iOS 17** (broad reach; gate FoundationModels/Translation-programmatic behind `#available`) vs 18+ (simpler).
2. **Sync/backend:** CloudKit-only first; add a server only for leaderboards/social (Profile's "Top 8%") + the server-LLM fallback.
3. **AI:** hybrid (on-device FoundationModels + server fallback) vs single server LLM.
4. **Fonts:** bundle Fraunces+Inter (tune Dynamic Type) vs SF Pro UI + Fraunces display.
5. ⚠️ **Payments must use StoreKit/IAP.** The custom credit-card **Checkout (`1DN-0`) is a visual reference only** — shipping it as the real payment path for a digital subscription will get the app rejected. Use StoreKit's purchase flow / `SubscriptionStoreView`.
6. **FoundationModels** needs iOS 26 + Apple-Intelligence-capable devices — always have the fallback wired.
7. **Canonical variants:** ship Home `1-0` + Swipe `3H-0`; keep the others (ring/dark home, minimal/focus swipe) as alternates / dark-mode reference.

---

## 12. Testing

- The engine's 113 tests run in Xcode unchanged — keep them green; add SwiftData repo tests (the protocols already have a test contract in `VocablyServicesTests`).
- **Snapshot tests** for DesignSystem components (light+dark, Dynamic Type sizes).
- **XCUITest** for the review loop and the sandbox purchase.
- StoreKit `.storekit` config for local purchase testing; Instruments for the swipe at 60/120 fps.

---

## 13. Reference index

- `STATUS.md` — verified state, module map, build commands.
- `docs/IOS_BUILD_HANDOFF.md` — full spec: tokens §5, components §6, data model §7, service protocols §8, screens + **Paper node IDs** §11, integrations §12.
- `Packages/VocablyCore/` — the engine you build on:
  - `VocablyDomain` (models, `SampleData`) · `SRSEngine` (`SM2Scheduler`, `StudySession`, `StreakCalculator`, `LevelCurve`, `SessionBuilder`) · `VocablyServices` (service + repository protocols, mocks, JSON repos) · `VocablyPresentation` (the 7 screen state machines) · `VocablyCLI` (runnable reference of the full loop).
- Paper designs: `https://app.paper.design/file/01KW03XFEJP9EVDNM2VYTC9SH4/1-0`.

Welcome aboard — the brain is done and tested. Draw the designs over it and make it feel unmistakably native.
