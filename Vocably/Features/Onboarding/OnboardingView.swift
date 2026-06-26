import SwiftUI
import Observation
import VocablyDomain
import VocablyPresentation
import VocablyServices

// 8-screen onboarding (HANDOFF §11): welcome → language → motivation → goal → level
// → paywall → all-set. Wraps the tested OnboardingFlowState + PaywallState — the view
// only collects taps and draws; gating/validation/profile-building live in the engine.
@MainActor @Observable
final class OnboardingModel {
    var state = OnboardingFlowState()
    var paywall = PaywallState(products: OnboardingModel.proProducts)
    var name = ""
    private(set) var purchasedPro = false

    private let profiles: any ProfileRepository
    init(profiles: any ProfileRepository) { self.profiles = profiles }

    static let proProducts = [
        SubscriptionProduct(id: "pro.yearly", displayName: "Yearly", formattedPrice: "$39.99", period: .yearly, hasFreeTrial: true),
        SubscriptionProduct(id: "pro.monthly", displayName: "Monthly", formattedPrice: "$6.99", period: .monthly, hasFreeTrial: false),
    ]

    var step: OnboardingFlowState.Step { state.step }
    var canAdvance: Bool {
        if state.step == .welcome { return !name.trimmingCharacters(in: .whitespaces).isEmpty }
        return state.canAdvance
    }

    func advance() { state.advance() }
    func back() { state.back() }

    // Simulated purchase. Real StoreKit (LiveStoreService, §7) plugs in behind StoreService later.
    func purchase() async {
        paywall.begin()
        try? await Task.sleep(for: .milliseconds(700))
        paywall.succeed()
        purchasedPro = true
        state.advance()   // → done / all-set
    }

    func skipPaywall() { state.advance() }

    /// Persist the assembled profile and report completion.
    func finish() async {
        let displayName = name.trimmingCharacters(in: .whitespaces)
        var profile = state.makeProfile(name: displayName) ?? UserProfile(name: displayName)
        profile.proEntitlement = purchasedPro
        try? await profiles.save(profile)
    }
}

struct OnboardingView: View {
    @State private var model: OnboardingModel
    let onComplete: () -> Void

    init(profiles: any ProfileRepository, onComplete: @escaping () -> Void) {
        _model = State(initialValue: OnboardingModel(profiles: profiles))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            (model.step == .welcome ? Color.vocably.primary : Color.vocably.background)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                if model.step != .welcome && model.step != .done {
                    topBar
                }
                content
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
                    .id(model.step)
            }
            .animation(.spring(response: 0.35), value: model.step)
        }
    }

    private var topBar: some View {
        HStack(spacing: Space.s3) {
            Button { model.back() } label: {
                Image(systemName: "chevron.left").font(.ui(17, .semibold)).foregroundStyle(Color.vocably.ink)
            }
            SegmentedProgress(fraction: model.state.progressFraction)
        }
        .padding(.horizontal, Space.s6).padding(.top, Space.s4).padding(.bottom, Space.s2)
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .welcome:    welcome
        case .language:   language
        case .motivation: motivation
        case .goal:       goal
        case .level:      level
        case .paywall:    paywall
        case .done:       allSet
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: Space.s5) {
            Spacer()
            Image(systemName: "leaf.fill").font(.system(size: 64)).foregroundStyle(Color.vocably.onPrimary)
            Text("Vocably").font(.display(48, .bold)).foregroundStyle(Color.vocably.onPrimary)
            Text("Learn any language, one word at a time.")
                .font(.ui(17)).foregroundStyle(Color.vocably.onPrimary.opacity(0.85))
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: Space.s2) {
                Text("WHAT SHOULD WE CALL YOU?")
                    .font(.ui(12, .semibold)).tracking(1.2)
                    .foregroundStyle(Color.vocably.onPrimary.opacity(0.7))
                TextField("", text: $model.name, prompt: Text("Your name").foregroundColor(Color.vocably.onPrimary.opacity(0.5)))
                    .textFieldStyle(.plain)
                    .font(.ui(18, .medium))
                    .foregroundStyle(Color.vocably.onPrimary)
                    .multilineTextAlignment(.center)
                    .padding(Space.s3)
                    .background(Color.vocably.onPrimary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            Button { model.advance() } label: {
                Text("Get started").font(.ui(17, .semibold))
                    .foregroundStyle(Color.vocably.primary)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Color.vocably.onPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.full, style: .continuous))
            }
            .opacity(model.canAdvance ? 1 : 0.5).disabled(!model.canAdvance)
        }
        .padding(.horizontal, Space.s6).padding(.bottom, Space.s8)
    }

    private var language: some View {
        stepScaffold(title: "Which language?", subtitle: "Pick the one you want to learn first.") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Space.s3) {
                ForEach(Language.catalog) { lang in
                    selectCard(selected: model.state.selectedLanguage?.code == lang.code) {
                        model.state.selectedLanguage = lang
                    } content: {
                        VStack(spacing: 4) {
                            Text(lang.nativeName).font(.display(20, .semibold)).foregroundStyle(Color.vocably.ink)
                            Text(lang.name).font(.ui(13)).foregroundStyle(Color.vocably.muted)
                            if let l = lang.learners {
                                Text(l).font(.ui(11)).foregroundStyle(Color.vocably.faint)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, Space.s2)
                    }
                }
            }
        }
    }

    private var motivation: some View {
        stepScaffold(title: "Why are you learning?", subtitle: "Choose all that apply.") {
            VStack(spacing: Space.s2) {
                ForEach(Motivation.allCases) { m in
                    OptionRow(title: m.title, subtitle: m.subtitle,
                              selected: model.state.motivations.contains(m),
                              multi: true) { model.state.toggle(m) }
                }
            }
        }
    }

    private var goal: some View {
        stepScaffold(title: "Your daily goal", subtitle: "You can change this anytime.") {
            VStack(spacing: Space.s2) {
                ForEach(DailyGoal.allCases) { g in
                    OptionRow(title: g.title, subtitle: g.subtitle,
                              selected: model.state.dailyGoal == g, multi: false,
                              badge: g == .recommended ? "Popular" : nil,
                              bars: barsFor(g)) { model.state.dailyGoal = g }
                }
            }
        }
    }

    private var level: some View {
        stepScaffold(title: "How much do you know?", subtitle: "We'll start you in the right place.") {
            VStack(spacing: Space.s2) {
                ForEach(ProficiencyLevel.allCases) { lvl in
                    OptionRow(title: lvl.title, subtitle: lvl.subtitle,
                              selected: model.state.level == lvl, multi: false,
                              bars: lvl.bars) { model.state.level = lvl }
                }
            }
        }
    }

    private var paywall: some View {
        VStack(spacing: Space.s4) {
            ScrollView {
                VStack(spacing: Space.s4) {
                    Image(systemName: "crown.fill").font(.system(size: 48)).foregroundStyle(Color.vocably.accent)
                    Text("Vocably Pro").font(.display(30, .semibold)).foregroundStyle(Color.vocably.ink)
                    VStack(alignment: .leading, spacing: Space.s2) {
                        feature("Unlimited AI-generated decks")
                        feature("Camera scan → instant cards")
                        feature("Offline study & sync across devices")
                        feature("Detailed progress & streak insights")
                    }
                    .padding(.vertical, Space.s2)
                    ForEach(model.paywall.products) { product in
                        PlanCard(product: product,
                                 selected: model.paywall.selectedProductID == product.id) {
                            model.paywall.select(product.id)
                        }
                    }
                }
                .padding(.horizontal, Space.s6).padding(.top, Space.s2)
            }
            VStack(spacing: Space.s2) {
                PrimaryButton(title: model.paywall.phase == .purchasing ? "Processing…" : model.paywall.ctaTitle,
                              systemImage: "sparkles") {
                    Task { await model.purchase() }
                }
                Button("Maybe later") { model.skipPaywall() }
                    .font(.ui(15)).foregroundStyle(Color.vocably.muted)
            }
            .padding(.horizontal, Space.s6).padding(.bottom, Space.s6)
        }
    }

    private var allSet: some View {
        VStack(spacing: Space.s5) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 76)).foregroundStyle(Color.vocably.primary)
            Text("You're all set, \(model.name)!").font(.display(28, .semibold))
                .foregroundStyle(Color.vocably.ink).multilineTextAlignment(.center)
            if let lang = model.state.selectedLanguage, let goal = model.state.dailyGoal {
                Text("Learning \(lang.name) · \(goal.minutes) min/day")
                    .font(.ui(16)).foregroundStyle(Color.vocably.muted)
            }
            Spacer()
            PrimaryButton(title: "Start learning") {
                Task { await model.finish(); onComplete() }
            }
            .padding(.horizontal, Space.s6).padding(.bottom, Space.s8)
        }
        .padding(.horizontal, Space.s6)
    }

    // MARK: Helpers

    private func stepScaffold<C: View>(title: String, subtitle: String, @ViewBuilder body: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            VStack(alignment: .leading, spacing: Space.s2) {
                Text(title).font(.display(28, .semibold)).foregroundStyle(Color.vocably.ink)
                Text(subtitle).font(.ui(15)).foregroundStyle(Color.vocably.muted)
            }
            .padding(.horizontal, Space.s6).padding(.top, Space.s4)
            ScrollView { body().padding(.horizontal, Space.s6).padding(.bottom, Space.s6) }
            PrimaryButton(title: "Continue") { model.advance() }
                .opacity(model.canAdvance ? 1 : 0.5).disabled(!model.canAdvance)
                .padding(.horizontal, Space.s6).padding(.bottom, Space.s6)
        }
    }

    private func selectCard<C: View>(selected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        Button(action: action) {
            content()
                .background(selected ? Color.vocably.primarySoft : Color.vocably.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(selected ? Color.vocably.primary : Color.vocably.line, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func feature(_ text: String) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.vocably.primary)
            Text(text).font(.ui(15)).foregroundStyle(Color.vocably.ink)
            Spacer()
        }
    }

    private func barsFor(_ g: DailyGoal) -> Int {
        switch g { case .casual: return 1; case .regular: return 2; case .serious: return 3; case .intense: return 4 }
    }
}

// MARK: - Onboarding components (§6)

struct SegmentedProgress: View {
    let fraction: Double
    private let segments = 6
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<segments, id: \.self) { i in
                Capsule()
                    .fill(Double(i + 1) / Double(segments) <= fraction + 0.001
                          ? Color.vocably.primary : Color.vocably.line)
                    .frame(height: 6)
            }
        }
    }
}

struct OptionRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    var multi: Bool = false
    var badge: String? = nil
    var bars: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Space.s2) {
                        Text(title).font(.ui(16, .semibold)).foregroundStyle(Color.vocably.ink)
                        if let badge {
                            Text(badge).font(.ui(11, .bold)).foregroundStyle(Color.vocably.accent)
                                .padding(.horizontal, Space.s2).padding(.vertical, 2)
                                .background(Color.vocably.accentSoft).clipShape(Capsule())
                        }
                    }
                    Text(subtitle).font(.ui(13)).foregroundStyle(Color.vocably.muted)
                }
                Spacer()
                if let bars {
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { i in
                            Capsule().fill(i < bars ? Color.vocably.primary : Color.vocably.line)
                                .frame(width: 4, height: 14)
                        }
                    }
                    .padding(.trailing, Space.s2)
                }
                ZStack {
                    Circle().stroke(selected ? Color.vocably.primary : Color.vocably.line, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if selected {
                        Circle().fill(Color.vocably.primary).frame(width: 24, height: 24)
                        Image(systemName: multi ? "checkmark" : "circle.fill")
                            .font(.system(size: multi ? 11 : 8, weight: .bold))
                            .foregroundStyle(Color.vocably.onPrimary)
                    }
                }
            }
            .padding(Space.s4)
            .background(selected ? Color.vocably.primarySoft : Color.vocably.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(selected ? Color.vocably.primary : Color.vocably.line, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}

struct PlanCard: View {
    let product: SubscriptionProduct
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s3) {
                ZStack {
                    Circle().stroke(selected ? Color.vocably.primary : Color.vocably.line, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if selected { Circle().fill(Color.vocably.primary).frame(width: 14, height: 14) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Space.s2) {
                        Text(product.displayName).font(.ui(16, .semibold)).foregroundStyle(Color.vocably.ink)
                        if product.hasFreeTrial {
                            Text("7-day free trial").font(.ui(11, .bold)).foregroundStyle(Color.vocably.primary)
                                .padding(.horizontal, Space.s2).padding(.vertical, 2)
                                .background(Color.vocably.primarySoft).clipShape(Capsule())
                        }
                    }
                    Text(product.period == .yearly ? "Billed yearly" : "Billed monthly")
                        .font(.ui(13)).foregroundStyle(Color.vocably.muted)
                }
                Spacer()
                Text(product.formattedPrice).font(.display(18, .semibold)).foregroundStyle(Color.vocably.ink)
            }
            .padding(Space.s4)
            .background(selected ? Color.vocably.primarySoft : Color.vocably.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(selected ? Color.vocably.primary : Color.vocably.line, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}
