# Vocably — Build Status

_Last verified: Swift 6.3.2 (x86_64-unknown-windows-msvc), 113 tests passing._

Vocably is a native-iOS vocabulary app. The **entire non-UI core is built and tested on Windows**; the SwiftUI layer is added later on a Mac over this finished engine. Designs (21 screens) live in Paper — see `docs/IOS_BUILD_HANDOFF.md`.

---

## What's done (verified on Windows)

`Packages/VocablyCore/` — a portable Swift package, **no Apple-only frameworks**, so it compiles unchanged on macOS/Xcode later.

| Module | Responsibility |
|---|---|
| `VocablyDomain` | Value types: Card, Deck, Review, UserProfile, DailyActivity, Rating, Language(+catalog), Motivation/DailyGoal/ProficiencyLevel, Achievement, drafts, subscription types, **SampleData** |
| `SRSEngine` | `SM2Scheduler` (SuperMemo SM-2), `Mastery`, `DueQuery`, `StudySession`, `StreakCalculator`, `LevelCurve`, `SessionBuilder` (multi-deck queue) |
| `VocablyServices` | Service **protocols** (`AIService`, `ScanService`, `TranslateService`, `SpeechService`, `StoreService`, `ReminderService`) + mocks; **repository protocols** (`DeckRepository`/`ProfileRepository`/`ActivityRepository`) + in-memory **and** JSON-file actor impls |
| `VocablyPresentation` | Per-screen state machines (plain Swift, no SwiftUI): `OnboardingFlowState`, `PaywallState`, `StudyScreenState`, `SessionSummaryState`, `HomeState`, `LibraryState`, `DeckDetailState` |
| `VocablyCLI` | `vocably-cli` — runs the full loop (seed → review → score → persist) in the terminal |

**Status: Track A (W1–W4) + W6 presentation logic complete. 113 unit tests, 0 failures.**

---

## Build & run (Windows)

The installer's env vars don't reach an already-open shell, so a helper sets them:

```
cmd.exe /c sw.bat build      # build all targets
cmd.exe /c sw.bat test       # 113 tests
cmd.exe /c sw.bat run vocably-cli
```

`sw.bat` (repo root, machine-local — gitignored data) prepends the toolchain + runtime to PATH and sets `SDKROOT`. In a **freshly opened terminal** the installer's PATH/SDKROOT apply, so plain `swift build|test|run` works from `Packages/VocablyCore/`. IDE: VS Code + the Swift extension.

---

## Not here yet (needs a Mac / Xcode)

SwiftUI screens, DesignSystem (tokens→assets, fonts), SwiftData persistence adapter, live services (FoundationModels, VisionKit, Translation, AVSpeech, StoreKit 2, UserNotifications), WidgetKit/ActivityKit/App Intents, Sign in with Apple, TestFlight/App Store. None of this compiles on Windows.

---

## Mac pickup steps

1. Open the repo on a Mac with Xcode.
2. New Xcode **App** project (SwiftUI lifecycle), bundle id e.g. `app.vocably`.
3. **Add `Packages/VocablyCore` as a local Swift package** dependency → it builds and its 113 tests run unchanged. (This is the entire "port" of the engine.)
4. Build `DesignSystem` from the tokens in `docs/IOS_BUILD_HANDOFF.md` §5 (asset-catalog colors light+dark, Fraunces/Inter fonts, components in §6).
5. Build each screen: a SwiftUI view + an `@Observable` view model that wraps the matching `Vocably*State` (e.g. `HomeViewModel { var state: HomeState }`). Logic is already tested — the view just binds + draws the Paper design (node IDs in handoff §11).
6. Add a SwiftData persistence layer conforming to `DeckRepository`/`ProfileRepository`/`ActivityRepository`; swap the JSON repo for it.
7. Replace mocks with live services (`AIService`→FoundationModels, `ScanService`→VisionKit DataScanner, `StoreService`→StoreKit 2, …).
8. System integrations, accessibility, localization, TestFlight (handoff §12–§14).

---

## Open decisions (confirm before the Mac phase — see handoff §16)

1. Min iOS **17** (AI gated) vs 18+.
2. CloudKit-only vs a custom backend (needed for leaderboards/social + server-LLM fallback).
3. AI: on-device FoundationModels + server fallback (hybrid) vs single server LLM.
4. Bundle Fraunces/Inter vs SF Pro for UI + Fraunces display only.
5. **Payments must use StoreKit/IAP** — the custom card-form checkout screen (`1DN-0`) is a visual reference only, not the real payment path (App Store rule).
6. Canonical variants: Home `1-0`, Swipe `3H-0` recommended.

---

## Optional remaining Windows work

- **Vapor `AIProxy` backend** (server-LLM fallback + leaderboards). Note: Vapor's full stack is rough on Windows; build on Linux/macOS CI or treat as Mac-side.
- Engine hardening: "again" requeue within a session, JSON schema versioning, FSRS scheduler behind the existing `Scheduler` protocol.
