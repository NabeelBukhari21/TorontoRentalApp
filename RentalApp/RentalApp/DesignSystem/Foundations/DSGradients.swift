//
//  DSGradients.swift
//  RentalApp
//
//  Design System — Gradients & animated ambient backgrounds.
//

import SwiftUI

extension DS {

    enum Gradients {

        /// Primary brand gradient — champagne gold → saffron.
        static let brand = LinearGradient(
            colors: [DS.Colors.brand, DS.Colors.brandViolet],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// AI accent gradient — champagne gold → platinum. Reserved for AI features.
        static let ai = LinearGradient(
            colors: [DS.Colors.brand, DS.Colors.brandCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Warm gradient — saffron → coral. Alerts, highlights.
        static let warm = LinearGradient(
            colors: [DS.Colors.accentAmber, DS.Colors.accentCoral],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Success gradient for positive stats.
        static let success = LinearGradient(
            colors: [DS.Colors.success, Color(hex: 0x0E6B52)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Signature surface gradient — pure obsidian → polished titanium.
        /// Use for premium cards, overviews, and hero surfaces.
        static let obsidian = LinearGradient(
            colors: [Color(hex: 0x121212), Color(hex: 0x2A2D34)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Champagne fill — pale champagne → gold. The signature fill for
        /// unread pills, sent bubbles, premium chips, and confirmed states.
        /// Pair with `DS.Colors.onGold` ink.
        static let champagne = LinearGradient(
            colors: [Color(hex: 0xF5E7C1), Color(hex: 0xD4AF37)],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Horizontal gold sweep — deep → gold → champagne.
        /// For progress fills on obsidian surfaces (lease terms, usage).
        static let goldSweep = LinearGradient(
            colors: [Color(hex: 0x8C6D1F), Color(hex: 0xD4AF37), Color(hex: 0xF5E7C1)],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// Hairline for obsidian surfaces — champagne light falling off.
        static let obsidianHairline = LinearGradient(
            colors: [
                Color(hex: 0xF5E7C1).opacity(0.5),
                Color(hex: 0xD4AF37).opacity(0.22),
                .white.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Subtle sheen used as a top highlight on glass panels —
        /// white light with a champagne-gold accent line.
        static let glassHighlight = LinearGradient(
            colors: [
                .white.opacity(0.4),
                Color(hex: 0xD4AF37).opacity(0.28),
                .white.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Animated Ambient Background

/// A slowly drifting, blurred multi-color background.
/// Place behind glass content for the signature "alive" ambient look.
struct DSAmbientBackground: View {

    var colors: [Color] = [
        DS.Colors.brand.opacity(0.22),
        DS.Colors.brandCyan.opacity(0.14),
        DS.Colors.brandViolet.opacity(0.10)
    ]

    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                DS.Colors.background

                Circle()
                    .fill(colors.indices.contains(0) ? colors[0] : .clear)
                    .frame(width: size.width * 0.9)
                    .offset(
                        x: animate ? -size.width * 0.25 : size.width * 0.20,
                        y: animate ? -size.height * 0.18 : -size.height * 0.32
                    )

                Circle()
                    .fill(colors.indices.contains(1) ? colors[1] : .clear)
                    .frame(width: size.width * 0.8)
                    .offset(
                        x: animate ? size.width * 0.30 : -size.width * 0.22,
                        y: animate ? size.height * 0.05 : size.height * 0.18
                    )

                Circle()
                    .fill(colors.indices.contains(2) ? colors[2] : .clear)
                    .frame(width: size.width * 0.7)
                    .offset(
                        x: animate ? -size.width * 0.10 : size.width * 0.15,
                        y: animate ? size.height * 0.35 : size.height * 0.22
                    )
            }
            .blur(radius: 90)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
    }
}

#Preview("Ambient Background") {
    DSAmbientBackground()
}
