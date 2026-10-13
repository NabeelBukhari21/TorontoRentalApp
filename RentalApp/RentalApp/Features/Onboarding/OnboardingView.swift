//
//  OnboardingView.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Flow container: progress, back, the step, and one
//  primary call to action. See `OnboardingFlowViewModel` for the flow
//  and docs/ONBOARDING_PLAYBOOK.md for why it's shaped this way.
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
            SplashBackground()
            SplashParticleField(particleCount: 14)

            VStack(spacing: 0) {
                if viewModel.step.showsProgress {
                    topBar
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                content
            }
        }
        .animation(DS.Motion.smooth, value: viewModel.step.showsProgress)
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(spacing: DS.Spacing.md) {
            AuthBackButton { viewModel.goBack() }
                .opacity(viewModel.step.allowsBack ? 1 : 0)
                .disabled(!viewModel.step.allowsBack)

            OnboardingProgressBar(progress: viewModel.progress, label: viewModel.stepLabel)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.sm)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if viewModel.step == .hello {
            OnboardingHelloStep(onStart: viewModel.advance, onSignIn: onSignIn)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
                .transition(.opacity)
        } else {
            ScrollView(showsIndicators: false) {
                stepBody
                    .id(viewModel.step)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: viewModel.movesForward ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: viewModel.movesForward ? .leading : .trailing).combined(with: .opacity)
                        )
                    )
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.xl)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)

            if showsContinue {
                DSButton(
                    title: viewModel.continueTitle,
                    variant: .primary,
                    size: .large,
                    isFullWidth: true
                ) { viewModel.advance() }
                .disabled(!viewModel.canContinue)
                .animation(DS.Motion.gentle, value: viewModel.canContinue)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.lg)
                .frame(maxWidth: 560)
                .transition(.opacity)
            }
        }
    }

    /// The building step advances itself and sign-up has its own button.
    private var showsContinue: Bool {
        viewModel.step != .building && viewModel.step != .signUp
    }

    @ViewBuilder
    private var stepBody: some View {
        switch viewModel.step {
        case .hello:
            EmptyView()

        case .persona, .units, .headaches, .goal, .personalize:
            VStack(spacing: DS.Spacing.xl) {
                OnboardingQuestionHeader(
                    mood: viewModel.mascotMood,
                    question: viewModel.question,
                    line: viewModel.mascotLine
                )
                quizOptions
            }

        case .building:
            OnboardingBuildingStep(tasks: viewModel.buildTasks)

        case .unlocked:
            OnboardingUnlockedStep(profile: viewModel.profile)

        case .signUp:
            OnboardingSignUpStep(viewModel: viewModel, onSignedUp: onSignedUp, onSignIn: onSignIn)
        }
    }

    @ViewBuilder
    private var quizOptions: some View {
        switch viewModel.step {
        case .persona:     OnboardingPersonaStep(viewModel: viewModel)
        case .units:       OnboardingUnitsStep(viewModel: viewModel)
        case .headaches:   OnboardingHeadachesStep(viewModel: viewModel)
        case .goal:        OnboardingGoalStep(viewModel: viewModel)
        case .personalize: OnboardingPersonalizeStep(viewModel: viewModel)
        default:           EmptyView()
        }
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingView(container: .preview, onSignedUp: { _ in }, onSignIn: {})
}
