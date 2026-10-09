//
//  DSMaterials.swift
//  RentalApp
//
//  Design System — Surfaces.
//
//  ─────────────────────────────────────────────────────────────────
//  FROM GLASS TO PAPER
//  ─────────────────────────────────────────────────────────────────
//  The previous theme was built on glassmorphism: blur, translucency and
//  a gold hairline over dark, glowing backgrounds. That reads as premium
//  on obsidian and as murky on white — a frosted panel over a white page
//  is just a slightly grey rectangle.
//
//  This theme is clean, solid cards: an opaque fill, a faint hairline so
//  the edge survives on white, a soft shadow tinted with the brand violet
//  rather than black, and a generous corner radius. Friendlier, crisper,
//  and considerably cheaper to render than live blur.
//
//  The modifiers keep one job each:
//    • `dsSurface`      — the standard card. Every list row and panel.
//    • `dsHeroSurface`  — a gradient card for flagship moments.
//

import SwiftUI

// MARK: - Surface

/// The standard card treatment: solid fill, hairline, soft coloured shadow.
struct DSSurfaceModifier: ViewModifier {

    var cornerRadius: CGFloat = DS.Radius.lg
    var fill: Color = DS.Colors.surfaceRaised
    var shadow: DSShadowStyle = DS.Shadows.card

    func body(content: Content) -> some View {
        content
            .background(
                fill,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DS.Gradients.cardHairline, lineWidth: 1)
            )
            .dsShadow(shadow)
    }
}

extension View {

    /// Applies the standard card surface: white, hairline, soft shadow.
    ///
    /// Defaults to `surfaceRaised` (white) rather than `surface` (#F6F7FB)
    /// because this modifier is used for cards floating over the ambient
    /// background and over other cards — places where a white card with a
    /// coloured shadow is what separates it. Pass `fill: DS.Colors.surface`
    /// for grouped content sitting directly on the white page.
    func dsSurface(
        cornerRadius: CGFloat = DS.Radius.lg,
        fill: Color = DS.Colors.surfaceRaised,
        shadow: DSShadowStyle = DS.Shadows.card
    ) -> some View {
        modifier(DSSurfaceModifier(cornerRadius: cornerRadius, fill: fill, shadow: shadow))
    }
}

// MARK: - Hero Surface

/// A gradient card for flagship moments — the revenue card, lease cards,
/// the AI panel, billing. Text on it uses `textOnBrand` by default; pass a
/// different gradient for warm/fresh variants and use `textOnAccent` there.
struct DSHeroSurfaceModifier: ViewModifier {

    var cornerRadius: CGFloat = DS.Radius.xl
    var gradient: LinearGradient = DS.Gradients.hero
    var glow: Color = DS.Colors.brand

    func body(content: Content) -> some View {
        content
            .background(
                gradient,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DS.Gradients.heroHairline, lineWidth: 1)
            )
            .dsShadow(DS.Shadows.glow(glow, intensity: 0.28))
    }
}

extension View {

    /// Applies a gradient hero card. Defaults to violet → sky.
    func dsHeroSurface(
        cornerRadius: CGFloat = DS.Radius.xl,
        gradient: LinearGradient = DS.Gradients.hero,
        glow: Color = DS.Colors.brand
    ) -> some View {
        modifier(DSHeroSurfaceModifier(cornerRadius: cornerRadius, gradient: gradient, glow: glow))
    }
}

// MARK: - Surface Panel

/// A ready-made card container with standard padding.
struct DSSurfacePanel<Content: View>: View {

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
            .dsSurface(cornerRadius: cornerRadius)
    }
}

#Preview("Surfaces") {
    ZStack {
        DSAmbientBackground()

        VStack(spacing: DS.Spacing.xl) {
            DSSurfacePanel {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Portfolio Value").dsOverline()
                    Text("$4.2M")
                        .font(DS.Typography.statValue)
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("MONTHLY RENT")
                    .font(DS.Typography.overline)
                    .foregroundStyle(DS.Colors.textOnBrand.opacity(0.85))
                Text("$18,450")
                    .font(DS.Typography.statValue)
                    .foregroundStyle(DS.Colors.textOnBrand)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.xl)
            .dsHeroSurface()
        }
        .padding(DS.Spacing.xxl)
    }
}
