//
//  WelcomeComponents.swift
//  RentalApp (Purrperty)
//
//  Onboarding — The welcome screen's parts: drifting feature cards, the
//  paw button that fills with liquid, the terms chip and Purr's sleepy
//  sign-in pill. Picked from the Remotion studies (tools/motion).
//

import SwiftUI

// MARK: - Feature Cards

/// One thing Purrperty does, as a small card. Only shipped features:
/// whatever the welcome screen shows has to be true on day one.
struct WelcomeFeature: Identifiable, Sendable {
    let id: Int
    let symbol: String
    let title: String
    let detail: String
    let accent: DSAccent
    /// A person instead of an icon (a tenant's message).
    var initials: String? = nil

    static let all: [WelcomeFeature] = [
        WelcomeFeature(id: 0, symbol: "banknote", title: "Rent recorded", detail: "$2,150 · Unit 4B", accent: .mint),
        WelcomeFeature(id: 1, symbol: "wrench.and.screwdriver", title: "Repair booked", detail: "Thu 10 am · Leaky tap", accent: .blush),
        WelcomeFeature(id: 2, symbol: "calendar", title: "Lease renews", detail: "In 60 days · N1 ready", accent: .sky),
        WelcomeFeature(id: 3, symbol: "door.left.hand.open", title: "Unit 12 is vacant", detail: "Asking $2,400", accent: .gold),
        WelcomeFeature(id: 4, symbol: "bubble.left", title: "Amara O.", detail: "“Thanks, the tap is fixed!”", accent: .cherry, initials: "AO"),
        WelcomeFeature(id: 5, symbol: "chart.pie", title: "October rent", detail: "$18.4K of $22K in", accent: .mint),
        WelcomeFeature(id: 6, symbol: "clock", title: "Plumber arriving", detail: "In 25 min · Unit 4B", accent: .sky),
        WelcomeFeature(id: 7, symbol: "checkmark.circle", title: "Job accepted", detail: "Tri-City Plumbing", accent: .mint),
        WelcomeFeature(id: 8, symbol: "checkmark.shield", title: "Rent increase check", detail: "Within Ontario guideline", accent: .cherry),
    ]
}

struct WelcomeFeatureCard: View {

    let feature: WelcomeFeature

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                if let initials = feature.initials {
                    Circle().fill(feature.accent.tint)
                    Text(verbatim: initials)
                        .font(DS.Typography.brandFixed(12))
                        .foregroundStyle(feature.accent.ink)
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(feature.accent.tint)
                    Image(systemName: feature.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(feature.accent.ink)
                }
            }
            .frame(width: 31, height: 31)

            VStack(alignment: .leading, spacing: 1) {
                Text(feature.title)
                    .font(DS.Typography.brandFixed(13.5, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(feature.detail)
                    .font(DS.Typography.brandFixed(11.5, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(width: WelcomeFeatureMarquee.cardWidth, alignment: .leading)
        .background(DS.Colors.surfaceRaised.opacity(0.94), in: .rect(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }
}

/// An endless row of cards drifting sideways, Luma style. Decorative:
/// VoiceOver hears the summary on the welcome screen instead.
struct WelcomeFeatureMarquee: View {

    static let cardWidth: CGFloat = 200
    private static let step: CGFloat = cardWidth + 18

    let features: [WelcomeFeature]
    /// Points per second; negative drifts left.
    let speed: CGFloat
    var offset: CGFloat = 0
    var tilts: [Double] = [-3, 2.5, -1.5, 3, -2.5, 1.5]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(start)
            let loop = CGFloat(features.count) * Self.step
            ZStack(alignment: .topLeading) {
                ForEach(features.indices, id: \.self) { i in
                    let raw = CGFloat(i) * Self.step + offset + CGFloat(elapsed) * speed
                    let x = (raw.truncatingRemainder(dividingBy: loop) + loop).truncatingRemainder(dividingBy: loop) - Self.step
                    WelcomeFeatureCard(feature: features[i])
                        .rotationEffect(.degrees(tilts[i % tilts.count]))
                        .offset(x: x, y: i.isMultiple(of: 2) ? 0 : 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: 72)
        .accessibilityHidden(true)
    }
}

// MARK: - Background

/// Pastel light pooled in the corners, over the app background.
struct WelcomeBackground: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                DSAccent.blush.fill.opacity(0.16), .clear, DSAccent.gold.fill.opacity(0.22),
                .clear, .clear, .clear,
                DSAccent.gold.fill.opacity(0.22), .clear, DSAccent.blush.fill.opacity(0.14),
            ]
        )
        .background(DS.Colors.background)
        .ignoresSafeArea()
    }
}

// MARK: - Paw Button

/// Get started: hold the paw for a second and it fills with liquid. Let go
/// early and it drains, with a nudge to hold. Assistive technologies just
/// activate it.
struct PawHoldButton: View {

    @Binding var isHolding: Bool
    let action: () -> Void

    static let duration = 1.0

    @State private var level: CGFloat = 0
    @State private var isDone = false
    @State private var nudges = 0
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Capsule().fill(DS.Colors.surfaceRaised)
                // The words sit on the paper until the liquid reaches them.
                label(DS.Colors.brandInk)
                TimelineView(.animation(paused: reduceMotion || (!isHolding && !isDone))) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate * 9
                    LiquidLevel(level: level, phase: phase)
                        .fill(LinearGradient(colors: [DS.Colors.brand, DS.Colors.brandDeep], startPoint: .leading, endPoint: .trailing))
                        .overlay { label(DS.Colors.textOnBrand).mask { LiquidLevel(level: level, phase: phase) } }
                }
            }
            .frame(width: typeSize.isAccessibilitySize ? 320 : 248, height: typeSize.isAccessibilitySize ? 84 : 66)
            .clipShape(.capsule)
            .contentShape(.capsule)
            .shadow(color: DS.Colors.groundShadow, radius: 12, y: 7)
            .scaleEffect(isHolding && !reduceMotion ? 0.96 : 1)
            .animation(DS.Motion.snappy, value: isHolding)
            .shake(on: nudges)
            .onLongPressGesture(minimumDuration: Self.duration, maximumDistance: 80, perform: finish, onPressingChanged: pressing)
            .accessibilityElement()
            .accessibilityLabel("Get started")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { finish() }

            Text(nudges > 0 && !isHolding ? "Keep holding for a second" : "Press and hold")
                .font(DS.Typography.brand(.footnote))
                .foregroundStyle(DS.Colors.textSecondary)
                .contentTransition(.opacity)
                .accessibilityHidden(true)
        }
        .task(id: isHolding) { await rumble() }
    }

    private func label(_ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 26, weight: .bold))
                // Waves while it waits to be pressed.
                .symbolEffect(.wiggle.clockwise, options: .repeat(.periodic(delay: 2.2)), isActive: !isHolding && !isDone && !reduceMotion)
            Text("Get started")
                .font(DS.Typography.brand(22, weight: .semibold, relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 22)
    }

    private func pressing(_ down: Bool) {
        guard !isDone else { return }
        if down {
            feedback?.play(.press)
            isHolding = true
            withAnimation(.linear(duration: Self.duration)) { level = 1 }
        } else {
            isHolding = false
            withAnimation(DS.Motion.bouncy) {
                level = 0
                nudges += 1
            }
        }
    }

    private func finish() {
        guard !isDone else { return }
        isDone = true
        feedback?.play(.fill)
        withAnimation(.easeOut(duration: 0.12)) { level = 1 }
        isHolding = false
        action()
    }

    /// Felt building up under the finger.
    private func rumble() async {
        guard isHolding else { return }
        for pulse in 1...9 {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, isHolding else { return }
            feedback?.play(.charge(Float(pulse) / 9))
        }
    }
}


/// Liquid filling a shape from the bottom, its surface a moving wave.
private struct LiquidLevel: Shape {

    var level: CGFloat
    var phase: Double

    var animatableData: CGFloat {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard level > 0 else { return Path() }
        // Starts just below the bottom edge, so no wave shows until pressed.
        let surface = rect.maxY + 8 - level * (rect.height + 20)
        let amplitude = 3 * (1 - level * 0.6)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0...40 {
            let x = rect.minX + rect.width * CGFloat(i) / 40
            path.addLine(to: CGPoint(x: x, y: surface + sin(Double(i) / 3 + phase) * amplitude))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Terms

/// "By continuing you agree to our" and a glass chip that opens the
/// Terms of Service or the Privacy Policy.
struct WelcomeTermsChip: View {

    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(spacing: 6) {
            Text("By continuing you agree to our")
                .font(DS.Typography.brand(.footnote, weight: .regular))
                .foregroundStyle(DS.Colors.textSecondary)
            Menu {
                Link(LegalDocument.termsOfService.title, destination: LegalDocument.termsOfService.url())
                Link(LegalDocument.privacyPolicy.title, destination: LegalDocument.privacyPolicy.url())
            } label: {
                Label("Terms · Privacy", systemImage: "info.circle")
                    .font(DS.Typography.brand(.footnote))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .simultaneousGesture(TapGesture().onEnded { feedback?.play(.tap) })
            .accessibilityLabel("Terms of Service and Privacy Policy")
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Sign In

/// "Sign in" with a sleeping Purr, who wakes up and waves when tapped.
struct SleepyPurrSignInButton: View {

    let action: () -> Void

    @State private var isAwake = false
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            guard !isAwake else { return }
            isAwake = true
            feedback?.play(.purr)
            Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 380))
                action()
            }
        } label: {
            HStack(spacing: 7) {
                // Asleep with Zs drifting up; wakes into a greeting.
                PurrMascot(mood: isAwake ? .welcomeBack : .idleTimeout, size: 40, isInteractive: false)
                    .padding(-4)
                Text("Sign in")
                    .font(DS.Typography.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(DS.Colors.brandInk)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(SquishStyle(scale: 0.93))
        .accessibilityLabel("Sign in")
        .accessibilityHint("For people who already have an account")
    }
}
