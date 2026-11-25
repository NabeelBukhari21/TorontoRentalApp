//
//  OrgSetupFlowView.swift
//  RentalApp
//
//  Org Setup — Workspace setup on Purr's stage, carrying on from the
//  sign-up scene.
//

import SwiftUI

struct OrgSetupFlowView: View {

    /// Called when setup completes, carrying the organization the
    /// session should be bound to.
    let onFinished: (_ organizationID: String, _ recap: WorkspaceRecap) -> Void
    /// Getting started shows the finished workspace itself.
    private let showsCompletion: Bool

    @State private var viewModel: OrgSetupViewModel

    init(
        container: AppContainer = .shared,
        profile: OnboardingProfile = OnboardingProfile(),
        ownerName: String = "",
        showsCompletion: Bool = true,
        onFinished: @escaping (_ organizationID: String, _ recap: WorkspaceRecap) -> Void
    ) {
        self.showsCompletion = showsCompletion
        self.onFinished = onFinished
        _viewModel = State(initialValue: OrgSetupViewModel(
            service: container.organization,
            units: profile.unitRange,
            journey: SetupJourney(profile: profile),
            ownerName: ownerName
        ))
    }

    var body: some View {
        PurrStage(
            step: isDone ? -1 : viewModel.step.rawValue,
            accent: accent,
            mood: mood,
            title: isDone ? "Your workspace is ready" : viewModel.step.title,
            line: isDone ? "\(viewModel.orgName) is ready to go." : viewModel.step.subtitle,
            movesForward: viewModel.movesForward,
            progress: viewModel.progress,
            progressLabel: viewModel.progressLabel,
            props: isDone ? ["star.fill", "sparkles"] : viewModel.step.props,
            celebrates: isDone,
            onBack: viewModel.step == .name || isDone ? nil : { viewModel.goBack() }
        ) {
            if isDone {
                OrgSummary(recap: viewModel.recap)
            } else {
                stepContent
            }
        } actions: {
            if let error = viewModel.submissionError {
                AuthFormError(message: error)
            }
            if isDone {
                // "Continue", not "Go to Dashboard": a new account goes on
                // to getting started (first property) before Home.
                StageButton(title: "Continue") {
                    finish()
                }
            } else {
                StageButton(title: viewModel.continueTitle, isEnabled: viewModel.canContinue, isLoading: viewModel.isSubmitting || viewModel.isComplete) {
                    Task {
                        await viewModel.advance()
                        if viewModel.isComplete, !showsCompletion { finish() }
                    }
                }
            }
        }
        .overlay {
            if isDone {
                OrgConfettiBurst()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
    }

    private var isDone: Bool { viewModel.isComplete && showsCompletion }

    private func finish() {
        onFinished(viewModel.createdOrganizationID ?? "org_unknown", viewModel.recap)
    }

    private var accent: DSAccent {
        if isDone { return .gold }
        return switch viewModel.step {
        case .name: .gold
        case .logo: .blush
        case .propertyType: .sky
        case .inviteTeam: .mint
        }
    }

    private var mood: PurrMood {
        if isDone { return .partyTime }
        return switch viewModel.step {
        case .name: viewModel.canContinue ? .success : .editProfile
        case .logo: .profilePhoto
        case .propertyType: viewModel.propertyType == nil ? .properties : .keysReady
        case .inviteTeam: viewModel.inviteEmails.isEmpty ? .inviteFriends : .thankYou
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .name: OrgNameStep(viewModel: viewModel)
        case .logo: OrgLogoStep(viewModel: viewModel)
        case .propertyType: StageAnswers(choices: viewModel.typeChoices)
        case .inviteTeam: OrgInviteStep(viewModel: viewModel)
        }
    }
}

extension OrgSetupStep {
    /// Clay props around Purr.
    var props: [String] {
        switch self {
        case .name: ["hammer.fill", "paintbrush.fill"]
        case .logo: ["photo.fill", "paintbrush.fill"]
        case .propertyType: ["house.fill", "building.fill"]
        case .inviteTeam: ["envelope.fill", "person.2.fill"]
        }
    }
}

extension OrgSetupViewModel {

    var typeChoices: [OnboardingChoice] {
        zip(PropertyTypeOption.allCases, [DSAccent.sky, .gold, .cherry, .mint, .blush]).map { option, accent in
            OnboardingChoice(id: option.id, title: option.title, subtitle: "", symbol: option.icon, accent: accent,
                             isSelected: propertyType == option) {
                withAnimation(DS.Motion.bouncy) { self.propertyType = option }
            }
        }
    }
}

// MARK: - Previews

#Preview("Org Setup") {
    OrgSetupFlowView(container: .preview) { _, _ in }
}
