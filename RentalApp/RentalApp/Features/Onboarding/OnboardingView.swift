//
//  OnboardingView.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Flow container. A navigation stack gives each step a
//  system navigation bar (Back, and progress in the principal slot); the
//  step itself is an inset-grouped list topped by Purr and a large title;
//  the step's single main action sits in a bottom bar.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        NavigationStack {
            Group {
                if viewModel.step == .hello {
                    OnboardingHelloStep(onStart: viewModel.advance, onSignIn: onSignIn)
                } else {
                    stepList
                }
            }
            .id(viewModel.step)
            .transition(reduceMotion ? .opacity : .push(from: viewModel.movesForward ? .trailing : .leading))
            .toolbar { toolbar }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if viewModel.step.allowsBack {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", systemImage: "chevron.backward") { viewModel.goBack() }
            }
        }
        if viewModel.step.showsProgress {
            ToolbarItem(placement: .principal) {
                OnboardingProgressView(progress: viewModel.progress, label: viewModel.stepLabel)
            }
        }
    }

    // MARK: Step

    private var stepList: some View {
        List {
            Section {
                OnboardingHeader(mood: viewModel.mascotMood, title: header.title, message: header.message)
            }
            .onboardingHeaderSection()

            stepSections
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(Color.groupedBackground)
        .primaryActionBar { bottomBar }
    }

    @ViewBuilder
    private var stepSections: some View {
        switch viewModel.step {
        case .hello:       EmptyView()
        case .persona:     OnboardingPersonaStep(viewModel: viewModel)
        case .units:       OnboardingUnitsStep(viewModel: viewModel)
        case .headaches:   OnboardingHeadachesStep(viewModel: viewModel)
        case .goal:        OnboardingGoalStep(viewModel: viewModel)
        case .personalize: OnboardingPersonalizeStep(viewModel: viewModel)
        case .building:    OnboardingBuildingStep(tasks: viewModel.buildTasks)
        case .unlocked:    OnboardingUnlockedStep(profile: viewModel.profile)
        case .signUp:      OnboardingSignUpStep(viewModel: viewModel, onSignedUp: onSignedUp, onSignIn: onSignIn)
        }
    }

    /// Large title and explanation for the current step.
    private var header: (title: String, message: String?) {
        switch viewModel.step {
        case .building:
            ("Building your Purrperty", "This takes a few seconds.")
        case .unlocked:
            ("Here's what you unlocked", viewModel.profile.goal?.outcome)
        case .signUp:
            ("Create your account", viewModel.profile.persona == .tenant
                ? "Join your landlord on Purrperty."
                : viewModel.profile.goal?.outcome ?? "Save your setup so it's here every time you open the app.")
        default:
            (viewModel.question, viewModel.mascotLine)
        }
    }

    // MARK: Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        switch viewModel.step {
        case .building, .hello:
            EmptyView()
        case .signUp:
            PrimaryActionButton(title: "Create account", isLoading: viewModel.auth.isLoading) {
                Task {
                    if let outcome = await viewModel.signUp() { onSignedUp(outcome) }
                }
            }
        default:
            PrimaryActionButton(title: viewModel.continueTitle) { viewModel.advance() }
                .disabled(!viewModel.canContinue)
        }
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingView(container: .preview, onSignedUp: { _ in }, onSignIn: {})
}
