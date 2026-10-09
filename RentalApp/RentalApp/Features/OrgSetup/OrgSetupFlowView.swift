//
//  OrgSetupFlowView.swift
//  RentalApp
//
//  Org Setup — Wizard container. Progress bar, animated step header,
//  directional step transitions, and back/continue navigation.
//

import SwiftUI

struct OrgSetupFlowView: View {

    /// Called when setup completes, carrying the organization the
    /// session should be bound to.
    let onFinished: (_ organizationID: String, _ organizationName: String) -> Void

    @State private var viewModel: OrgSetupViewModel

    init(
        container: AppContainer = .shared,
        onFinished: @escaping (_ organizationID: String, _ organizationName: String) -> Void
    ) {
        self.onFinished = onFinished
        _viewModel = State(initialValue: OrgSetupViewModel(service: container.organization))
    }

    var body: some View {
        ZStack {
            SplashBackground()
            SplashParticleField(particleCount: 14)

            if viewModel.isComplete {
                OrgCompletionView(viewModel: viewModel) {
                    onFinished(
                        viewModel.createdOrganizationID ?? "org_unknown",
                        viewModel.orgName.trimmingCharacters(in: .whitespaces)
                    )
                }
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                wizard
                    .transition(.opacity)
            }
        }
    }

    // MARK: Wizard

    private var wizard: some View {
        VStack(spacing: 0) {
            // Progress.
            OrgSetupProgressBar(
                progress: viewModel.progress,
                stepIndex: viewModel.step.rawValue,
                stepCount: OrgSetupStep.allCases.count
            )
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)

            // Step content.
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.xxl) {
                    OrgSetupStepHeader(step: viewModel.step, isReady: viewModel.canContinue)
                        .id("header-\(viewModel.step.rawValue)")
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    stepContent
                        .id("step-\(viewModel.step.rawValue)")
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: viewModel.movesForward ? .trailing : .leading)
                                    .combined(with: .opacity),
                                removal: .move(edge: viewModel.movesForward ? .leading : .trailing)
                                    .combined(with: .opacity)
                            )
                        )
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            // Navigation.
            HStack(spacing: DS.Spacing.md) {
                if viewModel.step != .name {
                    AuthBackButton {
                        viewModel.goBack()
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                DSButton(
                    title: viewModel.continueTitle,
                    variant: .primary,
                    size: .large,
                    isFullWidth: true,
                    isLoading: viewModel.isSubmitting
                ) {
                    Task { await viewModel.advance() }
                }
                .disabled(!viewModel.canContinue || viewModel.isSubmitting)
                .animation(DS.Motion.gentle, value: viewModel.canContinue)
            }
            .animation(DS.Motion.smooth, value: viewModel.step)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
            .overlay(alignment: .top) {
                if let error = viewModel.submissionError {
                    AuthFormError(message: error)
                        .padding(.horizontal, DS.Spacing.xl)
                        .offset(y: -DS.Spacing.xxl)
                }
            }
            .animation(DS.Motion.gentle, value: viewModel.submissionError)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .name:
            OrgNameStep(viewModel: viewModel)
        case .logo:
            OrgLogoStep(viewModel: viewModel)
        case .propertyType:
            OrgTypeStep(viewModel: viewModel)
        case .portfolioSize:
            OrgSizeStep(viewModel: viewModel)
        case .inviteTeam:
            OrgInviteStep(viewModel: viewModel)
        }
    }
}

// MARK: - Previews

#Preview("Org Setup") {
    OrgSetupFlowView(container: .preview) { _, _ in }
}
