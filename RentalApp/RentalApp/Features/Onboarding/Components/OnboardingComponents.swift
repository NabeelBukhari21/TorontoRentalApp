//
//  OnboardingComponents.swift
//  RentalApp
//
//  Onboarding — Shared building blocks: progress indicator,
//  floating glass chips, and mini glass cards used inside illustrations.
//

import SwiftUI

// MARK: - Progress Indicator

/// Animated page indicator — the active page stretches into a gradient capsule.
struct OnboardingProgressIndicator: View {

    let current: OnboardingPage

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(OnboardingPage.allCases) { page in
                Capsule()
                    .fill(
                        page == current
                            ? AnyShapeStyle(DS.Gradients.ai)
                            : AnyShapeStyle(DS.Colors.track)
                    )
                    .frame(width: page == current ? 30 : 8, height: 8)
                    .overlay(
                        Capsule().strokeBorder(DS.Colors.highlightLine.opacity(page == current ? 1 : 0), lineWidth: 0.5)
                    )
            }
        }
        .animation(DS.Motion.smooth, value: current)
    }
}

// MARK: - Floating Chip

/// A small glass capsule with icon + label that floats gently.
/// Used to orbit feature hints around illustrations.
struct OnboardingFloatingChip: View {

    let icon: String
    let text: String
    var tint: Color = DS.Colors.accentSkyInk
    var isActive: Bool = false
    var entranceDelay: Double = 0
    var floatDuration: Double = 3.0

    var body: some View {
        HStack(spacing: DS.Spacing.xs + 2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surfaceRaised, in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                DS.Gradients.cardHairline,
                lineWidth: 1
            )
        )
        .dsShadow(DS.Shadows.card)
        .scaleEffect(isActive ? 1 : 0.5)
        .opacity(isActive ? 1 : 0)
        .animation(DS.Motion.bouncy.delay(entranceDelay), value: isActive)
        .dsFloating(amplitude: 5, duration: floatDuration)
    }
}

// MARK: - Mini Glass Card

/// A compact glass "UI vignette" card: icon tile + two text lines + trailing slot.
struct OnboardingMiniCard<Trailing: View>: View {

    let icon: String
    let title: String
    let subtitle: String
    var iconGradient: LinearGradient = DS.Gradients.brand
    /// Glyph colour on `iconGradient` — `textOnAccent` for `warm`/`fresh`.
    var iconForeground: Color = DS.Colors.textOnBrand
    private let trailing: Trailing

    init(
        icon: String,
        title: String,
        subtitle: String,
        iconGradient: LinearGradient = DS.Gradients.brand,
        iconForeground: Color = DS.Colors.textOnBrand,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconGradient = iconGradient
        self.iconForeground = iconForeground
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconForeground)
                .frame(width: 38, height: 38)
                .background(iconGradient)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            trailing
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(
                    DS.Gradients.cardHairline,
                    lineWidth: 1
                )
        )
        .dsShadow(DS.Shadows.card)
    }
}
