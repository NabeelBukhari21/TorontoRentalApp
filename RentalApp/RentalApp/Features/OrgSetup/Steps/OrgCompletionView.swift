//
//  OrgCompletionView.swift
//  RentalApp
//
//  Org Setup — The confetti burst behind a celebration.
//

import SwiftUI

// MARK: - Confetti

/// One-shot confetti burst drawn in a single Canvas.
struct OrgConfettiBurst: View {

    private struct Piece {
        let x: Double          // 0...1 horizontal position
        let delay: Double
        let fallSpeed: Double  // fraction of height per second
        let sway: Double
        let swayFrequency: Double
        let spin: Double
        let size: Double
        let colorIndex: Int
        let isRect: Bool
    }

    private static func makePieces(count: Int) -> [Piece] {
        var seed: UInt64 = 0xC0FFEE
        func next() -> Double {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return Double(seed % 10_000) / 10_000
        }
        return (0..<count).map { _ in
            Piece(
                x: next(),
                delay: next() * 0.5,
                fallSpeed: 0.28 + next() * 0.3,
                sway: 14 + next() * 26,
                swayFrequency: 1.2 + next() * 2.2,
                spin: (next() - 0.5) * 10,
                size: 5 + next() * 6,
                colorIndex: Int(next() * Double(palette.count)) % palette.count,
                isRect: next() > 0.4
            )
        }
    }

    private let pieces = Self.makePieces(count: 56)
    @State private var startDate = Date()

    /// True until the last piece has fallen off-screen.
    ///
    /// "One-shot" was only true of the drawing. Every piece is culled once
    /// its progress passes 1.25, but `TimelineView(.animation)` kept firing
    /// at the display's refresh rate regardless — so a few seconds after the
    /// burst this was redrawing an *empty* canvas at up to 120Hz, forever,
    /// on a screen the user sits on until they tap Continue. Ending the
    /// timeline is the whole fix.
    @State private var isFalling = true

    /// When the slowest piece finishes: its delay plus the time to travel
    /// the full 1.25 progress at its own speed.
    private var duration: TimeInterval {
        (pieces.map { $0.delay + 1.25 / $0.fallSpeed }.max() ?? 0) + 0.1
    }

    /// Rebuilt every frame before; six `Color` lookups that never change.
    ///
    /// Bright fills, not inks: confetti is pure decoration, and the whole
    /// point is that it's loud. No white — on the white completion screen a
    /// white piece is invisible. Six entries so each accent appears, with
    /// cherry (the brand) weighted twice.
    private static var palette: [Color] { [
        DS.Colors.brand,
        DS.Colors.accentBlush,
        DS.Colors.accentGold,
        DS.Colors.accentMint,
        DS.Colors.accentSky,
        DS.Colors.brand
    ] }

    /// Celebration is decoration, and this is a full-screen burst of motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isFalling && !reduceMotion {
                burst
            } else {
                // Nothing left to draw, and now nothing scheduling draws.
                Color.clear
            }
        }
        .task {
            guard !reduceMotion else { return }
            startDate = Date()
            try? await Task.sleep(for: .seconds(duration))
            isFalling = false
        }
    }

    private var burst: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(startDate)
                let colors = Self.palette

                for piece in pieces {
                    let localTime = t - piece.delay
                    guard localTime > 0 else { continue }

                    let progress = localTime * piece.fallSpeed
                    guard progress < 1.25 else { continue }

                    let y = progress * (size.height + 60) - 30
                    let x = piece.x * size.width
                        + sin(localTime * piece.swayFrequency) * piece.sway

                    // Fade near the end of the fall.
                    let alpha = progress > 1 ? max(0, 1.25 - progress) / 0.25 : 1

                    var pieceContext = context
                    pieceContext.translateBy(x: x, y: y)
                    pieceContext.rotate(by: .radians(localTime * piece.spin))
                    pieceContext.opacity = alpha

                    let rect = CGRect(
                        x: -piece.size / 2,
                        y: -piece.size / 2,
                        width: piece.size,
                        height: piece.isRect ? piece.size * 0.55 : piece.size
                    )

                    let path = piece.isRect
                        ? Path(roundedRect: rect, cornerRadius: 1.5)
                        : Path(ellipseIn: rect)

                    pieceContext.fill(path, with: .color(colors[piece.colorIndex]))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
