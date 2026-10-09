//
//  AuthFlowView.swift
//  RentalApp (RentOS)
//
//  Auth — Flow container. Owns the AuthViewModel and switches between
//  Login / Role Selection / Sign Up / Forgot Password / Reset Password
//  with directional slide-and-fade transitions over the shared
//  animated background.
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

    /// Offered on the login screen when a biometric-gated session is
    /// already on this device.
    private let biometricUnlock: BiometricUnlockOption?

    @State private var viewModel: AuthViewModel
    @State private var screen: Screen = .login
    @State private var movesForward = true

    init(
        container: AppContainer = .shared,
        biometricUnlock: BiometricUnlockOption? = nil,
        onAuthenticated: @escaping (SignInOutcome) -> Void
    ) {
        self.onAuthenticated = onAuthenticated
        self.biometricUnlock = biometricUnlock
        _viewModel = State(initialValue: AuthViewModel(
            auth: container.auth,
            prefilledEmail: container.sessionStore.lastSignedInEmail
        ))
    }

    var body: some View {
        ZStack {
            SplashBackground()
            SplashParticleField(particleCount: 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if screen != .login {
                        HStack {
                            AuthBackButton {
                                navigate(to: backDestination)
                            }
                            Spacer()
                        }
                        .padding(.bottom, DS.Spacing.lg)
                        .transition(.opacity)
                    }

                    screenContent
                        .id(screen)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: movesForward ? .trailing : .leading)
                                    .combined(with: .opacity),
                                removal: .move(edge: movesForward ? .leading : .trailing)
                                    .combined(with: .opacity)
                            )
                        )
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: Screens

    @ViewBuilder
    private var screenContent: some View {
        switch screen {
        case .login:
            LoginView(
                viewModel: viewModel,
                onNavigate: { navigate(to: $0) },
                onAuthenticated: onAuthenticated,
                biometricUnlock: biometricUnlock
            )
        case .roleSelection:
            RoleSelectionView(
                viewModel: viewModel,
                onNavigate: { navigate(to: $0) }
            )
        case .signUp:
            SignUpView(
                viewModel: viewModel,
                onNavigate: { navigate(to: $0) },
                onAuthenticated: onAuthenticated
            )
        case .forgotPassword:
            ForgotPasswordView(
                viewModel: viewModel,
                onNavigate: { navigate(to: $0) }
            )
        case .resetPassword:
            ResetPasswordView(
                viewModel: viewModel,
                onNavigate: { navigate(to: $0) }
            )
        }
    }

    // MARK: Navigation

    /// Sign-up backs into role selection, everything else into login —
    /// so the user never loses the role they just chose.
    private var backDestination: Screen {
        screen == .signUp ? .roleSelection : .login
    }

    private func navigate(to destination: Screen) {
        guard destination != screen else { return }
        movesForward = destination.rawValue > screen.rawValue
        viewModel.resetTransientState()
        withAnimation(DS.Motion.smooth) {
            screen = destination
        }
    }
}

// MARK: - Previews

#Preview("Auth Flow") {
    AuthFlowView(container: .preview, onAuthenticated: { _ in })
}
