//
//  DSGradients.swift
//  RentalApp
//
//  Design System — Gradients & the ambient background.
//
//  Every gradient that carries text documents which text colour is safe
//  on it. A gradient is only as readable as its worst end, so the stops
//  were chosen against the text that sits on them, not just for looks.
//

import SwiftUI

extension DS {

    enum Gradients {

        // MARK: Signature gradients

        /// Violet → sky. Hero cards, the dashboard revenue card, AI panel,
        /// flagship moments. Text: `textOnBrand` (white).
        ///
        /// Ends on `accentSkyDeep` rather than plain sky so white text holds
        /// AA across the whole card: 4.86 at the violet end, 5.06 at the sky
        /// end. Plain #4DA8FF would drop to 2.51.
        static var hero: LinearGradient { LinearGradient(
            colors: [DS.Colors.brand, DS.Colors.accentSkyDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ) }

        /// Coral → sunny. Celebrations, streak-style highlights, alerts that
        /// should feel warm rather than alarming. Text: `textOnAccent` (ink,
        /// 6.08–12.25).
        static let warm = LinearGradient(
            colors: [DS.Colors.accentCoral, DS.Colors.accentSunny],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Mint → sky. Positive, calm moments: occupancy, success states,
        /// completion. Text: `textOnAccent` (ink, 6.72–9.22).
        static let fresh = LinearGradient(
            colors: [DS.Colors.accentMint, DS.Colors.accentSky],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // MARK: Role gradients

        /// Primary brand gradient — primary buttons, the FAB, icon wells.
        /// Violet → deeper violet, so white labels pass at both ends
        /// (4.86, 6.06) while still reading as a gradient.
        static var brand: LinearGradient { LinearGradient(
            colors: [DS.Colors.brand, DS.Colors.brandInk],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ) }

        /// AI features. Violet → sky, angled differently from `hero` so the
        /// two read as related but distinct. Text: `textOnBrand`.
        static var ai: LinearGradient { LinearGradient(
            colors: [DS.Colors.accentSkyDeep, DS.Colors.brand],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ) }

        /// Positive stats. Mint → sky, ink text.
        static let success = fresh

        /// Filled highlight — sent message bubbles, unread pills, selected
        /// chips, confirmed states. Text: `onHighlight` (white, 4.86–6.06).
        static var highlight: LinearGradient { LinearGradient(
            colors: [DS.Colors.brand, DS.Colors.brandInk],
            startPoint: .top,
            endPoint: .bottom
        ) }

        /// Horizontal multi-colour sweep for progress fills (lease terms,
        /// usage, onboarding). Decorative — never carries text.
        static var progress: LinearGradient { LinearGradient(
            colors: [DS.Colors.brand, DS.Colors.accentSky, DS.Colors.accentMint],
            startPoint: .leading,
            endPoint: .trailing
        ) }

        // MARK: Hairlines

        /// Light edge for gradient cards — catches the top-left like a
        /// sheet of glossy paper rather than glass.
        static let heroHairline = LinearGradient(
            colors: [
                DS.Colors.highlightLine,
                DS.Colors.highlightLine.opacity(0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Edge for plain cards. A faint ink line, slightly stronger at the
        /// bottom where the shadow is, so cards on white keep their shape.
        static let cardHairline = LinearGradient(
            colors: [DS.Colors.outline.opacity(0.6), DS.Colors.outline],
            startPoint: .top,
            endPoint: .bottom
        )

        // MARK: Placeholders

        /// Colour stops for photo placeholders (properties without photos).
        ///
        /// Stored per property as `paletteIndex`, so COUNT and ORDER are a
        /// contract with saved data — recolour freely, never reorder or
        /// remove. Fixed colours: a placeholder stands in for a photo, and
        /// photos don't change with dark mode. Text never sits directly on
        /// these; overlays add a `mediaBackground` fade first.
        static let placeholderStops: [[Color]] = [
            [Color(hex: 0x6C5CE7), Color(hex: 0x4DA8FF)], // violet → sky
            [Color(hex: 0xFF6B6B), Color(hex: 0xFFD93D)], // coral → sunny
            [Color(hex: 0x2ED8A3), Color(hex: 0x4DA8FF)], // mint → sky
            [Color(hex: 0xFFD93D), Color(hex: 0x2ED8A3)], // sunny → mint
            [Color(hex: 0x4DA8FF), Color(hex: 0x6C5CE7)], // sky → violet
            [Color(hex: 0x6C5CE7), Color(hex: 0xFF6B6B)]  // violet → coral
        ]

        static let placeholders: [LinearGradient] = placeholderStops.map {
            LinearGradient(colors: $0, startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        /// Organisation monogram presets — the "pick a look" swatches in org
        /// setup. Stored by index, so the COUNT and ORDER are a contract
        /// with saved organisations: recolour freely, but never reorder,
        /// remove, or insert anywhere but the end.
        ///
        /// Fixed colours (identity shouldn't change with dark mode), each
        /// pair chosen so white letters (`onFixedColor`) pass AA at BOTH
        /// ends: every stop here is 4.86–6.14 against white.
        static let monogramStops: [[Color]] = [
            [Color(hex: 0x6C5CE7), Color(hex: 0x5A49E0)], // violet
            [Color(hex: 0x6C5CE7), Color(hex: 0x2A6BD4)], // violet → sky
            [Color(hex: 0xB72D28), Color(hex: 0x6C5CE7)], // coral → violet
            [Color(hex: 0x885900), Color(hex: 0xB72D28)], // sunset
            [Color(hex: 0x116F57), Color(hex: 0x0B60BE)]  // mint → sky
        ]

        /// Stable placeholder for an index (e.g. a stored palette index).
        static func placeholder(_ index: Int) -> LinearGradient {
            placeholders[((index % placeholders.count) + placeholders.count) % placeholders.count]
        }
    }
}

// MARK: - Ambient Background

/// A slowly drifting field of soft colour blobs on white.
///
/// Used to be heavily blurred brand colour behind glass; now it is a
/// gentle wash — candy-coloured light at low opacity — so content on top
/// stays crisp and white still dominates. Respects Reduce Motion by
/// holding still.
struct DSAmbientBackground: View {

    var colors: [Color] = [
        DS.Colors.brand.opacity(0.14),
        DS.Colors.accentSky.opacity(0.14),
        DS.Colors.accentCoral.opacity(0.10),
        DS.Colors.accentSunny.opacity(0.14)
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                DS.Colors.background

                blob(0, width: size.width * 0.9,
                     at: animate ? CGPoint(x: -0.25, y: -0.18) : CGPoint(x: 0.20, y: -0.32),
                     in: size)
                blob(1, width: size.width * 0.8,
                     at: animate ? CGPoint(x: 0.30, y: 0.05) : CGPoint(x: -0.22, y: 0.18),
                     in: size)
                blob(2, width: size.width * 0.7,
                     at: animate ? CGPoint(x: -0.10, y: 0.35) : CGPoint(x: 0.15, y: 0.22),
                     in: size)
                blob(3, width: size.width * 0.6,
                     at: animate ? CGPoint(x: 0.28, y: -0.30) : CGPoint(x: 0.05, y: 0.40),
                     in: size)
            }
            .blur(radius: 80)
            .ignoresSafeArea()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
    }

    @ViewBuilder
    private func blob(_ index: Int, width: CGFloat, at unit: CGPoint, in size: CGSize) -> some View {
        if colors.indices.contains(index) {
            Circle()
                .fill(colors[index])
                .frame(width: width)
                .offset(x: size.width * unit.x, y: size.height * unit.y)
        }
    }
}

#Preview("Ambient Background") {
    DSAmbientBackground()
}
