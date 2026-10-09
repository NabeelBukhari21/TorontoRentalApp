//
//  SplashBackground.swift
//  RentalApp
//
//  Splash — Bright background with drifting colour orbs.
//
//  Shared by splash, onboarding, auth, org setup and MFA so the whole
//  launch flow feels like one continuous space. White first, with soft
//  violet, sky, coral and sunny light drifting behind the content — the
//  launch flow's equivalent of `DSAmbientBackground`, a little bolder
//  because there is less content on screen competing with it.
//
//  Follows the app's colour scheme: white in light mode (the default),
//  the dark DS background in dark mode.
//

import SwiftUI

struct SplashBackground: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                DS.Colors.background

                orb(DS.Colors.brand.opacity(0.20), width: size.width * 1.0, blur: 100,
                    from: CGPoint(x: 0.25, y: -0.18), to: CGPoint(x: -0.35, y: -0.32), in: size)

                orb(DS.Colors.accentSky.opacity(0.20), width: size.width * 0.9, blur: 110,
                    from: CGPoint(x: -0.25, y: 0.15), to: CGPoint(x: 0.35, y: 0.32), in: size)

                orb(DS.Colors.accentCoral.opacity(0.14), width: size.width * 0.7, blur: 90,
                    from: CGPoint(x: -0.10, y: 0.10), to: CGPoint(x: 0.10, y: -0.05), in: size)

                orb(DS.Colors.accentSunny.opacity(0.22), width: size.width * 0.6, blur: 90,
                    from: CGPoint(x: 0.30, y: 0.38), to: CGPoint(x: -0.20, y: 0.20), in: size)

                orb(DS.Colors.accentMint.opacity(0.14), width: size.width * 0.5, blur: 80,
                    from: CGPoint(x: -0.30, y: -0.40), to: CGPoint(x: 0.05, y: -0.10), in: size)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
        }
        .ignoresSafeArea()
    }

    private func orb(
        _ color: Color,
        width: CGFloat,
        blur: CGFloat,
        from: CGPoint,
        to: CGPoint,
        in size: CGSize
    ) -> some View {
        let point = drift ? to : from
        return Circle()
            .fill(color)
            .frame(width: width)
            .blur(radius: blur)
            .offset(x: size.width * point.x, y: size.height * point.y)
    }
}

#Preview("Splash Background") {
    SplashBackground()
}
