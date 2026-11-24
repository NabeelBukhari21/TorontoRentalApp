//
//  Clay.swift
//  RentalApp (Purrperty)
//
//  Components/Core — Soft moulded surfaces: the clay fill, clay icon
//  tokens and the button style that presses into its own edge.
//

import SwiftUI

// MARK: - Clay

extension ShapeStyle where Self == AnyShapeStyle {
    /// A soft moulded surface: lit from the top left, shaded below.
    static func clay(_ color: Color, shade: Color, size: CGFloat) -> AnyShapeStyle {
        AnyShapeStyle(
            color
                .shadow(.inner(color: .white.opacity(0.6), radius: size * 0.05, x: size * 0.03, y: size * 0.05))
                .shadow(.inner(color: shade.opacity(0.45), radius: size * 0.08, x: -size * 0.03, y: -size * 0.07))
        )
    }
}

/// A moulded icon, like a soft toy of the thing.
struct ClayToken: View {
    let symbol: String
    let accent: DSAccent
    var size: CGFloat = 64

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
            .fill(.clay(accent.fill, shade: accent.ink, size: size))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(accent.onFill)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Press

/// A key-like button: a face on a darker edge that sinks when pressed.
struct PressableDepthStyle: ButtonStyle {
    var edge: Color
    var depth: CGFloat = 6
    var shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? depth : 0)
            .background(shape.fill(edge).offset(y: depth))
            .contentShape(shape)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}
