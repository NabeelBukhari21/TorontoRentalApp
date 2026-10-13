//
//  SplashParticleField.swift
//  RentalApp
//
//  Splash — GPU-friendly floating particles drawn in a single Canvas,
//  driven by TimelineView. Particles rise slowly, drift sideways,
//  and twinkle at individual rhythms.
//

import SwiftUI

struct SplashParticleField: View {

    private struct Particle {
        let baseX: Double        // 0...1 horizontal anchor
        let baseY: Double        // 0...1 starting vertical offset
        let speed: Double        // vertical rise speed (fraction of height / sec)
        let driftAmplitude: Double
        let driftFrequency: Double
        let twinkleFrequency: Double
        let phase: Double
        let size: Double
        let colorIndex: Int
    }

    var particleCount: Int = 38

    /// Deterministic particle set — stable across view reloads.
    private static func makeParticles(count: Int) -> [Particle] {
        var seed: UInt64 = 0x5EED_1EAF
        func next() -> Double {
            // xorshift64 — cheap deterministic pseudo-randomness.
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return Double(seed % 10_000) / 10_000
        }

        return (0..<count).map { _ in
            Particle(
                baseX: next(),
                baseY: next(),
                speed: 0.015 + next() * 0.035,
                driftAmplitude: 6 + next() * 18,
                driftFrequency: 0.15 + next() * 0.35,
                twinkleFrequency: 0.4 + next() * 1.2,
                phase: next() * .pi * 2,
                size: 1.5 + next() * 3.5,
                // Derived from the palette, not a literal 3 — the palette
                // grew to five and a hardcoded modulus would silently use
                // only the first three.
                colorIndex: Int(next() * Double(palette.count)) % palette.count
            )
        }
    }

    private let particles: [Particle]

    /// Rebuilt every frame before — three `Color` allocations at up to 120Hz
    /// for values that never change. Hoisted to a constant.
    ///
    /// Confetti-bright. No white: on the white launch background a white
    /// particle is invisible, which is exactly what two of the three old
    /// colours (white and champagne) would have been.
    private static var palette: [Color] { [
        DS.Colors.brand,
        DS.Colors.accentCoral,
        DS.Colors.accentSunny,
        DS.Colors.accentMint,
        DS.Colors.accentSky
    ] }

    /// Honouring this is not optional: a drifting, twinkling field is exactly
    /// the kind of motion Reduce Motion exists to suppress.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Backgrounded scenes should not be scheduling redraws.
    @Environment(\.scenePhase) private var scenePhase

    /// Stable origin for the periodic schedule.
    private static let epoch = Date()

    init(particleCount: Int = 38) {
        self.particleCount = particleCount
        self.particles = Self.makeParticles(count: particleCount)
    }

    private var isAnimated: Bool {
        !reduceMotion && scenePhase == .active
    }

    var body: some View {
        Group {
            if isAnimated {
                // `.animation` redraws at the display's refresh rate — 120Hz
                // on ProMotion. This is ambience *behind* the login and org
                // setup forms, where the user is typing; a decorative layer
                // has no business competing with keyboard input for frames.
                // 30fps is indistinguishable for slow drift and costs a
                // quarter of the redraws.
                // Fixed epoch, not `.now`: `body` can run many times, and a
                // schedule whose start moves each time is a schedule that
                // keeps restarting.
                TimelineView(.periodic(from: Self.epoch, by: 1.0 / 30.0)) { timeline in
                    field(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                // One deterministic frame. Still decorative, no timer.
                field(at: 0)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func field(at t: TimeInterval) -> some View {
        Canvas { context, size in
            let colors = Self.palette

            for particle in particles {
                // Rise and wrap.
                let progress = (particle.baseY - t * particle.speed)
                    .truncatingRemainder(dividingBy: 1)
                let y = (progress < 0 ? progress + 1 : progress) * size.height

                // Sideways drift.
                let x = particle.baseX * size.width
                    + sin(t * particle.driftFrequency + particle.phase) * particle.driftAmplitude

                // Twinkle.
                let twinkle = 0.25 + 0.6 * abs(sin(t * particle.twinkleFrequency + particle.phase))

                let rect = CGRect(
                    x: x - particle.size / 2,
                    y: y - particle.size / 2,
                    width: particle.size,
                    height: particle.size
                )

                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(colors[particle.colorIndex].opacity(twinkle))
                )
            }
        }
    }
}

#Preview("Particles") {
    ZStack {
        SplashBackground()
        SplashParticleField()
    }
}
