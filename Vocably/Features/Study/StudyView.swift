import SwiftUI
import Observation
import VocablyDomain
import SRSEngine
import VocablyPresentation

// Wraps the tested `StudyScreenState` (which holds a StudySession and isn't Equatable).
// The view calls flip/swipe/rate/undo and re-reads the published values (MAC_DEV_GUIDE §3).
@MainActor @Observable
final class StudyModel {
    private var state: StudyScreenState
    private let startStreak: Int

    init(cards: [Card], streak: Int) {
        self.state = StudyScreenState(cards: cards)
        self.startStreak = streak
    }

    var face: StudyScreenState.Face { state.face }
    var currentCard: Card? { state.currentCard }
    var progressText: String { state.progressText }
    var progressFraction: Double { state.progressFraction }
    var isFinished: Bool { state.isFinished }

    func flip() { state.flip() }
    func reveal() { state.reveal() }
    func rate(_ rating: Rating) { state.rate(rating, now: .now) }
    func swipe(_ direction: SwipeDirection) { state.swipe(direction, now: .now) }
    func undo() { state.undo() }

    var result: StudySessionResult { state.result(now: .now) }

    var summary: SessionSummaryState {
        SessionSummaryState(result: state.result(now: .now), streakAfter: startStreak, newDueCount: 0)
    }
}

/// Identifiable wrapper so a study session can be presented via `.fullScreenCover(item:)`,
/// guaranteeing the StudyView is built with the real card list (not an empty initial value).
struct StudySessionCards: Identifiable {
    let id = UUID()
    let cards: [Card]
}

struct StudyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: StudyModel
    @State private var dragOffset: CGSize = .zero
    @State private var committed = false
    private let onCommit: ((StudySessionResult) async -> Void)?

    init(cards: [Card], streak: Int = 0, onCommit: ((StudySessionResult) async -> Void)? = nil) {
        _model = State(initialValue: StudyModel(cards: cards, streak: streak))
        self.onCommit = onCommit
    }

    var body: some View {
        ZStack {
            Color.vocably.background.ignoresSafeArea()
            if model.isFinished {
                SessionCompleteView(summary: model.summary) { dismiss() }
                    .task {
                        guard !committed else { return }
                        committed = true
                        await onCommit?(model.result)
                    }
            } else {
                studying
            }
        }
    }

    private var studying: some View {
        VStack(spacing: Space.s4) {
            topBar
            if let card = model.currentCard {
                Spacer()
                Flashcard(
                    term: card.term,
                    translation: card.translation,
                    ipa: card.ipa,
                    partOfSpeech: card.partOfSpeech,
                    example: model.face == .revealed ? card.example : nil,
                    revealed: model.face == .revealed
                )
                .padding(.horizontal, Space.s6)
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width) / 18))
                .overlay(swipeHint)
                .gesture(dragGesture)
                .onTapGesture { if model.face == .prompt { withAnimation(.spring) { model.reveal() } } }
                .animation(.spring(response: 0.3), value: dragOffset)
                Spacer()
                controls
            }
        }
        .padding(.vertical, Space.s5)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.ui(17, .semibold)).foregroundStyle(Color.vocably.muted)
            }
            ProgressBar(value: model.progressFraction).padding(.horizontal, Space.s3)
            Text(model.progressText).font(.ui(14, .semibold)).foregroundStyle(Color.vocably.muted)
        }
        .padding(.horizontal, Space.s6)
    }

    @ViewBuilder private var controls: some View {
        if model.face == .prompt {
            Button { withAnimation(.spring) { model.reveal() } } label: {
                Text("Show answer").font(.ui(17, .semibold))
                    .foregroundStyle(Color.vocably.onPrimary)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color.vocably.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.full, style: .continuous))
            }
            .padding(.horizontal, Space.s6)
        } else {
            // Two crisp choices — fastest effective review, no decorative icons.
            HStack(spacing: Space.s3) {
                rateButton("Again", Color.vocably.rose, .again)
                rateButton("Got it", Color.vocably.primary, .good)
            }
            .padding(.horizontal, Space.s6)
        }
    }

    private func rateButton(_ label: String, _ color: Color, _ rating: Rating) -> some View {
        Button {
            commit(direction: nil, rating: rating)
        } label: {
            Text(label).font(.ui(17, .semibold))
                .foregroundStyle(Color.vocably.onPrimary)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: Radius.full, style: .continuous))
        }
    }

    @ViewBuilder private var swipeHint: some View {
        if model.face == .revealed {
            HStack {
                badge("AGAIN", Color.vocably.rose, dragOffset.width < -40)
                Spacer()
                badge("GOT IT", Color.vocably.primary, dragOffset.width > 40)
            }
            .padding(Space.s6)
        }
    }

    private func badge(_ text: String, _ color: Color, _ visible: Bool) -> some View {
        Text(text).font(.ui(14, .bold)).foregroundStyle(.white)
            .padding(.horizontal, Space.s3).padding(.vertical, 6)
            .background(color).clipShape(Capsule())
            .opacity(visible ? 1 : 0)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in if model.face == .revealed { dragOffset = value.translation } }
            .onEnded { value in
                let threshold: CGFloat = 110
                if model.face == .revealed && value.translation.width > threshold {
                    commit(direction: .right, rating: nil)
                } else if model.face == .revealed && value.translation.width < -threshold {
                    commit(direction: .left, rating: nil)
                } else {
                    withAnimation(.spring) { dragOffset = .zero }
                }
            }
    }

    /// Throw the card off-screen, then apply the rating and reset for the next card.
    private func commit(direction: SwipeDirection?, rating: Rating?) {
        let goingRight = direction == .right || rating == .good || rating == .easy
        withAnimation(.spring(response: 0.28)) {
            dragOffset = CGSize(width: goingRight ? 600 : -600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let direction { model.swipe(direction) } else if let rating { model.rate(rating) }
            dragOffset = .zero
        }
    }
}

// Session Complete (§5 / node R1-0), bound to SessionSummaryState.
struct SessionCompleteView: View {
    let summary: SessionSummaryState
    let onDone: () -> Void
    @State private var pop = false

    var body: some View {
        VStack(spacing: Space.s6) {
            Spacer()
            Image(systemName: "medal.fill")
                .font(.system(size: 76))
                .foregroundStyle(Color.vocably.accent)
                .scaleEffect(pop ? 1 : 0.6)
            VStack(spacing: Space.s2) {
                Text(summary.headline).font(.display(28, .semibold)).foregroundStyle(Color.vocably.ink)
                Text(summary.subtitle).font(.ui(16)).foregroundStyle(Color.vocably.muted)
            }
            HStack(spacing: Space.s3) {
                stat("\(summary.reviewed)", "Reviewed")
                stat("\(summary.accuracyPercent)%", "Accuracy")
                stat("+\(summary.xpEarned)", "XP")
            }
            Spacer()
            PrimaryButton(title: "Keep going") { onDone() }
                .padding(.horizontal, Space.s6)
        }
        .padding(.vertical, Space.s8)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { pop = true } }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        SurfaceCard {
            VStack(spacing: 4) {
                Text(value).font(.display(24, .semibold)).foregroundStyle(Color.vocably.primary)
                Text(label).font(.ui(12)).foregroundStyle(Color.vocably.muted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
