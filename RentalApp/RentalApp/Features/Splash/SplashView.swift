//
//  SplashView.swift
//  RentalApp
//
//  Splash — Orchestrates the launch sequence:
//  background fade → ring draw + logo reveal → wordmark rise →
//  tagline cascade → hold → hand off to onboarding.
//
//  Respects Reduce Motion with an instant, gentle fade instead.
//

import SwiftUI

struct SplashView: View {

    /// Called when the sequence completes — the parent advances the launch flow.
    let onFinished: () -> Void

    // MARK: Animation State

    @State private var backgroundVisible = false
    @State private var ringProgress: CGFloat = 0
    @State private var logoRevealed = false
    @State private var wordmarkVisible = false
    @State private var taglineVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SplashBackground()
                .opacity(backgroundVisible ? 1 : 0)

            SplashParticleField()
                .opacity(backgroundVisible ? 1 : 0)

            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                SplashLogoView(ringProgress: ringProgress, isRevealed: logoRevealed)
                    .dsFloating(amplitude: 4, duration: 3.6)

                VStack(spacing: DS.Spacing.md) {
                    RentOSWordmark(fontSize: 40)
                        .kerning(wordmarkVisible ? 0.5 : 6)
                        .opacity(wordmarkVisible ? 1 : 0)
                        .blur(radius: wordmarkVisible ? 0 : 8)
                        .offset(y: wordmarkVisible ? 0 : 16)

                    SplashCascadeText(
                        text: "Property management, reimagined.",
                        isVisible: taglineVisible
                    )
                }

                Spacer()
                Spacer()
            }
        }
        .task { await runSequence() }
    }

    // MARK: Sequence

    private func runSequence() async {
        guard !reduceMotion else {
            await runReducedSequence()
            return
        }

        // 1 — Space fades in.
        withAnimation(.easeOut(duration: 0.7)) {
            backgroundVisible = true
        }
        try? await Task.sleep(for: .milliseconds(350))

        // 2 — Ring draws while the tile springs through it.
        withAnimation(.easeInOut(duration: 1.0)) {
            ringProgress = 1
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.25)) {
            logoRevealed = true
        }
        try? await Task.sleep(for: .milliseconds(1000))

        // 3 — Wordmark condenses into place.
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            wordmarkVisible = true
        }
        try? await Task.sleep(for: .milliseconds(450))

        // 4 — Tagline cascades (per-character delays live in the component).
        taglineVisible = true
        try? await Task.sleep(for: .milliseconds(1700))

        // 5 — Hand off.
        onFinished()
    }

    /// Reduce Motion: a calm fade with no movement, then hand off sooner.
    private func runReducedSequence() async {
        withAnimation(.easeOut(duration: 0.5)) {
            backgroundVisible = true
            ringProgress = 1
            logoRevealed = true
            wordmarkVisible = true
        }
        taglineVisible = true
        try? await Task.sleep(for: .milliseconds(1500))
        onFinished()
    }
}

#Preview("Splash") {
    SplashView(onFinished: {})
}
