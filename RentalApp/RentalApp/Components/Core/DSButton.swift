//
//  DSButton.swift
//  RentalApp
//
//  Design System — Buttons.
//  Five variants, three sizes, loading state, press-scale feedback.
//

import SwiftUI

struct DSButton: View {

    // MARK: Variant

    enum Variant {
        /// Brand gradient fill with glow. One per screen.
        case primary
        /// Tinted surface fill. Standard secondary action.
        case secondary
        /// Text-only. Low emphasis.
        case ghost
        /// Red fill for destructive actions.
        case destructive
        /// White surface with a hairline. For use over ambient, coloured or
        /// photo backgrounds. (Was `.glass` in the previous theme.)
        case soft
    }

    // MARK: Size

    enum Size {
        case small, medium, large

        var font: Font {
            switch self {
            case .small: DS.Typography.caption
            case .medium: DS.Typography.subheadline
            case .large: DS.Typography.headline
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: DS.Spacing.sm
            case .medium: DS.Spacing.md
            case .large: DS.Spacing.lg
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: DS.Spacing.md
            case .medium: DS.Spacing.lg
            case .large: DS.Spacing.xl
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: DS.Radius.sm
            case .medium: DS.Radius.md
            case .large: DS.Radius.lg
            }
        }
    }

    // MARK: Properties

    let title: String
    var icon: String? = nil
    var variant: Variant = .primary
    var size: Size = .medium
    var isFullWidth: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    // MARK: Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foregroundColor)
                } else if let icon {
                    Image(systemName: icon)
                        .font(size.font.weight(.semibold))
                }

                Text(title)
                    .font(size.font.weight(.semibold))
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .foregroundStyle(foregroundColor)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .dsShadow(shadow)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(DSPressStyle())
        .disabled(isLoading)
    }

    // MARK: Styling

    private var foregroundColor: Color {
        switch variant {
        // White on violet 4.86 / on coral-ink 5.52 (light); dark ink in dark.
        case .primary, .destructive: DS.Colors.textOnBrand
        // `brandInk`, not `brand`: on the 12% violet tint `brand` is 4.14,
        // under AA; `brandInk` is 5.16.
        case .secondary: DS.Colors.brandInk
        case .soft: DS.Colors.brandInk
        case .ghost: DS.Colors.textSecondary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            DS.Gradients.brand
        case .secondary:
            DS.Colors.brand.opacity(0.12)
        case .ghost:
            Color.clear
        case .destructive:
            DS.Colors.danger
        case .soft:
            DS.Colors.surfaceRaised
        }
    }

    @ViewBuilder
    private var border: some View {
        if variant == .soft {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .strokeBorder(DS.Gradients.cardHairline, lineWidth: 1)
        }
    }

    private var shadow: DSShadowStyle {
        switch variant {
        case .primary: DS.Shadows.glow(DS.Colors.brand)
        case .destructive: DS.Shadows.glow(DS.Colors.accentCoralInk, intensity: 0.30)
        case .soft: DS.Shadows.soft
        default: DSShadowStyle(color: .clear, radius: 0, y: 0)
        }
    }
}

// MARK: - Icon-Only Button

/// A compact circular icon button (toolbar actions, card actions).
struct DSIconButton: View {

    let icon: String
    var variant: DSButton.Variant = .soft
    var diameter: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: diameter * 0.4, weight: .semibold))
                .foregroundStyle(variant == .primary ? DS.Colors.textOnBrand : DS.Colors.brandInk)
                .frame(width: diameter, height: diameter)
                .background(iconBackground)
                .overlay(
                    Circle().strokeBorder(
                        variant == .soft ? AnyShapeStyle(DS.Gradients.cardHairline) : AnyShapeStyle(Color.clear),
                        lineWidth: 1
                    )
                )
                .clipShape(Circle())
                .dsShadow(variant == .soft ? DS.Shadows.soft : DSShadowStyle(color: .clear, radius: 0, y: 0))
        }
        .buttonStyle(DSPressStyle(scale: 0.9))
    }

    @ViewBuilder
    private var iconBackground: some View {
        switch variant {
        case .primary:
            DS.Gradients.brand
        case .soft:
            DS.Colors.surfaceRaised
        default:
            DS.Colors.brand.opacity(0.12)
        }
    }
}

// MARK: - Previews

#Preview("Buttons") {
    ZStack {
        DSAmbientBackground()

        VStack(spacing: DS.Spacing.lg) {
            DSButton(title: "Add Property", icon: DS.Icons.add, variant: .primary, size: .large, isFullWidth: true) {}
            DSButton(title: "View Report", variant: .secondary) {}
            DSButton(title: "Skip for now", variant: .ghost) {}
            DSButton(title: "Delete Lease", variant: .destructive) {}
            DSButton(title: "Ask AI", icon: DS.Icons.ai, variant: .soft) {}
            DSButton(title: "Saving…", variant: .primary, isLoading: true) {}

            HStack(spacing: DS.Spacing.md) {
                DSIconButton(icon: DS.Icons.search) {}
                DSIconButton(icon: DS.Icons.filter) {}
                DSIconButton(icon: DS.Icons.add, variant: .primary) {}
            }
        }
        .padding(DS.Spacing.xxl)
    }
}
