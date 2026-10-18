//
//  AppStyle.swift
//  RentalApp (Purrperty)
//
//  AppStyle — The thin presentation layer that replaces the custom
//  design system. See docs/UI_REBUILD_PLAN.md.
//
//  ─────────────────────────────────────────────────────────────────
//  THE RULES (Human Interface Guidelines, Liquid Glass)
//  ─────────────────────────────────────────────────────────────────
//  • Colour: semantic system colours only. The single brand colour is
//    the `AccentColor` asset (violet), applied as the app's tint. It
//    has dark and Increase Contrast variants, so views never pick hex.
//  • Type: Dynamic Type text styles only (`.largeTitle` … `.caption2`).
//    No fixed point sizes.
//  • Icons: SF Symbols, named through `AppSymbol` for domain concepts.
//  • Materials: Liquid Glass comes from system bars, controls and
//    sheets. Custom floating controls use `.glassEffect`. Content never
//    sits on glass, and nothing imitates glass with blur or gradients.
//  • Layout: `List` / `Form` (inset grouped) first. A card is only for
//    content a list can't express, such as a chart tile on Home.
//
//  Prefer a system component over anything in this folder. Add here
//  only what several screens need and the system doesn't provide.
//

import SwiftUI
import UIKit

enum AppStyle {}

// MARK: - Backgrounds

extension Color {

    /// The canvas behind inset-grouped content (`List`, `Form`, Home).
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)

    /// A row or card sitting on `groupedBackground`.
    static let secondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)

    /// A nested element inside a card or row.
    static let tertiaryGroupedBackground = Color(uiColor: .tertiarySystemGroupedBackground)

    /// The plain canvas, for full-screen content that isn't grouped.
    static let plainBackground = Color(uiColor: .systemBackground)
}

// MARK: - Status

/// What a state *means*, mapped to a system colour and symbol. Feature
/// code picks a role ("this lease is overdue → critical"), never a colour.
enum StatusRole: Sendable, CaseIterable {
    case positive
    case caution
    case critical
    case informational
    case neutral

    var color: Color {
        switch self {
        case .positive:      .green
        case .caution:       .orange
        case .critical:      .red
        case .informational: .blue
        case .neutral:       .secondary
        }
    }

    var symbol: AppSymbol {
        switch self {
        case .positive:      .positive
        case .caution:       .caution
        case .critical:      .critical
        case .informational: .informational
        case .neutral:       .neutral
        }
    }
}
