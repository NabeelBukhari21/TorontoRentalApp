//
//  DSColors.swift
//  RentalApp
//
//  Design System — Colour palette.
//  Bright, playful, white-first. Adaptive light/dark.
//
//  ─────────────────────────────────────────────────────────────────
//  FILLS AND INKS: WHY EVERY ACCENT HAS TWO TOKENS
//  ─────────────────────────────────────────────────────────────────
//  The accent palette is bright on purpose — it is what makes the app
//  feel fun. But bright colours fail as TEXT on white. Measured against
//  WCAG AA (4.5:1 for body text):
//
//      Coral  #FF6B6B   2.78:1   ✗
//      Sunny  #FFD93D   1.38:1   ✗
//      Mint   #2ED8A3   1.83:1   ✗
//      Sky    #4DA8FF   2.51:1   ✗
//
//  So each accent comes as a pair:
//
//  • `accentX`     — the bright colour. Fills, gradients, chips' soft
//                    backgrounds, illustrations, confetti. Never text.
//  • `accentXInk`  — same hue, darkened until it passes AA on white, on
//                    the `surface` card colour, AND on its own 14% tint.
//                    Text, icons, and anything that must be read.
//
//  Text sitting ON a bright accent fill uses `textOnAccent` (dark ink),
//  which passes on all four (6.1–12.3:1).
//
//  Violet is the exception that makes the brand work: `#6C5CE7` passes
//  both as text on white (4.86:1) and under white text (4.86:1), so it
//  can be the CTA colour with white labels. Violet text on a violet TINT
//  does not pass (4.04:1) — use `brandInk` for that one case.
//
//  Every value below was checked; the ratios are recorded beside them.
//

import SwiftUI
import UIKit

/// Root namespace for all design-system tokens.
enum DS {}

// MARK: - Colour Initialisers

extension Color {

    /// Creates a colour from a hex value, e.g. `Color(hex: 0x6C5CE7)`.
    ///
    /// Use inside the design system only. A hex literal in a feature file
    /// is a colour the theme cannot reach.
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Creates an adaptive colour that resolves per light/dark appearance.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Palette

extension DS {

    enum Colors {

        // MARK: Brand — electric violet

        /// Primary brand colour and CTA fill. Passes as text on white
        /// (4.86) and on cards (4.54); white text on it passes (4.86).
        /// Dark mode lifts it so it still reads on dark surfaces (5.15+).
        static let brand = Color(
            light: Color(hex: 0x6C5CE7),
            dark: Color(hex: 0x8B7FF0)
        )

        /// Violet for text on a violet tint (selected chips, active tabs).
        /// `brand` itself drops to 4.04 there; this holds 5.04.
        static let brandInk = Color(
            light: Color(hex: 0x5A49E0),
            dark: Color(hex: 0xA99FF5)
        )

        // MARK: Accents — bright fills

        /// Coral fill. Not for text — see `accentCoralInk`.
        static let accentCoral = Color(
            light: Color(hex: 0xFF6B6B),
            dark: Color(hex: 0xFF7A7A)
        )

        /// Sunny fill. Not for text — see `accentSunnyInk`.
        static let accentSunny = Color(
            light: Color(hex: 0xFFD93D),
            dark: Color(hex: 0xFFD93D)
        )

        /// Mint fill. Not for text — see `accentMintInk`.
        static let accentMint = Color(
            light: Color(hex: 0x2ED8A3),
            dark: Color(hex: 0x2ED8A3)
        )

        /// Sky fill. Not for text — see `accentSkyInk`.
        static let accentSky = Color(
            light: Color(hex: 0x4DA8FF),
            dark: Color(hex: 0x4DA8FF)
        )

        /// The end stop of the hero gradient, chosen against the text that
        /// sits on it (`textOnBrand`):
        ///
        /// • Light: deep sky #2A6BD4 — white text 5.06. Plain sky under
        ///   white text is 2.51.
        /// • Dark: plain sky #4DA8FF — dark ink 7.50. The deep sky would
        ///   carry dark-mode ink at only 3.72.
        static let accentSkyDeep = Color(
            light: Color(hex: 0x2A6BD4),
            dark: Color(hex: 0x4DA8FF)
        )

        // MARK: Accents — inks (text & icons)

        /// Coral for text/icons. 6.14 on white · 5.74 on card · 5.33 on its
        /// bright tint · 4.61 on a tint of itself over a card (the tightest
        /// pairing the app uses — `category.tint.opacity(0.13)` chips).
        static let accentCoralInk = Color(
            light: Color(hex: 0xB72D28),
            dark: Color(hex: 0xFF8A8A)
        )

        /// Sunny for text/icons. 6.04 on white · 5.64 on card · 5.77 on
        /// bright tint · 4.65 on self-tint over a card.
        static let accentSunnyInk = Color(
            light: Color(hex: 0x885900),
            dark: Color(hex: 0xFFD93D)
        )

        /// Mint for text/icons. 6.11 on white · 5.71 on card · 5.59 on
        /// bright tint · 4.68 on self-tint over a card.
        static let accentMintInk = Color(
            light: Color(hex: 0x116F57),
            dark: Color(hex: 0x3EE0AE)
        )

        /// Sky for text/icons. 6.12 on white · 5.72 on card · 5.43 on
        /// bright tint · 4.66 on self-tint over a card.
        static let accentSkyInk = Color(
            light: Color(hex: 0x0B60BE),
            dark: Color(hex: 0x6BB8FF)
        )

        // MARK: Surfaces

        /// App background — pure white.
        static let background = Color(
            light: Color(hex: 0xFFFFFF),
            dark: Color(hex: 0x0F1020)
        )

        /// Cards and grouped content.
        static let surface = Color(
            light: Color(hex: 0xF6F7FB),
            dark: Color(hex: 0x1A1B2E)
        )

        /// Raised surface — white cards that sit ON coloured or ambient
        /// backgrounds, floating pills, controls inside `surface` cards,
        /// sheets. Separated from the background by shadow and hairline.
        ///
        /// Dark #222439 keeps `brand` text at 4.63; the first pick, #24263D,
        /// sat at exactly 4.50.
        static let surfaceRaised = Color(
            light: Color(hex: 0xFFFFFF),
            dark: Color(hex: 0x222439)
        )

        /// Secondary surface — input fields, tracks, inactive segments.
        ///
        /// The same value as `surface` in light mode, deliberately.
        ///
        /// Fields carry secondary text and violet labels. The first pick,
        /// #EEF0F7, looked better and failed both (4.31 / 4.27). #F5F6FA
        /// got secondary text to 4.54 but violet only to 4.498 — rounds to
        /// 4.50, still under the line. #F6F7FB is the darkest grey where
        /// both pass (4.58 / 4.54). Fields are told apart from cards by their
        /// `outline` border rather than by fill; on white surfaces they read
        /// as soft grey wells. Dark mode keeps a distinct value.
        static let surfaceSecondary = Color(
            light: Color(hex: 0xF6F7FB),
            dark: Color(hex: 0x202238)
        )

        /// Hairline separators and outlines.
        static let outline = Color(
            light: Color(hex: 0x1B1B2F, opacity: 0.08),
            dark: Color(hex: 0xFFFFFF, opacity: 0.10)
        )

        /// Unfilled tracks: progress bars, inactive page dots, empty meter
        /// segments. Darker than `surfaceSecondary`, which is too close to
        /// white to read as a track (it is tuned for text contrast).
        static let track = Color(
            light: Color(hex: 0x1B1B2F, opacity: 0.10),
            dark: Color(hex: 0xFFFFFF, opacity: 0.14)
        )

        /// A light-on-colour hairline: highlight edges on gradient cards,
        /// rings around avatars on colourful backgrounds.
        static let highlightLine = Color(hex: 0xFFFFFF, opacity: 0.45)

        /// Dimming scrim behind media overlays and modal content.
        static let scrim = Color(hex: 0x1B1B2F, opacity: 0.45)

        /// Behind full-screen photos and video. Black in both modes —
        /// media viewers are dark everywhere, so photos aren't framed by
        /// glare. Pair with `onFixedColor`.
        static let mediaBackground = Color(hex: 0x000000)

        // MARK: Text

        /// Ink. 16.88 on white · 15.76 on card.
        static let textPrimary = Color(
            light: Color(hex: 0x1B1B2F),
            dark: Color(hex: 0xF4F5FA)
        )

        /// 4.90 on white · 4.58 on card.
        static let textSecondary = Color(
            light: Color(hex: 0x6B7085),
            dark: Color(hex: 0xA9ADC1)
        )

        /// Same value as `textSecondary`, deliberately.
        ///
        /// A lighter grey reads as "tertiary", but no grey lighter than
        /// #6B7085 passes AA on the #F6F7FB cards (#71768B manages 4.20).
        /// Hierarchy between secondary and tertiary now comes from size
        /// and weight rather than from a contrast drop users can't read.
        static let textTertiary = Color(
            light: Color(hex: 0x6B7085),
            dark: Color(hex: 0xA9ADC1)
        )

        /// Text on `brand` fills and the hero gradient.
        ///
        /// White in light mode (4.86 on violet). Dark ink in dark mode,
        /// because the lifted dark-mode violet is too light for white
        /// (3.29 ✗) but carries dark ink at 5.73.
        static let textOnBrand = Color(
            light: Color(hex: 0xFFFFFF),
            dark: Color(hex: 0x0F1020)
        )

        /// Text on bright accent fills (coral, sunny, mint, sky) and the
        /// warm and fresh gradients. 6.08–12.25 across all four.
        static let textOnAccent = Color(hex: 0x1B1B2F)

        /// White that does NOT adapt — for content on fixed, non-adaptive
        /// colour fills such as org monograms and photo placeholders, which
        /// stay the same colour in dark mode and so need the same ink.
        static let onFixedColor = Color(hex: 0xFFFFFF)

        /// Ink on `highlight` fills — sent message bubbles, unread pills,
        /// selected chips. Highlight is the brand violet pair, so this is
        /// the same rule as `textOnBrand`: white in light mode (4.86–6.06),
        /// dark ink in dark mode, where white on the lifted violet is 3.29.
        static let onHighlight = textOnBrand

        // MARK: Status
        //
        // Status colours are the accent INKS, because their main job is
        // text and icons on their own tint (badges, banners, toasts). Each
        // passes AA on its tint — see `DSStatusKind.tint`.

        static let success = accentMintInk
        static let warning = accentSunnyInk
        static let danger  = accentCoralInk
        static let info    = accentSkyInk

        static let neutral = Color(
            light: Color(hex: 0x6B7085),
            dark: Color(hex: 0xA9ADC1)
        )
    }
}

// MARK: - Theme Swatches

extension DS.Colors {

    /// The light and dark palettes as FIXED colours, for the theme picker's
    /// preview tiles. Those tiles must show what Light and Dark look like
    /// regardless of which mode is active — an adaptive token would make the
    /// "Dark" tile render light while you're in light mode. Values mirror
    /// `background` / `surface` / `brand` above; keep them in step.
    enum ThemeSwatch {
        static let lightBackground = Color(hex: 0xFFFFFF)
        static let lightSurface    = Color(hex: 0xF6F7FB)
        static let lightAccent     = Color(hex: 0x6C5CE7)
        static let darkBackground  = Color(hex: 0x0F1020)
        static let darkSurface     = Color(hex: 0x1A1B2E)
        static let darkAccent      = Color(hex: 0x8B7FF0)
    }
}

// MARK: - Partner Brands

extension DS.Colors {

    /// Other companies' brand colours, for their marks only (e.g. "Sign in
    /// with Google"). They are not part of this theme and must never be
    /// retuned to match it — partner guidelines fix them — but they still
    /// live here so no hex literal sits in a feature file.
    enum Partner {
        static let googleBlue  = Color(hex: 0x4285F4)
        static let googleGreen = Color(hex: 0x34A853)
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

    /// Foreground — text, icons, dots. AA on `tint`.
    var color: Color {
        switch self {
        case .success: DS.Colors.success
        case .warning: DS.Colors.warning
        case .danger: DS.Colors.danger
        case .info: DS.Colors.info
        case .neutral: DS.Colors.neutral
        }
    }

    /// The bright accent behind this status. For solid fills and glows.
    var fill: Color {
        switch self {
        case .success: DS.Colors.accentMint
        case .warning: DS.Colors.accentSunny
        case .danger: DS.Colors.accentCoral
        case .info: DS.Colors.accentSky
        case .neutral: DS.Colors.textSecondary
        }
    }

    /// Soft tinted background for pills and badges.
    ///
    /// Tinted from the BRIGHT accent rather than the ink, so badges read as
    /// candy-coloured rather than muddy. The ink foreground was measured
    /// against exactly this 14% blend.
    var tint: Color { fill.opacity(0.14) }
}

// MARK: - Accent

/// One of the five brand colours, as a unit.
///
/// Used to give categories (document types, search kinds, settings
/// sections, maintenance priorities…) their own colour, without each one
/// reinventing which shade to use for which job.
enum DSAccent: CaseIterable, Sendable {
    case violet
    case coral
    case sunny
    case mint
    case sky

    /// Bright colour — fills, gradients, illustrations.
    var fill: Color {
        switch self {
        case .violet: DS.Colors.brand
        case .coral:  DS.Colors.accentCoral
        case .sunny:  DS.Colors.accentSunny
        case .mint:   DS.Colors.accentMint
        case .sky:    DS.Colors.accentSky
        }
    }

    /// AA-safe foreground — text and icons on white, cards, or `tint`.
    var ink: Color {
        switch self {
        case .violet: DS.Colors.brandInk
        case .coral:  DS.Colors.accentCoralInk
        case .sunny:  DS.Colors.accentSunnyInk
        case .mint:   DS.Colors.accentMintInk
        case .sky:    DS.Colors.accentSkyInk
        }
    }

    /// Soft background for chips, badges and icon wells.
    var tint: Color { fill.opacity(0.14) }

    /// Text that sits on `fill`.
    var onFill: Color {
        switch self {
        case .violet: DS.Colors.textOnBrand
        case .coral, .sunny, .mint, .sky: DS.Colors.textOnAccent
        }
    }
}
