//
//  DSShadows.swift
//  RentalApp
//
//  Design System — Elevation shadows.
//
//  Soft, diffused, and tinted with the brand violet rather than black.
//  A grey shadow on white reads as "dirty"; a faint violet one reads as
//  light passing through a coloured object — the friendlier of the two.
//  Dark mode switches to deep, neutral shadows, because a tinted shadow
//  on a near-black surface just looks like a stain.
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
            color: Color(
                light: Color(hex: 0x6C5CE7, opacity: 0.07),
                dark: Color(hex: 0x000000, opacity: 0.30)
            ),
            radius: 12,
            y: 4
        )

        /// Standard card elevation.
        static let card = DSShadowStyle(
            color: Color(
                light: Color(hex: 0x6C5CE7, opacity: 0.10),
                dark: Color(hex: 0x000000, opacity: 0.40)
            ),
            radius: 20,
            y: 8
        )

        /// High elevation — floating panels, popovers, the tab bar.
        static let floating = DSShadowStyle(
            color: Color(
                light: Color(hex: 0x6C5CE7, opacity: 0.16),
                dark: Color(hex: 0x000000, opacity: 0.50)
            ),
            radius: 32,
            y: 14
        )

        /// Coloured glow for brand elements (primary buttons, hero cards,
        /// accent icons). Pass the element's fill colour.
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
