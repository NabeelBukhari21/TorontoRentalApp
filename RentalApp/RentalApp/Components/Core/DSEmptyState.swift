//
//  DSEmptyState.swift
//  RentalApp
//
//  Design System — Empty states: Purr keeps you company, acting out the
//  moment (inbox zero, nothing archived, no results), with the screen's
//  own icon as a badge so the context is still clear at a glance.
//

import SwiftUI

struct DSEmptyState: View {

    let icon: String
    let title: String
    let message: String
    /// What Purr acts out. Good-news empties ("All clear") deserve a
    /// happier mood than "nothing found".
    var mood: PurrMood = .emptyState
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack(alignment: .bottomTrailing) {
                PurrMascot(mood: mood, size: 150)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.textOnBrand)
                    .frame(width: 38, height: 38)
                    .background(DS.Gradients.brand, in: Circle())
                    .overlay(Circle().strokeBorder(DS.Colors.surfaceRaised, lineWidth: 3))
                    .dsShadow(DS.Shadows.glow(DS.Colors.brand, intensity: 0.3))
                    .offset(x: -8, y: -10)
                    .accessibilityHidden(true)
            }

            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.title3)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text(message)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                DSButton(title: actionTitle, icon: DS.Icons.add, variant: .primary, action: action)
                    .padding(.top, DS.Spacing.sm)
            }
        }
        .padding(DS.Spacing.xxxl)
        .frame(maxWidth: .infinity)
        .dsEntrance()
    }
}

#Preview("Empty State") {
    ZStack {
        DSAmbientBackground()

        DSEmptyState(
            icon: DS.Icons.properties,
            title: "No properties yet",
            message: "Add your first property to start managing units, tenants, and maintenance in one place.",
            actionTitle: "Add Property",
            action: {}
        )
    }
}
