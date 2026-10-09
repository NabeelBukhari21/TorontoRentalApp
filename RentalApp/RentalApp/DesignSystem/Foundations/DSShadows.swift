//
//  DSShadows.swift
//  RentalApp
//
//  Design System — Elevation shadows.
//  Soft, diffused shadows that read as "floating" rather than harsh drop shadows.
//

import SwiftUI

/// A reusable shadow definition.
struct DSShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

extension DS {

    enum Shadows {

        /// Subtle lift for resting cards.
        static let soft = DSShadowStyle(
            color: Color(hex: 0x0F172A, opacity: 0.06),
            radius: 12,
            y: 4
        )

        /// Standard card elevation.
        static let card = DSShadowStyle(
            color: Color(hex: 0x0F172A, opacity: 0.10),
            radius: 20,
            y: 8
        )

        /// High elevation — floating panels, popovers.
        static let floating = DSShadowStyle(
            color: Color(hex: 0x0F172A, opacity: 0.16),
            radius: 32,
            y: 14
        )

        /// Colored glow for brand elements (primary buttons, AI accents).
        static func glow(_ color: Color, intensity: Double = 0.35) -> DSShadowStyle {
            DSShadowStyle(color: color.opacity(intensity), radius: 18, y: 8)
        }
    }
}

// MARK: - View Modifier

extension View {

    /// Applies a design-system shadow token.
    func dsShadow(_ style: DSShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: 0, y: style.y)
    }
}
