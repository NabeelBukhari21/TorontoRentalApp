//
//  AuthComponents.swift
//  RentalApp
//
//  Auth — Shared pieces: the form error banner, the biometric option and
//  the demo accounts.
//

import SwiftUI

// MARK: - Form Error

/// Whole-form failure banner — wrong credentials, taken email, network.
/// Distinct from a field's own error; this one belongs to the submission.
struct AuthFormError: View {

    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: DS.Icons.warning)
                .font(.system(size: 12, weight: .semibold))

            Text(message)
                .font(.system(size: 12.5, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .foregroundStyle(DS.Colors.danger)
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DS.Colors.danger.opacity(0.12),
            in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Colors.danger.opacity(0.28), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Biometric Unlock

/// What the login screen needs in order to offer Face ID / Touch ID.
/// Passed down as a value so the login form never has to know the session
/// coordinator exists.
struct BiometricUnlockOption {
    let kind: BiometricKind
    let action: () -> Void
}

// MARK: - Demo Hint

/// Credentials for the seeded mock accounts. Deleted the day a real
/// identity provider lands — see `MockAccountDirectory`.
struct AuthDemoHint: View {

    var body: some View {
        VStack(spacing: 3) {
            Text("Demo accounts")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .kerning(1.1)
                .foregroundStyle(DS.Colors.textTertiary)

            Text("owner@rentos.ca · manager@rentos.ca · tenant@rentos.ca · vendor@rentos.ca")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(DS.Colors.textTertiary)
                .multilineTextAlignment(.center)

            Text("Password: \(MockAccountDirectory.demoPassword) · MFA code: \(MockAccountDirectory.demoMFACode)")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(.horizontal, DS.Spacing.md)
    }
}
