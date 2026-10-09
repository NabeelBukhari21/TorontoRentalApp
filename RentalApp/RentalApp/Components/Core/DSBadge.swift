//
//  DSBadge.swift
//  RentalApp
//
//  Design System — Badges, chips, and status indicators.
//

import SwiftUI

// MARK: - Badge

/// A small tinted pill for statuses and counts, e.g. "Urgent", "3 new".
struct DSBadge: View {

    let text: String
    var kind: DSStatusKind = .neutral
    var icon: String? = nil
    /// A category colour instead of a status colour — for chips that label
    /// *what* something is (Plumbing, PDF) rather than *how* it is (Urgent).
    /// Takes precedence over `kind` when set.
    var accent: DSAccent? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(DS.Typography.caption)
        }
        .foregroundStyle(accent?.ink ?? kind.color)
        .padding(.horizontal, DS.Spacing.sm + 2)
        .padding(.vertical, DS.Spacing.xs + 1)
        .background(accent?.tint ?? kind.tint, in: Capsule())
    }
}

// MARK: - Status Dot

/// A colored dot with an optional pulsing halo — for "live" statuses like urgent requests.
struct DSStatusDot: View {

    var kind: DSStatusKind = .success
    var pulses: Bool = false
    var size: CGFloat = 9

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if pulses {
                Circle()
                    .fill(kind.color.opacity(0.45))
                    .frame(width: size, height: size)
                    .scaleEffect(isPulsing ? 2.4 : 1)
                    .opacity(isPulsing ? 0 : 0.7)
            }

            Circle()
                .fill(kind.color)
                .frame(width: size, height: size)
        }
        .onAppear {
            guard pulses else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Status Label

/// Dot + text combination, e.g. "● Occupied".
struct DSStatusLabel: View {

    let text: String
    var kind: DSStatusKind = .success
    var pulses: Bool = false

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            DSStatusDot(kind: kind, pulses: pulses)
            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
}

// MARK: - Chip

/// A selectable filter chip with animated selection state.
struct DSChip: View {

    let title: String
    var icon: String? = nil
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs + 2) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(DS.Typography.caption)
            }
            .foregroundStyle(isSelected ? DS.Colors.textOnBrand : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md + 2)
            .padding(.vertical, DS.Spacing.sm)
            .background(chipBackground, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.clear : DS.Colors.outline,
                    lineWidth: 1
                )
            )
            .dsShadow(isSelected ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.25) : DSShadowStyle(color: .clear, radius: 0, y: 0))
        }
        .buttonStyle(DSPressStyle(scale: 0.94))
        .animation(DS.Motion.snappy, value: isSelected)
    }

    private var chipBackground: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(DS.Gradients.brand)
            : AnyShapeStyle(DS.Colors.surfaceRaised)
    }
}

// MARK: - Previews

#Preview("Badges & Chips") {
    struct Demo: View {
        @State private var selected = "All"
        private let filters = ["All", "Urgent", "In Progress", "Done"]

        var body: some View {
            ZStack {
                DSAmbientBackground()

                VStack(spacing: DS.Spacing.xxl) {
                    HStack(spacing: DS.Spacing.sm) {
                        DSBadge(text: "Urgent", kind: .danger, icon: DS.Icons.warning)
                        DSBadge(text: "Occupied", kind: .success)
                        DSBadge(text: "Pending", kind: .warning)
                        DSBadge(text: "3 new", kind: .info)
                    }

                    HStack(spacing: DS.Spacing.xl) {
                        DSStatusLabel(text: "Occupied", kind: .success)
                        DSStatusLabel(text: "Urgent", kind: .danger, pulses: true)
                        DSStatusLabel(text: "Vacant", kind: .neutral)
                    }

                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(filters, id: \.self) { filter in
                            DSChip(title: filter, isSelected: selected == filter) {
                                selected = filter
                            }
                        }
                    }
                }
                .padding(DS.Spacing.xxl)
            }
        }
    }
    return Demo()
}
