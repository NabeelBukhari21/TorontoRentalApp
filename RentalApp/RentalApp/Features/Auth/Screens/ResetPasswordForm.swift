//
//  ResetPasswordForm.swift
//  RentalApp (Purrperty)
//
//  Auth — Choosing a new password, with the same live checklist as
//  sign-up.
//

import SwiftUI

struct ResetPasswordForm: View {

    @Bindable var viewModel: AuthViewModel
    @Binding var focus: AuthFocus?
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            field("New password", text: $viewModel.newPassword, error: viewModel.newPasswordError)
                .onChange(of: viewModel.newPassword) { _, _ in viewModel.newPasswordError = nil }
            FlowLayoutCompat(spacing: 6) {
                ForEach(viewModel.newPasswordRequirements) { OnboardingRequirementChip(requirement: $0) }
            }
            .animation(DS.Motion.bouncy, value: viewModel.newPassword)
            field("Type it again", text: $viewModel.confirmNewPassword, error: viewModel.confirmNewPasswordError)
                .submitLabel(.go)
                .onSubmit(onSubmit)
                .onChange(of: viewModel.confirmNewPassword) { _, _ in viewModel.confirmNewPasswordError = nil }
            AuthErrorLine(message: viewModel.formError)
        }
        .shake(on: viewModel.shakeTrigger)
    }

    private func field(_ prompt: String, text: Binding<String>, error: String?) -> some View {
        StageField(symbol: "lock.fill", prompt: prompt, text: text, error: error, isSecure: true) {
            $focus.track(.password, $0)
        }
        .textContentType(.newPassword)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }
}
