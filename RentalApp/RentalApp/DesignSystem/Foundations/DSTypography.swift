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

        // MARK: Brand

        /// Fredoka, the brand face: the wordmark, the launch and the
        /// welcome screen. Bundled (`Resources/Fonts`, OFL) and scaled with
        /// Dynamic Type relative to `style`. Everything else stays on the
        /// system faces.
        static func brand(_ size: CGFloat, weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
            Font.custom("Fredoka", size: size, relativeTo: style).weight(weight)
        }

        /// Fixed-size Fredoka, for art that is laid out to the point (the
        /// launch animation), where scaling would break the composition.
        static func brandFixed(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            Font.custom("Fredoka", fixedSize: size).weight(weight)
        }

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
