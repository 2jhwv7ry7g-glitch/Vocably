import SwiftUI
import PhotosUI
import Observation
import VocablyDomain
import VocablyServices

// Scan a vocab book (HANDOFF §11 node 5J-0). Pick/take a photo → OCR + layout parsing →
// editable pairs → save as a deck. On device a camera/document scan can feed the same parser.
@MainActor @Observable
final class ScanModel {
    var photoItem: PhotosPickerItem?
    private(set) var image: UIImage?
    private(set) var drafts: [CardDraft] = []
    private(set) var isProcessing = false
    var deckName = "Scanned words"
    var language = "es"
    private(set) var savedName: String?

    private let decks: any DeckRepository
    private let scanner = BookScanService()
    private let suggester: TagSuggester

    init(decks: any DeckRepository, suggester: TagSuggester = DictionaryTagSuggester()) {
        self.decks = decks
        self.suggester = suggester
    }

    func loadPicked() async {
        guard let photoItem,
              let data = try? await photoItem.loadTransferable(type: Data.self),
              let ui = UIImage(data: data) else { return }
        image = ui
        savedName = nil
        isProcessing = true
        drafts = await scanner.extractVocabulary(from: ui)
        isProcessing = false
    }

    func remove(_ draft: CardDraft) { drafts.removeAll { $0 == draft } }

    func save() async {
        guard !drafts.isEmpty else { return }
        let cards = drafts.map { d in
            Card(term: d.term, translation: d.translation, example: d.example,
                 tags: suggester.suggestions(term: d.term, translation: d.translation, existing: []),
                 source: .scan)
        }
        let name = deckName.trimmingCharacters(in: .whitespaces).isEmpty ? "Scanned words" : deckName
        let deck = Deck(name: name, languageCode: language, level: "",
                        colorTokenName: "rose", source: .scan, cards: cards)
        try? await decks.save(deck)
        savedName = name
        drafts = []
        image = nil
    }
}

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ScanModel

    init(repos: Repos) { _model = State(initialValue: ScanModel(decks: repos.decks)) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vocably.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s4) {
                        intro
                        picker
                        if let image = model.image { preview(image) }
                        if model.isProcessing { processing }
                        if let name = model.savedName { saved(name) }
                        if !model.drafts.isEmpty { resultsSection }
                    }
                    .padding(Space.s6)
                }
            }
            .navigationTitle("Scan a book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
            .task(id: model.photoItem) { await model.loadPicked() }
        }
    }

    private var intro: some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "text.viewfinder").foregroundStyle(Color.vocably.primary)
            Text("Photograph a vocab list — Vocably reads the columns and pairs each word with its translation.")
                .font(.ui(14)).foregroundStyle(Color.vocably.muted)
        }
    }

    private var picker: some View {
        PhotosPicker(selection: $model.photoItem, matching: .images) {
            HStack(spacing: Space.s2) {
                Image(systemName: "photo.on.rectangle.angled")
                Text(model.image == nil ? "Choose a photo" : "Choose another photo").font(.ui(16, .semibold))
            }
            .foregroundStyle(Color.vocably.onPrimary)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(Color.vocably.primary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.full, style: .continuous))
        }
    }

    private func preview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable().scaledToFit()
            .frame(maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Color.vocably.line, lineWidth: 1))
    }

    private var processing: some View {
        HStack(spacing: Space.s3) { ProgressView(); Text("Reading the page…").font(.ui(15)).foregroundStyle(Color.vocably.muted) }
            .frame(maxWidth: .infinity).padding(.vertical, Space.s6)
    }

    private func saved(_ name: String) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.vocably.primary)
            Text("Saved “\(name)” to your decks").font(.ui(15, .semibold)).foregroundStyle(Color.vocably.ink)
        }
        .padding(Space.s4).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.vocably.primarySoft).clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("\(model.drafts.count) words found").font(.display(20, .semibold)).foregroundStyle(Color.vocably.ink)
            ForEach(Array(model.drafts.enumerated()), id: \.offset) { _, draft in
                SurfaceCard {
                    HStack(spacing: Space.s3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.term).font(.ui(16, .semibold)).foregroundStyle(Color.vocably.ink)
                            Text(draft.translation).font(.ui(14)).foregroundStyle(Color.vocably.muted)
                            if let ex = draft.example, !ex.isEmpty {
                                Text(ex).font(.ui(12)).italic().foregroundStyle(Color.vocably.faint)
                            }
                        }
                        Spacer()
                        Button { model.remove(draft) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.vocably.faint)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("DECK NAME").font(.ui(12, .semibold)).tracking(1).foregroundStyle(Color.vocably.muted)
                TextField("Deck name", text: $model.deckName)
                    .font(.ui(16)).padding(Space.s3)
                    .background(Color.vocably.surfaceBright)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Color.vocably.line, lineWidth: 1))
            }
            .padding(.top, Space.s2)
            PrimaryButton(title: "Save \(model.drafts.count) as a deck", systemImage: "tray.and.arrow.down") {
                Task { await model.save() }
            }
        }
    }
}
