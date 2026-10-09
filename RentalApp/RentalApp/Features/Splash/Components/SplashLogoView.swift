//
//  SplashLogoView.swift
//  RentalApp
//
//  Splash — Animated logo mark: a breathing glow, a gradient ring that
//  draws itself, and a glass tile that springs in with a blur reveal.
//  The parent drives `ringProgress` and `isRevealed` inside withAnimation.
//

import SwiftUI

struct SplashLogoView: View {

    /// 0...1 — how much of the gradient ring is drawn.
    var ringProgress: CGFloat = 0
    /// Whether the glass tile has revealed.
    var isRevealed: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowBreathes = false

    var body: some View {
        ZStack {
            // Breathing violet-and-sunny glow behind everything.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DS.Colors.accentSunny.opacity(0.45), DS.Colors.brand.opacity(0.25), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 30)
                .scaleEffect(glowBreathes ? 1.18 : 0.9)
                .opacity(isRevealed ? 1 : 0)

            // Self-drawing rainbow ring.
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            DS.Colors.brand,
                            DS.Colors.accentSky,
                            DS.Colors.accentMint,
                            DS.Colors.accentSunny,
                            DS.Colors.accentCoral,
                            DS.Colors.brand
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 136, height: 136)
                .rotationEffect(.degrees(-90))
                .shadow(color: DS.Colors.brand.opacity(0.35), radius: 10)

            // The tile with the RentOS mark.
            RentOSLogoTile(size: 96)
                .scaleEffect(isRevealed ? 1 : 0.5)
                .blur(radius: isRevealed ? 0 : 14)
                .opacity(isRevealed ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowBreathes = true
            }
        }
    }
}

#Preview("Logo") {
    ZStack {
        SplashBackground()
        SplashLogoView(ringProgress: 1, isRevealed: true)
    }
}
