# VocablyCore

The portable, UI-free heart of Vocably — **builds and tests on Windows, Linux, and macOS** with the open-source Swift toolchain. No Apple-only frameworks here, so the same code drops straight into the Xcode app later behind the live service implementations.

## Modules
| Target | What |
|---|---|
| `VocablyDomain` | Value types: `Card`, `Deck`, `Review`, `UserProfile`, `Rating`, drafts, subscription types |
| `SRSEngine` | `Scheduler` protocol + `SM2Scheduler` (SuperMemo SM-2) + `Mastery` + `DueQuery` |
| `VocablyServices` | Service **protocols** (`AIService`, `ScanService`, `TranslateService`, `SpeechService`, `StoreService`, `ReminderService`) + deterministic **mocks** |

## Run it on Windows
1. Install Swift — easiest is **swiftly**:
   - Get it from <https://www.swift.org/install/windows/> (swiftly installer), then:
     ```
     swiftly install latest
     ```
   - Or download the Windows toolchain `.exe` from swift.org and install.
2. Build & test:
   ```
   cd Packages/VocablyCore
   swift build
   swift test
   ```
   You should see all `SRSEngineTests`, `VocablyDomainTests`, and `VocablyServicesTests` pass.
3. IDE: **VS Code + the Swift extension** (SourceKit-LSP) gives autocomplete, build, and debugging.

## What's portable vs Mac-only
- ✅ **Here (any OS):** domain models, the SM-2 scheduler, service contracts + mocks, and their tests.
- 🍎 **Added on a Mac (Xcode):** SwiftUI `DesignSystem` + feature screens, the SwiftData persistence adapter for these structs, and the **live** services (FoundationModels, VisionKit DataScanner, Translation, AVSpeech, StoreKit 2, UserNotifications), plus widgets/Live Activities.

## How it maps to the app
- The swipe gestures in **Swipe Study** call `Rating.from(swipe:)`; buttons call `Rating(buttonLabel:)`.
- A review commit calls `SM2Scheduler.schedule(_:rating:now:)` → new `due`, `interval`, `ease`, `masteryLevel`.
- `Mastery.level` → the mastery dots in **Deck Detail**; `DueQuery.dueCount` → Home's "words due" and reminder scheduling.
- The Mac app's SwiftData `@Model`s wrap these structs (or convert to/from them) so persistence stays an Apple-only concern.

See `../../docs/IOS_BUILD_HANDOFF.md` for the full app spec.
