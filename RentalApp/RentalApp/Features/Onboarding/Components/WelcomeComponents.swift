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

/// The main button: a glass capsule with Purr's paw. Tapped, liquid rises
/// inside it, the paw turns white, and then it calls `action`.
struct PawFillButton: View {

    let action: () -> Void

    @State private var level: CGFloat = 0
    @State private var isPressed = false
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: press) {
            ZStack {
                TimelineView(.animation(paused: reduceMotion || level == 0)) { context in
                    LiquidLevel(level: level, phase: context.date.timeIntervalSinceReferenceDate * 9)
                        .fill(LinearGradient(colors: [DS.Colors.brand, DS.Colors.accentEmber], startPoint: .leading, endPoint: .trailing))
                }
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(level > 0.55 ? Color.white : DS.Colors.brand)
                    .contentTransition(.symbolEffect(.replace))
                    // Waves while it waits to be pressed.
                    .symbolEffect(.wiggle.clockwise, options: .repeat(.periodic(delay: 2.2)), isActive: !isPressed && !reduceMotion)
            }
            .frame(width: 200, height: 62)
            .clipShape(.capsule)
            .contentShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(SquishStyle(scale: 0.94, cue: .press))
        .disabled(isPressed)
        .accessibilityLabel("Get started")
    }

    private func press() {
        guard !isPressed else { return }
        isPressed = true
        feedback?.play(.fill)
        let fill = reduceMotion ? 0.15 : 0.45
        withAnimation(.easeInOut(duration: fill)) { level = 1 }
        Task {
            try? await Task.sleep(for: .seconds(fill))
            action()
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
