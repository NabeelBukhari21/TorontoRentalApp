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
    let onFinished: (_ organizationID: String, _ organizationName: String) -> Void

    @State private var viewModel: OrgSetupViewModel

    init(
        container: AppContainer = .shared,
        suggestedSize: PortfolioSizeOption? = nil,
        ownerName: String = "",
        onFinished: @escaping (_ organizationID: String, _ organizationName: String) -> Void
    ) {
        self.onFinished = onFinished
        _viewModel = State(initialValue: OrgSetupViewModel(
            service: container.organization,
            suggestedSize: suggestedSize,
            ownerName: ownerName
        ))
    }

    var body: some View {
        PurrStage(
            step: viewModel.isComplete ? -1 : viewModel.step.rawValue,
            accent: accent,
            mood: mood,
            title: viewModel.isComplete ? "You're all set!" : viewModel.step.title,
            line: viewModel.isComplete ? "\(viewModel.orgName) is ready to go." : viewModel.step.subtitle,
            movesForward: viewModel.movesForward,
            progress: viewModel.isComplete ? nil : viewModel.progress,
            progressLabel: "Step \(viewModel.step.rawValue + 1) of \(OrgSetupStep.allCases.count)",
            props: viewModel.isComplete ? ["star.fill", "sparkles"] : viewModel.step.props,
            celebrates: viewModel.isComplete,
            onBack: viewModel.step == .name || viewModel.isComplete ? nil : { viewModel.goBack() }
        ) {
            if viewModel.isComplete {
                OrgSummary(viewModel: viewModel)
            } else {
                stepContent
            }
        } actions: {
            if let error = viewModel.submissionError {
                AuthFormError(message: error)
            }
            if viewModel.isComplete {
                // "Continue", not "Go to Dashboard": a new account goes on
                // to getting started (first property) before Home.
                StageButton(title: "Continue") {
                    onFinished(
                        viewModel.createdOrganizationID ?? "org_unknown",
                        viewModel.orgName.trimmingCharacters(in: .whitespaces)
                    )
                }
            } else {
                StageButton(title: viewModel.continueTitle, isEnabled: viewModel.canContinue, isLoading: viewModel.isSubmitting) {
                    Task { await viewModel.advance() }
                }
            }
        }
        .overlay {
            if viewModel.isComplete {
                OrgConfettiBurst()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
    }

    private var accent: DSAccent {
        if viewModel.isComplete { return .gold }
        return switch viewModel.step {
        case .name: .gold
        case .logo: .blush
        case .propertyType: .sky
        case .portfolioSize: .mint
        case .inviteTeam: .gold
        }
    }

    private var mood: PurrMood {
        if viewModel.isComplete { return .partyTime }
        return switch viewModel.step {
        case .name: viewModel.canContinue ? .success : .editProfile
        case .logo: .profilePhoto
        case .propertyType: viewModel.propertyType == nil ? .properties : .keysReady
        case .portfolioSize: viewModel.portfolioSize == nil ? .analytics : .clapping
        case .inviteTeam: viewModel.inviteEmails.isEmpty ? .inviteFriends : .thankYou
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .name: OrgNameStep(viewModel: viewModel)
        case .logo: OrgLogoStep(viewModel: viewModel)
        case .propertyType: StageAnswers(choices: viewModel.typeChoices)
        case .portfolioSize: StageAnswers(choices: viewModel.sizeChoices)
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
        case .portfolioSize: ["chart.bar.fill", "house.and.flag.fill"]
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

    var sizeChoices: [OnboardingChoice] {
        zip(PortfolioSizeOption.allCases, [DSAccent.mint, .sky, .gold, .cherry]).map { option, accent in
            OnboardingChoice(id: option.id, title: option.title, subtitle: option.subtitle, symbol: option.icon, accent: accent,
                             isSelected: portfolioSize == option) {
                withAnimation(DS.Motion.bouncy) { self.portfolioSize = option }
            }
        }
    }
}

// MARK: - Previews

#Preview("Org Setup") {
    OrgSetupFlowView(container: .preview) { _, _ in }
}
