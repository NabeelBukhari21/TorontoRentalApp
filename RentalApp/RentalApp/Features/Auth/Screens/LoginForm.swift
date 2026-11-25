//
//  LoginForm.swift
//  RentalApp (Purrperty)
//
//  Auth — What sign-in puts on Purr's counter: email and password,
//  forgotten password, Apple and Google, and biometric unlock for
//  returning users.
//

import SwiftUI

/// The field being typed in, for Purr to react to.
enum AuthFocus { case email, password }

struct LoginForm: View {

    @Bindable var viewModel: AuthViewModel
    @Binding var focus: AuthFocus?
    /// Present only when this device has a biometric-gated session
    /// stored — the one-tap path back in for a returning user.
    var biometricUnlock: BiometricUnlockOption?
    let onSubmit: () -> Void
    let onForgot: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            AuthEmailField(viewModel: viewModel, focus: $focus)

            StageField(symbol: "lock.fill", prompt: "Password", text: $viewModel.password, error: viewModel.passwordError, isSecure: true) {
                $focus.track(.password, $0)
            }
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .onSubmit(onSubmit)
            .onChange(of: viewModel.password) { _, _ in viewModel.passwordError = nil }

            AuthErrorLine(message: viewModel.formError)

            HStack {
                if let biometricUnlock {
                    Button("Unlock with \(biometricUnlock.kind.title)", systemImage: biometricUnlock.kind.icon, action: biometricUnlock.action)
                }
                Spacer(minLength: 0)
                Button("Forgot password?", action: onForgot)
            }
            .font(DS.Typography.brand(.subheadline, weight: .semibold))
            .foregroundStyle(DS.Colors.brandInk)
            .frame(minHeight: 40)
            .buttonStyle(SquishStyle(scale: 0.95))
        }
        .shake(on: viewModel.shakeTrigger)
    }
}

// MARK: - Shared

struct AuthEmailField: View {

    @Bindable var viewModel: AuthViewModel
    @Binding var focus: AuthFocus?

    var body: some View {
        StageField(symbol: "envelope.fill", prompt: "Email", text: $viewModel.email, error: viewModel.emailError) {
            $focus.track(.email, $0)
        }
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onChange(of: viewModel.email) { _, _ in viewModel.emailError = nil }
    }
}

/// A whole-form failure: wrong credentials, network.
struct AuthErrorLine: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, symbol: .caution)
                .font(DS.Typography.brand(.footnote))
                .foregroundStyle(DS.Colors.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension Binding<AuthFocus?> {
    /// Follows one field gaining or losing the keyboard.
    func track(_ field: AuthFocus, _ isFocused: Bool) {
        if isFocused { wrappedValue = field } else if wrappedValue == field { wrappedValue = nil }
    }
}
