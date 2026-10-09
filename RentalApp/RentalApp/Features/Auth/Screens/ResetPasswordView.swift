//
//  ResetPasswordView.swift
//  RentalApp
//
//  Auth — Choose a new password, with strength meter and an
//  animated success state that returns to sign in.
//

import SwiftUI

struct ResetPasswordView: View {

    @Bindable var viewModel: AuthViewModel
    let onNavigate: (AuthFlowView.Screen) -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            if viewModel.passwordResetDone {
                successContent
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                formContent
                    .transition(.opacity)
            }
        }
        .animation(DS.Motion.smooth, value: viewModel.passwordResetDone)
    }

    // MARK: Form

    private var formContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            AuthHeader(
                title: "Set a new password",
                subtitle: "Make it strong — you won't need to remember it here again"
            )
            .dsEntrance(index: 0)

            AuthCard {
                VStack(spacing: DS.Spacing.lg) {
                    VStack(spacing: DS.Spacing.sm) {
                        AuthTextField(
                            label: "New password",
                            text: $viewModel.newPassword,
                            icon: "lock.fill",
                            isSecure: true,
                            textContentType: .newPassword,
                            error: viewModel.newPasswordError,
                            shakeTrigger: viewModel.shakeTrigger
                        )
                        .onChange(of: viewModel.newPassword) { _, _ in
                            viewModel.newPasswordError = nil
                        }

                        if !viewModel.newPassword.isEmpty {
                            AuthPasswordStrengthMeter(strength: viewModel.newPasswordStrength)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(DS.Motion.gentle, value: viewModel.newPassword.isEmpty)

                    AuthTextField(
                        label: "Confirm new password",
                        text: $viewModel.confirmNewPassword,
                        icon: "lock.fill",
                        isSecure: true,
                        textContentType: .newPassword,
                        error: viewModel.confirmNewPasswordError,
                        showsValidCheck: !viewModel.confirmNewPassword.isEmpty
                            && viewModel.confirmNewPassword == viewModel.newPassword,
                        shakeTrigger: viewModel.shakeTrigger
                    )
                    .onChange(of: viewModel.confirmNewPassword) { _, _ in
                        viewModel.confirmNewPasswordError = nil
                    }

                    if let formError = viewModel.formError {
                        AuthFormError(message: formError)
                    }

                    DSButton(
                        title: "Update Password",
                        variant: .primary,
                        size: .large,
                        isFullWidth: true,
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            _ = await viewModel.resetPassword()
                        }
                    }
                }
            }
            .dsEntrance(index: 1)

            AuthFooterLink(prompt: "Changed your mind?", actionTitle: "Back to sign in") {
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
                Text("Password updated")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("Your new password is ready to use.")
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            AuthCard {
                DSButton(
                    title: "Back to Sign In",
                    variant: .primary,
                    size: .large,
                    isFullWidth: true
                ) {
                    onNavigate(.login)
                }
            }
        }
    }
}
