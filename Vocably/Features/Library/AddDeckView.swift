import SwiftUI
import VocablyDomain
import VocablyServices

// Create a new (empty) deck and pick its language pair: the word language and the
// translation language. Addresses "let me make a new deck and choose the languages".
struct AddDeckView: View {
    @Environment(\.dismiss) private var dismiss
    let repos: Repos
    var onCreated: () -> Void

    @State private var name = ""
    @State private var wordLanguage = "es"
    @State private var translationLanguage = "en"

    private var canCreate: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vocably.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s5) {
                        field("DECK NAME") {
                            TextField("e.g. Japanese basics", text: $name)
                                .font(.ui(18, .medium)).padding(Space.s3)
                                .background(Color.vocably.surfaceBright)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Color.vocably.line, lineWidth: 1))
                        }
                        languagePicker("WORD LANGUAGE", selection: $wordLanguage)
                        HStack { Spacer(); Image(systemName: "arrow.down").foregroundStyle(Color.vocably.faint); Spacer() }
                        languagePicker("TRANSLATION LANGUAGE", selection: $translationLanguage)
                    }
                    .padding(Space.s6)
                }
            }
            .navigationTitle("New deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { Task { await create() } }.bold().disabled(!canCreate)
                }
            }
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(label).font(.ui(12, .semibold)).tracking(1).foregroundStyle(Color.vocably.muted)
            content()
        }
    }

    private func languagePicker(_ label: String, selection: Binding<String>) -> some View {
        field(label) {
            Menu {
                ForEach(Language.catalog) { lang in
                    Button("\(lang.nativeName) — \(lang.name)") { selection.wrappedValue = lang.code }
                }
            } label: {
                HStack {
                    Text(Language.named(selection.wrappedValue).map { "\($0.nativeName) — \($0.name)" } ?? selection.wrappedValue)
                        .font(.ui(16, .medium)).foregroundStyle(Color.vocably.ink)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.ui(13)).foregroundStyle(Color.vocably.muted)
                }
                .padding(Space.s3)
                .background(Color.vocably.surfaceBright)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Color.vocably.line, lineWidth: 1))
            }
        }
    }

    private func create() async {
        let deck = Deck(
            name: name.trimmingCharacters(in: .whitespaces),
            languageCode: wordLanguage,
            translationLanguageCode: translationLanguage,
            source: .manual
        )
        try? await repos.decks.save(deck)
        onCreated()
        dismiss()
    }
}
