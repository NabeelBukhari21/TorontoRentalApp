//
//  PurrpertyLogo.swift
//  RentalApp (Purrperty)
//
//  Brand — The Purrperty logo, "Peek-a-roof": Purr peeking over a cherry
//  roof with a gold ridge and a little cream house below.
//
//  It ships as the app icon (`AppIcon.icon`, layered for Liquid Glass) and
//  in three in-app forms: the mark, the glass tile, and the wordmark. All
//  use the same two layers, made by tools/mascot/logo_icon.py.
//
//  The mark can BUILD ITSELF: the house rises, then Purr pops up behind
//  it. The launch uses that; everywhere else shows the finished logo.
//

import SwiftUI

// MARK: - Brand Constants

/// The logo's own palette.
///
/// Fixed values rather than adaptive DS tokens on purpose: a logo should
/// look identical in light and dark mode. Logo-only — screens use
/// `DS.Colors`.
enum PurrpertyBrand {
    static let cherry     = Color(hex: 0xE03838)
    static let blush      = Color(hex: 0xF07870)
    static let gold       = Color(hex: 0xF2B83A)
    static let honey      = Color(hex: 0xFFD27A)
    static let ember      = Color(hex: 0xB4501E)
    static let cream      = Color(hex: 0xFFF4E4)
    static let mint       = Color(hex: 0x2ED8A3)
    static let sky        = Color(hex: 0x4DA8FF)
    static let white      = Color(hex: 0xFFFFFF)
}

// MARK: - Logo Mark

/// Purr behind the roof. Live (he blinks and breathes) when `animates`.
struct PurrpertyLogoMark: View {

    /// Side of the mark's square canvas.
    var size: CGFloat = 120
    /// A live Purr. Off for tiny uses.
    var animates: Bool = true
    /// When false the canvas is empty; flipping it to true plays the build.
    var isBuilt: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the icon art puts Purr's canvas, as fractions of the mark.
    /// Mirrors `option_a` in tools/mascot/logo_icon.py.
    private enum Art {
        static let purrSide: CGFloat = 1.2012
        static let purrCenter = CGPoint(x: 0.4824, y: 0.4297)
        /// The eaves; everything of Purr below them is behind the house.
        static let eaves: CGFloat = 0.86
    }

    var body: some View {
        ZStack {
            purr
                .offset(y: isBuilt ? 0 : size * 0.5)
                .frame(width: size, height: size)
                .mask(alignment: .top) { Rectangle().frame(height: size * Art.eaves) }
                .opacity(isBuilt ? 1 : 0)
                .animation(entrance(delay: 0.3), value: isBuilt)

            Image("LogoRoof")
                .resizable()
                .scaleEffect(x: 1, y: isBuilt ? 1 : 0.01, anchor: .bottom)
                .opacity(isBuilt ? 1 : 0)
                .animation(entrance(delay: 0), value: isBuilt)
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Purrperty")
    }

    @ViewBuilder
    private var purr: some View {
        if animates {
            // The brand is always Classic, whichever look the user picked.
            PurrMascot(mood: .dashboard, size: size * Art.purrSide, isInteractive: false)
                .environment(\.purrStyle, .classic)
                .position(x: size * Art.purrCenter.x, y: size * Art.purrCenter.y)
        } else {
            Image("LogoPurr").resizable()
        }
    }

    private func entrance(delay: Double) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.3) }
        return .spring(response: 0.5, dampingFraction: 0.62).delay(delay)
    }
}

// MARK: - Logo Tile

/// The mark on its honey-cream tile under a sheet of Liquid Glass, like
/// the app icon.
struct PurrpertyLogoTile: View {

    var size: CGFloat = 96
    var animates: Bool = true
    var isBuilt: Bool = true

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: size * 0.235, style: .continuous) }

    var body: some View {
        PurrpertyLogoMark(size: size, animates: animates, isBuilt: isBuilt)
            .background(
                LinearGradient(colors: [PurrpertyBrand.cream, PurrpertyBrand.honey], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(shape)
            .glassEffect(.clear, in: shape)
            .shadow(color: PurrpertyBrand.ember.opacity(0.22), radius: size * 0.14, y: size * 0.06)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Purrperty")
    }
}

// MARK: - Wordmark

/// "Purrperty" — "Purr" (the mascot's name, the way Duo lives inside
/// Duolingo) in a cherry → ember gradient, "perty" in ink.
struct PurrpertyWordmark: View {

    var fontSize: CGFloat = 38
    /// Light "perty" for use on a coloured or dark background.
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Cherry 4.38 → ember 5.11 on white: passes AA at display sizes.
            Text(verbatim: "Purr")
                .foregroundStyle(
                    LinearGradient(
                        colors: [PurrpertyBrand.cherry, PurrpertyBrand.ember],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(verbatim: "perty")
                .foregroundStyle(onDark ? AnyShapeStyle(PurrpertyBrand.white) : AnyShapeStyle(DS.Colors.textPrimary))
        }
        // Fredoka, the brand face; a logo keeps its size, so no Dynamic Type.
        .font(DS.Typography.brandFixed(fontSize, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Purrperty"))
    }
}

// MARK: - Previews

#Preview("Logo") {
    VStack(spacing: DS.Spacing.xxl) {
        PurrpertyLogoMark(size: 220)
        HStack(spacing: DS.Spacing.xl) {
            PurrpertyLogoTile(size: 120)
            PurrpertyLogoTile(size: 64, animates: false)
        }
        PurrpertyWordmark()
    }
    .padding()
    .background(DS.Colors.background)
}
