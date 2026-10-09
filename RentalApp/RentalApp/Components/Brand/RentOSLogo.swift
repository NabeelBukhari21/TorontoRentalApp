//
//  RentOSLogo.swift
//  RentalApp (RentOS)
//
//  Brand — The RentOS logo system, bright edition.
//
//  Same "Orbit Monolith" shape as before, recoloured for the playful
//  white-first theme: an electric-violet tower with twinkling white
//  windows, a sunny beacon on top, and a multi-colour orbit with a coral
//  satellite circling it.
//
//  INTERIM. A new logo is planned; this recolour keeps the app visually
//  consistent until it lands. When it does, everything outside this file
//  only references `RentOSLogoMark`, `RentOSLogoTile` and `RentOSWordmark`,
//  so it can be swapped here without touching any screen.
//
//  Ships in three forms: the mark, the tile, and the wordmark.
//

import SwiftUI

// MARK: - Brand Constants

/// The logo's own palette.
///
/// Fixed values rather than adaptive DS tokens on purpose: a logo should
/// look identical in light and dark mode. These mirror the DS light-mode
/// hues exactly, so the mark and the app always agree.
///
/// Logo-only. Screens must use `DS.Colors` — that is what lets the theme
/// reach them.
enum RentOSBrand {
    static let violet      = Color(hex: 0x6C5CE7)
    static let violetLight = Color(hex: 0x8F83F0)
    static let violetDeep  = Color(hex: 0x4B3BC9)
    static let coral       = Color(hex: 0xFF6B6B)
    static let sunny       = Color(hex: 0xFFD93D)
    static let sunnyLight  = Color(hex: 0xFFF0A8)
    static let mint        = Color(hex: 0x2ED8A3)
    static let sky         = Color(hex: 0x4DA8FF)
    static let skyDeep     = Color(hex: 0x2A6BD4)
    static let ink         = Color(hex: 0x1B1B2F)
    static let white       = Color(hex: 0xFFFFFF)

    /// The orbit's colour sweep, in order around the ring.
    static let orbitSweep: [Color] = [coral, sunny, mint, sky, violetLight, coral]
}

// MARK: - Logo Mark

/// The RentOS orbit-monolith mark. Pure vector — scales to any size.
struct RentOSLogoMark: View {

    /// Overall side length of the mark's square canvas.
    var size: CGFloat = 64
    /// Enables orbit, twinkle, and beacon pulse. Disable for tiny/static uses.
    var animates: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beaconPulses = false
    @State private var orbitAngle: Double = 200

    /// Animation is a decoration; Reduce Motion turns it off entirely.
    private var isAnimating: Bool { animates && !reduceMotion }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Orbit ring (behind the tower).
            orbitRing
                .offset(y: -size * 0.34)

            // The monolith.
            monolith
                .padding(.bottom, size * 0.1)

            // Crown beacon.
            beacon
                .offset(y: -size * 0.87)

            // Orbiting satellite (in front).
            satellite
                .offset(y: -size * 0.34)

            // Rainbow hover light under the tower.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [RentOSBrand.coral, RentOSBrand.sunny, RentOSBrand.mint, RentOSBrand.sky],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.62, height: size * 0.04)
                .blur(radius: size * 0.008)

            Capsule()
                .fill(RentOSBrand.violet.opacity(0.35))
                .frame(width: size * 0.44, height: size * 0.05)
                .blur(radius: size * 0.08)
                .offset(y: size * 0.02)
        }
        .frame(width: size, height: size, alignment: .bottom)
        .onAppear {
            guard isAnimating else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                beaconPulses = true
            }
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                orbitAngle += 360
            }
        }
    }

    // MARK: Monolith

    private var monolith: some View {
        RoundedRectangle(cornerRadius: size * 0.075, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [RentOSBrand.violetLight, RentOSBrand.violet, RentOSBrand.violetDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Glossy white edge light.
                RoundedRectangle(cornerRadius: size * 0.075, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                RentOSBrand.white.opacity(0.85),
                                RentOSBrand.white.opacity(0.30),
                                RentOSBrand.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(size * 0.014, 1)
                    )
            )
            .overlay(
                // Twinkling windows.
                VStack(spacing: size * 0.052) {
                    ForEach(0..<6, id: \.self) { row in
                        HStack(spacing: size * 0.05) {
                            windowDot(index: Double(row) * 2)
                            windowDot(index: Double(row) * 2 + 1)
                        }
                    }
                }
                .padding(.top, size * 0.1),
                alignment: .top
            )
            .frame(width: size * 0.34, height: size * 0.78)
            .shadow(color: RentOSBrand.violet.opacity(0.40), radius: size * 0.08, y: 2)
    }

    private func windowDot(index: Double) -> some View {
        RentOSWindow(
            size: size * 0.055,
            animates: isAnimating,
            duration: 1.3 + index.truncatingRemainder(dividingBy: 3) * 0.5,
            delay: index.truncatingRemainder(dividingBy: 5) * 0.4
        )
    }

    // MARK: Beacon

    private var beacon: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [RentOSBrand.sunnyLight, RentOSBrand.sunny],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.07, height: size * 0.07)
            .rotationEffect(.degrees(45))
            .shadow(
                color: RentOSBrand.sunny.opacity(beaconPulses ? 0.95 : 0.40),
                radius: beaconPulses ? size * 0.07 : size * 0.02
            )
            .scaleEffect(beaconPulses ? 1.2 : 0.85)
    }

    // MARK: Orbit

    private var orbitRing: some View {
        Ellipse()
            .strokeBorder(
                AngularGradient(colors: RentOSBrand.orbitSweep, center: .center),
                lineWidth: max(size * 0.016, 1)
            )
            .frame(width: size * 0.96, height: size * 0.30)
            .rotationEffect(.degrees(-12))
            .opacity(0.9)
    }

    private var satellite: some View {
        Circle()
            .fill(RentOSBrand.coral)
            .frame(width: size * 0.06, height: size * 0.06)
            .overlay(Circle().strokeBorder(RentOSBrand.white, lineWidth: max(size * 0.008, 0.5)))
            .shadow(color: RentOSBrand.coral.opacity(0.8), radius: size * 0.03)
            .offset(x: size * 0.46)
            .rotationEffect(.degrees(orbitAngle))
            .scaleEffect(y: 0.31)
            .rotationEffect(.degrees(-12))
            .frame(width: size, height: size * 0.3)
    }
}

/// A single twinkling window — white, with a sunny glow when lit.
private struct RentOSWindow: View {

    let size: CGFloat
    let animates: Bool
    let duration: Double
    let delay: Double

    @State private var isLit = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(isLit ? RentOSBrand.sunnyLight : RentOSBrand.white)
            .frame(width: size, height: size)
            .opacity(isLit ? 1.0 : 0.45)
            .shadow(color: RentOSBrand.sunny.opacity(isLit ? 0.7 : 0), radius: size * 0.4)
            .onAppear {
                guard animates else {
                    isLit = true
                    return
                }
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    isLit = true
                }
            }
    }
}

// MARK: - Logo Tile

/// The mark on a white app-icon-style tile with a soft rainbow glow.
///
/// White rather than coloured: the tower is violet, so a violet or
/// gradient tile would swallow it. White makes the tower the colour.
struct RentOSLogoTile: View {

    var size: CGFloat = 96
    var animates: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOffset: CGFloat = -1.2

    private var cornerRadius: CGFloat { size * 0.27 }
    private var isAnimating: Bool { animates && !reduceMotion }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(RentOSBrand.white)

            // Pastel glow pooling under the tower.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [RentOSBrand.sunny.opacity(0.28), RentOSBrand.sky.opacity(0.10), .clear],
                        center: UnitPoint(x: 0.5, y: 0.66),
                        startRadius: 0,
                        endRadius: size * 0.62
                    )
                )

            RentOSLogoMark(size: size * 0.64, animates: isAnimating)
                .offset(y: size * 0.06)

            // Glossy shimmer sweep.
            if isAnimating {
                LinearGradient(
                    colors: [.clear, RentOSBrand.white.opacity(0.55), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: size * 0.5)
                .rotationEffect(.degrees(18))
                .offset(x: shimmerOffset * size)
                .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(RentOSBrand.violet.opacity(0.12), lineWidth: 1)
        )
        .dsShadow(DS.Shadows.glow(RentOSBrand.violet, intensity: 0.25))
        .onAppear {
            guard isAnimating else { return }
            withAnimation(
                .easeInOut(duration: 2.8)
                .repeatForever(autoreverses: false)
                .delay(0.6)
            ) {
                shimmerOffset = 1.2
            }
        }
    }
}

// MARK: - Wordmark

/// "RentOS" — "Rent" in ink, "OS" in a violet → sky gradient.
struct RentOSWordmark: View {

    var fontSize: CGFloat = 38
    /// Light "Rent" for use on a coloured or dark background. The launch
    /// screens are white now, so the default is the adaptive ink.
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text("Rent")
                .foregroundStyle(onDark ? AnyShapeStyle(RentOSBrand.white) : AnyShapeStyle(DS.Colors.textPrimary))

            // Violet 4.86 → deep sky 5.06 on white. Both ends pass AA even
            // as body text, so the wordmark holds at any size.
            Text("OS")
                .foregroundStyle(
                    LinearGradient(
                        colors: [RentOSBrand.violet, RentOSBrand.skyDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .font(.system(size: fontSize, weight: .heavy, design: .rounded))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RentOS")
    }
}

// MARK: - Previews

#Preview("RentOS Brand") {
    ZStack {
        SplashBackground()

        VStack(spacing: DS.Spacing.huge) {
            RentOSLogoTile(size: 120)
            RentOSLogoMark(size: 80)
            RentOSWordmark()
            RentOSWordmark(fontSize: 22)
        }
    }
}
