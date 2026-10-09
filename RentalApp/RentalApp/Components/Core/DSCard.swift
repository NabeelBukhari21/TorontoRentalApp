//
//  DSCard.swift
//  RentalApp
//
//  Design System — Card containers.
//  Three surface styles; the building block for every list and dashboard.
//

import SwiftUI

struct DSCard<Content: View>: View {

    enum Style {
        /// Soft grey `surface` card with a light shadow. Grouped content
        /// sitting directly on the white page.
        case elevated
        /// White card, hairline edge, soft violet shadow. The standard card
        /// — reads cleanly on white and on the ambient background.
        /// (Was `.glass` in the previous theme.)
        case raised
        /// Hairline border, no shadow. For nested/secondary content.
        case outlined
    }

    var style: Style = .elevated
    var cornerRadius: CGFloat = DS.Radius.lg
    var padding: CGFloat = DS.Spacing.lg
    private let content: Content

    init(
        style: Style = .elevated,
        cornerRadius: CGFloat = DS.Radius.lg,
        padding: CGFloat = DS.Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        switch style {
        case .elevated:
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(DS.Colors.surface)
                )
                .dsShadow(DS.Shadows.soft)

        case .raised:
            content
                .padding(padding)
                .dsSurface(cornerRadius: cornerRadius)

        case .outlined:
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(DS.Colors.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(DS.Colors.outline, lineWidth: 1)
                )
        }
    }
}

// MARK: - Stat Card

/// A compact metric card with an animated counter feel — dashboard building block.
struct DSStatCard: View {

    let title: String
    let value: String
    var icon: String? = nil
    var iconGradient: LinearGradient = DS.Gradients.brand
    /// Glyph colour on `iconGradient`. `textOnBrand` suits the violet
    /// gradients; pass `textOnAccent` with `warm` or `fresh`, where white
    /// fails even the 3:1 icon minimum (1.38 on sunny).
    var iconForeground: Color = DS.Colors.textOnBrand
    var trend: String? = nil
    var trendKind: DSStatusKind = .success

    var body: some View {
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(iconForeground)
                            .frame(width: 34, height: 34)
                            .background(iconGradient)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    }

                    Spacer()

                    if let trend {
                        Text(trend)
                            .font(DS.Typography.caption)
                            .foregroundStyle(trendKind.color)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(trendKind.tint, in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(value)
                        .font(DS.Typography.statValueSmall)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .contentTransition(.numericText())

                    Text(title)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Previews

#Preview("Cards") {
    ZStack {
        DSAmbientBackground()

        VStack(spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.md) {
                DSStatCard(
                    title: "Occupancy",
                    value: "94%",
                    icon: DS.Icons.occupancy,
                    trend: "+2.1%"
                )
                DSStatCard(
                    title: "Open Requests",
                    value: "12",
                    icon: DS.Icons.maintenance,
                    iconGradient: DS.Gradients.warm,
                    iconForeground: DS.Colors.textOnAccent,
                    trend: "3 urgent",
                    trendKind: .danger
                )
            }

            DSCard(style: .elevated) {
                Text("Elevated card")
                    .font(DS.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            DSCard(style: .outlined) {
                Text("Outlined card")
                    .font(DS.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DS.Spacing.xxl)
    }
}
