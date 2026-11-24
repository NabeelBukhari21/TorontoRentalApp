//
//  DSColors.swift
//  RentalApp
//
//  Design System — Colour palette.
//  Purr's colours: cherry red and gold on white, a warm cream for cards,
//  warm brown for text. Adaptive light/dark.
//
//  ─────────────────────────────────────────────────────────────────
//  FILLS AND INKS: WHY EVERY ACCENT HAS TWO TOKENS
//  ─────────────────────────────────────────────────────────────────
//  The bright accents are what make the app feel fun, but bright colours
//  fail as TEXT on white (WCAG AA is 4.5:1 for body text): gold #F2B83A
//  is 1.98, blush #F07870 2.74, mint 1.83, sky 2.51.
//
//  So each accent comes as a pair:
//
//  • `accentX`     — the bright colour. Fills, gradients, chips' soft
//                    backgrounds, illustrations, confetti. Never text.
//  • `accentXInk`  — same hue, darkened until it passes AA on white, on
//                    the cream `surface`, AND on its own 14% tint.
//                    Text, icons, and anything that must be read.
//
//  Text sitting ON a bright accent fill uses `textOnAccent` (warm ink),
//  6.2–9.5 on all four.
//
//  Cherry is the brand and the system tint (`AccentColor` asset): light
//  #CC2E2E carries white labels at 5.25 and reads as text at 5.25 on
//  white, 4.91 on cream. In dark mode no single red can carry white text
//  AND read as text on the near-black background, so the fill (#D63535,
//  white text 4.75) and the text colour (`brandInk`, #FF8A80, 8.08) part.
//
//  Ratios were measured (WCAG relative luminance) and are recorded beside
//  each value.
//

import SwiftUI
import UIKit

/// Root namespace for all design-system tokens.
enum DS {}

// MARK: - Colour Initialisers

extension Color {

    /// Creates a colour from a hex value, e.g. `Color(hex: 0xCC2E2E)`.
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

        // MARK: Brand — Purr's cherry red

        /// The system accent (the `AccentColor` asset, with dark and
        /// Increase Contrast variants): buttons, tints, selection, fills
        /// that carry white text. Light #CC2E2E · dark #D63535.
        static var brand: Color { .accentColor }

        /// Cherry for text and icons. Light: the brand itself (5.25 on
        /// white, 4.91 on cream); on its own tint use this darker #B02727
        /// (5.47). Dark: lifted #FF8A80 (8.08 on the background).
        static let brandInk = Color(
            light: Color(hex: 0xB02727),
            dark: Color(hex: 0xFF8A80)
        )

        /// Deeper cherry, for the far end of brand gradients. Same in both
        /// modes because it carries white labels (6.63); `brandInk` is light
        /// in dark mode and must never sit under white.
        static let brandDeep = Color(hex: 0xB02727)

        // MARK: Accents — bright fills

        /// Purr's gold. Not for text — see `accentGoldInk`.
        static let accentGold = Color(
            light: Color(hex: 0xF2B83A),
            dark: Color(hex: 0xF2B83A)
        )

        /// Purr's blush, the pink of his cheeks. Not for text — see
        /// `accentBlushInk`.
        static let accentBlush = Color(
            light: Color(hex: 0xF07870),
            dark: Color(hex: 0xFF8A80)
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

        /// The end stop of the hero gradient (cherry → ember), chosen
        /// against the white text on it: ember #B4501E is 5.11 in light
        /// mode; dark mode ends on the dark brand red, 4.75.
        static let accentEmber = Color(
            light: Color(hex: 0xB4501E),
            dark: Color(hex: 0xB4501E)
        )

        // MARK: Accents — inks (text & icons)

        /// Gold for text/icons. 6.31 on white · 5.90 on cream · 5.48 on
        /// its tint over cream. Dark #FFC94D: 12.05 on the background.
        static let accentGoldInk = Color(
            light: Color(hex: 0x855600),
            dark: Color(hex: 0xFFC94D)
        )

        /// Blush (rose) for text/icons; also `danger`. 5.86 on white ·
        /// 5.48 on cream · 4.83 on its tint over cream. Dark #FF9A90: 9.03.
        static let accentBlushInk = Color(
            light: Color(hex: 0xB23A44),
            dark: Color(hex: 0xFF9A90)
        )

        /// Mint for text/icons. 6.11 on white · 5.72 on cream · 5.25 on
        /// its tint over cream. Dark: 10.97.
        static let accentMintInk = Color(
            light: Color(hex: 0x116F57),
            dark: Color(hex: 0x3EE0AE)
        )

        /// Sky for text/icons. 6.12 on white · 5.73 on cream · 5.10 on its
        /// tint over cream. Dark: 8.72.
        static let accentSkyInk = Color(
            light: Color(hex: 0x0B60BE),
            dark: Color(hex: 0x6BB8FF)
        )

        // MARK: Surfaces

        /// The launch frame: Purr's cream. Also the system launch screen
        /// (`UILaunchScreen` in Info.plist), so the hand-off from the
        /// system to the launch animation can't be seen.
        static let launchBackground = Color("LaunchBackground")

        /// App background — pure white; warm near-black in dark mode.
        static let background = Color(
            light: Color(hex: 0xFFFFFF),
            dark: Color(hex: 0x1A1210)
        )

        /// Cards and grouped content — a warm cream, Purr's fur.
        static let surface = Color(
            light: Color(hex: 0xFFF6EC),
            dark: Color(hex: 0x261A17)
        )

        /// Raised surface — white cards that sit ON coloured or ambient
        /// backgrounds, floating pills, controls inside `surface` cards,
        /// sheets. Separated from the background by shadow and hairline.
        static let surfaceRaised = Color(
            light: Color(hex: 0xFFFFFF),
            dark: Color(hex: 0x2E201C)
        )

        /// Secondary surface — input fields, tracks, inactive segments.
        /// The same cream as `surface` in light mode, deliberately: every
        /// text colour passes on it (secondary 5.86, brand 4.91); fields
        /// are told apart from cards by their `outline` border.
        static let surfaceSecondary = Color(
            light: Color(hex: 0xFFF6EC),
            dark: Color(hex: 0x2A1D19)
        )

        /// Hairline separators and outlines.
        static let outline = Color(
            light: Color(hex: 0x2B1712, opacity: 0.09),
            dark: Color(hex: 0xFFFFFF, opacity: 0.10)
        )

        /// Unfilled tracks: progress bars, inactive page dots, empty meter
        /// segments. Darker than `surfaceSecondary`, which is too close to
        /// white to read as a track (it is tuned for text contrast).
        static let track = Color(
            light: Color(hex: 0x2B1712, opacity: 0.10),
            dark: Color(hex: 0xFFFFFF, opacity: 0.14)
        )

        /// A light-on-colour hairline: highlight edges on gradient cards,
        /// rings around avatars on colourful backgrounds.
        static let highlightLine = Color(hex: 0xFFFFFF, opacity: 0.45)

        /// Dimming scrim behind media overlays and modal content.
        static let scrim = Color(hex: 0x2B1712, opacity: 0.45)

        /// The soft contact shadow under Purr (and anything else that
        /// "stands" on the page). Brown-tinted on white; deeper in dark
        /// mode, where a light shadow would read as a glow.
        static let groundShadow = Color(
            light: Color(hex: 0x2B1712, opacity: 0.13),
            dark: Color(hex: 0x000000, opacity: 0.45)
        )

        /// Behind full-screen photos and video. Black in both modes —
        /// media viewers are dark everywhere, so photos aren't framed by
        /// glare. Pair with `onFixedColor`.
        static let mediaBackground = Color(hex: 0x000000)

        // MARK: Text

        /// Warm brown ink, from Purr's outline. 17.02 on white · 15.92 on
        /// cream. Dark #FBF1EA: 16.58.
        static let textPrimary = Color(
            light: Color(hex: 0x2B1712),
            dark: Color(hex: 0xFBF1EA)
        )

        /// 6.26 on white · 5.86 on cream. Dark #C2ADA4: 8.62 · 7.32 raised.
        static let textSecondary = Color(
            light: Color(hex: 0x765A52),
            dark: Color(hex: 0xC2ADA4)
        )

        /// Same value as `textSecondary`, deliberately: hierarchy between
        /// secondary and tertiary comes from size and weight, not from a
        /// contrast drop users can't read.
        static let textTertiary = Color(
            light: Color(hex: 0x765A52),
            dark: Color(hex: 0xC2ADA4)
        )

        /// Text on `brand` fills and the hero gradient: white in both
        /// modes (5.25 light, 4.75 on the dark-mode red).
        static let textOnBrand = Color.white

        /// Text on bright accent fills (gold, blush, mint, sky) and the
        /// warm and fresh gradients. 6.18–9.48 across all four.
        static let textOnAccent = Color(hex: 0x2B1712)

        /// White that does NOT adapt — for content on fixed, non-adaptive
        /// colour fills such as org monograms and photo placeholders, which
        /// stay the same colour in dark mode and so need the same ink.
        static let onFixedColor = Color(hex: 0xFFFFFF)

        /// Ink on `highlight` fills — sent message bubbles, unread pills,
        /// selected chips. Highlight is the brand red, so: white.
        static let onHighlight = textOnBrand

        // MARK: Status
        //
        // Status colours are the accent INKS, because their main job is
        // text and icons on their own tint (badges, banners, toasts). Each
        // passes AA on its tint — see `DSStatusKind.tint`.

        static let success = accentMintInk
        static let warning = accentGoldInk
        static let danger  = accentBlushInk
        static let info    = accentSkyInk

        /// Danger as a FILL under white text (5.86), the same in both
        /// modes: `danger` is a text colour and turns light in dark mode.
        static let dangerFill = Color(hex: 0xB23A44)

        static let neutral = Color(
            light: Color(hex: 0x765A52),
            dark: Color(hex: 0xC2ADA4)
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
        static let lightSurface    = Color(hex: 0xFFF6EC)
        static let lightAccent     = Color(hex: 0xCC2E2E)
        static let darkBackground  = Color(hex: 0x1A1210)
        static let darkSurface     = Color(hex: 0x261A17)
        static let darkAccent      = Color(hex: 0xD63535)
    }
}

// MARK: - Partner Brands

extension DS.Colors {

    /// Other companies' brand colours, for their marks only (e.g. "Sign in
    /// with Google"). They are not part of this theme and must never be
    /// retuned to match it — partner guidelines fix them — but they still
    /// live here so no hex literal sits in a feature file.
    enum Partner {
        /// Apple's logo: black on light, white on dark.
        static let appleMark = Color(light: Color(hex: 0x000000), dark: Color(hex: 0xFFFFFF))
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
        case .warning: DS.Colors.accentGold
        case .danger: DS.Colors.accentBlush
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

/// One of the five brand colours, as a unit: Purr's cherry, gold and
/// blush, plus mint and sky for calm and informational categories.
///
/// Used to give categories (document types, search kinds, settings
/// sections, maintenance priorities…) their own colour, without each one
/// reinventing which shade to use for which job.
enum DSAccent: CaseIterable, Sendable {
    case cherry
    case blush
    case gold
    case mint
    case sky

    /// Bright colour — fills, gradients, illustrations.
    var fill: Color {
        switch self {
        case .cherry: DS.Colors.brand
        case .blush:  DS.Colors.accentBlush
        case .gold:   DS.Colors.accentGold
        case .mint:   DS.Colors.accentMint
        case .sky:    DS.Colors.accentSky
        }
    }

    /// AA-safe foreground — text and icons on white, cards, or `tint`.
    var ink: Color {
        switch self {
        case .cherry: DS.Colors.brandInk
        case .blush:  DS.Colors.accentBlushInk
        case .gold:   DS.Colors.accentGoldInk
        case .mint:   DS.Colors.accentMintInk
        case .sky:    DS.Colors.accentSkyInk
        }
    }

    /// Soft background for chips, badges and icon wells.
    var tint: Color { fill.opacity(0.14) }

    /// Text that sits on `fill`.
    var onFill: Color {
        switch self {
        case .cherry: DS.Colors.textOnBrand
        case .blush, .gold, .mint, .sky: DS.Colors.textOnAccent
        }
    }
}
