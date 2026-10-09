//
//  SignUpView.swift
//  RentalApp
//
//  Auth — Create account: name, email, password with live strength
//  meter, confirmation, and social placeholders.
//

import SwiftUI

struct SignUpView: View {

    @Bindable var viewModel: AuthViewModel
    let onNavigate: (AuthFlowView.Screen) -> Void
    let onAuthenticated: (SignInOutcome) -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            AuthHeader(
                title: "Create your account",
                subtitle: "Start managing properties in minutes"
            )
            .dsEntrance(index: 0)

            AuthSelectedRoleChip(role: viewModel.selectedRole) {
                onNavigate(.roleSelection)
            }
            .dsEntrance(index: 1)

            AuthCard {
                VStack(spacing: DS.Spacing.lg) {
                    AuthTextField(
                        label: "Full name",
                        text: $viewModel.name,
                        icon: "person.fill",
                        textContentType: .name,
                        error: viewModel.nameError,
                        shakeTrigger: viewModel.shakeTrigger
                    )
                    .onChange(of: viewModel.name) { _, _ in
                        viewModel.nameError = nil
                    }

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

                    VStack(spacing: DS.Spacing.sm) {
                        AuthTextField(
                            label: "Password",
                            text: $viewModel.password,
                            icon: "lock.fill",
                            isSecure: true,
                            textContentType: .newPassword,
                            error: viewModel.passwordError,
                            shakeTrigger: viewModel.shakeTrigger
                        )
                        .onChange(of: viewModel.password) { _, _ in
                            viewModel.passwordError = nil
                        }

                        if !viewModel.password.isEmpty {
                            AuthPasswordStrengthMeter(strength: viewModel.passwordStrength)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(DS.Motion.gentle, value: viewModel.password.isEmpty)

                    AuthTextField(
                        label: "Confirm password",
                        text: $viewModel.confirmPassword,
                        icon: "lock.fill",
                        isSecure: true,
                        textContentType: .newPassword,
                        error: viewModel.confirmPasswordError,
                        showsValidCheck: !viewModel.confirmPassword.isEmpty
                            && viewModel.confirmPassword == viewModel.password,
                        shakeTrigger: viewModel.shakeTrigger
                    )
                    .onChange(of: viewModel.confirmPassword) { _, _ in
                        viewModel.confirmPasswordError = nil
                    }

                    if let formError = viewModel.formError {
                        AuthFormError(message: formError)
                    }

                    DSButton(
                        title: "Create Account",
                        variant: .primary,
                        size: .large,
                        isFullWidth: true,
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            if let outcome = await viewModel.signUp() {
                                onAuthenticated(outcome)
                            }
                        }
                    }

                    Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)

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
            .dsEntrance(index: 2)

            AuthFooterLink(prompt: "Already have an account?", actionTitle: "Sign in") {
                onNavigate(.login)
            }
            .dsEntrance(index: 3)
        }
        .animation(DS.Motion.gentle, value: viewModel.formError)
    }
}
