//
//  OnboardingScene.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Every step after the cover, as one continuous scene. Purr,
//  the progress tube and the main button stay on screen the whole way;
//  between steps Purr glides to his next place, the next colour spreads
//  out as a drop of liquid, and only the words and answers change.
//
//  Three stagings (`OnboardingStaging`): a counter Purr stands behind, a
//  giant Purr under the answers, and answers orbiting him as bubbles.
//  At accessibility text sizes and in landscape the same content is a
//  plain scrolling page instead (`OnboardingPlainPage`).
//

import SwiftUI

struct OnboardingScene: View {

    @Bindable var viewModel: OnboardingFlowViewModel
    let onSignedUp: (SignInOutcome) -> Void
    let onSignIn: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.feedback) private var feedback

    /// Measured heights, per step, so Purr can fill what's left.
    @State private var topHeights: [OnboardingStep: CGFloat] = [:]
    @State private var counterHeights: [OnboardingStep: CGFloat] = [:]
    /// The step whose arrival has finished.
    @State private var settledStep: OnboardingStep?
    @State private var sceneHeight: CGFloat = 800
    @State private var hasEntered = false
    @State private var reaction: PurrMood?
    /// Sign-ups refused so far; each one shakes the form.
    @State private var refusals = 0
    @FocusState private var focus: OnboardingField?
    @AccessibilityFocusState private var titleIsFocused: Bool

    private var step: OnboardingStep { viewModel.step }
    private var staging: OnboardingStaging { step.staging }
    /// The keyboard is up and has taken most of the room.
    private var isTyping: Bool { focus != nil && sceneHeight < 620 }
    private var isFlooded: Bool { viewModel.buildLevel > 0.9 }
    private var usesPlainPage: Bool { typeSize.isAccessibilitySize || verticalSizeClass == .compact }

    var body: some View {
        Group {
            if usesPlainPage {
                OnboardingPlainPage(viewModel: viewModel, mood: mood, focus: $focus, onSignIn: onSignIn, actions: actions)
            } else {
                TiltScene {
                    GeometryReader { proxy in scene(proxy.size) }
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { sceneHeight = $0 }
                }
                .background { backdrop }
            }
        }
        .modifier(OnboardingCues(viewModel: viewModel, focus: focus))
        .task(id: step) {
            titleIsFocused = true
            reaction = nil
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { settledStep = step }
        }
        .onAppear { withAnimation(DS.Motion.scene) { hasEntered = true } }
    }

    // MARK: - Purr's mood

    private var mood: PurrMood {
        if let reaction { return reaction }
        guard step == .signUp else { return viewModel.mascotMood }
        let auth = viewModel.auth
        if auth.formError != nil { return .loginFailed }
        if !auth.name.isEmpty, auth.emailLooksValid, auth.passwordRequirements.allSatisfy(\.isMet) { return .signUpDone }
        switch focus {
        case .password: return .passwordHidden
        case .name, .email: return .loginTyping
        case nil: return .signUp
        }
    }

    private func tickle() {
        feedback?.play(.purr)
        guard reaction == nil, let move = PurrMood.signatureMoves.randomElement() else { return }
        reaction = move
        Task {
            try? await Task.sleep(for: .seconds(3))
            reaction = nil
        }
    }

    // MARK: - Scene

    private var buildProgress: Double {
        let total = Double(max(viewModel.buildTasks.count, 1))
        let done = Double(viewModel.buildTasks.count { $0.state == .done })
        return viewModel.buildTasks.isEmpty ? 0 : min(1, (done + 0.35) / total)
    }

    private static let barHeight: CGFloat = 44
    /// Room the main button takes at the bottom.
    private static let buttonRoom: CGFloat = 84

    private func scene(_ size: CGSize) -> some View {
        let purr = placement(in: size)
        return ZStack(alignment: .top) {
            if staging == .orbit {
                LiquidPool(accent: viewModel.look.accent, feet: CGPoint(x: size.width / 2, y: purr.center.y + purr.size * 0.455), targets: poolTargets(in: size))
                    .transition(.opacity)
            }

            VStack(spacing: 8) {
                topBar
                top
            }

            behindPurr(size, purr)

            LivingPurr(mood: mood, size: purr.size, showsFloor: staging != .giant, beat: step)
                .position(x: purr.center.x, y: hasEntered ? purr.center.y : size.height + purr.size)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : DS.Motion.scene, value: purr)
            Circle().fill(.clear)
                .frame(width: purr.size * 0.36)
                .contentShape(.circle)
                .onTapGesture(perform: tickle)
                .position(purr.center)
                .accessibilityHidden(true)

            inFrontOfPurr(size, purr)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if staging == .counter, hasEntered { counter }
            }

            VStack {
                Spacer(minLength: 0)
                actions
            }
            .padding(.bottom, 10)
        }
        .frame(width: size.width, height: size.height)
    }

    private var backdrop: some View {
        ZStack {
            LiquidBackdrop(look: viewModel.look, origin: spreadOrigin)
            TimelineView(.animation(paused: step != .building || reduceMotion)) { context in
                LiquidWave(level: viewModel.buildLevel, phase: context.date.timeIntervalSinceReferenceDate * 3)
                    .fill(LinearGradient(colors: [DS.Colors.brand, DS.Colors.brandDeep], startPoint: .top, endPoint: .bottom))
            }
            .opacity(step == .building || step == .unlocked ? 1 : 0)
            .animation(.spring(response: 0.9, dampingFraction: 0.8), value: viewModel.buildLevel)
            if step == .unlocked {
                SunRays(color: DSAccent.gold.fill, center: UnitPoint(x: 0.5, y: 0.36))
                    .transition(.opacity.animation(.easeOut(duration: 0.8).delay(0.4)))
            }
        }
        .ignoresSafeArea()
    }

    /// Where the next colour comes from: the button going on, the Back
    /// button going back, and the picked bubble when the theme changes.
    private var spreadOrigin: UnitPoint {
        if step == .personalize, settledStep == .personalize,
           let index = viewModel.choices.firstIndex(where: \.isSelected) {
            let spot = spots[index]
            return UnitPoint(x: spot.x, y: 0.2 + spot.y * 0.6)
        }
        return viewModel.movesForward ? UnitPoint(x: 0.5, y: 0.92) : UnitPoint(x: 0.1, y: 0.1)
    }

    // MARK: - Where Purr stands

    private struct Placement: Equatable {
        let size: CGFloat
        let center: CGPoint
    }

    /// In the rig's square canvas his ears start 19% down, his chin is at
    /// 66% and his feet at 97%.
    private func placement(in size: CGSize) -> Placement {
        let width = min(size.width, 480)
        let top = Self.barHeight + 8 + (topHeights[step] ?? 90)
        let side: CGFloat
        let y: CGFloat

        switch staging {
        case .counter:
            let edge = size.height - (counterHeights[step] ?? 330)
            if isTyping {
                side = min(max((edge - top) / 0.36, 170), 300)
                y = edge - side * 0.55
            } else {
                // His happy hop on sign-up needs more headroom.
                let headroom: CGFloat = step == .signUp ? 30 : 14
                side = min(max((edge - top - headroom) / 0.61, 170), width * 1.1)
                y = max(top + headroom - side * 0.19, edge - side * 0.9)
            }
        case .giant where step == .building:
            side = min((size.height + 30 - top) / 0.78, width * 1.6)
            y = size.height + 30 - side * 0.97
        case .giant:
            let chin = size.height - Self.buttonRoom + 4
            side = min(max((chin - top) / 0.47, 240), width * 1.6)
            y = chin - side * 0.66
        case .orbit:
            let room = size.height - Self.buttonRoom - top
            side = min(width * 1.1, room * 0.8)
            y = top + room * 0.54 - side / 2
        }
        return Placement(size: side, center: CGPoint(x: size.width / 2, y: y + side / 2))
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { viewModel.goBack() } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(topInk)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(SquishStyle(scale: 0.86))
            .opacity(step.allowsBack ? 1 : 0)
            .disabled(!step.allowsBack)
            .accessibilityLabel("Back")

            OnboardingProgressTube(progress: viewModel.progress, label: viewModel.stepLabel,
                                   fill: staging == .giant ? topInk : DS.Colors.brand,
                                   track: staging == .giant ? Color.white.opacity(0.5) : DS.Colors.track)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 560)
        .frame(height: Self.barHeight)
    }

    private var topInk: Color {
        guard staging == .giant else { return DS.Colors.textPrimary }
        return isFlooded ? DS.Colors.textOnBrand : DS.Colors.textOnAccent
    }

    /// The words, and on giant-Purr steps the content above his ears. On
    /// the old and new step at once while one replaces the other.
    private var top: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 14) {
                if !(isTyping && step == .signUp) { words }
                if staging == .giant { giantContent }
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { [step] in topHeights[step] = $0 }
            .id(step)
            .transition(.drift)
        }
        .frame(maxWidth: 520)
    }

    private var words: some View {
        VStack(spacing: staging == .orbit ? 8 : 4) {
            Text(viewModel.sceneTitle)
                .font(DS.Typography.brand(36, weight: .bold))
                .lineLimit(step == .signUp ? 1 : 2)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleIsFocused)
            if !viewModel.sceneLine.isEmpty {
                Text(viewModel.sceneLine)
                    .font(DS.Typography.brand(.subheadline))
                    .contentTransition(.opacity)
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(GlassLine(isOn: staging == .orbit))
            }
        }
        .foregroundStyle(topInk)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22)
    }

    @ViewBuilder private var giantContent: some View {
        if step == .building {
            VStack(spacing: 10) {
                ForEach(Array(viewModel.buildTasks.enumerated()), id: \.element.id) { index, task in
                    OnboardingBuildPill(task: task)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -3 : 3))
                        .offset(x: index.isMultiple(of: 2) ? -18 : 18)
                }
                SakugaProgress(value: buildProgress, showsLabel: false)
                    .padding(.horizontal, 44)
                    .padding(.top, 48)
            }
        } else {
            VStack(spacing: 18) {
                ForEach(viewModel.choices.rows(of: 3), id: \.first?.id) { row in
                    HStack(spacing: 12) {
                        ForEach(row) { OnboardingAnswerKey(choice: $0) }
                    }
                    .padding(.horizontal, row.count < 3 ? 56 : 0)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Around Purr

    /// Where each bubble floats: across the screen, and down the space
    /// between the words and the button.
    private struct Spot { let x: Double, y: Double, diameter: CGFloat, isInFront: Bool }

    private let spots = [
        Spot(x: 0.16, y: 0.15, diameter: 116, isInFront: false),
        Spot(x: 0.83, y: 0.42, diameter: 128, isInFront: true),
        Spot(x: 0.26, y: 0.80, diameter: 138, isInFront: true),
    ]

    private func point(_ index: Int, in size: CGSize) -> CGPoint {
        let top = Self.barHeight + 8 + (topHeights[step] ?? 90)
        let room = size.height - Self.buttonRoom - top
        let width = min(size.width, 480)
        return CGPoint(x: size.width / 2 + (spots[index].x - 0.5) * width, y: top + spots[index].y * room)
    }

    private func poolTargets(in size: CGSize) -> [LiquidPool.Target] {
        viewModel.choices.enumerated().compactMap { index, choice in
            guard choice.isSelected, index < spots.count else { return nil }
            return .init(id: choice.id, point: point(index, in: size), radius: spots[index].diameter / 2, color: choice.accent.fill)
        }
    }

    @ViewBuilder
    private func bubbles(_ size: CGSize, inFront: Bool) -> some View {
        if staging == .orbit {
            ForEach(Array(viewModel.choices.enumerated()), id: \.element.id) { index, choice in
                if index < spots.count, spots[index].isInFront == inFront {
                    OnboardingAnswerBubble(choice: choice, diameter: spots[index].diameter)
                        .floating(depth: inFront ? 1 : -0.4, phase: Double(index) * 1.7, bob: inFront ? 1 : 0.7)
                        .position(point(index, in: size))
                        .transition(.bubble(index))
                }
            }
        }
    }

    private func behindPurr(_ size: CGSize, _ purr: Placement) -> some View {
        ZStack {
            bubbles(size, inFront: false)
            if step.props.count > 1, step != .signUp, hasEntered {
                let spread = min(size.width, 480) / 2
                let scale = min(1, purr.size / 340)
                ZStack {
                    prop(step.props[1], .blush, 66 * scale)
                        .blur(radius: 1.2)
                        .floating(depth: -0.5, phase: 1)
                        .position(x: size.width / 2 - spread + 40, y: purr.center.y - purr.size * 0.14)
                    prop(step.props[0], .gold, 80 * scale)
                        .floating(depth: -0.3, phase: 3)
                        .position(x: size.width / 2 + spread - 44, y: purr.center.y - purr.size * 0.22)
                }
                .id(step)
                .transition(.bubble(0))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func inFrontOfPurr(_ size: CGSize, _ purr: Placement) -> some View {
        ZStack {
            bubbles(size, inFront: true)
            let edge = size.height - (counterHeights[step] ?? 330)
            // Only where they leave his face clear.
            if step == .signUp, !isTyping, purr.size > 300 {
                ZStack {
                    sticker(viewModel.profile.persona == .tenant ? "Your landlord can invite you" : "Your answers are saved", .sky, tilt: 4)
                        .floating(depth: 0.9, phase: 1, bob: 0.5)
                        .position(x: size.width * 0.75, y: edge - 64)
                    sticker("Free to start, no card needed", .gold, tilt: -3)
                        .floating(depth: 1.1, phase: 3, bob: 0.5)
                        .position(x: size.width * 0.36, y: edge - 30)
                }
                .transition(.bubble(1))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func prop(_ symbol: String, _ accent: DSAccent, _ size: CGFloat) -> some View {
        ClayToken(symbol: symbol, accent: accent, size: size)
            .shadow(color: DS.Colors.groundShadow, radius: 9, y: 9)
    }

    private func sticker(_ text: String, _ accent: DSAccent, tilt: Double) -> some View {
        Text(text)
            .font(DS.Typography.brand(15, weight: .semibold, relativeTo: .footnote))
            .foregroundStyle(accent.onFill)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(.clay(accent.fill, shade: accent.ink, size: 36)))
            .shadow(color: DS.Colors.groundShadow, radius: 7, y: 6)
            .rotationEffect(.degrees(tilt))
            .fixedSize()
    }

    // MARK: - Counter

    /// Stays up between counter steps; only what's on it changes.
    private var counter: some View {
        ZStack(alignment: .top) {
            counterContent
                .id(step)
                .transition(.drift)
        }
        .shake(on: refusals)
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, Self.buttonRoom + 10)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38, style: .continuous)
                .fill(DS.Colors.background)
                .shadow(color: DS.Colors.groundShadow, radius: 22, y: -10)
                .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            if step.props.count > 2, !isTyping, step != .signUp {
                // On the counter's edge, nearest to us.
                prop(step.props[2], .sky, 60)
                    .floating(depth: 1.2, phase: 5, bob: 0.6)
                    .offset(x: -22, y: -42)
                    .id(step)
                    .transition(.bubble(2))
            }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { [step] in counterHeights[step] = $0 }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder private var counterContent: some View {
        switch step {
        case .signUp:
            OnboardingSignUpForm(auth: viewModel.auth, focus: $focus, onSignIn: onSignIn)
        case .unlocked:
            ScrollView {
                OnboardingUnlockList(unlocks: viewModel.profile.unlocks)
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .containerRelativeFrame(.vertical) { height, _ in height * 0.29 }
        default:
            let choices = viewModel.choices
            VStack(spacing: 12) {
                ForEach(choices.rows(of: choices.count > 3 ? 2 : 1), id: \.first?.id) { row in
                    HStack(spacing: 12) {
                        ForEach(row) { OnboardingAnswerCard(choice: $0, isCompact: choices.count > 3) }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        OnboardingActions(viewModel: viewModel, onSignedUp: onSignedUp, onRefused: { refusals += 1 }) { focus = nil }
    }
}

// MARK: - Cues

/// What the scene sounds and feels like: moving between steps, answering,
/// the build, the password rules.
private struct OnboardingCues: ViewModifier {

    let viewModel: OnboardingFlowViewModel
    let focus: OnboardingField?

    @Environment(\.feedback) private var feedback

    /// The answers of one step, so a change of step isn't heard as answers.
    private struct Answers: Equatable {
        let step: OnboardingStep
        let picked: [Bool]
    }

    private var answers: Answers { Answers(step: viewModel.step, picked: viewModel.choices.map(\.isSelected)) }
    private var tasksDone: Int { viewModel.buildTasks.count { $0.state == .done } }
    private var rulesMet: Int { viewModel.auth.passwordRequirements.count { $0.isMet } }

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.step) { _, step in
                feedback?.play(step == .unlocked ? .celebrate : viewModel.movesForward ? .advance : .back)
            }
            .onChange(of: answers) { old, new in
                guard old.step == new.step, old.picked.count == new.picked.count else { return }
                if let index = new.picked.indices.first(where: { new.picked[$0] && !old.picked[$0] }) {
                    feedback?.play(.select(index))
                } else if old != new {
                    feedback?.play(.deselect)
                }
            }
            .onChange(of: tasksDone) { old, new in
                guard new > old else { return }
                feedback?.play(new == viewModel.buildTasks.count ? .flood : .taskDone(new - 1))
            }
            .onChange(of: rulesMet) { old, new in
                if new > old { feedback?.play(.tick) }
            }
            .onChange(of: focus) { _, field in
                if field != nil { feedback?.play(.focus) }
            }
    }
}

// MARK: - Transitions

/// Words and answers blur away upward, and the next rise into focus.
struct DriftTransition: Transition {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity || reduceMotion ? 0 : 10)
            .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.96)
            .offset(y: reduceMotion ? 0 : phase == .willAppear ? 22 : phase == .didDisappear ? -16 : 0)
    }
}

extension AnyTransition {
    static var drift: AnyTransition {
        .asymmetric(
            insertion: AnyTransition(DriftTransition()).animation(DS.Motion.scene.delay(0.16)),
            removal: AnyTransition(DriftTransition()).animation(.easeIn(duration: 0.2))
        )
    }

    /// Swells in one after another, and shrinks away together.
    static func bubble(_ index: Int) -> AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.3).combined(with: .opacity)
                .animation(DS.Motion.bouncy.delay(0.25 + Double(index) * DS.Motion.staggerStep)),
            removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeIn(duration: 0.2))
        )
    }
}

private struct GlassLine: ViewModifier {
    let isOn: Bool
    func body(content: Content) -> some View {
        if isOn {
            content
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
        } else {
            content
        }
    }
}
