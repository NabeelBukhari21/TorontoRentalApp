//
//  OnboardingSceneParts.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Smaller parts of the scene: the progress tube, the main
//  button, the build pills, the unlock list, and the plain page used at
//  accessibility text sizes and in landscape.
//

import SwiftUI

extension Array {
    /// Split into rows, the last one possibly shorter.
    func rows(of size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

// MARK: - Progress

/// Progress as liquid in a tube.
struct OnboardingProgressTube: View {
    let progress: Double
    let label: String
    let fill: Color
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(track)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(fill.shadow(.inner(color: .white.opacity(0.5), radius: 2, y: 2)))
                        .frame(width: max(14, proxy.size.width * progress))
                }
        }
        .frame(height: 12)
        .animation(DS.Motion.bouncy, value: progress)
        .accessibilityElement()
        .accessibilityLabel("Setup progress")
        .accessibilityValue(label)
    }
}

// MARK: - Main Button

/// The step's single main action. One button for the whole flow: its
/// words and colour change, its place doesn't. On sign-up, Apple and
/// Google join it.
struct OnboardingActions: View {

    let viewModel: OnboardingFlowViewModel
    let onSignedUp: (SignInOutcome) -> Void
    let onRefused: () -> Void
    let endEditing: () -> Void

    @Environment(\.feedback) private var feedback

    @Environment(\.dynamicTypeSize) private var typeSize
    private var isSignUp: Bool { viewModel.step == .signUp }
    private var isHidden: Bool { viewModel.step == .building }
    private var title: String { isSignUp ? "Create account" : viewModel.continueTitle }

    private var kind: SakugaButton.Kind {
        switch viewModel.step.staging {
        case .counter: isSignUp ? .primary : .dark
        case .giant: .plain
        case .orbit: .primary
        }
    }

    /// The burst is for the moments that matter; the rest get whiskers.
    private var isBig: Bool { [.personalize, .unlocked, .signUp].contains(viewModel.step) }

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            if isSignUp {
                HStack(spacing: 12) {
                    OnboardingSocialButton(provider: .apple) { signIn(with: .apple) }
                    OnboardingSocialButton(provider: .google) { signIn(with: .google) }
                }
                .transition(.scale.combined(with: .opacity))
            }
            SakugaButton(
                title: title, kind: kind, impact: isBig ? .full : .light,
                symbol: "chevron.forward", isLoading: viewModel.auth.isLoading, action: perform
            )
            .disabled(!viewModel.canContinue)
            .jelly(on: viewModel.canContinue)
        }
        .padding(.horizontal, 16)
        .animation(DS.Motion.bouncy, value: viewModel.canContinue)
        .offset(y: isHidden ? 140 : 0)
        .opacity(isHidden ? 0 : 1)
        .accessibilityHidden(isHidden)
    }

    private func perform() {
        guard isSignUp else { return viewModel.advance() }
        endEditing()
        Task {
            finish(await viewModel.signUp())
        }
    }

    private func finish(_ outcome: SignInOutcome?) {
        if let outcome {
            feedback?.play(.celebrate)
            onSignedUp(outcome)
        } else {
            feedback?.play(.error)
            onRefused()
        }
    }

    private func signIn(with provider: SocialProvider) {
        endEditing()
        Task {
            finish(await viewModel.signIn(with: provider))
        }
    }
}

// MARK: - Building

struct OnboardingBuildPill: View {
    let task: OnboardingBuildTask

    var body: some View {
        HStack(spacing: 8) {
            switch task.state {
            case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(DSAccent.mint.ink).transition(.scale)
            case .running: ProgressView()
            case .pending: EmptyView()
            }
            Text(task.title)
        }
        .font(DS.Typography.brand(18, weight: .semibold, relativeTo: .headline))
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(.horizontal, 18)
        .frame(minHeight: 46)
        .background(Capsule().fill(.clay(DS.Colors.surfaceRaised, shade: DSAccent.blush.ink, size: 46)))
        .shadow(color: DS.Colors.groundShadow, radius: 10, y: 8)
        .scaleEffect(task.state == .running ? 1.05 : 1)
        .opacity(task.state == .pending ? 0.6 : 1)
        .jelly(on: task.state == .done)
        .accessibilityElement(children: .combine)
        .accessibilityValue(task.state == .done ? "Done" : task.state == .running ? "In progress" : "Waiting")
    }
}

// MARK: - Unlocks

/// What the answers switched on, dealt in one by one.
struct OnboardingUnlockList: View {
    let unlocks: [OnboardingUnlock]
    @State private var shown = 0
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(unlocks.enumerated()), id: \.element.id) { index, unlock in
                HStack(spacing: 14) {
                    ClayToken(symbol: unlock.icon, accent: [.gold, .mint, .sky, .cherry, .blush][index % 5], size: 50)
                        .shadow(color: DS.Colors.groundShadow, radius: 5, y: 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(unlock.title)
                            .font(DS.Typography.brand(18, weight: .semibold, relativeTo: .headline))
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(unlock.detail)
                            .font(DS.Typography.brand(.footnote, weight: .regular))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(DS.Colors.surface))
                .accessibilityElement(children: .combine)
                .scaleEffect(index < shown || reduceMotion ? 1 : 0.8)
                .opacity(index < shown ? 1 : 0)
                .offset(y: index < shown || reduceMotion ? 0 : 30)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(650))
            for count in 1...max(unlocks.count, 1) {
                withAnimation(DS.Motion.bouncy) { shown = count }
                if !unlocks.isEmpty { feedback?.play(.deal(count - 1)) }
                try? await Task.sleep(for: .milliseconds(110))
            }
        }
    }
}

/// The unlocks in a deck that plainly scrolls: how many there are, the
/// next card fading out of view, and a paw that says how many are left.
struct OnboardingUnlockDeck: View {

    let unlocks: [OnboardingUnlock]

    @State private var position = ScrollPosition(edge: .top)
    @State private var below: CGFloat = 0
    @State private var contentHeight: CGFloat = 1
    @State private var hasScrolled = false
    @State private var bounce = false
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Extent: Equatable {
        let below, content: CGFloat
    }

    /// Cards not fully on screen yet.
    private var remaining: Int {
        guard below > 14, !unlocks.isEmpty else { return 0 }
        return min(unlocks.count, max(1, Int((below / (contentHeight / CGFloat(unlocks.count))).rounded(.up))))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill").accessibilityHidden(true)
                Text("^[\(unlocks.count) thing](inflect: true) unlocked")
                Spacer(minLength: 0)
            }
            .font(DS.Typography.brand(.subheadline, weight: .semibold))
            .foregroundStyle(DS.Colors.brandInk)
            .accessibilityElement(children: .combine)

            ScrollView {
                OnboardingUnlockList(unlocks: unlocks)
                    .padding(.bottom, 12)
            }
            .scrollPosition($position)
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: Extent.self) {
                Extent(below: $0.contentSize.height - $0.visibleRect.maxY, content: $0.contentSize.height)
            } action: { _, extent in
                below = extent.below
                contentHeight = max(extent.content, 1)
            }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { hasScrolled = true }
            }
            .containerRelativeFrame(.vertical) { height, _ in height * 0.28 }
            .mask {
                // The last visible card fades, so there's clearly more.
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .black.opacity(remaining > 0 ? 0.08 : 1)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 56)
                }
            }
            .overlay(alignment: .bottom) {
                if remaining > 0 { moreChip.transition(.scale.combined(with: .opacity)) }
            }
        }
        .animation(DS.Motion.bouncy, value: remaining)
        .task { await nudge() }
    }

    private var moreChip: some View {
        Button {
            hasScrolled = true
            feedback?.play(.tap)
            withAnimation(DS.Motion.smooth) { position.scrollTo(edge: .bottom) }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "pawprint.fill")
                Text("\(remaining) more")
                    .contentTransition(.numericText(value: Double(remaining)))
                Image(systemName: "chevron.down")
                    .offset(y: bounce ? 3 : -1)
            }
            .font(DS.Typography.brand(.subheadline, weight: .semibold))
            .foregroundStyle(DS.Colors.textOnBrand)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(Capsule().fill(.clay(DS.Colors.brand, shade: DS.Colors.brandDeep, size: 40)))
            .shadow(color: DS.Colors.groundShadow, radius: 8, y: 5)
        }
        .buttonStyle(SquishStyle(scale: 0.93))
        .offset(y: 6)
        .accessibilityLabel("Show \(remaining) more")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { bounce = true }
        }
    }

    /// Once dealt, the deck slides up a little and back, unless it's
    /// already been moved.
    private func nudge() async {
        try? await Task.sleep(for: .seconds(2.2))
        guard !reduceMotion, !hasScrolled, remaining > 0, !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.45)) { position.scrollTo(y: 46) }
        try? await Task.sleep(for: .milliseconds(520))
        guard !hasScrolled, !Task.isCancelled else { return }
        withAnimation(DS.Motion.bouncy) { position.scrollTo(y: 0) }
    }
}

// MARK: - Plain Page

/// The same step as a scrolling page, where the scene wouldn't fit: at
/// accessibility text sizes and in landscape.
struct OnboardingPlainPage<Actions: View>: View {

    let viewModel: OnboardingFlowViewModel
    let mood: PurrMood
    var focus: FocusState<OnboardingField?>.Binding
    let onSignIn: () -> Void
    let actions: Actions

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    if viewModel.step.allowsBack {
                        Button("Back", systemImage: "chevron.backward") { viewModel.goBack() }
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                            .buttonStyle(SquishStyle())
                    }
                    OnboardingProgressTube(progress: viewModel.progress, label: viewModel.stepLabel, fill: DS.Colors.brand, track: DS.Colors.track)
                }
                PurrMascot(mood: mood, size: 150)
                Text(viewModel.sceneTitle)
                    .font(DS.Typography.brand(34))
                    .accessibilityAddTraits(.isHeader)
                if !viewModel.sceneLine.isEmpty {
                    Text(viewModel.sceneLine).font(DS.Typography.brand(.body, weight: .regular)).foregroundStyle(DS.Colors.textSecondary)
                }
                content
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .id(viewModel.step)
            .transition(.opacity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DS.Colors.background)
        .safeAreaInset(edge: .bottom) {
            if viewModel.step != .building {
                actions
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(DS.Colors.background)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.step {
        case .building:
            ForEach(viewModel.buildTasks) { OnboardingBuildPill(task: $0) }
        case .unlocked:
            OnboardingUnlockList(unlocks: viewModel.profile.unlocks).multilineTextAlignment(.leading)
        case .signUp:
            OnboardingSignUpForm(auth: viewModel.auth, focus: focus, onSignIn: onSignIn)
        default:
            VStack(spacing: 12) {
                ForEach(viewModel.choices) { OnboardingAnswerCard(choice: $0) }
            }
            .multilineTextAlignment(.leading)
        }
    }
}
