//
//  OnboardingCoverSteps.swift
//  RentalApp (Purrperty)
//
//  Onboarding — The two full-screen steps before the questions: the
//  welcome (the name, drifting feature cards, the paw button) and the
//  fly-over video of the app at work.
//

import AVFoundation
import Combine
import SwiftUI

// MARK: - Welcome

struct OnboardingWelcomeStep: View {

    let onStart: () -> Void
    let onSignIn: () -> Void

    @State private var buttonFrame: CGRect = .zero
    @State private var flood: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var features: [WelcomeFeature] { WelcomeFeature.all }

    var body: some View {
        ZStack {
            WelcomeBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 64)
                if !typeSize.isAccessibilitySize {
                    // Three cards per row fill the loop, and no card shows
                    // twice on screen at once.
                    VStack(spacing: 30) {
                        WelcomeFeatureMarquee(features: Array(features[0...2]), speed: -30)
                        WelcomeFeatureMarquee(features: Array(features[3...5]), speed: -20, offset: 100)
                    }
                }
                Spacer(minLength: 20)
                brand
                Spacer(minLength: 20)
                if !typeSize.isAccessibilitySize {
                    WelcomeFeatureMarquee(features: Array(features[6...8]), speed: 26, offset: 40)
                }
                Spacer(minLength: 24)
                PawFillButton(action: start)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { buttonFrame = $0 }
                WelcomeTermsChip()
                    .padding(.top, 22)
                    .padding(.bottom, 8)
            }

            // The paw button's liquid floods the screen on the way out.
            if flood > 0 {
                Circle()
                    .fill(DS.Colors.brand)
                    .frame(width: 62, height: 62)
                    .scaleEffect(flood)
                    .position(x: buttonFrame.midX, y: buttonFrame.midY)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(.named(Self.space))
        .overlay(alignment: .topTrailing) {
            SleepyPurrSignInButton(action: onSignIn)
                .padding(.top, 8)
                .padding(.trailing, 16)
        }
    }

    private static let space = "welcome"

    private var brand: some View {
        VStack(spacing: 6) {
            PurrMascot(mood: .welcome, size: 168, surprisesOnTap: true)
            PurrpertyWordmark(fontSize: 52)
            Text("Every rental, under one paw.")
                .font(DS.Typography.brand(19, weight: .medium, relativeTo: .title3))
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Purrperty. Every rental, under one paw. Rent, repairs, leases and tenant messages in one place.")
        .accessibilityAddTraits(.isHeader)
    }

    private func start() {
        guard !reduceMotion else { return onStart() }
        // About 30 button-widths covers any phone from the button's centre.
        withAnimation(.easeIn(duration: 0.4)) { flood = 30 }
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            onStart()
        }
    }
}

// MARK: - Intro Fly-over

/// The fly-over: a drawn Toronto, a building opened floor by floor,
/// tenants and a vendor visit. Muted; skippable; moves on by itself at
/// the end. With Reduce Motion it shows the closing frame instead.
struct OnboardingIntroStep: View {

    let onFinished: (_ skipped: Bool) -> Void

    @State private var player = VideoClipPlayer(resource: "PurrIntroFlyover")
    @State private var didFinish = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The closing frame: Purr cheering over the name.
    private static let posterTime = CMTime(value: 255, timescale: 30)

    var body: some View {
        ZStack {
            DS.Colors.launchBackground.ignoresSafeArea()
            VideoClipSurface(player: player.player, gravity: .resizeAspectFill)
                .ignoresSafeArea()
                .accessibilityLabel("A map of Toronto tilts into 3D, a building opens floor by floor to show its units and tenants, then Purr cheers.")
        }
        .overlay(alignment: .topTrailing) {
            if !reduceMotion {
                Button { finish(skipped: true) } label: {
                    Text("Skip")
                        .font(DS.Typography.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(SquishStyle())
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
        }
        .overlay(alignment: .bottom) {
            if reduceMotion {
                PrimaryActionButton(title: "Continue") { finish(skipped: false) }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            guard player.isAvailable else { return finish(skipped: true) }
            if reduceMotion { player.hold(at: Self.posterTime) } else { player.playFromStart() }
        }
        .onDisappear { player.reset() }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: player.item)) { _ in
            player.didPlayToEnd()
            finish(skipped: false)
        }
    }

    private func finish(skipped: Bool) {
        guard !didFinish else { return }
        didFinish = true
        player.player.pause()
        onFinished(skipped)
    }
}

// MARK: - Previews

#Preview("Welcome") {
    OnboardingWelcomeStep(onStart: {}, onSignIn: {})
}

#Preview("Intro") {
    OnboardingIntroStep { _ in }
}
