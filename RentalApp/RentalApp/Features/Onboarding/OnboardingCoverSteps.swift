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

/// The fly-over: Toronto in 3D, live. Offline, and where there's no 3D
/// imagery, the drawn film plays instead; with Reduce Motion it shows that
/// film's closing frame. Skippable; moves on by itself at the end.
struct OnboardingIntroStep: View {

    let onFinished: (_ skipped: Bool) -> Void

    @State private var style = FlyoverChoice.current
    @State private var usesFilm = !FlyoverChoice.canFlyLive
    @State private var didFinish = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            DS.Colors.launchBackground.ignoresSafeArea()
            if usesFilm || reduceMotion {
                IntroFilm { finish(skipped: $0) }
            } else {
                LiveFlyover(style: style, onLanded: { finish(skipped: false) }, onUnavailable: { usesFilm = true })
                    .id(style)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !reduceMotion {
                Button { finish(skipped: true) } label: {
                    Text("Skip")
                        .font(DS.Typography.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(DS.Colors.surfaceRaised))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(SquishStyle())
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
        }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            if DebugLaunchOverride.isOnboardingOnly, !usesFilm, !reduceMotion { picker }
        }
        #endif
    }

    private func finish(skipped: Bool) {
        guard !didFinish else { return }
        didFinish = true
        onFinished(skipped)
    }

    #if DEBUG
    /// Test builds: the three flights, to choose from.
    private var picker: some View {
        HStack(spacing: 6) {
            ForEach(Array(zip(["A", "B", "C"], FlyoverStyle.allCases)), id: \.1) { letter, option in
                Button {
                    FlyoverChoice.current = option
                    style = option
                } label: {
                    Text(letter)
                        .font(DS.Typography.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(style == option ? DS.Colors.textOnBrand : DS.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(style == option ? DS.Colors.brand : DS.Colors.surfaceRaised))
                }
                .buttonStyle(SquishStyle())
                .accessibilityLabel("Flight \(letter)")
            }
        }
        .padding(.top, 8)
        .padding(.leading, 16)
    }
    #endif
}

/// Which flight plays, and whether this device can fly it.
@MainActor
enum FlyoverChoice {
    private static let key = "PurrpertyFlyover"

    static var current: FlyoverStyle {
        get {
            #if DEBUG
            UserDefaults.standard.string(forKey: key).flatMap(FlyoverStyle.init(rawValue:)) ?? .skyline
            #else
            .skyline
            #endif
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    /// The simulator has no 3D imagery, unless it's given rendered frames.
    static var canFlyLive: Bool {
        #if targetEnvironment(simulator)
        UserDefaults.standard.string(forKey: "PurrpertyFlyoverFrames") != nil
        #else
        true
        #endif
    }
}

/// The drawn film, with its short score.
private struct IntroFilm: View {

    let onFinished: (_ skipped: Bool) -> Void

    @State private var player = VideoClipPlayer(resource: "PurrIntroFlyover")
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The closing frame: Purr cheering over the name.
    private static let posterTime = CMTime(value: 255, timescale: 30)

    var body: some View {
        VideoClipSurface(player: player.player, gravity: .resizeAspectFill)
            .ignoresSafeArea()
            .accessibilityLabel("A map of Toronto tilts into 3D, a building opens floor by floor to show its units and tenants, then Purr cheers.")
            .overlay(alignment: .bottom) {
                if reduceMotion {
                    PrimaryActionButton(title: "Continue") { onFinished(false) }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
            .onAppear {
                guard player.isAvailable else { return onFinished(true) }
                if reduceMotion {
                    player.hold(at: Self.posterTime)
                } else {
                    player.playFromStart()
                    feedback?.startMusic("flyover")
                }
            }
            .onDisappear {
                player.reset()
                feedback?.stopMusic()
            }
            .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: player.item)) { _ in
                player.didPlayToEnd()
                onFinished(false)
            }
    }
}

// MARK: - Previews

#Preview("Welcome") {
    OnboardingWelcomeStep(onStart: {}, onSignIn: {})
}

#Preview("Intro") {
    OnboardingIntroStep { _ in }
}
