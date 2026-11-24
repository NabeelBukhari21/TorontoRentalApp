//
//  OnboardingStudioKit.swift
//  RentalApp (Purrperty)
//
//  Onboarding studio — The pieces the three 1.3–1.11 directions share: a
//  big, lit Purr, clay props that float in depth, a liquid backdrop and
//  the answers as one uniform list. DEBUG builds only.
//

#if DEBUG
import SwiftUI

// MARK: - Content

/// One answer on a question screen, whatever the question.
struct StudioChoice: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let accent: DSAccent
    let isSelected: Bool
    let select: () -> Void
}

extension OnboardingFlowViewModel {

    var studioChoices: [StudioChoice] {
        switch step {
        case .persona:
            zip(OnboardingPersona.allCases, [DSAccent.gold, .sky, .mint]).map { item, accent in
                StudioChoice(id: item.id, title: item.title, subtitle: item.subtitle, symbol: item.icon, accent: accent,
                             isSelected: profile.persona == item) { self.select(item) }
            }
        case .units:
            zip(OnboardingUnitRange.allCases, [DSAccent.mint, .sky, .gold, .cherry]).map { item, accent in
                StudioChoice(id: item.id, title: item.title, subtitle: item.subtitle, symbol: item.icon, accent: accent,
                             isSelected: profile.unitRange == item) { self.select(item) }
            }
        case .headaches:
            zip(OnboardingHeadache.allCases, [DSAccent.mint, .cherry, .sky, .gold, .blush]).map { item, accent in
                StudioChoice(id: item.id, title: item.title, subtitle: "", symbol: item.icon, accent: accent,
                             isSelected: profile.headaches.contains(item)) { self.toggle(item) }
            }
        case .goal:
            zip(OnboardingGoal.allCases, [DSAccent.sky, .mint, .cherry]).map { item, accent in
                StudioChoice(id: item.id, title: item.title, subtitle: item.subtitle, symbol: item.icon, accent: accent,
                             isSelected: profile.goal == item) { self.select(item) }
            }
        case .personalize:
            zip(AppTheme.allCases, [DSAccent.blush, .gold, .sky]).map { item, accent in
                StudioChoice(id: item.id, title: item == .system ? "Automatic" : item.rawValue,
                             subtitle: item == .system ? "Match iPhone" : item == .light ? "Bright days" : "Cosy nights",
                             symbol: item.icon, accent: accent,
                             isSelected: theme == item) { self.theme = item }
            }
        default: []
        }
    }

    /// Purr acts out the answer itself, not just the fact of answering.
    var studioMood: PurrMood {
        switch step {
        case .persona:
            switch profile.persona {
            case nil: .assistantThinking
            case .landlord: .keysReady
            case .propertyManager: .superhero
            case .tenant: .moveInDay
            }
        case .units:
            switch profile.unitRange {
            case nil: .assistantThinking
            case .one: .favourited
            case .twoToFive: .keysReady
            case .sixToTwenty: .fullyOccupied
            case .twentyPlus: .royalWave
            }
        case .headaches:
            if profile.headaches.isEmpty { .begging }
            else if profile.headaches.count > 2 { .tantrum }
            else if profile.headaches.contains(.repairs) { .urgentIssue }
            else if profile.headaches.contains(.lateRent) { .rentOverdue }
            else if profile.headaches.contains(.paperwork) { .documents }
            else if profile.headaches.contains(.tenantMessages) { .newMessage }
            else { .vacancy }
        case .goal:
            switch profile.goal {
            case nil: .assistantIdea
            case .saveTime: .meditate
            case .getPaidOnTime: .moneyDance
            case .fewerVacancies: .victoryLap
            }
        case .personalize:
            switch theme {
            case .system: .appearance
            case .light: .goodMorning
            case .dark: .stargazing
            }
        case .building: .builder
        case .unlocked: .partyTime
        case .signUp:
            if auth.password.isEmpty { .signUp }
            else if auth.passwordRequirements.allSatisfy(\.isMet) { .signUpDone }
            else { .passwordHidden }
        default: .welcome
        }
    }

    var studioTitle: String {
        switch step {
        case .building: "Building your Purrperty"
        case .unlocked: "Look what you unlocked!"
        case .signUp: "Keep it safe with me"
        default: question
        }
    }

    var studioLine: String {
        switch step {
        case .building: "This takes a few seconds."
        case .unlocked, .signUp: profile.goal?.outcome ?? "Save your setup so it's here every time."
        default: mascotLine
        }
    }

    /// Each step has its own colour; the backdrop morphs between them.
    var studioAccent: DSAccent {
        switch step {
        case .persona: .gold
        case .units: .sky
        case .headaches: .blush
        case .goal: .mint
        case .personalize: theme == .dark ? .sky : .gold
        case .building: .blush
        case .unlocked: .gold
        default: .blush
        }
    }

    /// The props drifting around Purr on each step.
    var studioProps: [String] {
        switch step {
        case .persona: ["key.fill", "house.fill", "questionmark"]
        case .units: ["building.2.fill", "house.fill", "door.left.hand.closed"]
        case .headaches: ["dollarsign", "wrench.and.screwdriver.fill", "doc.text.fill"]
        case .goal: ["clock.fill", "star.fill", "chart.line.uptrend.xyaxis"]
        case .personalize: theme == .dark ? ["moon.fill", "star.fill", "sparkles"] : ["sun.max.fill", "cloud.fill", "paintbrush.fill"]
        case .building: ["hammer.fill", "gearshape.fill", "house.fill"]
        case .unlocked: ["star.fill", "sparkles", "trophy.fill"]
        default: ["lock.fill", "heart.fill", "envelope.fill"]
        }
    }
}

// MARK: - Depth

extension EnvironmentValues {
    /// How far the scene is tilted, in points. Front layers move most.
    @Entry var sceneTilt: CGSize = .zero
}

/// Floats a layer: it bobs on its own and shifts with the scene's tilt.
/// Negative depths sit behind Purr and move against it.
private struct FloatInDepth: ViewModifier {
    let depth: Double
    let phase: Double
    let bob: Double
    @Environment(\.sceneTilt) private var tilt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            content
                .rotationEffect(.degrees(sin(t * 0.9 + phase) * 4 * bob))
                .offset(
                    x: tilt.width * depth + (reduceMotion ? 0 : sin(t * 0.7 + phase) * 5 * bob),
                    y: tilt.height * depth + (reduceMotion ? 0 : cos(t * 1.1 + phase) * 7 * bob)
                )
        }
    }
}

extension View {
    func floating(depth: Double, phase: Double = 0, bob: Double = 1) -> some View {
        modifier(FloatInDepth(depth: depth, phase: phase, bob: bob))
    }
}

/// Dragging anywhere tilts the scene; letting go springs it back.
struct TiltScene<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var tilt: CGSize = .zero

    var body: some View {
        content
            .environment(\.sceneTilt, tilt)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        tilt = CGSize(width: max(-30, min(30, value.translation.width / 5)),
                                      height: max(-20, min(20, value.translation.height / 8)))
                    }
                    .onEnded { _ in withAnimation(.spring(response: 0.6, dampingFraction: 0.45)) { tilt = .zero } }
            )
    }
}

// MARK: - Purr

/// Purr, big and lit: a contact shadow under his feet, a soft one thrown
/// behind him, and a slight turn with the scene.
struct LitPurr: View {
    let mood: PurrMood
    var size: CGFloat
    var showsFloor = true
    var shadow: Color = DS.Colors.groundShadow

    @Environment(\.sceneTilt) private var tilt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if showsFloor {
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let breath = reduceMotion ? 0 : sin(context.date.timeIntervalSinceReferenceDate * 2.2) * 0.04
                    ZStack {
                        Ellipse().fill(shadow.opacity(0.75))
                            .frame(width: size * 0.66, height: size * 0.12)
                            .blur(radius: size * 0.035)
                            .offset(x: size * 0.06, y: size * 0.47)
                        Ellipse().fill(shadow)
                            .frame(width: size * 0.42 * (1 - breath), height: size * 0.055)
                            .blur(radius: size * 0.012)
                            .offset(y: size * 0.465)
                    }
                }
            }
            PurrMascot(mood: mood, size: size, surprisesOnTap: true)
                // Thrown on whatever is behind him.
                .shadow(color: shadow, radius: size * 0.03, x: size * 0.035, y: size * 0.045)
                .rotation3DEffect(.degrees(tilt.width * 0.5), axis: (0, 1, 0))
                .offset(x: tilt.width * 0.35, y: tilt.height * 0.2)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Clay

extension ShapeStyle where Self == AnyShapeStyle {
    /// A soft moulded surface: lit from the top left, shaded below.
    static func clay(_ color: Color, shade: Color, size: CGFloat) -> AnyShapeStyle {
        AnyShapeStyle(
            color
                .shadow(.inner(color: .white.opacity(0.6), radius: size * 0.05, x: size * 0.03, y: size * 0.05))
                .shadow(.inner(color: shade.opacity(0.45), radius: size * 0.08, x: -size * 0.03, y: -size * 0.07))
        )
    }
}

/// A moulded icon, like a soft toy of the thing.
struct ClayToken: View {
    let symbol: String
    let accent: DSAccent
    var size: CGFloat = 64

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
            .fill(.clay(accent.fill, shade: accent.ink, size: size))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(accent.onFill)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Backdrop

/// Slow liquid: wobbling blobs that fuse where they touch.
struct LiquidBlobs: View {
    struct Blob { let x: Double, y: Double, r: Double, phase: Double }
    let color: Color
    let blobs: [Blob]
    var amount = 0.05
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                canvas.liquidLayer(color: color, blur: 14) { layer in
                    for blob in blobs {
                        let c = CGPoint(x: blob.x * size.width + sin(t * 0.5 + blob.phase) * 10,
                                        y: blob.y * size.height + cos(t * 0.6 + blob.phase) * 10)
                        layer.fill(.wobblyCircle(center: c, radius: blob.r * size.width, time: t * 0.6 + blob.phase, amount: amount), with: .color(.black))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Chrome

/// Back, and progress as liquid in a tube.
struct StudioTopBar: View {
    let viewModel: OnboardingFlowViewModel
    var ink: Color = DS.Colors.textPrimary
    var fill: Color = DS.Colors.brand
    var track: Color = DS.Colors.track

    var body: some View {
        HStack(spacing: 14) {
            Button { viewModel.goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ink)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .opacity(viewModel.step.allowsBack ? 1 : 0)
            .accessibilityLabel("Back")

            GeometryReader { proxy in
                Capsule().fill(track)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(fill.shadow(.inner(color: .white.opacity(0.5), radius: 2, y: 2)))
                            .frame(width: max(14, proxy.size.width * viewModel.progress))
                    }
            }
            .frame(height: 12)
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: viewModel.progress)
            .accessibilityElement()
            .accessibilityLabel("Setup progress")
            .accessibilityValue(viewModel.stepLabel)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
    }
}

/// A key-like button: a face on a darker edge that sinks when pressed.
struct PressableDepthStyle: ButtonStyle {
    var edge: Color
    var depth: CGFloat = 6
    var shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? depth : 0)
            .background(shape.fill(edge).offset(y: depth))
            .contentShape(shape)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

/// The next arrow, on its own.
struct StudioNextButton: View {
    let viewModel: OnboardingFlowViewModel
    var title: String? = nil
    var background: Color = DS.Colors.brand
    var edge: Color = DS.Colors.brandDeep
    var ink: Color = DS.Colors.textOnBrand

    var body: some View {
        Button { viewModel.advance() } label: {
            HStack(spacing: 8) {
                Text(title ?? viewModel.continueTitle)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .heavy))
            }
            .font(DS.Typography.brand(20, weight: .semibold, relativeTo: .headline))
            .foregroundStyle(ink)
            .padding(.horizontal, 34)
            .frame(height: 58)
            .background(Capsule().fill(.clay(background, shade: edge, size: 58)))
        }
        .buttonStyle(PressableDepthStyle(edge: edge))
        .shadow(color: DS.Colors.groundShadow, radius: 14, y: 12)
        .saturation(viewModel.canContinue ? 1 : 0)
        .opacity(viewModel.canContinue ? 1 : 0.55)
        .disabled(!viewModel.canContinue)
    }
}

/// Apple and Google, as two round buttons.
struct StudioSocialButtons: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(["apple.logo", "g.circle.fill"], id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(.clay(DS.Colors.surfaceRaised, shade: DS.Colors.textTertiary, size: 54)))
                    .shadow(color: DS.Colors.groundShadow, radius: 8, y: 5)
                    .accessibilityLabel(symbol == "apple.logo" ? "Continue with Apple" : "Continue with Google")
            }
        }
    }
}

/// Name, email and password, sharing one look.
struct StudioSignUpFields: View {
    @Bindable var auth: AuthViewModel
    var background: Color = DS.Colors.surface

    var body: some View {
        VStack(spacing: 10) {
            row("person.fill") { TextField("Name", text: $auth.name).textContentType(.name) }
            row("envelope.fill") { TextField("Email", text: $auth.email).textContentType(.emailAddress).textInputAutocapitalization(.never) }
            row("lock.fill") { SecureField("Password", text: $auth.password).textContentType(.newPassword) }
            HStack(spacing: 8) {
                ForEach(auth.passwordRequirements) { requirement in
                    HStack(spacing: 4) {
                        Image(systemName: requirement.isMet ? "checkmark.circle.fill" : "circle")
                            .contentTransition(.symbolEffect(.replace))
                        Text(shortTitle(requirement.rule)).lineLimit(1)
                    }
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(requirement.isMet ? DSAccent.mint.ink : DS.Colors.textSecondary)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(Capsule().fill(requirement.isMet ? DSAccent.mint.fill.opacity(0.2) : background))
                    .scaleEffect(requirement.isMet ? 1.04 : 1)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: auth.password)
        }
    }

    private func shortTitle(_ rule: PasswordRequirement.Rule) -> String {
        switch rule {
        case .length: "8+ characters"
        case .letter: "A letter"
        case .number: "A number"
        }
    }

    private func row(_ symbol: String, @ViewBuilder field: () -> some View) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(DS.Colors.brandInk).frame(width: 24)
            field().font(.system(.body, design: .rounded, weight: .medium))
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(background.shadow(.inner(color: DS.Colors.groundShadow.opacity(0.5), radius: 3, y: 2))))
    }
}

extension Array where Element == StudioChoice {
    /// Split into rows, the last one possibly shorter.
    func rows(of size: Int) -> [[StudioChoice]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

// MARK: - Entrances

extension AnyTransition {
    /// Pops up out of the floor, one after another.
    static func popIn(_ index: Int) -> AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.4, anchor: .bottom).combined(with: .opacity)
                .animation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.15 + Double(index) * 0.06)),
            removal: .opacity.animation(.easeOut(duration: 0.15))
        )
    }
}
#endif
