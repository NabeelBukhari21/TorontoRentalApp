//
//  DSColors.swift
//  RentalApp
//
//  Design System — Color palette.
//  Adaptive (light/dark) brand, surface, text, and status colors.
//

import SwiftUI
import UIKit

/// Root namespace for all design-system tokens.
enum DS {}

// MARK: - Color Initializers

extension Color {

    /// Creates a color from a hex value, e.g. `Color(hex: 0xD4AF37)`.
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Creates an adaptive color that resolves per light/dark appearance.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Palette

extension DS {

    enum Colors {

        // MARK: Brand (Obsidian & Champagne)

        /// Primary brand accent — muted champagne gold (#D4AF37 on dark).
        static let brand = Color(
            light: Color(hex: 0x9C7C1E),
            dark: Color(hex: 0xD4AF37)
        )

        /// Secondary accent — saffron (#FFB703 on dark). Premium-tier metrics,
        /// urgent flags, high-value highlights. (Historic name kept for API stability.)
        static let brandViolet = Color(
            light: Color(hex: 0xC98A00),
            dark: Color(hex: 0xFFB703)
        )

        /// Tertiary accent — polished platinum/titanium sheen. AI features.
        /// (Historic name kept for API stability.)
        static let brandCyan = Color(
            light: Color(hex: 0x6E7681),
            dark: Color(hex: 0xC7CDD6)
        )

        /// Warm accent — coral, used sparingly for highlights.
        static let accentCoral = Color(
            light: Color(hex: 0xE45C6E),
            dark: Color(hex: 0xFB7185)
        )

        /// Warm accent — saffron gold.
        static let accentAmber = Color(
            light: Color(hex: 0xC98A00),
            dark: Color(hex: 0xFFB703)
        )

        // MARK: Surfaces (Obsidian & Titanium)

        /// App background — warm ivory / pure obsidian (#121212 family).
        static let background = Color(
            light: Color(hex: 0xF7F6F2),
            dark: Color(hex: 0x0C0C0E)
        )

        /// Elevated surface — cards, sheets.
        static let surface = Color(
            light: Color(hex: 0xFFFFFF),
            dark: Color(hex: 0x1A1C21)
        )

        /// Secondary surface — polished titanium (#2A2D34 family).
        static let surfaceSecondary = Color(
            light: Color(hex: 0xEFEDE6),
            dark: Color(hex: 0x2A2D34)
        )

        /// Hairline separators and outlines.
        static let outline = Color(
            light: Color(hex: 0x0F172A, opacity: 0.08),
            dark: Color(hex: 0xFFFFFF, opacity: 0.10)
        )

        // MARK: Text

        static let textPrimary = Color(
            light: Color(hex: 0x161614),
            dark: Color(hex: 0xF5F4F0)
        )

        static let textSecondary = Color(
            light: Color(hex: 0x5A5A54),
            dark: Color(hex: 0xA8A89F)
        )

        static let textTertiary = Color(
            light: Color(hex: 0x98968C),
            dark: Color(hex: 0x70706A)
        )

        /// Text placed on top of brand gradients / filled buttons.
        static let textOnBrand = Color.white

        /// Ink for content sitting on champagne-gold fills (pills, sent bubbles).
        static let onGold = Color(hex: 0x121212)

        // MARK: Status

        static let success = Color(
            light: Color(hex: 0x10B981),
            dark: Color(hex: 0x34D399)
        )

        static let warning = Color(
            light: Color(hex: 0xF59E0B),
            dark: Color(hex: 0xFBBF24)
        )

        static let danger = Color(
            light: Color(hex: 0xEF4444),
            dark: Color(hex: 0xF87171)
        )

        static let info = Color(
            light: Color(hex: 0x3B82F6),
            dark: Color(hex: 0x60A5FA)
        )

        static let neutral = Color(
            light: Color(hex: 0x64748B),
            dark: Color(hex: 0x94A3B8)
        )
    }
}

// MARK: - Semantic Status

/// Shared semantic status used by badges, dots, chips, and cards.
enum DSStatusKind: CaseIterable {
    case success
    case warning
    case danger
    case info
    case neutral

    var color: Color {
        switch self {
        case .success: DS.Colors.success
        case .warning: DS.Colors.warning
        case .danger: DS.Colors.danger
        case .info: DS.Colors.info
        case .neutral: DS.Colors.neutral
        }
    }

    /// Soft tinted background for pills and badges.
    var tint: Color { color.opacity(0.14) }
}
