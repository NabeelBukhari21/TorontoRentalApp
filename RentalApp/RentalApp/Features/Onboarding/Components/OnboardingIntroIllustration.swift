//
//  OnboardingIntroIllustration.swift
//  RentalApp
//
//  Onboarding page 1 — The platform. A glowing logo tile with feature
//  chips floating in orbit and a live-looking property card beneath.
//

import SwiftUI

struct OnboardingIntroIllustration: View {

    let isActive: Bool

    var body: some View {
        ZStack {
            // Central glow.
            Circle()
                .fill(DS.Colors.brandViolet.opacity(0.5))
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .opacity(isActive ? 1 : 0)
                .animation(DS.Motion.gentle, value: isActive)

            // RentOS logo tile.
            RentOSLogoTile(size: 88)
                .scaleEffect(isActive ? 1 : 0.6)
                .opacity(isActive ? 1 : 0)
                .animation(DS.Motion.bouncy.delay(0.1), value: isActive)
                .dsFloating(amplitude: 6, duration: 3.4)
                .offset(y: -30)

            // Orbiting feature chips.
            OnboardingFloatingChip(
                icon: DS.Icons.tenants,
                text: "Tenants",
                tint: DS.Colors.brandCyan,
                isActive: isActive,
                entranceDelay: 0.30,
                floatDuration: 2.9
            )
            .offset(x: -105, y: -105)

            OnboardingFloatingChip(
                icon: DS.Icons.maintenance,
                text: "Maintenance",
                tint: DS.Colors.accentAmber,
                isActive: isActive,
                entranceDelay: 0.42,
                floatDuration: 3.5
            )
            .offset(x: 100, y: -75)

            OnboardingFloatingChip(
                icon: DS.Icons.messages,
                text: "Messages",
                tint: DS.Colors.accentCoral,
                isActive: isActive,
                entranceDelay: 0.54,
                floatDuration: 3.1
            )
            .offset(x: -110, y: 30)

            OnboardingFloatingChip(
                icon: DS.Icons.payment,
                text: "Payments",
                tint: DS.Colors.success,
                isActive: isActive,
                entranceDelay: 0.66,
                floatDuration: 3.7
            )
            .offset(x: 108, y: 55)

            // Live property card.
            OnboardingMiniCard(
                icon: DS.Icons.properties,
                title: "Maple Duplex · Leslieville",
                subtitle: "6 units · 2 open requests"
            ) {
                Text("94%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DS.Colors.success)
            }
            .frame(width: 280)
            .offset(y: isActive ? 118 : 160)
            .opacity(isActive ? 1 : 0)
            .animation(DS.Motion.entrance.delay(0.5), value: isActive)
            .dsFloating(amplitude: 4, duration: 4.2)
        }
    }
}

#Preview("Intro Illustration") {
    ZStack {
        SplashBackground()
        OnboardingIntroIllustration(isActive: true)
    }
    .environment(\.colorScheme, .dark)
}
