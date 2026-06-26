import SwiftUI
import Charts
import Observation
import VocablyDomain
import SRSEngine
import VocablyServices

// Profile / Stats (HANDOFF §11, node NE-0): identity, level/XP ring, lifetime stats,
// a Swift Charts weekly activity chart, achievements, settings.
@MainActor @Observable
final class ProfileModel {
    private(set) var profile: UserProfile?
    private(set) var decks: [Deck] = []
    private(set) var activity: [DailyActivity] = []
    let achievements = Achievement.catalog

    private let repos: Repos
    init(repos: Repos) { self.repos = repos }

    func load() async {
        profile = (try? await repos.profiles.load()) ?? UserProfile()
        decks = (try? await repos.decks.allDecks()) ?? []
        activity = (try? await repos.activity.all()) ?? []
    }

    var levelProgress: (level: Int, intoLevel: Int, needed: Int, fraction: Double) {
        LevelCurve.progress(xp: profile?.xp ?? 0)
    }
    var totalWords: Int { decks.reduce(0) { $0 + $1.cards.count } }
    var masteredWords: Int { decks.reduce(0) { $0 + $1.masteredCount } }

    struct DayStat: Identifiable { let id = UUID(); let label: String; let count: Int; let isToday: Bool }

    /// Words reviewed per day for the last 7 calendar days.
    var weekStats: [DayStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let symbols = cal.veryShortWeekdaySymbols
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let count = activity.first { cal.isDate($0.date, inSameDayAs: day) }?.wordsReviewed ?? 0
            let idx = cal.component(.weekday, from: day) - 1
            return DayStat(label: symbols[idx], count: count, isToday: offset == 0)
        }
    }
}

struct ProfileView: View {
    @State private var model: ProfileModel
    init(repos: Repos) { _model = State(initialValue: ProfileModel(repos: repos)) }

    var body: some View {
        ZStack {
            Color.vocably.background.ignoresSafeArea()
            ScrollView {
                if let p = model.profile {
                    VStack(alignment: .leading, spacing: Space.s5) {
                        identity(p)
                        levelCard
                        statStrip(p)
                        activityChart
                        achievementsSection
                        settingsSection(p)
                    }
                    .padding(.horizontal, Space.s6).padding(.vertical, Space.s4)
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
        }
        .task { await model.load() }
    }

    // MARK: Sections

    private func identity(_ p: UserProfile) -> some View {
        HStack(spacing: Space.s4) {
            Circle().fill(Color.vocably.primary)
                .frame(width: 64, height: 64)
                .overlay(Text(p.avatarInitial.isEmpty ? "?" : p.avatarInitial)
                    .font(.display(28, .semibold)).foregroundStyle(Color.vocably.onPrimary))
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name.isEmpty ? "Learner" : p.name)
                    .font(.display(26, .semibold)).foregroundStyle(Color.vocably.ink)
                Text("Learning \(Language.named(p.learningLanguage)?.name ?? p.learningLanguage)")
                    .font(.ui(14)).foregroundStyle(Color.vocably.muted)
            }
            Spacer()
            if p.proEntitlement {
                Text("PRO").font(.ui(12, .bold)).foregroundStyle(Color.vocably.accent)
                    .padding(.horizontal, Space.s2).padding(.vertical, 4)
                    .background(Color.vocably.accentSoft).clipShape(Capsule())
            }
        }
    }

    private var levelCard: some View {
        let lp = model.levelProgress
        return SurfaceCard(bright: true) {
            HStack(spacing: Space.s5) {
                ZStack {
                    Circle().stroke(Color.vocably.line, lineWidth: 8).frame(width: 84, height: 84)
                    Circle().trim(from: 0, to: max(0.001, lp.fraction))
                        .stroke(Color.vocably.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 84, height: 84)
                    VStack(spacing: 0) {
                        Text("\(lp.level)").font(.display(26, .bold)).foregroundStyle(Color.vocably.ink)
                        Text("LVL").font(.ui(10, .semibold)).foregroundStyle(Color.vocably.muted)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(model.profile?.xp ?? 0) XP").font(.display(22, .semibold)).foregroundStyle(Color.vocably.ink)
                    Text("\(max(0, lp.needed - lp.intoLevel)) XP to level \(lp.level + 1)")
                        .font(.ui(13)).foregroundStyle(Color.vocably.muted)
                    ProgressBar(value: lp.fraction).padding(.top, 2)
                }
            }
        }
    }

    private func statStrip(_ p: UserProfile) -> some View {
        HStack(spacing: Space.s3) {
            stat("\(p.streakCount)", "Streak", "flame.fill", Color.vocably.accent)
            stat("\(p.bestStreak)", "Best", "trophy.fill", Color.vocably.primary)
            stat("\(model.totalWords)", "Words", "book.fill", Color.vocably.ink)
            stat("\(model.masteredWords)", "Mastered", "checkmark.seal.fill", Color.vocably.primary)
        }
    }

    private func stat(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        SurfaceCard {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.ui(15)).foregroundStyle(color)
                Text(value).font(.display(20, .semibold)).foregroundStyle(Color.vocably.ink)
                Text(label).font(.ui(11)).foregroundStyle(Color.vocably.muted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("This week").font(.display(20, .semibold)).foregroundStyle(Color.vocably.ink)
            SurfaceCard(bright: true) {
                Chart(model.weekStats) { day in
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Words", day.count),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(day.isToday ? Color.vocably.accent : Color.vocably.primary)
                    .cornerRadius(5)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 150)
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Achievements").font(.display(20, .semibold)).foregroundStyle(Color.vocably.ink)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Space.s3) {
                ForEach(model.achievements) { badge in
                    VStack(spacing: Space.s2) {
                        ZStack {
                            Circle().fill(badge.isEarned ? Color.vocably.primarySoft : Color.vocably.surface)
                                .frame(width: 56, height: 56)
                                .overlay(Circle().stroke(Color.vocably.line, lineWidth: badge.isEarned ? 0 : 1))
                            Image(systemName: badge.iconName)
                                .font(.title3)
                                .foregroundStyle(badge.isEarned ? Color.vocably.primary : Color.vocably.faint)
                        }
                        Text(badge.title).font(.ui(12)).foregroundStyle(badge.isEarned ? Color.vocably.ink : Color.vocably.faint)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(badge.isEarned ? 1 : 0.6)
                }
            }
        }
    }

    private func settingsSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Settings").font(.display(20, .semibold)).foregroundStyle(Color.vocably.ink)
            VStack(spacing: 0) {
                settingsRow("Daily goal", value: "\(p.dailyGoalMinutes) min", icon: "target")
                Divider().padding(.leading, Space.s10)
                settingsRow("Reminders", value: "Off", icon: "bell.fill")
                Divider().padding(.leading, Space.s10)
                settingsRow("Restore purchases", value: "", icon: "arrow.clockwise")
                Divider().padding(.leading, Space.s10)
                settingsRow("About Vocably", value: "v0.1", icon: "info.circle")
            }
            .background(Color.vocably.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Color.vocably.line, lineWidth: 1))
        }
    }

    private func settingsRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: Space.s3) {
            Image(systemName: icon).font(.ui(15)).foregroundStyle(Color.vocably.primary).frame(width: 24)
            Text(title).font(.ui(16)).foregroundStyle(Color.vocably.ink)
            Spacer()
            Text(value).font(.ui(14)).foregroundStyle(Color.vocably.muted)
            Image(systemName: "chevron.right").font(.ui(12)).foregroundStyle(Color.vocably.faint)
        }
        .padding(Space.s4)
    }
}
