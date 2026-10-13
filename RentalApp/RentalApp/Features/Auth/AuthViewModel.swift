//
//  AuthViewModel.swift
//  RentalApp (Purrperty)
//
//  Auth — View model for the credential screens.
//
//  Owns field state, validation, and loading. It calls
//  `AuthServiceProtocol` and hands the resulting `SignInOutcome` back
//  to the flow; deciding *what that means* is the session
//  coordinator's job, not this one's. Keeping the split means the mock
//  provider and a real one are interchangeable without touching a view.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class AuthViewModel {

    // MARK: Fields

    var name = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    var newPassword = ""
    var confirmNewPassword = ""

    /// Chosen on the role-selection screen and carried into sign-up.
    var selectedRole: AppRole = .owner

    /// The auth screens ask for the password twice. Onboarding's sign-up
    /// shows a reveal toggle and a live checklist instead, so it switches
    /// the second field off.
    var requiresPasswordConfirmation = true

    // MARK: UI State

    var isLoading = false
    var loadingProvider: SocialProvider?

    /// Incremented to trigger the shake animation on invalid submits.
    var shakeTrigger = 0

    /// Field-level validation errors (nil = valid / untouched).
    var nameError: String?
    var emailError: String?
    var passwordError: String?
    var confirmPasswordError: String?
    var newPasswordError: String?
    var confirmNewPasswordError: String?

    /// Whole-form failure from the service (bad credentials, taken email).
    var formError: String?

    /// Success flags for the recovery screens.
    var resetLinkSent = false
    var passwordResetDone = false

    // MARK: Dependencies

    private let auth: AuthServiceProtocol

    init(auth: AuthServiceProtocol, prefilledEmail: String? = nil) {
        self.auth = auth
        self.email = prefilledEmail ?? ""
    }

    // MARK: Live Validation Helpers

    var emailLooksValid: Bool {
        email.range(
            of: #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#,
            options: .regularExpression
        ) != nil
    }

    /// 0...1 password strength: length, case mix, digits, symbols.
    var passwordStrength: Double {
        strength(of: password)
    }

    var newPasswordStrength: Double {
        strength(of: newPassword)
    }

    /// The rules a new password must meet, each with its live state.
    /// What the checklist shows is exactly what validation enforces.
    var passwordRequirements: [PasswordRequirement] {
        PasswordRequirement.Rule.allCases.map {
            PasswordRequirement(rule: $0, isMet: $0.isMet(by: password))
        }
    }

    private func meetsRequirements(_ value: String) -> Bool {
        PasswordRequirement.Rule.allCases.allSatisfy { $0.isMet(by: value) }
    }

    private func strength(of value: String) -> Double {
        guard !value.isEmpty else { return 0 }
        var score = 0.0
        if value.count >= 8 { score += 0.25 }
        if value.count >= 12 { score += 0.15 }
        if value.rangeOfCharacter(from: .uppercaseLetters) != nil,
           value.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 0.2 }
        if value.rangeOfCharacter(from: .decimalDigits) != nil { score += 0.2 }
        if value.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil { score += 0.2 }
        return min(score, 1)
    }

    // MARK: Validation

    private func validateEmailField() {
        emailError = emailLooksValid ? nil : "Enter a valid email address"
    }

    func validateLogin() -> Bool {
        validateEmailField()
        // Deliberately lenient on length here: the server decides
        // whether a password is right. Demo accounts use 6 characters.
        passwordError = password.isEmpty ? "Enter your password" : nil
        return failIfNeeded(emailError, passwordError)
    }

    func validateSignUp() -> Bool {
        nameError = name.trimmingCharacters(in: .whitespaces).count >= 2 ? nil : "Enter your full name"
        validateEmailField()
        passwordError = meetsRequirements(password) ? nil : "Use 8+ characters with a mix of letters and numbers"
        if requiresPasswordConfirmation {
            confirmPasswordError = confirmPassword == password && !password.isEmpty ? nil : "Passwords don't match"
        }
        return failIfNeeded(nameError, emailError, passwordError, confirmPasswordError)
    }

    func validateForgotPassword() -> Bool {
        validateEmailField()
        return failIfNeeded(emailError)
    }

    func validateResetPassword() -> Bool {
        newPasswordError = meetsRequirements(newPassword) ? nil : "Use 8+ characters with a mix of letters and numbers"
        confirmNewPasswordError = confirmNewPassword == newPassword && !newPassword.isEmpty ? nil : "Passwords don't match"
        return failIfNeeded(newPasswordError, confirmNewPasswordError)
    }

    /// Shakes and returns false when any error is present.
    private func failIfNeeded(_ errors: String?...) -> Bool {
        if errors.contains(where: { $0 != nil }) {
            withAnimation(.linear(duration: 0.4)) {
                shakeTrigger += 1
            }
            return false
        }
        return true
    }

    // MARK: Actions

    /// Returns the outcome on success, nil when validation or the
    /// service rejected the attempt.
    func logIn() async -> SignInOutcome? {
        guard validateLogin() else { return nil }
        return await perform {
            try await self.auth.signIn(email: self.email, password: self.password)
        }
    }

    func signUp() async -> SignInOutcome? {
        guard validateSignUp() else { return nil }
        return await perform {
            try await self.auth.signUp(
                name: self.name,
                email: self.email,
                password: self.password,
                role: self.selectedRole
            )
        }
    }

    func signIn(with provider: SocialProvider) async -> SignInOutcome? {
        loadingProvider = provider
        formError = nil
        defer { loadingProvider = nil }

        do {
            return try await auth.signIn(with: provider)
        } catch {
            surface(error)
            return nil
        }
    }

    @discardableResult
    func sendResetLink() async -> Bool {
        guard validateForgotPassword() else { return false }
        isLoading = true
        formError = nil
        defer { isLoading = false }

        do {
            try await auth.sendPasswordReset(to: email)
            withAnimation(DS.Motion.bouncy) { resetLinkSent = true }
            return true
        } catch {
            surface(error)
            return false
        }
    }

    @discardableResult
    func resetPassword() async -> Bool {
        guard validateResetPassword() else { return false }
        isLoading = true
        formError = nil
        defer { isLoading = false }

        do {
            try await auth.resetPassword(newPassword: newPassword)
            withAnimation(DS.Motion.bouncy) { passwordResetDone = true }
            return true
        } catch {
            surface(error)
            return false
        }
    }

    // MARK: Plumbing

    private func perform(_ work: @escaping () async throws -> SignInOutcome) async -> SignInOutcome? {
        isLoading = true
        formError = nil
        defer { isLoading = false }

        do {
            return try await work()
        } catch {
            surface(error)
            return nil
        }
    }

    /// Service failures shake the form the same way validation does —
    /// to the user there's no difference between "wrong password" and
    /// "invalid email", so they shouldn't look different either.
    private func surface(_ error: Error) {
        formError = (error as? AppError)?.errorDescription ?? AppError.unknown.errorDescription
        withAnimation(.linear(duration: 0.4)) { shakeTrigger += 1 }
    }

    // MARK: Housekeeping

    /// Clears transient state when switching between screens.
    func resetTransientState() {
        isLoading = false
        loadingProvider = nil
        nameError = nil
        emailError = nil
        passwordError = nil
        confirmPasswordError = nil
        newPasswordError = nil
        confirmNewPasswordError = nil
        formError = nil
        resetLinkSent = false
        passwordResetDone = false
    }
}

// MARK: - Password Requirements

/// One rule of the new-password policy and whether it's currently met.
struct PasswordRequirement: Identifiable, Equatable {

    enum Rule: CaseIterable {
        case length
        case letter
        case number

        var title: String {
            switch self {
            case .length: "At least 8 characters"
            case .letter: "A letter"
            case .number: "A number"
            }
        }

        func isMet(by value: String) -> Bool {
            switch self {
            case .length: value.count >= 8
            case .letter: value.rangeOfCharacter(from: .letters) != nil
            case .number: value.rangeOfCharacter(from: .decimalDigits) != nil
            }
        }
    }

    let rule: Rule
    let isMet: Bool

    var id: Rule { rule }
}
