//
//  LoginView.swift
//  RentalApp (Purrperty)
//
//  Auth — Sign in on Purr's stage, like the rest of onboarding: email and
//  password, forgotten password, Apple and Google, and biometric unlock
//  for returning users.
//

import SwiftUI

struct LoginView: View {

    @Bindable var viewModel: AuthViewModel
    let onNavigate: (AuthFlowView.Screen) -> Void
    let onAuthenticated: (SignInOutcome) -> Void
    /// Present only when this device has a biometric-gated session
    /// stored — the one-tap path back in for a returning user.
    var biometricUnlock: BiometricUnlockOption? = nil
    /// Back to the welcome, when that's where they came from.
    var onBack: (() -> Void)? = nil

    private enum Field { case email, password }
    @State private var focus: Field?

    /// Purr peeks at the email and looks away from the password.
    private var mood: PurrMood {
        if viewModel.isLoading { return .loading }
        switch focus {
        case .password: return .passwordHidden
        case .email:    return .loginTyping
        case nil:       return viewModel.formError == nil ? .login : .loginFailed
        }
    }

    private func focusChanged(_ field: Field, _ focused: Bool) {
        if focused { focus = field } else if focus == field { focus = nil }
    }

    var body: some View {
        PurrStage(
            step: 0, accent: .blush, mood: mood,
            title: "Welcome back",
            line: "Sign in to pick up where you left off.",
            props: ["key.fill", "heart.fill"],
            onBack: onBack
        ) {
            form
        } actions: {
            actions
        }
        .animation(DS.Motion.gentle, value: viewModel.formError)
    }

    private var form: some View {
        VStack(spacing: 10) {
            StageField(symbol: "envelope.fill", prompt: "Email", text: $viewModel.email, error: viewModel.emailError) {
                focusChanged(.email, $0)
            }
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .onChange(of: viewModel.email) { _, _ in viewModel.emailError = nil }

            StageField(symbol: "lock.fill", prompt: "Password", text: $viewModel.password, error: viewModel.passwordError, isSecure: true) {
                focusChanged(.password, $0)
            }
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .onSubmit(logIn)
            .onChange(of: viewModel.password) { _, _ in viewModel.passwordError = nil }

            if let formError = viewModel.formError {
                Label(formError, symbol: .caution)
                    .font(DS.Typography.brand(.footnote))
                    .foregroundStyle(DS.Colors.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if let biometricUnlock {
                    Button("Unlock with \(biometricUnlock.kind.title)", systemImage: biometricUnlock.kind.icon, action: biometricUnlock.action)
                }
                Spacer(minLength: 0)
                Button("Forgot password?") { onNavigate(.forgotPassword) }
            }
            .font(DS.Typography.brand(.subheadline, weight: .semibold))
            .foregroundStyle(DS.Colors.brandInk)
            .frame(minHeight: 40)
            .buttonStyle(SquishStyle(scale: 0.95))
        }
        .shake(on: viewModel.shakeTrigger)
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    @ViewBuilder private var actions: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            HStack(spacing: 12) {
                social(.apple)
                social(.google)
            }
            SakugaButton(title: "Sign in", impact: .full, symbol: "chevron.forward", isLoading: viewModel.isLoading, action: logIn)
        }
        .padding(.bottom, 6)
        StageLink(title: "New to Purrperty? Create account") { onNavigate(.roleSelection) }
        #if DEBUG
        // Test builds only: the mock accounts.
        AuthDemoHint()
        #endif
    }

    private func social(_ provider: SocialProvider) -> some View {
        OnboardingSocialButton(provider: provider) {
            TapAwayKeyboard.dismiss()
            Task {
                if let outcome = await viewModel.signIn(with: provider) { onAuthenticated(outcome) }
            }
        }
        .disabled(viewModel.isLoading || viewModel.loadingProvider != nil)
    }

    private func logIn() {
        TapAwayKeyboard.dismiss()
        Task {
            if let outcome = await viewModel.logIn() { onAuthenticated(outcome) }
        }
    }
}
