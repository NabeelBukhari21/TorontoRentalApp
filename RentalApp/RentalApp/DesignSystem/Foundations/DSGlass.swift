//
//  DSGlass.swift
//  RentalApp (Purrperty)
//
//  Design System — Glass, and the solid surface that replaces it.
//
//  Every glass or frosted surface in the app goes through here, so one
//  switch makes them all solid: Settings ▸ Appearance ▸ Reduce glass
//  effects, or the system's Reduce Transparency. Solid surfaces are
//  easier to read over busy backgrounds and cheaper to draw.
//

import SwiftUI

extension EnvironmentValues {
    /// Settings ▸ Appearance ▸ Reduce glass effects. Injected at the root.
    @Entry var reducesGlass = false
}

/// Whether glass should be drawn here, or a solid surface instead.
struct DSGlassPolicy: DynamicProperty {
    @Environment(\.reducesGlass) private var setting
    @Environment(\.accessibilityReduceTransparency) private var system

    var isSolid: Bool { setting || system }
}

private struct DSGlassModifier<S: Shape>: ViewModifier {
    let glass: Glass
    let shape: S
    /// The fill used instead of glass, when glass is off.
    let solid: Color
    let isEnabled: Bool
    private let policy = DSGlassPolicy()

    func body(content: Content) -> some View {
        if !isEnabled {
            content
        } else if policy.isSolid {
            content
                .background(shape.fill(solid))
                .overlay(shape.stroke(DS.Colors.outline, lineWidth: 1))
        } else {
            content.glassEffect(glass, in: shape)
        }
    }
}

private struct DSFrostModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Double
    private let policy = DSGlassPolicy()

    func body(content: Content) -> some View {
        content.background {
            if policy.isSolid {
                shape.fill(DS.Colors.surfaceRaised)
            } else {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(DS.Colors.surfaceRaised.opacity(tint))
                }
            }
        }
    }
}

extension View {

    /// Liquid Glass in `shape`, or a solid surface when glass is reduced.
    func dsGlass(
        _ glass: Glass = .regular,
        in shape: some Shape,
        solid: Color = DS.Colors.surfaceRaised,
        isEnabled: Bool = true
    ) -> some View {
        modifier(DSGlassModifier(glass: glass, shape: shape, solid: solid, isEnabled: isEnabled))
    }

    /// Frosted material with a warm tint, or a solid surface when glass is
    /// reduced. Unlike Liquid Glass, it stays light over dark imagery.
    func dsFrost(in shape: some Shape, tint: Double = 0.72) -> some View {
        modifier(DSFrostModifier(shape: shape, tint: tint))
    }
}
