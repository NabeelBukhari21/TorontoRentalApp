//
//  AuthFlowView.swift
//  RentalApp (Purrperty)
//
//  Auth — Flow container. Owns the AuthViewModel and switches between
//  Login / Role Selection / Sign Up / Forgot Password / Reset Password
//  on one Purr stage.
//
//  It handles navigation *between* credential screens; what a
//  successful sign-in means is decided one level up by
//  `SessionViewModel`. That's why this view reports a `SignInOutcome`
//  rather than a bare "done".
//

import SwiftUI

struct AuthFlowView: View {

    /// Ordered so `rawValue` comparison gives the slide direction.
    enum Screen: Int {
        case login
        case roleSelection
        case signUp
        case forgotPassword
        case resetPassword
    }

    /// Called with whatever the provider returned — a session, or an
    /// MFA challenge the session coordinator will route to.
    let onAuthenticated: (SignInOutcome) -> Void

    /// Called instead of `onAuthenticated` when the password sign-up form
    /// created a brand-new account, so the session can start the
    /// getting-started flow for it.
    let onSignedUp: (SignInOutcome) -> Void

    /// Back from the login screen to the welcome, when that's where the
    /// person came from.
    private let onBack: (() -> Void)?

    /// Offered on the login screen when a biometric-gated session is
    /// already on this device.
    private let biometricUnlock: BiometricUnlockOption?

    @State private var viewModel: AuthViewModel
    @State private var screen: Screen = .login
    @State private var movesForward = true
    @State private var focus: AuthFocus?
    @FocusState private var signUpFocus: OnboardingField?
    @Environment(\.dynamicTypeSize) private var typeSize

    init(
        container: AppContainer = .shared,
        biometricUnlock: BiometricUnlockOption? = nil,
        onBack: (() -> Void)? = nil,
        onAuthenticated: @escaping (SignInOutcome) -> Void,
        onSignedUp: ((SignInOutcome) -> Void)? = nil
    ) {
        self.onAuthenticated = onAuthenticated
        self.onSignedUp = onSignedUp ?? onAuthenticated
        self.onBack = onBack
        self.biometricUnlock = biometricUnlock
        let viewModel = AuthViewModel(auth: container.auth, prefilledEmail: container.sessionStore.lastSignedInEmail)
        // Sign-up shows a live checklist instead of asking twice.
        viewModel.requiresPasswordConfirmation = false
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // One stage for every screen: Purr and the counter stay, and only
        // what's on it changes.
        PurrStage(
            step: step,
            accent: accent, mood: mood, title: title, line: line,
            movesForward: movesForward,
            props: props,
            celebrates: step.isDone,
            onBack: back
        ) {
            content
        } actions: {
            actions
        }
        .animation(DS.Motion.gentle, value: viewModel.formError)
        .onChange(of: screen) { _, _ in
            focus = nil
            signUpFocus = nil
        }
    }

    // MARK: Step

    private struct Step: Hashable {
        let screen: Screen
        /// The link was sent, or the password changed.
        let isDone: Bool
    }

    private var step: Step {
        switch screen {
        case .forgotPassword: Step(screen: screen, isDone: viewModel.resetLinkSent)
        case .resetPassword: Step(screen: screen, isDone: viewModel.passwordResetDone)
        case .login, .roleSelection, .signUp: Step(screen: screen, isDone: false)
        }
    }

    private var title: String {
        switch screen {
        case .login: "Welcome back"
        case .roleSelection: "Who are you?"
        case .signUp: "Create your account"
        case .forgotPassword: step.isDone ? "Check your inbox" : "Forgot password?"
        case .resetPassword: step.isDone ? "Password updated" : "Set a new password"
        }
    }

    private var line: String {
        switch screen {
        case .login: "Sign in to pick up where you left off."
        case .roleSelection: "I'll set things up to match."
        case .signUp: "Signing up as: \(viewModel.selectedRole.title)"
        case .forgotPassword: step.isDone ? "We sent a reset link to \(viewModel.email)." : "It happens. I'll email you a reset link."
        case .resetPassword: step.isDone ? "Your new password is ready to use." : "Go on, I'm not looking."
        }
    }

    private var accent: DSAccent {
        if step.isDone { return .gold }
        return switch screen {
        case .login, .signUp: .blush
        case .roleSelection: .gold
        case .forgotPassword: .sky
        case .resetPassword: .mint
        }
    }

    private var props: [String] {
        if step.isDone { return ["star.fill", "sparkles"] }
        return switch screen {
        case .login: ["key.fill", "heart.fill"]
        case .roleSelection: ["key.fill", "house.fill"]
        case .signUp: ["lock.fill", "heart.fill"]
        case .forgotPassword: ["envelope.fill", "questionmark"]
        case .resetPassword: ["lock.fill", "key.fill"]
        }
    }

    /// Purr peeks at the email and looks away from the password.
    private var mood: PurrMood {
        if viewModel.isLoading { return .loading }
        if viewModel.formError != nil, focus == nil, signUpFocus == nil { return .loginFailed }
        switch screen {
        case .login:
            return focus == .password ? .passwordHidden : focus == .email ? .loginTyping : .login
        case .roleSelection:
            return viewModel.selectedRole.mood
        case .signUp:
            if !viewModel.name.isEmpty, viewModel.emailLooksValid, viewModel.passwordRequirements.allSatisfy(\.isMet) { return .signUpDone }
            return signUpFocus == .password ? .passwordHidden : signUpFocus == nil ? .signUp : .loginTyping
        case .forgotPassword:
            return step.isDone ? .resetEmailSent : focus == .email ? .loginTyping : .forgotPassword
        case .resetPassword:
            return step.isDone ? .loginSuccess : .passwordHidden
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch screen {
        case .login:
            LoginForm(
                viewModel: viewModel, focus: $focus, biometricUnlock: biometricUnlock,
                onSubmit: logIn, onForgot: { navigate(to: .forgotPassword) }
            )
        case .roleSelection:
            StageAnswers(choices: viewModel.roleChoices)
        case .signUp:
            OnboardingSignUpForm(auth: viewModel, focus: $signUpFocus) { navigate(to: .login) }
                .shake(on: viewModel.shakeTrigger)
        case .forgotPassword:
            if !step.isDone {
                VStack(spacing: 10) {
                    AuthEmailField(viewModel: viewModel, focus: $focus)
                        .submitLabel(.send)
                        .onSubmit(sendLink)
                    AuthErrorLine(message: viewModel.formError)
                }
                .shake(on: viewModel.shakeTrigger)
            }
        case .resetPassword:
            if !step.isDone {
                ResetPasswordForm(viewModel: viewModel, focus: $focus, onSubmit: resetPassword)
            }
        }
    }

    // MARK: Actions

    @ViewBuilder private var actions: some View {
        switch screen {
        case .login:
            withPartners(onOutcome: onAuthenticated) {
                SakugaButton(title: "Sign in", impact: .full, symbol: "chevron.forward", isLoading: viewModel.isLoading, action: logIn)
            }
            StageLink(title: "New to Purrperty? Create account") { navigate(to: .roleSelection) }
            #if DEBUG
            // Test builds only: the mock accounts.
            AuthDemoHint()
            #endif
        case .roleSelection:
            StageButton(title: "Continue") { navigate(to: .signUp) }
            StageLink(title: "Already have an account? Sign in") { navigate(to: .login) }
        case .signUp:
            withPartners(onOutcome: onAuthenticated) {
                SakugaButton(title: "Create account", impact: .full, symbol: "chevron.forward", isLoading: viewModel.isLoading, action: signUp)
            }
        case .forgotPassword:
            if step.isDone {
                StageButton(title: "Set a new password", isProminent: true) { navigate(to: .resetPassword) }
                StageLink(title: "Back to sign in") { navigate(to: .login) }
            } else {
                StageButton(title: "Send the link", isLoading: viewModel.isLoading, isProminent: true, action: sendLink)
                StageLink(title: "Remembered it? Sign in") { navigate(to: .login) }
            }
        case .resetPassword:
            if step.isDone {
                StageButton(title: "Sign in", isProminent: true) { navigate(to: .login) }
            } else {
                StageButton(title: "Update password", isLoading: viewModel.isLoading, isProminent: true, action: resetPassword)
                StageLink(title: "Back to sign in") { navigate(to: .login) }
            }
        }
    }

    /// Apple and Google beside the main button.
    private func withPartners(onOutcome: @escaping (SignInOutcome) -> Void, @ViewBuilder main: () -> some View) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            HStack(spacing: 12) {
                ForEach([SocialProvider.apple, .google], id: \.self) { provider in
                    OnboardingSocialButton(provider: provider) {
                        TapAwayKeyboard.dismiss()
                        Task {
                            if let outcome = await viewModel.signIn(with: provider) { onOutcome(outcome) }
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.loadingProvider != nil)
                }
            }
            main()
        }
        .padding(.bottom, 6)
    }

    private func logIn() {
        TapAwayKeyboard.dismiss()
        Task {
            if let outcome = await viewModel.logIn() { onAuthenticated(outcome) }
        }
    }

    private func signUp() {
        TapAwayKeyboard.dismiss()
        Task {
            if let outcome = await viewModel.signUp() { onSignedUp(outcome) }
        }
    }

    private func sendLink() {
        TapAwayKeyboard.dismiss()
        Task { await viewModel.sendResetLink() }
    }

    private func resetPassword() {
        TapAwayKeyboard.dismiss()
        Task { await viewModel.resetPassword() }
    }

    // MARK: Navigation

    /// Sign-up backs into role selection, everything else into login —
    /// so the user never loses the role they just chose.
    private var back: (() -> Void)? {
        switch screen {
        case .login: onBack
        case .signUp: { navigate(to: .roleSelection) }
        case .roleSelection, .forgotPassword, .resetPassword: { navigate(to: .login) }
        }
    }

    private func navigate(to destination: Screen) {
        guard destination != screen else { return }
        movesForward = destination.rawValue > screen.rawValue
        viewModel.resetTransientState()
        withAnimation(DS.Motion.scene) {
            screen = destination
        }
    }
}

// MARK: - Previews

#Preview("Auth Flow") {
    AuthFlowView(container: .preview, onAuthenticated: { _ in })
}
