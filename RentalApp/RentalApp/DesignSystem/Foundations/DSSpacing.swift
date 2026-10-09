//
//  DSSpacing.swift
//  RentalApp
//
//  Design System — Spacing & corner radius scales.
//  All layout paddings and radii must come from these tokens.
//

import SwiftUI

extension DS {

    // MARK: - Spacing (4pt base grid)

    enum Spacing {
        /// 2pt — hairline gaps.
        static let xxs: CGFloat = 2
        /// 4pt — icon-to-text gaps.
        static let xs: CGFloat = 4
        /// 8pt — tight internal spacing.
        static let sm: CGFloat = 8
        /// 12pt — default internal spacing.
        static let md: CGFloat = 12
        /// 16pt — card padding, screen edge insets.
        static let lg: CGFloat = 16
        /// 20pt — comfortable card padding.
        static let xl: CGFloat = 20
        /// 24pt — section spacing.
        static let xxl: CGFloat = 24
        /// 32pt — large section breaks.
        static let xxxl: CGFloat = 32
        /// 48pt — hero spacing.
        static let huge: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        /// 8pt — small controls, chips.
        static let sm: CGFloat = 8
        /// 12pt — text fields, buttons.
        static let md: CGFloat = 12
        /// 16pt — standard cards.
        static let lg: CGFloat = 16
        /// 22pt — large floating cards, sheets.
        static let xl: CGFloat = 22
        /// 28pt — hero panels.
        static let xxl: CGFloat = 28
    }
}
