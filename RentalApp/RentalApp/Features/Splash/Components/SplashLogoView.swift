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

    @State private var glowBreathes = false

    var body: some View {
        ZStack {
            // Breathing glow behind everything.
            Circle()
                .fill(RentOSBrand.gold.opacity(0.4))
                .frame(width: 150, height: 150)
                .blur(radius: 42)
                .scaleEffect(glowBreathes ? 1.18 : 0.9)
                .opacity(isRevealed ? 1 : 0)

            // Self-drawing gradient ring.
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            RentOSBrand.goldDeep,
                            RentOSBrand.gold,
                            RentOSBrand.champagne,
                            RentOSBrand.saffron,
                            RentOSBrand.goldDeep
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 136, height: 136)
                .rotationEffect(.degrees(-90))
                .shadow(color: DS.Colors.brand.opacity(0.6), radius: 12)

            // Glass tile with the RentOS skyline mark.
            RentOSLogoTile(size: 96)
                .scaleEffect(isRevealed ? 1 : 0.5)
                .blur(radius: isRevealed ? 0 : 14)
                .opacity(isRevealed ? 1 : 0)
        }
        .onAppear {
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
