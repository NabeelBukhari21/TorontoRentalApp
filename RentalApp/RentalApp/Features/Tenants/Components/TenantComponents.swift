//
//  TenantComponents.swift
//  RentalApp (RentOS)
//
//  Tenants — Shared components: list row, obsidian lease card,
//  and timeline rows.
//

import SwiftUI

// MARK: - Tenant Row

struct TenantRow: View {

    let tenant: Tenant
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                DSAvatar(
                    name: tenant.name,
                    size: .medium,
                    status: tenant.status.kind == .success ? .success
                        : (tenant.status == .overdue ? .danger : .info)
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(tenant.name)
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1)

                        if tenant.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DS.Colors.brand)
                        }
                    }

                    Text("\(tenant.unitName) · \(tenant.propertyName)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)

                    // Lease progress micro-bar.
                    HStack(spacing: DS.Spacing.sm) {
                        DSProgressBar(
                            value: tenant.leaseProgress,
                            gradient: tenant.leaseProgress > 0.85 ? DS.Gradients.warm : DS.Gradients.brand,
                            height: 3
                        )
                        .frame(width: 72)

                        Text("ends \(tenant.leaseEnd)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer(minLength: DS.Spacing.sm)

                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    Text("$\(tenant.rent)")
                        .font(DS.Typography.subheadline.monospacedDigit())
                        .foregroundStyle(DS.Colors.textPrimary)

                    DSBadge(text: tenant.status.rawValue, kind: tenant.status.kind)
                }

                Image(systemName: DS.Icons.chevronRight)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.lg)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(
                        tenant.isPremium
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [DS.Colors.brand.opacity(0.55), DS.Colors.brand.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                              )
                            : AnyShapeStyle(DS.Gradients.glassHighlight),
                        lineWidth: 1
                    )
            )
            .dsShadow(DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle())
    }
}

// MARK: - Lease Card (signature obsidian surface)

struct TenantLeaseCard: View {

    let tenant: Tenant

    @State private var barVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack {
                Text("LEASE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(Color(hex: 0xD4AF37))

                Spacer()

                if tenant.isPremium {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Premium")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(DS.Colors.onGold)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(
                        DS.Gradients.champagne,
                        in: Capsule()
                    )
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text("$\(tenant.rent)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text("/month")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Term progress.
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))

                        Capsule()
                            .fill(
                                DS.Gradients.goldSweep
                            )
                            .frame(width: proxy.size.width * (barVisible ? tenant.leaseProgress : 0))
                    }
                }
                .frame(height: 6)

                HStack {
                    termLabel(tenant.leaseStart, alignment: .leading)
                    Spacer()
                    Text("\(Int(tenant.leaseProgress * 100))% elapsed")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xD4AF37))
                    Spacer()
                    termLabel(tenant.leaseEnd, alignment: .trailing)
                }
            }

            // Footer facts.
            HStack(spacing: DS.Spacing.xl) {
                leaseFact(label: "Deposit", value: "$\(tenant.deposit)")
                leaseFact(label: "On-time", value: "\(tenant.onTimeRate)%")
                leaseFact(label: "Status", value: tenant.status.rawValue)
                Spacer(minLength: 0)
            }
        }
        .padding(DS.Spacing.xl)
        .dsObsidianSurface()
        .onAppear {
            withAnimation(DS.Motion.entrance.delay(0.3)) {
                barVisible = true
            }
        }
    }

    private func termLabel(_ text: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func leaseFact(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Timeline Row

struct TenantTimelineRow: View {

    let event: TenantEvent
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            // Dot + connector.
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(event.kind.tint)
                        .frame(width: 30, height: 30)

                    Image(systemName: event.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(event.kind.color)
                }

                if !isLast {
                    Rectangle()
                        .fill(DS.Colors.outline)
                        .frame(width: 1.5)
                        .frame(minHeight: 26)
                }
            }

            // Content.
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textPrimary)

                    Spacer()

                    Text(event.date)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Text(event.detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(2)
            }
            .padding(.bottom, isLast ? 0 : DS.Spacing.md)
        }
    }
}

// MARK: - Previews

#Preview("Tenant Components") {
    ZStack {
        DSAmbientBackground()

        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                TenantRow(tenant: TenantMockData.tenants[0]) {}
                TenantLeaseCard(tenant: TenantMockData.tenants[0])

                DSCard(style: .glass) {
                    VStack(spacing: 0) {
                        let events = TenantMockData.timeline(for: TenantMockData.tenants[0])
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            TenantTimelineRow(event: event, isLast: index == events.count - 1)
                        }
                    }
                }
            }
            .padding(DS.Spacing.xl)
        }
    }
}
