//
//  AIAssistantComponents.swift
//  RentalApp (RentOS)
//
//  AI Assistant — The copilot's visual language: the orb, obsidian
//  briefing panel, action cards, insight panels, health dial,
//  activity rows, and loading skeletons.
//

import SwiftUI

// MARK: - AI Orb

/// The copilot's presence — a golden core with an orbiting satellite,
/// echoing the RentOS logo. Spins faster while "working".
struct AIOrb: View {

    var size: CGFloat = 64
    var isWorking: Bool = false

    @State private var breathe = false
    @State private var orbit: Double = 0

    var body: some View {
        ZStack {
            // Halo.
            Circle()
                .fill(DS.Colors.accentSunny.opacity(0.40))
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: size * 0.22)
                .scaleEffect(breathe ? 1.25 : 0.9)

            // Core.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DS.Colors.onFixedColor, DS.Colors.accentSunny, DS.Colors.accentCoral],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size * 0.52, height: size * 0.52)
                .overlay(
                    Circle().strokeBorder(DS.Colors.highlightLine, lineWidth: 1)
                )
                .scaleEffect(breathe ? 1.05 : 0.96)

            // Orbit ring + satellite.
            Ellipse()
                .strokeBorder(
                    LinearGradient(
                        colors: [.clear, DS.Colors.accentSky.opacity(0.85), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
                .frame(width: size, height: size * 0.38)
                .rotationEffect(.degrees(-14))

            ZStack {
                Circle()
                    .fill(DS.Colors.accentMint)
                    .frame(width: size * 0.09, height: size * 0.09)
                    .shadow(color: DS.Colors.accentMint.opacity(0.9), radius: size * 0.05)
                    .offset(x: size * 0.48)
            }
            .rotationEffect(.degrees(orbit))
            .scaleEffect(y: 0.38)
            .rotationEffect(.degrees(-14))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                orbit += 360
            }
        }
        .animation(DS.Motion.smooth, value: isWorking)
    }
}

// MARK: - Obsidian Panel

/// The copilot's signature surface: obsidian gradient + champagne hairline.
struct AIHeroPanel<Content: View>: View {

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DS.Spacing.xl)
        .dsHeroSurface()
    }
}

// MARK: - Section Label

struct AISectionLabel: View {

    let text: String

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: DS.Icons.ai)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DS.Colors.brand)

            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(DS.Colors.textTertiary)
        }
    }
}

// MARK: - Recommended Action Card

struct AIActionCard: View {

    let action: AIRecommendedAction
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: action.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(action.kind.color)
                .frame(width: 40, height: 40)
                .background(action.kind.tint)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                Text(action.detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)

                Text(action.impact)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.brand)
            }

            Spacer(minLength: DS.Spacing.sm)

            // Controls.
            if action.state == .accepted {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(action.acceptedLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(DS.Colors.onHighlight)
                .padding(.horizontal, DS.Spacing.sm + 2)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    DS.Gradients.highlight,
                    in: Capsule()
                )
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    Button(action: onDismiss) {
                        Image(systemName: DS.Icons.close)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 32, height: 32)
                            .background(DS.Colors.surfaceSecondary, in: Circle())
                    }
                    .buttonStyle(DSPressStyle(scale: 0.85))
                    .accessibilityLabel("Dismiss")

                    Button(action: onAccept) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Colors.textOnBrand)
                            .frame(width: 32, height: 32)
                            .background(DS.Gradients.brand, in: Circle())
                            .dsShadow(DS.Shadows.glow(DS.Colors.brand, intensity: 0.35))
                    }
                    .buttonStyle(DSPressStyle(scale: 0.85))
                    .accessibilityLabel("Accept")
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .padding(DS.Spacing.md + 2)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(
                    action.state == .accepted
                        ? AnyShapeStyle(DS.Colors.brand.opacity(0.5))
                        : AnyShapeStyle(DS.Gradients.cardHairline),
                    lineWidth: 1
                )
        )
        .dsShadow(DS.Shadows.soft)
        .animation(DS.Motion.bouncy, value: action.state)
    }
}

// MARK: - Insight Panel

struct AIInsightPanel: View {

    let title: String
    let icon: String
    let rows: [AIInsightRow]

    var body: some View {
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.brand)
                    Text(title).dsOverline()
                    Spacer()
                }

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            Image(systemName: row.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(row.kind.color)
                                .frame(width: 26, height: 26)
                                .background(row.kind.tint, in: Circle())

                            Text(row.text)
                                .font(DS.Typography.footnote)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .dsEntrance(index: index)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Health Dial Card

struct AIHealthCard: View {

    let score: Int
    let factors: [AIHealthFactor]

    @State private var revealed = false

    var body: some View {
        AIHeroPanel {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack {
                    Text("PORTFOLIO HEALTH")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .kerning(1.2)
                        .foregroundStyle(DS.Colors.textOnBrand)

                    Spacer()

                    Text("Updated just now")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Colors.textOnBrand)
                }

                HStack(spacing: DS.Spacing.xl) {
                    // Score dial.
                    ZStack {
                        Circle()
                            .stroke(DS.Colors.textOnBrand.opacity(0.25), lineWidth: 9)

                        Circle()
                            .trim(from: 0, to: revealed ? Double(score) / 100 : 0)
                            .stroke(
                                AngularGradient(
                                    colors: [DS.Colors.accentMint, DS.Colors.accentSunny, DS.Colors.accentCoral, DS.Colors.accentMint],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 9, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(revealed ? score : 0)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(DS.Colors.textOnBrand)
                                .contentTransition(.numericText())

                            Text("/ 100")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(DS.Colors.textOnBrand)
                        }
                    }
                    .frame(width: 96, height: 96)

                    // Factor bars.
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        ForEach(Array(factors.enumerated()), id: \.element.id) { index, factor in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(factor.name)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(DS.Colors.textOnBrand)

                                    Spacer()

                                    Text("\(Int(factor.score * 100))")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(factor.kind.color)
                                }

                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(DS.Colors.textOnBrand.opacity(0.25))
                                        Capsule()
                                            .fill(factor.kind.fill)
                                            .frame(width: proxy.size.width * (revealed ? factor.score : 0))
                                            .animation(
                                                DS.Motion.entrance.delay(0.3 + Double(index) * 0.1),
                                                value: revealed
                                            )
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(DS.Motion.entrance.delay(0.2)) {
                revealed = true
            }
        }
    }
}

// MARK: - Activity Row

struct AIActivityRow: View {

    let entry: AIActivityEntry

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: entry.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Colors.brand)
                .frame(width: 28, height: 28)
                .background(DS.Colors.brand.opacity(0.1), in: Circle())

            Text(entry.text)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Text(entry.time)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(entry.time == "Now" ? DS.Colors.brand : DS.Colors.textTertiary)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Loading Skeleton

struct AILoadingState: View {

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.md) {
                AIOrb(size: 56, isWorking: true)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Analyzing your portfolio…")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text("Reviewing 12 properties, 8 requests, 4 renewals")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer()
            }

            DSSkeleton(shape: .rect(height: 120, cornerRadius: DS.Radius.xl))
            DSSkeletonCard()
            DSSkeletonCard()
        }
        .transition(.opacity)
    }
}

// MARK: - Previews

#Preview("AI Components") {
    ZStack {
        DSAmbientBackground()

        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                AIOrb(size: 80)

                AIActionCard(
                    action: AIRecommendedAction(
                        icon: DS.Icons.payment, kind: .danger,
                        title: "Send late-rent reminder",
                        detail: "Liam O'Connor · Unit 407",
                        impact: "Recovers $2,820",
                        acceptedLabel: "Reminder queued"
                    ),
                    onAccept: {},
                    onDismiss: {}
                )

                AIHealthCard(
                    score: 87,
                    factors: [
                        AIHealthFactor(name: "Occupancy", score: 0.94, kind: .success),
                        AIHealthFactor(name: "Collections", score: 0.96, kind: .success),
                        AIHealthFactor(name: "Maintenance", score: 0.82, kind: .warning)
                    ]
                )
            }
            .padding(DS.Spacing.xl)
        }
    }
}
