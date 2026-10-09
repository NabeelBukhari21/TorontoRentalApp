//
//  DSEmptyState.swift
//  RentalApp
//
//  Design System — Empty states with a floating gradient icon and optional action.
//

import SwiftUI

struct DSEmptyState: View {

    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DS.Gradients.brand)
                    .frame(width: 84, height: 84)
                    .opacity(0.15)
                    .blur(radius: 12)

                Circle()
                    .fill(DS.Colors.surfaceRaised)
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle().strokeBorder(DS.Gradients.cardHairline, lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(DS.Gradients.brand)
            }
            .dsFloating(amplitude: 5, duration: 3.4)

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
