//
//  OnboardingPortfolioIllustration.swift
//  RentalApp
//
//  Onboarding page 3 — Portfolio management. A fanned stack of
//  property cards, each floating on its own rhythm, with animated
//  occupancy bars.
//

import SwiftUI

struct OnboardingPortfolioIllustration: View {

    let isActive: Bool

    var body: some View {
        ZStack {
            propertyCard(
                name: "Queen West Lofts",
                detail: "12 units",
                occupancy: 0.83,
                gradient: DS.Gradients.warm,
                delay: 0.1,
                floatDuration: 4.0
            )
            .rotationEffect(.degrees(isActive ? -7 : -2))
            .offset(x: isActive ? -46 : 0, y: isActive ? -58 : 20)

            propertyCard(
                name: "Danforth Triplex",
                detail: "3 units",
                occupancy: 1.0,
                gradient: DS.Gradients.success,
                delay: 0.25,
                floatDuration: 3.4
            )
            .rotationEffect(.degrees(isActive ? 7 : 2))
            .offset(x: isActive ? 46 : 0, y: isActive ? 4 : 30)

            propertyCard(
                name: "Maple Duplex",
                detail: "6 units · 2 requests",
                occupancy: 0.94,
                gradient: DS.Gradients.brand,
                delay: 0.4,
                floatDuration: 3.8
            )
            .offset(y: isActive ? 72 : 60)
        }
        .animation(DS.Motion.entrance.delay(0.1), value: isActive)
    }

    // MARK: Card

    private func propertyCard(
        name: String,
        detail: String,
        occupancy: Double,
        gradient: LinearGradient,
        delay: Double,
        floatDuration: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: DS.Icons.properties)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(gradient)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer(minLength: 0)

                Text("\(Int(occupancy * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(occupancy >= 0.9 ? DS.Colors.success : DS.Colors.accentAmber)
            }

            // Occupancy bar that fills when the page activates.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(gradient)
                        .frame(width: proxy.size.width * (isActive ? occupancy : 0))
                        .animation(DS.Motion.entrance.delay(delay + 0.35), value: isActive)
                }
            }
            .frame(height: 6)
        }
        .padding(DS.Spacing.lg)
        .frame(width: 270)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.45), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .dsShadow(DS.Shadows.floating)
        .opacity(isActive ? 1 : 0)
        .animation(DS.Motion.entrance.delay(delay), value: isActive)
        .dsFloating(amplitude: 4, duration: floatDuration)
    }
}

#Preview("Portfolio Illustration") {
    ZStack {
        SplashBackground()
        OnboardingPortfolioIllustration(isActive: true)
    }
    .environment(\.colorScheme, .dark)
}
