import SwiftUI
import Translation

// Bridges Apple's Translation framework (iOS 18+) into the Add-Word flow. The framework's
// API is bound to SwiftUI's `.translationTask`, so this invisible view owns the session and
// reports the translation back. Lives behind `if #available(iOS 18)` so the app still targets 17.
// On first use iOS may prompt to download the language pack (the user's "must have the
// language downloaded" — same as the keyboard).
@available(iOS 18.0, *)
struct TranslationBridge: View {
    let term: String
    let from: String
    let to: String
    let onResult: (String) -> Void

    @State private var config: TranslationSession.Configuration?
    @State private var debounce: Task<Void, Never>?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(config) { session in
                let text = term.trimmingCharacters(in: .whitespaces)
                guard text.count >= 2 else { return }
                if let response = try? await session.translate(text) {
                    onResult(response.targetText)
                }
            }
            .onChange(of: term) { _, newValue in
                debounce?.cancel()
                guard newValue.trimmingCharacters(in: .whitespaces).count >= 2 else { return }
                debounce = Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    guard !Task.isCancelled else { return }
                    if config == nil {
                        config = .init(source: Locale.Language(identifier: from),
                                       target: Locale.Language(identifier: to))
                    } else {
                        config?.invalidate()
                    }
                }
            }
    }
}
