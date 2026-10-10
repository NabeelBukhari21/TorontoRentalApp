//
//  AuthComponents.swift
//  RentalApp
//
//  Auth — Shared chrome: glass card, header, social sign-in buttons,
//  divider, footer links, back button, and animated success badge.
//

import SwiftUI

// MARK: - Card

/// The glass panel that hosts each auth form. Constrained for iPad.
struct AuthCard<Content: View>: View {

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DS.Spacing.xxl)
            .dsSurface(cornerRadius: DS.Radius.xxl, shadow: DS.Shadows.floating)
            .frame(maxWidth: 460)
    }
}

// MARK: - Header

/// Mini logo tile + title + subtitle above each form.
struct AuthHeader: View {

    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            PurrpertyLogoTile(size: 64)
                .dsFloating(amplitude: 4, duration: 3.6)

            VStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Social Sign-In

struct AuthSocialButton: View {

    let provider: SocialProvider
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DS.Colors.textPrimary)
                } else {
                    logo
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                DS.Colors.surfaceRaised,
                in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Colors.outline, lineWidth: 1)
            )
            .dsShadow(DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle())
        .disabled(isLoading)
    }

    private var title: String { provider.title }

    @ViewBuilder
    private var logo: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(DS.Colors.textPrimary)
        case .google:
            Text("G")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DS.Colors.Partner.googleBlue, DS.Colors.Partner.googleGreen],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

// MARK: - Divider

struct AuthDivider: View {

    var text: String = "or continue with"

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            line
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize()
            line
        }
    }

    private var line: some View {
        LinearGradient(
            colors: [DS.Colors.outline.opacity(0), DS.Colors.outline],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

// MARK: - Footer Link

/// "New here? **Create account**" style footer.
struct AuthFooterLink: View {

    let prompt: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(prompt)
                .foregroundStyle(DS.Colors.textSecondary)

            Button(action: action) {
                Text(actionTitle)
                    .foregroundStyle(DS.Colors.brand)
                    .fontWeight(.semibold)
            }
            .buttonStyle(DSPressStyle(scale: 0.95))
        }
        .font(.system(size: 14, design: .rounded))
    }
}

// MARK: - Back Button

struct AuthBackButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .frame(width: 38, height: 38)
                .background(DS.Colors.surfaceRaised, in: Circle())
                .overlay(Circle().strokeBorder(DS.Colors.outline, lineWidth: 1))
                .dsShadow(DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle(scale: 0.9))
        .accessibilityLabel("Back")
    }
}

// MARK: - Success Badge

/// Ring that draws itself, then a checkmark springs in. For success states.
struct AuthSuccessBadge: View {

    var tint: Color = DS.Colors.success

    @State private var ringProgress: CGFloat = 0
    @State private var checkVisible = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 92, height: 92)
                .blur(radius: 8)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 76, height: 76)
                .rotationEffect(.degrees(-90))

            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(tint)
                .scaleEffect(checkVisible ? 1 : 0.3)
                .opacity(checkVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                ringProgress = 1
            }
            withAnimation(DS.Motion.bouncy.delay(0.45)) {
                checkVisible = true
            }
        }
    }
}

// MARK: - Form Error

/// Whole-form failure banner — wrong credentials, taken email, network.
/// Distinct from `AuthTextField`'s inline errors, which belong to one
/// field; this one belongs to the submission.
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
/// Passed down as a value so `LoginView` never has to know the session
/// coordinator exists.
struct BiometricUnlockOption {
    let kind: BiometricKind
    let action: () -> Void
}

struct AuthBiometricButton: View {

    let option: BiometricUnlockOption

    var body: some View {
        Button(action: option.action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: option.kind.icon)
                    .font(.system(size: 17, weight: .medium))

                Text("Unlock with \(option.kind.title)")
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(DS.Colors.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                DS.Colors.brand.opacity(0.1),
                in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Colors.brand.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(DSPressStyle())
    }
}

// MARK: - Selected Role Chip

/// Shows the role chosen on the previous screen, and lets the user
/// change it without losing the form they've already filled in.
struct AuthSelectedRoleChip: View {

    let role: AppRole
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: role.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Colors.brandInk)

            Text("Signing up as \(role.title)")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.Colors.textSecondary)

            Button(action: onChange) {
                Text("Change")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.brandInk)
            }
            .buttonStyle(DSPressStyle(scale: 0.94))
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.brand.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(DS.Gradients.cardHairline, lineWidth: 1))
    }
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

// MARK: - Previews

#Preview("Auth Components") {
    ZStack {
        SplashBackground()

        VStack(spacing: DS.Spacing.xl) {
            AuthHeader(title: "Welcome back", subtitle: "Sign in to manage your portfolio")
            AuthSocialButton(provider: .apple) {}
            AuthSocialButton(provider: .google) {}
            AuthDivider()
            AuthSuccessBadge()
            AuthFooterLink(prompt: "New here?", actionTitle: "Create account") {}
        }
        .padding(DS.Spacing.xxl)
    }
}
