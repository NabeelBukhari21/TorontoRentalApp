//
//  OnboardingMaintenanceIllustration.swift
//  RentalApp
//
//  Onboarding page 2 — AI maintenance automation. A request card gets
//  swept by an AI scan beam, then classification badges pop in.
//

import SwiftUI

struct OnboardingMaintenanceIllustration: View {

    let isActive: Bool

    @State private var scanOffset: CGFloat = -90

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {

            // Request card being scanned.
            VStack(spacing: DS.Spacing.md) {
                OnboardingMiniCard(
                    icon: "drop.fill",
                    title: "Leaking kitchen faucet",
                    subtitle: "Unit 304 · Reported 8 min ago",
                    iconGradient: DS.Gradients.warm
                ) {
                    Image(systemName: DS.Icons.camera)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }

                OnboardingMiniCard(
                    icon: DS.Icons.tenant,
                    title: "Sarah Chen",
                    subtitle: "\u{201C}Water is pooling under the sink…\u{201D}"
                ) {
                    Image(systemName: DS.Icons.messages)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 290)
            .overlay(
                // AI scan beam.
                LinearGradient(
                    colors: [
                        .clear,
                        DS.Colors.brandCyan.opacity(0.45),
                        .white.opacity(0.35),
                        DS.Colors.brandCyan.opacity(0.45),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 54)
                .offset(y: scanOffset)
                .opacity(isActive ? 1 : 0)
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .scaleEffect(isActive ? 1 : 0.85)
            .opacity(isActive ? 1 : 0)
            .animation(DS.Motion.entrance.delay(0.1), value: isActive)
            .dsFloating(amplitude: 4, duration: 3.8)

            // AI verdict.
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icons.ai)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Gradients.ai)
                    .symbolEffect(.pulse, options: .repeating, isActive: isActive)

                Text("AI classified in 0.4s")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .opacity(isActive ? 1 : 0)
            .animation(DS.Motion.smooth.delay(0.7), value: isActive)

            // Classification badges pop in.
            HStack(spacing: DS.Spacing.sm) {
                verdictBadge("Urgent", icon: DS.Icons.warning, kind: .danger, delay: 0.85)
                verdictBadge("Plumbing", icon: "wrench.fill", kind: .info, delay: 1.0)
                verdictBadge("Vendor matched", icon: DS.Icons.success, kind: .success, delay: 1.15)
            }
        }
        .onAppear { startScan() }
    }

    private func verdictBadge(_ text: String, icon: String, kind: DSStatusKind, delay: Double) -> some View {
        DSBadge(text: text, kind: kind, icon: icon)
            .scaleEffect(isActive ? 1 : 0.4)
            .opacity(isActive ? 1 : 0)
            .animation(DS.Motion.bouncy.delay(delay), value: isActive)
    }

    private func startScan() {
        scanOffset = -90
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            scanOffset = 90
        }
    }
}

#Preview("Maintenance Illustration") {
    ZStack {
        SplashBackground()
        OnboardingMaintenanceIllustration(isActive: true)
    }
    .environment(\.colorScheme, .dark)
}
