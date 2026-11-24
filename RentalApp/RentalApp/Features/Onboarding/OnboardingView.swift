//
//  OnboardingView.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Flow container: the welcome and the fly-over fill the
//  screen, then every step after them is one continuous scene
//  (`OnboardingScene`).
//
//  The flow, answers and analytics live in `OnboardingFlowViewModel`;
//  docs/ONBOARDING_PLAYBOOK.md explains why it's shaped this way.
//

import SwiftUI

struct OnboardingView: View {

    /// Onboarding ended with a new account.
    let onSignedUp: (SignInOutcome) -> Void
    /// "I already have an account" — go to sign-in.
    let onSignIn: () -> Void

    @State private var viewModel: OnboardingFlowViewModel

    init(
        container: AppContainer,
        onSignedUp: @escaping (SignInOutcome) -> Void,
        onSignIn: @escaping () -> Void
    ) {
        self.onSignedUp = onSignedUp
        self.onSignIn = onSignIn
        _viewModel = State(initialValue: OnboardingFlowViewModel(
            store: container.onboardingProfile,
            preferences: container.preferences,
            dashboard: container.dashboard,
            authService: container.auth,
            analytics: container.analytics
        ))
    }

    var body: some View {
        ZStack {
            switch viewModel.step {
            case .welcome:
                OnboardingWelcomeStep(onStart: viewModel.advance, onSignIn: onSignIn)
                    .transition(.opacity)
            case .intro:
                OnboardingIntroStep { viewModel.finishIntro(skipped: $0) }
                    .transition(.opacity)
            default:
                OnboardingScene(viewModel: viewModel, onSignedUp: onSignedUp, onSignIn: onSignIn)
                    .transition(.opacity)
            }
        }
        #if DEBUG
        .task { await OnboardingAutopilot.run(viewModel) }
        #endif
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingView(container: .preview, onSignedUp: { _ in }, onSignIn: {})
}
