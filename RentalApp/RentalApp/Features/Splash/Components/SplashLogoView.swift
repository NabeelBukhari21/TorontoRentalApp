//
//  SplashLogoView.swift
//  RentalApp
//
//  Splash — The logo builds itself: a sun rises, the ground line draws,
//  the homes pop up one by one, the windows light, the cat hops in — and,
//  once the wordmark has landed, the cat cheers.
//
//  The parent drives `ringProgress` (the sun) and `isRevealed` (the build)
//  inside its own animation timeline; the finale is scheduled here so the
//  splash sequence itself didn't need to change.
//

import SwiftUI

struct SplashLogoView: View {

    /// 0...1 — how far the sun has risen behind the skyline.
    var ringProgress: CGFloat = 0
    /// Whether the neighbourhood has built.
    var isRevealed: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrates = false
    @State private var glowBreathes = false

    private let size: CGFloat = 190

    var body: some View {
        ZStack {
            // The sun, rising behind the towers.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DS.Colors.accentSunny, DS.Colors.accentSunny.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.42
                    )
                )
                .frame(width: size * 0.84, height: size * 0.84)
                .scaleEffect(glowBreathes ? 1.06 : 0.96)
                .offset(x: size * 0.16, y: size * (0.10 - 0.22 * ringProgress))
                .opacity(Double(ringProgress) * 0.75)

            PurrpertyLogoMark(size: size, isBuilt: isRevealed, celebrates: celebrates)
        }
        .frame(width: size, height: size)
        .task(id: isRevealed) {
            guard isRevealed else { return }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    glowBreathes = true
                }
            }
            // Finale: after the cat has hopped in and the wordmark is in
            // place, it throws its arms up.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 1500))
            celebrates = true
        }
    }
}

#Preview("Logo") {
    struct Demo: View {
        @State private var revealed = false
        @State private var ring: CGFloat = 0
        var body: some View {
            ZStack {
                SplashBackground()
                SplashLogoView(ringProgress: ring, isRevealed: revealed)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeInOut(duration: 1.0)) { ring = 1 }
                revealed = true
            }
        }
    }
    return Demo()
}
