//
//  DSAccent.swift
//  RentalApp (Purrperty)
//
//  Design System — The user's accent colour.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY THE ACCENT IS A SHARED STORE, NOT AN ENVIRONMENT VALUE
//  ─────────────────────────────────────────────────────────────────
//  `DS.Colors.brand` is read in ~200 places, many of them helpers and
//  styles that have no access to the SwiftUI environment. Threading an
//  environment value through all of them would touch every feature for
//  no behavioural gain.
//
//  Instead `brand` and `brandInk` are computed from this store. The store
//  is `@Observable`, so any view body that reads `DS.Colors.brand` is
//  tracked by Observation and re-renders when the accent changes, with
//  no `.id()` resets and no lost navigation state.
//
//  Every accent pair below passes the same WCAG AA bar the violet does
//  (see DSColors.swift). Ratios are recorded beside each value:
//
//      brand on white / white on brand · brand on `surface` ·
//      ink on a 14% brand tint · dark brand on dark bg / dark ink on it
//

import SwiftUI
import Observation

// MARK: - Accent

enum AccentTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case violet
    case coral
    case mint
    case sky

    var id: String { rawValue }

    var title: String {
        switch self {
        case .violet: "Violet"
        case .coral:  "Coral"
        case .mint:   "Mint"
        case .sky:    "Sky"
        }
    }

    /// CTA fill and brand text. White labels sit on it in light mode,
    /// dark ink (`textOnBrand`) in dark mode.
    var brand: Color {
        switch self {
        // 4.86 · 4.54 · — · dark 5.73
        case .violet: Color(light: Color(hex: 0x6C5CE7), dark: Color(hex: 0x8B7FF0))
        // 5.34 · 4.99 · — · dark 7.51
        case .coral:  Color(light: Color(hex: 0xC92D40), dark: Color(hex: 0xFF7A85))
        // 5.31 · 4.96 · — · dark 10.28
        case .mint:   Color(light: Color(hex: 0x077A5E), dark: Color(hex: 0x2ED8A3))
        // 4.88 · 4.56 · — · dark 8.01
        case .sky:    Color(light: Color(hex: 0x1F6FD6), dark: Color(hex: 0x5AAEFF))
        }
    }

    /// Text on a brand tint (selected chips, active tabs).
    var brandInk: Color {
        switch self {
        // 5.04 on tint · dark 5.57
        case .violet: Color(light: Color(hex: 0x5A49E0), dark: Color(hex: 0xA99FF5))
        // 5.44 on tint · dark 6.23
        case .coral:  Color(light: Color(hex: 0xAE2536), dark: Color(hex: 0xFF9AA2))
        // 5.39 on tint · dark 7.30
        case .mint:   Color(light: Color(hex: 0x066A52), dark: Color(hex: 0x5FE3B9))
        // 5.14 on tint · dark 6.77
        case .sky:    Color(light: Color(hex: 0x1A5FBA), dark: Color(hex: 0x8CC6FF))
        }
    }

    /// The bright swatch shown in pickers. Decorative only — never text.
    var swatch: Color {
        switch self {
        case .violet: Color(hex: 0x6C5CE7)
        case .coral:  Color(hex: 0xFF6B6B)
        case .mint:   Color(hex: 0x2ED8A3)
        case .sky:    Color(hex: 0x4DA8FF)
        }
    }
}

// MARK: - Store

/// The accent in effect, persisted across launches.
///
/// `@unchecked Sendable`: written only from the main actor (the picker
/// and onboarding), read from view bodies. Colour reads off the main
/// actor would at worst see the previous accent for one frame.
@Observable
final class AccentStore: @unchecked Sendable {

    /// One accent for the whole app. A singleton for the same reason the
    /// `DS` tokens are static: colours are read where no container is in
    /// reach. See the note at the top of this file.
    static let shared = AccentStore()

    private static let storageKey = "appearance.accent.v1"

    @ObservationIgnored private let defaults: UserDefaults

    var accent: AccentTheme {
        didSet {
            guard accent != oldValue else { return }
            defaults.set(accent.rawValue, forKey: Self.storageKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.accent = defaults.string(forKey: Self.storageKey)
            .flatMap(AccentTheme.init(rawValue:)) ?? .violet
    }
}
