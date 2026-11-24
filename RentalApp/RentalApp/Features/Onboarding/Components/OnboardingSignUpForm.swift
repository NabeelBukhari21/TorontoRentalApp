//
//  OnboardingSignUpForm.swift
//  RentalApp (Purrperty)
//
//  Onboarding — The sign-up fields with a live password checklist, the
//  errors, the small print, and the Apple and Google buttons.
//

import SwiftUI

enum OnboardingField: Hashable { case name, email, password }

struct OnboardingSignUpForm: View {

    @Bindable var auth: AuthViewModel
    var focus: FocusState<OnboardingField?>.Binding
    let onSignIn: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var errors: [String] {
        [auth.nameError, auth.emailError, auth.passwordError, auth.formError].compactMap { $0 }
    }

    var body: some View {
        VStack(spacing: 10) {
            row("person.fill", field: .name, hasError: auth.nameError != nil) {
                TextField("Name", text: $auth.name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused(focus, equals: .name)
                    .onSubmit { focus.wrappedValue = .email }
                    .onChange(of: auth.name) { _, _ in auth.nameError = nil }
            }
            row("envelope.fill", field: .email, hasError: auth.emailError != nil) {
                TextField("Email", text: $auth.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused(focus, equals: .email)
                    .onSubmit { focus.wrappedValue = .password }
                    .onChange(of: auth.email) { _, _ in auth.emailError = nil }
            }
            row("lock.fill", field: .password, hasError: auth.passwordError != nil) {
                SecureField("Password", text: $auth.password)
                    .textContentType(.newPassword)
                    .submitLabel(.done)
                    .focused(focus, equals: .password)
                    .onChange(of: auth.password) { _, _ in auth.passwordError = nil }
            }

            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
            layout { requirements }
            .animation(DS.Motion.bouncy, value: auth.password)

            ForEach(errors, id: \.self) { error in
                Label(error, symbol: .caution)
                    .font(DS.Typography.brand(.footnote))
                    .foregroundStyle(DS.Colors.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if focus.wrappedValue == nil {
                VStack(spacing: 2) {
                    Text(.init("By continuing, you agree to the [Terms](\(LegalDocument.termsOfService.url().absoluteString)) and [Privacy Policy](\(LegalDocument.privacyPolicy.url().absoluteString))."))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .tint(DS.Colors.brandInk)
                    Button("Already have an account? Sign in", action: onSignIn)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.brandInk)
                        .frame(minHeight: 36)
                        .buttonStyle(SquishStyle(scale: 0.95))
                }
                .font(DS.Typography.brand(.footnote, weight: .regular))
                .multilineTextAlignment(.center)
            }
        }
    }

    private var requirements: some View {
        ForEach(auth.passwordRequirements) { OnboardingRequirementChip(requirement: $0) }
    }

    private func row(_ symbol: String, field: OnboardingField, hasError: Bool, @ViewBuilder input: () -> some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        let isFocused = focus.wrappedValue == field
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(DS.Colors.brandInk)
                .frame(width: 24)
                .accessibilityHidden(true)
            input()
                .font(DS.Typography.brand(.body))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(shape.fill(DS.Colors.surface.shadow(.inner(color: DS.Colors.groundShadow.opacity(0.5), radius: 3, y: 2))))
        .overlay(shape.strokeBorder(hasError ? DS.Colors.danger : isFocused ? DS.Colors.brand : .clear, lineWidth: 2))
        .animation(DS.Motion.snappy, value: isFocused)
        .contentShape(shape)
        .onTapGesture { focus.wrappedValue = field }
    }
}

/// One password rule, filling in with a light haptic as it's met.
private struct OnboardingRequirementChip: View {
    let requirement: PasswordRequirement

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: requirement.isMet ? "checkmark.circle.fill" : "circle")
                .contentTransition(.symbolEffect(.replace))
            Text(requirement.rule.title).lineLimit(1).minimumScaleFactor(0.75)
        }
        .font(DS.Typography.brand(.caption))
        .foregroundStyle(requirement.isMet ? DSAccent.mint.ink : DS.Colors.textSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Capsule().fill(requirement.isMet ? DSAccent.mint.tint : DS.Colors.surface))
        .scaleEffect(requirement.isMet ? 1.04 : 1)
        .jelly(on: requirement.isMet)
        .accessibilityElement(children: .combine)
        .accessibilityValue(requirement.isMet ? "Met" : "Not met")
    }
}

/// Continue with Apple or Google, as a round clay button with the
/// partner's own logo.
struct OnboardingSocialButton: View {
    let provider: SocialProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                switch provider {
                case .apple: AppleLogo(size: 25).offset(y: -1)
                case .google: GoogleLogo(size: 23)
                }
            }
            .frame(width: 56, height: 56)
            .background(Circle().fill(.clay(DS.Colors.surfaceRaised, shade: DS.Colors.textTertiary, size: 56)))
        }
        .buttonStyle(PressableDepthStyle(edge: DS.Colors.track, depth: 5))
        .accessibilityLabel(provider.title)
    }
}
