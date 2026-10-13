//
//  OrgCompletionView.swift
//  RentalApp
//
//  Org Setup — Completion celebration: the mascot cheering inside a
//  confetti burst, and a summary card of the new workspace.
//

import SwiftUI

struct OrgCompletionView: View {

    let viewModel: OrgSetupViewModel
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            OrgConfettiBurst()

            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                // The cat, arms up. Replaces the success ring: a celebration
                // reads better as a character's reaction than as a checkmark.
                MascotView(mood: .cheer, size: 170)

                VStack(spacing: DS.Spacing.sm) {
                    Text("You're all set!")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DS.Colors.brand, DS.Colors.accentSkyDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("Your workspace is ready to go.")
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .dsEntrance(index: 1)

                // Workspace summary.
                AuthCard {
                    VStack(spacing: DS.Spacing.lg) {
                        HStack(spacing: DS.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.monogramGradient)

                                if let image = viewModel.logoImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                } else {
                                    Text(viewModel.monogram)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(DS.Colors.onFixedColor)
                                }
                            }
                            .frame(width: 54, height: 54)
                            .overlay(Circle().strokeBorder(DS.Colors.highlightLine, lineWidth: 1))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.orgName)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .lineLimit(1)

                                Text(summaryLine)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }

                            Spacer(minLength: 0)
                        }

                        if !viewModel.inviteEmails.isEmpty {
                            HStack {
                                DSAvatarStack(names: viewModel.inviteEmails, maxVisible: 4)

                                Text("\(viewModel.inviteEmails.count) invite\(viewModel.inviteEmails.count == 1 ? "" : "s") on the way")
                                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(DS.Colors.textSecondary)

                                Spacer()
                            }
                        }
                    }
                }
                .dsEntrance(index: 2)

                Spacer()

                // "Continue", not "Go to Dashboard": a new account goes on
                // to getting started (first property) before Home.
                DSButton(
                    title: "Continue",
                    icon: "arrow.right",
                    variant: .primary,
                    size: .large,
                    isFullWidth: true
                ) {
                    onFinished()
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxl)
                .dsEntrance(index: 3)
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private var summaryLine: String {
        var parts: [String] = []
        if let type = viewModel.propertyType { parts.append(type.title) }
        if let size = viewModel.portfolioSize { parts.append("\(size.title) properties") }
        return parts.isEmpty ? "Ready to add your first property" : parts.joined(separator: " · ")
    }
}

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
    /// violet (the brand) weighted twice.
    private static var palette: [Color] { [
        DS.Colors.brand,
        DS.Colors.accentCoral,
        DS.Colors.accentSunny,
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

#Preview("Completion") {
    struct Demo: View {
        var body: some View {
            let vm = OrgSetupViewModel(service: AppContainer.preview.organization)
            vm.orgName = "Bukhari Properties"
            vm.propertyType = .multiUnit
            vm.portfolioSize = .growing
            vm.inviteEmails = ["sarah@example.com", "mike@example.com"]

            return ZStack {
                SplashBackground()
                OrgCompletionView(viewModel: vm, onFinished: {})
            }
        }
    }
    return Demo()
}
