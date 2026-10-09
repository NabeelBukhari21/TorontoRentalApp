//
//  SplashBackground.swift
//  RentalApp
//
//  Splash — Deep animated gradient background with drifting light orbs.
//  Shared by the splash and onboarding so the transition between them
//  feels like one continuous space.
//

import SwiftUI

struct SplashBackground: View {

    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                // Obsidian → titanium base.
                LinearGradient(
                    colors: [
                        Color(hex: 0x0A0A0B),
                        RentOSBrand.obsidian,
                        Color(hex: 0x2A2D34)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Drifting champagne light orbs.
                Circle()
                    .fill(Color(hex: 0xD4AF37).opacity(0.24))
                    .frame(width: size.width * 1.0)
                    .blur(radius: 100)
                    .offset(
                        x: drift ? -size.width * 0.35 : size.width * 0.25,
                        y: drift ? -size.height * 0.30 : -size.height * 0.15
                    )

                Circle()
                    .fill(Color(hex: 0xC7CDD6).opacity(0.14))
                    .frame(width: size.width * 0.9)
                    .blur(radius: 110)
                    .offset(
                        x: drift ? size.width * 0.35 : -size.width * 0.25,
                        y: drift ? size.height * 0.32 : size.height * 0.15
                    )

                Circle()
                    .fill(Color(hex: 0xFFB703).opacity(0.12))
                    .frame(width: size.width * 0.7)
                    .blur(radius: 90)
                    .offset(
                        x: drift ? size.width * 0.10 : -size.width * 0.10,
                        y: drift ? -size.height * 0.05 : size.height * 0.10
                    )

                // Soft vignette to focus the center.
                RadialGradient(
                    colors: [.clear, Color(hex: 0x050505).opacity(0.6)],
                    center: .center,
                    startRadius: size.width * 0.25,
                    endRadius: size.width * 0.9
                )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview("Splash Background") {
    SplashBackground()
}
