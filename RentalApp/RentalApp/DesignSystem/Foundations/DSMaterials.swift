//
//  DSMaterials.swift
//  RentalApp
//
//  Design System — Glassmorphism materials.
//  The signature surface treatment: blur + translucency + gradient hairline + soft shadow.
//

import SwiftUI

// MARK: - Glass Modifier

/// Wraps content in the standard glass panel treatment.
struct DSGlassModifier: ViewModifier {

    var cornerRadius: CGFloat = DS.Radius.lg
    var shadow: DSShadowStyle = DS.Shadows.card

    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DS.Gradients.glassHighlight, lineWidth: 1)
            )
            .dsShadow(shadow)
    }
}

extension View {

    /// Applies the standard glass panel background: blur, hairline sheen, soft shadow.
    func dsGlass(
        cornerRadius: CGFloat = DS.Radius.lg,
        shadow: DSShadowStyle = DS.Shadows.card
    ) -> some View {
        modifier(DSGlassModifier(cornerRadius: cornerRadius, shadow: shadow))
    }
}

// MARK: - Obsidian Surface

/// The signature premium surface: obsidian → titanium gradient with a
/// champagne hairline and floating shadow. Used by lease cards, the AI
/// panel, billing, and any "flagship" moment.
struct DSObsidianModifier: ViewModifier {

    var cornerRadius: CGFloat = DS.Radius.xl

    func body(content: Content) -> some View {
        content
            .background(
                DS.Gradients.obsidian,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DS.Gradients.obsidianHairline, lineWidth: 1)
            )
            .dsShadow(DS.Shadows.floating)
    }
}

extension View {

    /// Applies the signature obsidian surface treatment.
    func dsObsidianSurface(cornerRadius: CGFloat = DS.Radius.xl) -> some View {
        modifier(DSObsidianModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Panel

/// A ready-made glass container with standard padding.
struct DSGlassPanel<Content: View>: View {

    var cornerRadius: CGFloat = DS.Radius.xl
    var padding: CGFloat = DS.Spacing.xl
    private let content: Content

    init(
        cornerRadius: CGFloat = DS.Radius.xl,
        padding: CGFloat = DS.Spacing.xl,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .dsGlass(cornerRadius: cornerRadius)
    }
}

#Preview("Glass Panel") {
    ZStack {
        DSAmbientBackground()

        DSGlassPanel {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Portfolio Value")
                    .dsOverline()
                Text("$4.2M")
                    .font(DS.Typography.statValue)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Spacing.xxl)
    }
}
