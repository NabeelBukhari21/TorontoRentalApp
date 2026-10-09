//
//  ForgotPasswordView.swift
//  RentalApp
//
//  Auth — Request a reset link, with an animated success state.
//

import SwiftUI

struct ForgotPasswordView: View {

    @Bindable var viewModel: AuthViewModel
    let onNavigate: (AuthFlowView.Screen) -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            if viewModel.resetLinkSent {
                successContent
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                formContent
                    .transition(.opacity)
            }
        }
        .animation(DS.Motion.smooth, value: viewModel.resetLinkSent)
    }

    // MARK: Form

    private var formContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            AuthHeader(
                title: "Forgot password?",
                subtitle: "Enter your email and we'll send you a reset link"
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

                    if let formError = viewModel.formError {
                        AuthFormError(message: formError)
                    }

                    DSButton(
                        title: "Send Reset Link",
                        icon: DS.Icons.send,
                        variant: .primary,
                        size: .large,
                        isFullWidth: true,
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            _ = await viewModel.sendResetLink()
                        }
                    }
                }
            }
            .dsEntrance(index: 1)

            AuthFooterLink(prompt: "Remembered it?", actionTitle: "Back to sign in") {
                onNavigate(.login)
            }
            .dsEntrance(index: 2)
        }
    }

    // MARK: Success

    private var successContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            AuthSuccessBadge()

            VStack(spacing: DS.Spacing.sm) {
                Text("Check your inbox")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("We sent a reset link to\n\(viewModel.email)")
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            AuthCard {
                VStack(spacing: DS.Spacing.md) {
                    DSButton(
                        title: "I have my code — set new password",
                        variant: .soft,
                        size: .large,
                        isFullWidth: true
                    ) {
                        onNavigate(.resetPassword)
                    }

                    DSButton(
                        title: "Back to Sign In",
                        variant: .ghost,
                        size: .medium,
                        isFullWidth: true
                    ) {
                        onNavigate(.login)
                    }
                }
            }
        }
    }
}
