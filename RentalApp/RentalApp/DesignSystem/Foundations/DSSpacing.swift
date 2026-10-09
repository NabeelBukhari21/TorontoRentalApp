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
    //
    // Rounder than the previous theme across the board. Large radii read as
    // soft and approachable, which is the point of this palette; the old
    // values were tuned for crisp, jewel-like glass panels.

    enum Radius {
        /// 10pt — small controls, chips. (was 8)
        static let sm: CGFloat = 10
        /// 14pt — text fields, buttons. (was 12)
        static let md: CGFloat = 14
        /// 20pt — standard cards. (was 16)
        static let lg: CGFloat = 20
        /// 26pt — large floating cards, sheets. (was 22)
        static let xl: CGFloat = 26
        /// 32pt — hero panels. (was 28)
        static let xxl: CGFloat = 32
    }
}
