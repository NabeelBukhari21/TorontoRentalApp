//
//  PurrpertyLogo.swift
//  RentalApp (Purrperty)
//
//  Brand — The Purrperty logo: Purr the cat in front of its neighbourhood.
//
//  The mascot sits on a little street of homes — a gold house with a blush
//  roof, a cherry condo and a sky tower behind it (a nod to Toronto's
//  skyline), and a cream house with a mint roof — on a rainbow ground
//  line. Friendly first, but it still says "property" at a glance.
//
//  It can BUILD ITSELF: the ground line draws, the homes pop up one after
//  another with springy overshoot, windows light up, and the cat hops in.
//  The splash uses that; everywhere else shows the finished logo.
//
//  Ships in three forms: the mark, the tile (app-icon style), and the
//  wordmark. Everything outside this file only uses those three names, so
//  the art can evolve here without touching any screen.
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
    static let cherryDeep = Color(hex: 0xB02727)
    static let blush      = Color(hex: 0xF07870)
    static let gold       = Color(hex: 0xF2B83A)
    static let goldLight  = Color(hex: 0xFFE6A8)
    static let honey      = Color(hex: 0xFFD27A)
    static let ember      = Color(hex: 0xB4501E)
    static let mint       = Color(hex: 0x2ED8A3)
    static let sky        = Color(hex: 0x4DA8FF)
    static let ink        = Color(hex: 0x2B1712)
    static let white      = Color(hex: 0xFFFFFF)

    // House walls — pale accents, so the roofs and Purr stay the most
    // colourful things in the logo.
    static let wallGold  = Color(hex: 0xFFE9A6)
    static let wallMint  = Color(hex: 0xC4F2E3)
    static let wallCream = Color(hex: 0xFFF1DA)
    static let wallBlush = Color(hex: 0xFDE0DA)
}

// MARK: - Geometry

/// Where everything sits, as fractions of the mark's side. Shared with the
/// app-icon renderer, so the icon and the in-app logo match.
enum PurrpertyLogoGeometry {
    /// Raised from the bottom so the whole scene — tower tops to the cat's
    /// shadow — sits optically centred in a square (tile and app icon).
    static let groundY: CGFloat = 0.85
    static let catSize: CGFloat = 0.72

    struct House {
        let centerX: CGFloat
        let width: CGFloat
        let bodyHeight: CGFloat
        let roofHeight: CGFloat
    }

    static let leftHouse  = House(centerX: 0.165, width: 0.28, bodyHeight: 0.23, roofHeight: 0.15)
    static let rightHouse = House(centerX: 0.835, width: 0.26, bodyHeight: 0.21, roofHeight: 0.14)

    /// Cherry condo, behind the cat's left ear.
    static let condoCenterX: CGFloat = 0.31
    static let condoWidth: CGFloat = 0.19
    static let condoHeight: CGFloat = 0.62

    /// Shorter sky tower behind the right shoulder — balances the skyline.
    static let towerCenterX: CGFloat = 0.69
    static let towerWidth: CGFloat = 0.16
    static let towerHeight: CGFloat = 0.47
}

// MARK: - Logo Mark

/// The cat in front of its neighbourhood. Pure vector homes + the mascot.
struct PurrpertyLogoMark: View {

    /// Side of the mark's square canvas.
    var size: CGFloat = 120
    /// Ambient life: twinkling windows, a breathing cat. Off for tiny uses.
    var animates: Bool = true
    /// When false the scene is empty; flipping it to true plays the build:
    /// ground → homes → windows → cat. Leave true to show it finished.
    var isBuilt: Bool = true
    /// Overrides the cat's mood once built — the splash uses `.cheer` for
    /// its finale. Defaults to happy.
    var celebrates: Bool = false
    /// The skyline alone — for places where the mascot is already on screen
    /// in its own right (onboarding), so there aren't two cats.
    var showsCat: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias G = PurrpertyLogoGeometry
    private var catMood: PurrMood {
        guard isBuilt else { return .dashboard }
        return celebrates ? .celebrate : .dashboard
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ground

            tower(centerX: G.condoCenterX, width: G.condoWidth, height: G.condoHeight,
                  top: PurrpertyBrand.blush, bottom: PurrpertyBrand.cherry,
                  cap: PurrpertyBrand.cherryDeep, rows: 5, order: 0)

            tower(centerX: G.towerCenterX, width: G.towerWidth, height: G.towerHeight,
                  top: PurrpertyBrand.honey, bottom: PurrpertyBrand.sky,
                  cap: PurrpertyBrand.ember, rows: 4, order: 1)

            house(G.leftHouse, wall: PurrpertyBrand.wallGold, roof: PurrpertyBrand.blush,
                  door: PurrpertyBrand.cherry, order: 2)

            // Mint roof, not sky: the sky tower stands right behind it.
            house(G.rightHouse, wall: PurrpertyBrand.wallCream, roof: PurrpertyBrand.mint,
                  door: PurrpertyBrand.blush, order: 3)

            if showsCat {
                cat
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Purrperty")
    }

    // MARK: Pieces

    private var ground: some View {
        PurrpertyGroundLine()
            .trim(from: 0, to: isBuilt ? 1 : 0)
            .stroke(
                LinearGradient(
                    colors: [PurrpertyBrand.blush, PurrpertyBrand.gold, PurrpertyBrand.mint, PurrpertyBrand.sky, PurrpertyBrand.cherry],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: max(size * 0.028, 1.5), lineCap: .round)
            )
            .frame(width: size * 0.92, height: 1)
            .position(x: size * 0.5, y: size * G.groundY)
            .animation(entrance(order: -1, duration: 0.55), value: isBuilt)
    }

    private func house(_ h: G.House, wall: Color, roof: Color, door: Color, order: Int) -> some View {
        PurrpertyToyHouse(
            width: size * h.width,
            bodyHeight: size * h.bodyHeight,
            roofHeight: size * h.roofHeight,
            wall: wall, roof: roof, door: door,
            windowsLit: isBuilt,
            animates: animates && !reduceMotion
        )
        .scaleEffect(x: 1, y: isBuilt ? 1 : 0.01, anchor: .bottom)
        .opacity(isBuilt ? 1 : 0)
        .animation(entrance(order: order), value: isBuilt)
        .position(
            x: size * h.centerX,
            // Matches the house's real frame (`bodyHeight + roofHeight * 0.92`),
            // so the walls sit exactly on the ground line.
            y: size * G.groundY - size * (h.bodyHeight + h.roofHeight * 0.92) / 2
        )
    }

    private func tower(
        centerX: CGFloat, width: CGFloat, height: CGFloat,
        top: Color, bottom: Color, cap: Color, rows: Int, order: Int
    ) -> some View {
        PurrpertyCondo(
            width: size * width,
            height: size * height,
            top: top, bottom: bottom, cap: cap, rows: rows,
            animates: animates && !reduceMotion,
            isLit: isBuilt
        )
        .scaleEffect(x: 1, y: isBuilt ? 1 : 0.01, anchor: .bottom)
        .opacity(isBuilt ? 1 : 0)
        .animation(entrance(order: order), value: isBuilt)
        .position(x: size * centerX, y: size * G.groundY - size * height / 2)
    }

    private var cat: some View {
        let catSide = size * G.catSize
        // Align Purr's feet (97% down his canvas) with the ground line.
        let top = size * G.groundY - catSide * 0.97
        return PurrMascot(mood: catMood, size: catSide, isInteractive: false)
        .offset(y: isBuilt ? 0 : size * 0.35)
        .opacity(isBuilt ? 1 : 0)
        .animation(entrance(order: 4, duration: 0.6), value: isBuilt)
        .position(x: size * 0.5, y: top + catSide / 2)
    }

    /// Staggered springy entrances; a plain fade under Reduce Motion.
    private func entrance(order: Int, duration: Double = 0.5) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.3) }
        let delay = order < 0 ? 0 : 0.18 + Double(order) * 0.13
        return .spring(response: duration, dampingFraction: 0.62).delay(delay)
    }
}

// MARK: - Toy House

/// A rounded, toy-like house: gable roof with overhang, a door, a window.
private struct PurrpertyToyHouse: View {

    let width: CGFloat
    let bodyHeight: CGFloat
    let roofHeight: CGFloat
    let wall: Color
    let roof: Color
    let door: Color
    var windowsLit: Bool
    var animates: Bool

    var body: some View {
        VStack(spacing: -roofHeight * 0.08) {
            PurrpertyGableRoof()
                .fill(LinearGradient(colors: [roof.opacity(0.82), roof], startPoint: .top, endPoint: .bottom))
                .frame(width: width * 1.14, height: roofHeight)
                .zIndex(1)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
                    .fill(wall)
                    // A whisper of shade toward the ground, so the flat homes
                    // sit closer to the soft, rendered look of the cat.
                    .overlay(
                        LinearGradient(
                            colors: [.clear, PurrpertyBrand.ink.opacity(0.07)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: width * 0.07, style: .continuous))
                    )

                HStack(alignment: .bottom, spacing: width * 0.12) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: width * 0.12,
                        topTrailingRadius: width * 0.12,
                        style: .continuous
                    )
                    .fill(door)
                    .frame(width: width * 0.24, height: bodyHeight * 0.52)

                    PurrpertyWindow(
                        size: width * 0.24,
                        lit: windowsLit,
                        animates: animates,
                        duration: 1.9,
                        delay: Double(width.truncatingRemainder(dividingBy: 7)) * 0.1
                    )
                    .padding(.bottom, bodyHeight * 0.34)
                }
            }
            .frame(width: width, height: bodyHeight)
        }
        .frame(width: width * 1.14, height: bodyHeight + roofHeight * 0.92)
    }
}

/// A straight line, left to right, so `trim` draws it in that direction.
/// (A `Capsule` would trace its whole outline and appear to run back.)
private struct PurrpertyGroundLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// A gable roof with a softened ridge.
private struct PurrpertyGableRoof: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let ridge = CGPoint(x: rect.midX, y: rect.minY)
        let soft = rect.width * 0.05
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: ridge.x - soft, y: ridge.y + soft * 0.9))
        p.addQuadCurve(to: CGPoint(x: ridge.x + soft, y: ridge.y + soft * 0.9), control: ridge)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Condo

/// A slim tower with a grid of twinkling windows.
private struct PurrpertyCondo: View {

    let width: CGFloat
    let height: CGFloat
    var top: Color
    var bottom: Color
    var cap: Color
    var rows: Int
    var animates: Bool
    var isLit: Bool

    private let columns = 2

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))

            // Roof cap.
            Capsule()
                .fill(cap)
                .frame(width: width * 0.5, height: width * 0.12)
                .offset(y: -width * 0.06)

            VStack(spacing: width * 0.14) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: width * 0.18) {
                        ForEach(0..<columns, id: \.self) { column in
                            PurrpertyWindow(
                                size: width * 0.22,
                                lit: isLit,
                                animates: animates,
                                duration: 1.3 + Double((row + column) % 3) * 0.5,
                                delay: Double((row * 3 + column * 5) % 7) * 0.25
                            )
                        }
                    }
                }
            }
            .padding(.top, width * 0.28)
        }
        .frame(width: width, height: height)
    }
}

/// A single window: white by day, warm sunny light when lit, with a slow
/// twinkle when animated.
private struct PurrpertyWindow: View {

    let size: CGFloat
    var lit: Bool
    var animates: Bool
    var duration: Double
    var delay: Double

    @State private var glow = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(lit ? PurrpertyBrand.goldLight : PurrpertyBrand.white)
            .frame(width: size, height: size)
            .shadow(color: PurrpertyBrand.gold.opacity(lit && glow ? 0.8 : 0), radius: size * 0.5)
            .opacity(lit ? (glow ? 1 : 0.82) : 0.9)
            .onAppear {
                guard animates else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
                    glow = true
                }
            }
    }
}

// MARK: - Logo Tile

/// The mark on a white app-icon-style tile with a soft pastel sky.
struct PurrpertyLogoTile: View {

    var size: CGFloat = 96
    var animates: Bool = true

    private var cornerRadius: CGFloat { size * 0.27 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PurrpertyBrand.white)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [PurrpertyBrand.wallBlush.opacity(0.75), PurrpertyBrand.white],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            PurrpertyLogoMark(size: size * 0.92, animates: animates)
                .offset(y: size * 0.02)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(PurrpertyBrand.cherry.opacity(0.12), lineWidth: 1)
        )
        .dsShadow(DS.Shadows.glow(PurrpertyBrand.cherry, intensity: 0.22))
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
            PurrpertyLogoTile(size: 64)
        }
        PurrpertyWordmark()
    }
    .padding()
    .background(DS.Colors.background)
}

#Preview("Logo builds") {
    struct Demo: View {
        @State private var built = false
        var body: some View {
            VStack(spacing: DS.Spacing.xl) {
                PurrpertyLogoMark(size: 240, isBuilt: built)
                DSButton(title: built ? "Reset" : "Build", variant: .primary) { built.toggle() }
            }
            .padding()
            .background(DS.Colors.background)
        }
    }
    return Demo()
}
