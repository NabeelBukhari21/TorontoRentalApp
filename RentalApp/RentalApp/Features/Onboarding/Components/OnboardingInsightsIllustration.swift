//
//  OnboardingInsightsIllustration.swift
//  RentalApp
//
//  Onboarding page 4 — Analytics & AI insights. A revenue chart whose
//  bars grow in with a rolling counter, plus a floating AI insight chip.
//

import SwiftUI

struct OnboardingInsightsIllustration: View {

    let isActive: Bool

    @State private var revenue = 0

    private let bars: [CGFloat] = [0.42, 0.58, 0.5, 0.72, 0.64, 0.9]

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {

            // Analytics card.
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("MONTHLY REVENUE")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .kerning(1.2)
                            .foregroundStyle(DS.Colors.textSecondary)

                        Text("$\(revenue)K")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DS.Colors.textPrimary)
                            .contentTransition(.numericText())
                    }

                    Spacer()

                    DSBadge(text: "+4.2%", kind: .success, icon: "arrow.up.right")
                        .scaleEffect(isActive ? 1 : 0.4)
                        .opacity(isActive ? 1 : 0)
                        .animation(DS.Motion.bouncy.delay(0.9), value: isActive)
                }

                // Growing bars.
                HStack(alignment: .bottom, spacing: DS.Spacing.md) {
                    ForEach(bars.indices, id: \.self) { index in
                        VStack(spacing: DS.Spacing.xs) {
                            Capsule()
                                .fill(
                                    index == bars.count - 1
                                        ? AnyShapeStyle(DS.Gradients.ai)
                                        : AnyShapeStyle(DS.Colors.accentSky.opacity(0.35))
                                )
                                .frame(height: 110 * bars[index])
                                .scaleEffect(
                                    y: isActive ? 1 : 0.06,
                                    anchor: .bottom
                                )
                                .animation(
                                    DS.Motion.bouncy.delay(0.25 + Double(index) * 0.08),
                                    value: isActive
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 110, alignment: .bottom)
            }
            .padding(DS.Spacing.xl)
            .frame(width: 300)
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .strokeBorder(
                        DS.Gradients.cardHairline,
                        lineWidth: 1
                    )
            )
            .dsShadow(DS.Shadows.floating)
            .scaleEffect(isActive ? 1 : 0.88)
            .opacity(isActive ? 1 : 0)
            .animation(DS.Motion.entrance.delay(0.1), value: isActive)
            .dsFloating(amplitude: 4, duration: 4.0)

            // AI insight chip.
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icons.ai)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Gradients.ai)
                    .symbolEffect(.pulse, options: .repeating, isActive: isActive)

                Text("3 leases renew next month — start early")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.surfaceRaised, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [DS.Colors.accentSkyInk.opacity(0.6), DS.Colors.accentSky.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .dsShadow(DS.Shadows.glow(DS.Colors.accentSkyInk, intensity: 0.25))
            .scaleEffect(isActive ? 1 : 0.6)
            .opacity(isActive ? 1 : 0)
            .animation(DS.Motion.bouncy.delay(1.0), value: isActive)
            .dsFloating(amplitude: 5, duration: 3.2)
        }
        .onChange(of: isActive) { _, active in
            withAnimation(DS.Motion.smooth.delay(0.4)) {
                revenue = active ? 128 : 0
            }
        }
        .onAppear {
            if isActive {
                withAnimation(DS.Motion.smooth.delay(0.4)) { revenue = 128 }
            }
        }
    }
}

#Preview("Insights Illustration") {
    ZStack {
        SplashBackground()
        OnboardingInsightsIllustration(isActive: true)
    }
}
