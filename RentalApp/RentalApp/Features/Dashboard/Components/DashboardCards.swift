//
//  DashboardCards.swift
//  RentalApp
//
//  Dashboard — Occupancy overview, maintenance overview, and quick actions.
//

import SwiftUI

// MARK: - Occupancy Card

struct DashboardOccupancyCard: View {

    let rate: Double
    let occupied: Int
    let vacant: Int
    let turnover: Int

    var body: some View {
        DSCard(style: .glass) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack {
                    Text("Occupancy").dsOverline()
                    Spacer()
                    DSBadge(text: "2 listings live", kind: .info)
                }

                HStack(spacing: DS.Spacing.xxl) {
                    DSProgressRing(value: rate, size: 96, label: "Occupied")

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        occupancyRow(kind: .success, label: "Occupied", count: occupied)
                        occupancyRow(kind: .warning, label: "Vacant", count: vacant)
                        occupancyRow(kind: .info, label: "Turnover", count: turnover)
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func occupancyRow(kind: DSStatusKind, label: String, count: Int) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            DSStatusDot(kind: kind)

            Text(label)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)

            Spacer(minLength: DS.Spacing.md)

            Text("\(count)")
                .font(DS.Typography.subheadline.monospacedDigit())
                .foregroundStyle(DS.Colors.textPrimary)
        }
    }
}

// MARK: - Maintenance Card

struct DashboardMaintenanceCard: View {

    let counts: [MaintenanceStatusCount]
    let onViewBoard: () -> Void

    @State private var barsVisible = false

    private var total: Int {
        max(counts.reduce(0) { $0 + $1.count }, 1)
    }

    var body: some View {
        DSCard(style: .glass) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack {
                    Text("Maintenance").dsOverline()
                    Spacer()
                    DSStatusLabel(text: "1 urgent", kind: .danger, pulses: true)
                }

                // Stacked distribution bar.
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        ForEach(counts) { status in
                            Capsule()
                                .fill(status.kind.color)
                                .frame(
                                    width: barsVisible
                                        ? max(proxy.size.width * CGFloat(status.count) / CGFloat(total) - 3, 8)
                                        : 8
                                )
                        }
                    }
                    .animation(DS.Motion.entrance.delay(0.25), value: barsVisible)
                }
                .frame(height: 10)

                // Legend.
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(counts) { status in
                        HStack(spacing: DS.Spacing.sm) {
                            DSStatusDot(kind: status.kind, size: 7)

                            Text(status.label)
                                .font(DS.Typography.footnote)
                                .foregroundStyle(DS.Colors.textSecondary)

                            Spacer()

                            Text("\(status.count)")
                                .font(DS.Typography.subheadline.monospacedDigit())
                                .foregroundStyle(DS.Colors.textPrimary)
                        }
                    }
                }

                DSButton(title: "Open Maintenance Board", variant: .secondary, size: .small, isFullWidth: true) {
                    onViewBoard()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { barsVisible = true }
    }
}

// MARK: - Quick Actions

struct DashboardQuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let gradient: LinearGradient
    let action: () -> Void
}

struct DashboardQuickActionsRow: View {

    let actions: [DashboardQuickAction]

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                Button(action: action.action) {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: action.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(action.gradient)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                            .dsShadow(DS.Shadows.card)

                        Text(action.title)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSPressStyle(scale: 0.9))
                .dsEntrance(index: index)
            }
        }
    }
}
