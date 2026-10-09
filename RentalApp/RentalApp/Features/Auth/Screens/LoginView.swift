//
//  LoginView.swift
//  RentalApp (RentOS)
//
//  Auth — Sign in: email + password, forgot-password link,
//  Apple/Google placeholders, biometric unlock for returning users,
//  loading state.
//

import SwiftUI

struct LoginView: View {

    @Bindable var viewModel: AuthViewModel
    let onNavigate: (AuthFlowView.Screen) -> Void
    let onAuthenticated: (SignInOutcome) -> Void
    /// Present only when this device has a biometric-gated session
    /// stored — the one-tap path back in for a returning user.
    var biometricUnlock: BiometricUnlockOption? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            AuthHeader(
                title: "Welcome back",
                subtitle: "Sign in to manage your portfolio"
            )
            .dsEntrance(index: 0)

            AuthCard {
                VStack(spacing: DS.Spacing.lg) {
                    AuthTextField(
                        label: "Email",
                        text: $viewModel.email,
                        icon: "envelope.fill",
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        error: viewModel.emailError,
                        showsValidCheck: viewModel.emailLooksValid,
                        shakeTrigger: viewModel.shakeTrigger
                    )
                    .onChange(of: viewModel.email) { _, _ in
                        viewModel.emailError = nil
                    }

                    AuthTextField(
                        label: "Password",
                        text: $viewModel.password,
                        icon: "lock.fill",
                        isSecure: true,
                        textContentType: .password,
                        error: viewModel.passwordError,
                        shakeTrigger: viewModel.shakeTrigger
                    )
                    .onChange(of: viewModel.password) { _, _ in
                        viewModel.passwordError = nil
                    }

                    HStack {
                        Spacer()
                        Button {
                            onNavigate(.forgotPassword)
                        } label: {
                            Text("Forgot password?")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.Colors.brand)
                        }
                        .buttonStyle(DSPressStyle(scale: 0.95))
                    }

                    if let formError = viewModel.formError {
                        AuthFormError(message: formError)
                    }

                    DSButton(
                        title: "Sign In",
                        variant: .primary,
                        size: .large,
                        isFullWidth: true,
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            if let outcome = await viewModel.logIn() {
                                onAuthenticated(outcome)
                            }
                        }
                    }

                    if let biometricUnlock {
                        AuthBiometricButton(option: biometricUnlock)
                    }

                    AuthDivider()

                    VStack(spacing: DS.Spacing.md) {
                        AuthSocialButton(
                            provider: .apple,
                            isLoading: viewModel.loadingProvider == .apple
                        ) {
                            Task {
                                if let outcome = await viewModel.signIn(with: .apple) {
                                    onAuthenticated(outcome)
                                }
                            }
                        }

                        AuthSocialButton(
                            provider: .google,
                            isLoading: viewModel.loadingProvider == .google
                        ) {
                            Task {
                                if let outcome = await viewModel.signIn(with: .google) {
                                    onAuthenticated(outcome)
                                }
                            }
                        }
                    }
                }
            }
            .dsEntrance(index: 1)

            VStack(spacing: DS.Spacing.md) {
                AuthFooterLink(prompt: "New to RentOS?", actionTitle: "Create account") {
                    onNavigate(.roleSelection)
                }

                AuthDemoHint()
            }
            .dsEntrance(index: 2)
        }
        .animation(DS.Motion.gentle, value: viewModel.formError)
    }
}
