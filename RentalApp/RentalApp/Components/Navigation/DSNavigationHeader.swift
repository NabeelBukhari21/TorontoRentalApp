//
//  DSNavigationHeader.swift
//  RentalApp
//
//  Navigation — Reusable glass navigation header.
//  Replaces the system bar: large rounded title, optional subtitle,
//  back button, and badge-capable trailing actions.
//

import SwiftUI

// MARK: - Header Action

/// A trailing header button with an optional notification badge.
struct DSHeaderAction: Identifiable {
    let id = UUID()
    let icon: String
    var badge: Int? = nil
    let action: () -> Void

    init(icon: String, badge: Int? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.badge = badge
        self.action = action
    }
}

// MARK: - Header

struct DSNavigationHeader: View {

    let title: String
    var subtitle: String? = nil
    var showsBack: Bool = false
    var trailingActions: [DSHeaderAction] = []

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            if showsBack {
                DSIconButton(icon: "chevron.left", diameter: 38) {
                    dismiss()
                }
                .accessibilityLabel("Back")
            }

            VStack(alignment: .leading, spacing: 1) {
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                Text(title)
                    .font(showsBack ? DS.Typography.title3 : DS.Typography.title2)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            ForEach(trailingActions) { action in
                DSIconButton(icon: action.icon, diameter: 38, action: action.action)
                    .overlay(alignment: .topTrailing) {
                        if let badge = action.badge, badge > 0 {
                            Text(badge > 9 ? "9+" : "\(badge)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(DS.Colors.danger, in: Capsule())
                                .offset(x: 5, y: -4)
                        }
                    }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.Colors.outline)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Modifier

extension View {

    /// Replaces the system navigation bar with the design-system header.
    func dsHeader(
        title: String,
        subtitle: String? = nil,
        showsBack: Bool = false,
        trailingActions: [DSHeaderAction] = []
    ) -> some View {
        self
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                DSNavigationHeader(
                    title: title,
                    subtitle: subtitle,
                    showsBack: showsBack,
                    trailingActions: trailingActions
                )
            }
    }
}

// MARK: - Previews

#Preview("Header") {
    ZStack {
        DSAmbientBackground()

        VStack(spacing: DS.Spacing.xxl) {
            DSNavigationHeader(
                title: "Home",
                subtitle: "Good morning, Syed",
                trailingActions: [
                    DSHeaderAction(icon: DS.Icons.notifications, badge: 3) {},
                    DSHeaderAction(icon: DS.Icons.tenant) {}
                ]
            )

            DSNavigationHeader(title: "Property Details", showsBack: true)

            Spacer()
        }
    }
}
