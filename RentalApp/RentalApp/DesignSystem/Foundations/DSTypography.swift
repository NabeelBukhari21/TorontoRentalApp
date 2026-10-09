//
//  DSTypography.swift
//  RentalApp
//
//  Design System — Type scale.
//  Built on system text styles so Dynamic Type scales everything for free.
//

import SwiftUI

extension DS {

    enum Typography {

        // MARK: Display

        /// Hero numbers and splash moments.
        static let display = Font.system(.largeTitle, design: .rounded, weight: .heavy)

        /// Screen titles.
        static let title1 = Font.system(.title, design: .rounded, weight: .bold)

        /// Section titles.
        static let title2 = Font.system(.title2, design: .rounded, weight: .bold)

        /// Card titles.
        static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)

        // MARK: Body

        /// Emphasized row / list titles.
        static let headline = Font.system(.headline, weight: .semibold)

        /// Default reading text.
        static let body = Font.system(.body)

        /// Slightly smaller supporting text.
        static let callout = Font.system(.callout)

        /// Secondary labels.
        static let subheadline = Font.system(.subheadline, weight: .medium)

        // MARK: Small

        /// Metadata and timestamps.
        static let footnote = Font.system(.footnote)

        /// Badges, chips, and fine print.
        static let caption = Font.system(.caption, weight: .medium)

        /// Tiny all-caps labels (use with `.textCase(.uppercase)` + tracking).
        static let overline = Font.system(.caption2, weight: .semibold)

        // MARK: Numeric

        /// Large stat values — monospaced digits so counters don't jitter.
        static let statValue = Font.system(.title, design: .rounded, weight: .bold).monospacedDigit()

        /// Compact stat values inside cards.
        static let statValueSmall = Font.system(.title3, design: .rounded, weight: .bold).monospacedDigit()
    }
}

// MARK: - Convenience Text Styles

extension View {

    /// Tiny uppercase section label, e.g. "PORTFOLIO".
    func dsOverline() -> some View {
        self
            .font(DS.Typography.overline)
            .textCase(.uppercase)
            .kerning(1.1)
            .foregroundStyle(DS.Colors.textTertiary)
    }
}
