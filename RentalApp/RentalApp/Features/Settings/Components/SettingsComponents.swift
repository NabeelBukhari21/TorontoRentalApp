//
//  SettingsComponents.swift
//  RentalApp (Purrperty)
//
//  Settings — Shared chrome: gold toggle style, section cards,
//  nav rows, toggle rows, and value rows.
//

import SwiftUI

// MARK: - Gold Toggle Style

/// The Purrperty switch: obsidian track that fills with champagne gold.
struct DSToggleStyle: ToggleStyle {

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(DS.Motion.bouncy) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(
                        configuration.isOn
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [DS.Colors.brand, DS.Colors.brandInk],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                              )
                            : AnyShapeStyle(DS.Colors.surfaceSecondary)
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            configuration.isOn ? DS.Colors.highlightLine : DS.Colors.outline,
                            lineWidth: 1
                        )
                    )

                Circle()
                    .fill(DS.Colors.onFixedColor)
                    .shadow(color: DS.Colors.scrim.opacity(0.45), radius: 2, y: 1)
                    .padding(2.5)
            }
            .frame(width: 48, height: 29)
            .dsShadow(
                configuration.isOn
                    ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.3)
                    : DSShadowStyle(color: .clear, radius: 0, y: 0)
            )
        }
        .buttonStyle(DSPressStyle(scale: 0.94))
    }
}

// MARK: - Section Card

/// Glass card that stacks settings rows with hairline dividers.
struct SettingsSectionCard<Content: View>: View {

    var title: String? = nil
    private let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let title {
                Text(title).dsOverline()
                    .padding(.horizontal, DS.Spacing.xs)
            }

            VStack(spacing: 0) {
                content
            }
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(DS.Gradients.cardHairline, lineWidth: 1)
            )
            .dsShadow(DS.Shadows.soft)
        }
    }
}

/// Hairline divider aligned past the icon column.
struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.Colors.outline)
            .frame(height: 0.5)
            .padding(.leading, 62)
    }
}

// MARK: - Icon Tile

struct SettingsIconTile: View {

    let icon: String
    var tint: Color = DS.Colors.brandInk

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }
}

// MARK: - Nav Row

struct SettingsNavRow: View {

    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = DS.Colors.brandInk
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                SettingsIconTile(icon: icon, tint: tint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer()

                if let badge {
                    DSBadge(text: badge, kind: .info)
                }

                Image(systemName: DS.Icons.chevronRight)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.md + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(DSPressStyle())
    }
}

// MARK: - Toggle Row

struct SettingsToggleRow: View {

    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = DS.Colors.brandInk
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            SettingsIconTile(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(DSToggleStyle())
                .labelsHidden()
        }
        .padding(DS.Spacing.md + 2)
    }
}

// MARK: - Value Row

struct SettingsValueRow: View {

    let icon: String
    let title: String
    let value: String
    var tint: Color = DS.Colors.brandInk

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            SettingsIconTile(icon: icon, tint: tint)

            Text(title)
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Colors.textPrimary)

            Spacer()

            Text(value)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.md + 2)
    }
}

// MARK: - Save Button (with success state)

struct SettingsSaveButton: View {

    let title: String
    var save: (() async throws -> Void)?

    @State private var isSaving = false
    @State private var isSaved = false

    var body: some View {
        Button {
            guard !isSaving, !isSaved else { return }
            withAnimation(DS.Motion.gentle) { isSaving = true }
            Task {
                if let save { try? await save() } else { try? await Task.sleep(for: .seconds(1)) }
                withAnimation(DS.Motion.bouncy) {
                    isSaving = false
                    isSaved = true
                }
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(DS.Motion.gentle) { isSaved = false }
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DS.Colors.textOnBrand)
                } else if isSaved {
                    Image(systemName: "checkmark.circle.fill")
                }

                Text(isSaved ? "Saved" : title)
                    .contentTransition(.opacity)
            }
            .font(DS.Typography.headline)
            .foregroundStyle(isSaved ? DS.Colors.textOnAccent : DS.Colors.textOnBrand)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                isSaved ? AnyShapeStyle(DS.Gradients.success) : AnyShapeStyle(DS.Gradients.brand),
                in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            )
            .dsShadow(DS.Shadows.glow(isSaved ? DS.Colors.accentMint : DS.Colors.brand, intensity: 0.35))
        }
        .buttonStyle(DSPressStyle())
        .animation(DS.Motion.bouncy, value: isSaved)
    }
}

// MARK: - Previews

#Preview("Settings Components") {
    struct Demo: View {
        @State private var on = true
        @State private var off = false

        var body: some View {
            ZStack {
                DSAmbientBackground()

                VStack(spacing: DS.Spacing.lg) {
                    SettingsSectionCard(title: "Alerts") {
                        SettingsToggleRow(
                            icon: DS.Icons.maintenance,
                            title: "Urgent maintenance",
                            subtitle: "Immediate push for urgent tickets",
                            tint: DS.Colors.danger,
                            isOn: $on
                        )
                        SettingsRowDivider()
                        SettingsToggleRow(
                            icon: DS.Icons.payment,
                            title: "Payments",
                            isOn: $off
                        )
                        SettingsRowDivider()
                        SettingsNavRow(icon: DS.Icons.ai, title: "AI Preferences", subtitle: "Copilot behavior") {}
                    }

                    SettingsSaveButton(title: "Save Changes")
                }
                .padding(DS.Spacing.xl)
            }
        }
    }
    return Demo()
}
