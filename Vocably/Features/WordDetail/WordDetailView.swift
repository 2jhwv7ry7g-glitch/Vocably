import SwiftUI
import VocablyDomain
import VocablyServices

// Word Detail (HANDOFF §11, node AD-0): the term, pronunciation, meaning, examples,
// the AI memory hook, and tags. "Listen" speaks the term via the live SpeechService.
struct WordDetailView: View {
    let card: Card
    let languageCode: String
    var speech: SpeechService = LiveSpeechService()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vocably.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s5) {
                        headerCard
                        if let example = card.example, !example.isEmpty { exampleCard(example) }
                        if let hook = card.mnemonic, !hook.isEmpty { memoryHook(hook) }
                        if !card.tags.isEmpty { tagRow }
                    }
                    .padding(Space.s6)
                }
            }
            .navigationTitle("Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.term).font(.display(40, .semibold)).foregroundStyle(Color.vocably.ink)
                Spacer()
                Button { speech.speak(card.term, language: languageCode) } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3).foregroundStyle(Color.vocably.onPrimary)
                        .frame(width: 48, height: 48)
                        .background(Color.vocably.primary).clipShape(Circle())
                }
                .accessibilityLabel("Listen")
            }
            if let ipa = card.ipa, !ipa.isEmpty {
                Text(ipa).font(.ui(16)).foregroundStyle(Color.vocably.muted)
            }
            if let pos = card.partOfSpeech, !pos.isEmpty {
                Text(pos).font(.ui(13, .semibold)).foregroundStyle(Color.vocably.primary)
                    .padding(.horizontal, Space.s3).padding(.vertical, 5)
                    .background(Color.vocably.primarySoft).clipShape(Capsule())
            }
            Divider().padding(.vertical, Space.s1)
            Text(card.translation).font(.display(24, .medium)).foregroundStyle(Color.vocably.ink)
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.vocably.surfaceBright)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(Color.vocably.line, lineWidth: 1))
    }

    private func exampleCard(_ example: String) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("EXAMPLE").font(.ui(12, .semibold)).tracking(1).foregroundStyle(Color.vocably.muted)
                HStack(alignment: .top, spacing: Space.s2) {
                    Text(example).font(.ui(16)).italic().foregroundStyle(Color.vocably.ink)
                    Spacer(minLength: 0)
                    Button { speech.speak(example, language: languageCode) } label: {
                        Image(systemName: "speaker.wave.2").foregroundStyle(Color.vocably.primary)
                    }
                }
                if let t = card.exampleTranslation, !t.isEmpty {
                    Text(t).font(.ui(14)).foregroundStyle(Color.vocably.muted)
                }
            }
        }
    }

    private func memoryHook(_ hook: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                Image(systemName: "sparkles").foregroundStyle(Color.vocably.accent)
                Text("AI memory hook").font(.ui(13, .semibold)).foregroundStyle(Color.vocably.accent)
            }
            Text(hook).font(.ui(15)).foregroundStyle(Color.vocably.ink)
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.vocably.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private var tagRow: some View {
        FlowLayout(spacing: Space.s2) {
            ForEach(card.tags, id: \.self) { tag in
                Text(tag).font(.ui(12, .semibold)).foregroundStyle(Color.vocably.primary)
                    .padding(.horizontal, Space.s3).padding(.vertical, 5)
                    .background(Color.vocably.primarySoft).clipShape(Capsule())
            }
        }
    }
}
