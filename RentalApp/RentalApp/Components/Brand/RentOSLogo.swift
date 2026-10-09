//
//  RentOSLogo.swift
//  RentalApp (RentOS)
//
//  Brand — The RentOS logo system, obsidian & champagne edition.
//  An obsidian monolith tower with golden windows, crowned by a
//  pulsing gold beacon, with a satellite of light orbiting the
//  tower — the "OS" in RentOS, always in motion.
//
//  Ships in three forms: the mark, the tile, and the wordmark.
//

import SwiftUI

// MARK: - Brand Constants

enum RentOSBrand {
    static let gold = Color(hex: 0xD4AF37)
    static let goldDeep = Color(hex: 0x8C6D1F)
    static let saffron = Color(hex: 0xFFB703)
    static let champagne = Color(hex: 0xF5E7C1)
    static let platinum = Color(hex: 0xC7CDD6)
    static let titanium = Color(hex: 0x2A2D34)
    static let obsidian = Color(hex: 0x121212)
}

// MARK: - Logo Mark

/// The RentOS orbit-monolith mark. Pure vector — scales to any size.
struct RentOSLogoMark: View {

    /// Overall side length of the mark's square canvas.
    var size: CGFloat = 64
    /// Enables orbit, twinkle, and beacon pulse. Disable for tiny/static uses.
    var animates: Bool = true

    @State private var beaconPulses = false
    @State private var orbitAngle: Double = 200

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

            // Orbiting satellite of light (in front).
            satellite
                .offset(y: -size * 0.34)

            // Hover light under the monolith.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [RentOSBrand.goldDeep, RentOSBrand.gold, RentOSBrand.saffron],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.62, height: size * 0.04)
                .blur(radius: size * 0.008)

            Capsule()
                .fill(RentOSBrand.gold.opacity(0.5))
                .frame(width: size * 0.44, height: size * 0.05)
                .blur(radius: size * 0.08)
                .offset(y: size * 0.02)
        }
        .frame(width: size, height: size, alignment: .bottom)
        .onAppear {
            guard animates else { return }
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
                    colors: [Color(hex: 0x43474F), RentOSBrand.titanium, RentOSBrand.obsidian],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Champagne edge light — the signature accent line.
                RoundedRectangle(cornerRadius: size * 0.075, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                RentOSBrand.champagne.opacity(0.9),
                                RentOSBrand.gold.opacity(0.45),
                                RentOSBrand.goldDeep.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(size * 0.014, 1)
                    )
            )
            .overlay(
                // Golden windows.
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
            .shadow(color: RentOSBrand.gold.opacity(0.35), radius: size * 0.08, y: 2)

    }

    private func windowDot(index: Double) -> some View {
        RentOSWindow(
            size: size * 0.055,
            animates: animates,
            duration: 1.3 + index.truncatingRemainder(dividingBy: 3) * 0.5,
            delay: index.truncatingRemainder(dividingBy: 5) * 0.4
        )
    }

    // MARK: Beacon

    private var beacon: some View {
        ZStack {
            // Diamond crown.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [RentOSBrand.champagne, RentOSBrand.gold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.07, height: size * 0.07)
                .rotationEffect(.degrees(45))
                .shadow(
                    color: RentOSBrand.gold.opacity(beaconPulses ? 0.95 : 0.35),
                    radius: beaconPulses ? size * 0.07 : size * 0.02
                )
                .scaleEffect(beaconPulses ? 1.2 : 0.85)
        }
    }

    // MARK: Orbit

    private var orbitRing: some View {
        Ellipse()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        RentOSBrand.gold.opacity(0.0),
                        RentOSBrand.gold.opacity(0.75),
                        RentOSBrand.champagne.opacity(0.9),
                        RentOSBrand.gold.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: max(size * 0.012, 1)
            )
            .frame(width: size * 0.96, height: size * 0.30)
            .rotationEffect(.degrees(-12))
    }

    private var satellite: some View {
        ZStack {
            Circle()
                .fill(RentOSBrand.saffron)
                .frame(width: size * 0.055, height: size * 0.055)
                .shadow(color: RentOSBrand.saffron.opacity(0.9), radius: size * 0.03)
                .offset(x: size * 0.46)
        }
        .rotationEffect(.degrees(orbitAngle))
        .scaleEffect(y: 0.31)
        .rotationEffect(.degrees(-12))
        .frame(width: size, height: size * 0.3)
    }
}

/// A single twinkling golden window.
private struct RentOSWindow: View {

    let size: CGFloat
    let animates: Bool
    let duration: Double
    let delay: Double

    @State private var isLit = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(RentOSBrand.champagne)
            .frame(width: size, height: size)
            .opacity(isLit ? 0.95 : 0.22)
            .shadow(color: RentOSBrand.gold.opacity(isLit ? 0.6 : 0), radius: size * 0.4)
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

/// The mark on an obsidian app-icon-style tile with a champagne shimmer.
struct RentOSLogoTile: View {

    var size: CGFloat = 96
    var animates: Bool = true

    @State private var shimmerOffset: CGFloat = -1.2

    private var cornerRadius: CGFloat { size * 0.27 }

    var body: some View {
        ZStack {
            // Obsidian → titanium tile.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DS.Gradients.obsidian)

            // Inner golden ambience.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [RentOSBrand.gold.opacity(0.22), .clear],
                        center: UnitPoint(x: 0.5, y: 0.62),
                        startRadius: 0,
                        endRadius: size * 0.62
                    )
                )

            // Mark.
            RentOSLogoMark(size: size * 0.64, animates: animates)
                .offset(y: size * 0.06)

            // Champagne shimmer sweep.
            if animates {
                LinearGradient(
                    colors: [.clear, RentOSBrand.champagne.opacity(0.16), .clear],
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
            // Gold accent hairline.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            RentOSBrand.champagne.opacity(0.7),
                            RentOSBrand.gold.opacity(0.35),
                            RentOSBrand.goldDeep.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .dsShadow(DS.Shadows.glow(RentOSBrand.gold, intensity: 0.35))
        .onAppear {
            guard animates else { return }
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

/// "RentOS" — "Rent" in polished platinum, "OS" in champagne gold.
struct RentOSWordmark: View {

    var fontSize: CGFloat = 38
    /// Use light text (launch screens) vs adaptive primary (in-app).
    var onDark: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            Text("Rent")
                .foregroundStyle(
                    onDark
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [.white, RentOSBrand.platinum],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                          )
                        : AnyShapeStyle(DS.Colors.textPrimary)
                )

            Text("OS")
                .foregroundStyle(
                    LinearGradient(
                        colors: [RentOSBrand.champagne, RentOSBrand.gold, RentOSBrand.goldDeep],
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
    .environment(\.colorScheme, .dark)
}
