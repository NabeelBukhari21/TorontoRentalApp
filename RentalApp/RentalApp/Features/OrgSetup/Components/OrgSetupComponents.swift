//
//  OrgSetupComponents.swift
//  RentalApp
//
//  Org Setup — An invited teammate, as a chip.
//

import SwiftUI

// MARK: - Invite Chip

struct OrgInviteChip: View {

    let email: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            DSAvatar(name: email, size: .small)

            Text(email)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(DSPressStyle(scale: 0.85))
            .accessibilityLabel("Remove \(email)")
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs + 2)
        .background(DS.Colors.surfaceRaised, in: Capsule())
        .overlay(
            Capsule().strokeBorder(DS.Colors.outline, lineWidth: 1)
        )
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}
