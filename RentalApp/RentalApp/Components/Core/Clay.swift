//
//  Clay.swift
//  RentalApp (Purrperty)
//
//  Components/Core — Soft moulded surfaces: the clay fill and clay
//  icon tokens. (Their press style is in `ButtonMotion`.)
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
