import SwiftUI
import VocablyPresentation

// Reusable components (IOS_BUILD_HANDOFF §6). Built against the design tokens.

// MARK: - PrimaryButton

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s2) {
                Text(title).font(.ui(17, .semibold))
                if let systemImage { Image(systemName: systemImage) }
            }
            .foregroundStyle(Color.vocably.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.vocably.primary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.full, style: .continuous))
            .shadow(color: Color.vocably.primary.opacity(0.25), radius: 12, y: 6)
        }
        .opacity(enabled ? 1 : 0.5)
        .disabled(!enabled)
    }
}

// MARK: - SurfaceCard

struct SurfaceCard<Content: View>: View {
    var bright: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Space.s5)
            .background(bright ? Color.vocably.surfaceBright : Color.vocably.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(Color.vocably.line, lineWidth: 1)
            )
    }
}

// MARK: - ProgressBar

struct ProgressBar: View {
    let value: Double              // 0...1
    var tint: Color = Color.vocably.primary

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.vocably.line)
                Capsule().fill(tint)
                    .frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - StreakWeek (§6) — seven day-dots from HomeState.weekDots

struct StreakWeek: View {
    let dots: [HomeState.DayDot]
    let streak: Int

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack(spacing: Space.s2) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.vocably.accent)
                    Text("\(streak) day streak")
                        .font(.ui(15, .semibold)).foregroundStyle(Color.vocably.ink)
                }
                HStack(spacing: Space.s2) {
                    ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(fill(for: dot.mark))
                                    .frame(width: 30, height: 30)
                                if dot.mark == .today {
                                    Circle().stroke(Color.vocably.accent, lineWidth: 2)
                                        .frame(width: 30, height: 30)
                                }
                                if dot.mark == .done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.vocably.onPrimary)
                                }
                            }
                            Text(dot.letter)
                                .font(.ui(11)).foregroundStyle(Color.vocably.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func fill(for mark: HomeState.DayDot.Mark) -> Color {
        switch mark {
        case .done:   return Color.vocably.primary
        case .today:  return Color.vocably.accentSoft
        case .future: return Color.vocably.line
        }
    }
}

// MARK: - DeckRow (§6)

struct DeckRow: View {
    let name: String
    let subtitle: String
    let dueCount: Int
    let progress: Double
    var colorToken: String = "primary"

    private var markColor: Color {
        switch colorToken {
        case "accent": return Color.vocably.accent
        case "rose":   return Color.vocably.rose
        default:        return Color.vocably.primary
        }
    }

    var body: some View {
        SurfaceCard {
            HStack(spacing: Space.s4) {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(markColor.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(subtitle.prefix(2).uppercased())
                            .font(.ui(13, .bold)).foregroundStyle(markColor)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.ui(16, .semibold)).foregroundStyle(Color.vocably.ink)
                    Text(subtitle).font(.ui(13)).foregroundStyle(Color.vocably.muted)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.vocably.line, lineWidth: 4).frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: max(0.001, min(1, progress)))
                        .stroke(markColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 40, height: 40)
                    if dueCount > 0 {
                        Text("\(dueCount)").font(.ui(13, .bold)).foregroundStyle(Color.vocably.ink)
                    } else {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                            .foregroundStyle(markColor)
                    }
                }
            }
        }
    }
}

// MARK: - Flashcard (§6)

struct Flashcard: View {
    let term: String
    let translation: String
    let ipa: String?
    let partOfSpeech: String?
    let example: String?
    let revealed: Bool

    var body: some View {
        VStack(spacing: Space.s4) {
            if let partOfSpeech {
                Text(partOfSpeech)
                    .font(.ui(12, .semibold))
                    .foregroundStyle(Color.vocably.primary)
                    .padding(.horizontal, Space.s3).padding(.vertical, 6)
                    .background(Color.vocably.primarySoft)
                    .clipShape(Capsule())
            }
            Text(term)
                .font(.display(40, .semibold))
                .foregroundStyle(Color.vocably.ink)
                .multilineTextAlignment(.center)
            if let ipa {
                Text(ipa).font(.ui(15)).foregroundStyle(Color.vocably.muted)
            }
            if revealed {
                Divider().padding(.vertical, Space.s1)
                Text(translation)
                    .font(.display(26, .medium))
                    .foregroundStyle(Color.vocably.primary)
                    .multilineTextAlignment(.center)
                if let example, !example.isEmpty {
                    Text(example)
                        .font(.ui(15))
                        .italic()
                        .foregroundStyle(Color.vocably.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.s4)
                }
            } else {
                Text("Tap to reveal")
                    .font(.ui(13)).foregroundStyle(Color.vocably.faint)
                    .padding(.top, Space.s2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 360)
        .padding(Space.s6)
        .background(Color.vocably.surfaceBright)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(Color.vocably.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }
}
