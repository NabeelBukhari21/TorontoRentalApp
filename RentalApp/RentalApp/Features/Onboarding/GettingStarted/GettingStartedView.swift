//
//  GettingStartedView.swift
//  RentalApp (Purrperty)
//
//  Getting started — First property (one question per screen), the aha
//  celebration with the founder's note, notification priming, then the
//  trial paywall, on Purr's stage.
//

import SwiftUI

struct GettingStartedView: View {

    @State private var viewModel: GettingStartedViewModel
    private let container: AppContainer
    @Environment(\.feedback) private var feedback

    init(
        container: AppContainer,
        session: AuthSession,
        onFinished: @escaping (_ addedProperty: Bool) -> Void
    ) {
        self.container = container
        _viewModel = State(initialValue: GettingStartedViewModel(
            session: session,
            container: container,
            onFinished: onFinished
        ))
    }

    var body: some View {
        if viewModel.step == .paywall {
            PaywallFlowView(container: container, profile: viewModel.profile, source: "onboarding") { _ in
                viewModel.finish()
            }
            .transition(.opacity)
        } else {
            PurrStage(
                step: viewModel.step,
                accent: accent,
                mood: mood,
                title: title,
                line: line,
                movesForward: viewModel.movesForward,
                progress: viewModel.step.isPropertyStep ? viewModel.progress : nil,
                progressLabel: viewModel.stepLabel,
                props: props,
                celebrates: viewModel.step == .celebration,
                onBack: viewModel.step.isPropertyStep && viewModel.step != .kind ? { viewModel.goBack() } : nil
            ) {
                content
            } actions: {
                actions
            }
            .overlay {
                if viewModel.step == .celebration {
                    OrgConfettiBurst()
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }
            }
            .onChange(of: viewModel.saveTasks.count { $0.state == .done }) { old, new in
                if new > old { feedback?.play(.taskDone(new - 1)) }
            }
        }
    }

    // MARK: Words

    private var title: String {
        switch viewModel.step {
        case .saving: "Adding \(viewModel.draft.name)"
        case .celebration: "\(propertyName) is live"
        case .notifications: "Never miss a rent payment"
        default: viewModel.question
        }
    }

    private var line: String {
        switch viewModel.step {
        case .saving: "This takes a few seconds."
        case .celebration: "Your first property is on Purrperty."
        case .notifications: "A nudge when rent lands, a repair comes in or a tenant messages you. You choose which in Settings."
        default: viewModel.mascotLine
        }
    }

    private var propertyName: String { viewModel.createdProperty?.name ?? viewModel.draft.name }

    // MARK: Purr

    private var mood: PurrMood {
        switch viewModel.step {
        case .saving: .builder
        case .celebration: .propertyAdded
        case .notifications: .newNotification
        default: viewModel.mascotMood
        }
    }

    private var accent: DSAccent {
        switch viewModel.step {
        case .kind, .celebration: .gold
        case .address: .sky
        case .name: .mint
        case .units, .saving: .blush
        default: .sky
        }
    }

    private var props: [String] {
        switch viewModel.step {
        case .kind: ["house.fill", "building.2.fill"]
        case .address: ["mappin.and.ellipse", "map.fill"]
        case .name: ["pencil", "tag.fill"]
        case .units: ["door.left.hand.closed", "key.fill"]
        case .saving: ["hammer.fill", "gearshape.fill"]
        case .celebration: ["star.fill", "sparkles"]
        default: ["bell.fill", "dollarsign"]
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        @Bindable var viewModel = viewModel

        switch viewModel.step {
        case .kind:
            StageAnswers(choices: kinds)

        case .address:
            VStack(alignment: .leading, spacing: 10) {
                StageField(symbol: "mappin", prompt: "Street", text: $viewModel.draft.addressLine1)
                    .textContentType(.fullStreetAddress)
                StageField(
                    symbol: "envelope.fill", prompt: "Postal code (optional)", text: $viewModel.draft.postalCode,
                    error: viewModel.postalCodeIsValid ? nil : "That doesn't look like a Canadian postal code."
                )
                .textContentType(.postalCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                StageField(symbol: "building.2.fill", prompt: "City", text: $viewModel.draft.city)
                    .textContentType(.addressCity)
            }

        case .name:
            VStack(alignment: .leading, spacing: 10) {
                StageField(symbol: "tag.fill", prompt: "Property name", text: $viewModel.draft.name)
                    .submitLabel(.next)
                    .onSubmit { if viewModel.canContinue { viewModel.advance() } }
                Text("Shown in your list and on Home.")
                    .font(DS.Typography.brand(.footnote, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
            }

        case .units:
            VStack(spacing: 12) {
                StageStepper(value: $viewModel.unitCount, range: 1...GettingStartedViewModel.maxUnits, label: "Units")
                Text("You can name each unit later, from the property.")
                    .font(DS.Typography.brand(.footnote, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
                if let error = viewModel.saveError {
                    Label(error, symbol: .caution)
                        .font(DS.Typography.brand(.footnote))
                        .foregroundStyle(DS.Colors.danger)
                }
            }

        case .saving:
            VStack(spacing: 12) {
                ForEach(viewModel.saveTasks) { OnboardingBuildPill(task: $0) }
                SakugaProgress(value: saveProgress, showsLabel: false)
                    .padding(.top, 54)
            }
            .frame(maxWidth: .infinity)

        case .celebration:
            FounderNoteCard(firstName: viewModel.firstName)

        case .notifications:
            notificationPreview

        case .paywall:
            EmptyView()
        }
    }

    private var saveProgress: Double {
        guard !viewModel.saveTasks.isEmpty else { return 0 }
        let done = Double(viewModel.saveTasks.count { $0.state == .done })
        return min(1, (done + 0.35) / Double(viewModel.saveTasks.count))
    }

    private var kinds: [OnboardingChoice] {
        zip(PropertyKind.allCases, [DSAccent.sky, .gold, .mint, .cherry]).map { kind, accent in
            OnboardingChoice(
                id: kind.rawValue, title: kind.rawValue, subtitle: subtitle(for: kind), symbol: kind.icon,
                accent: accent, isSelected: viewModel.draft.kind == kind && viewModel.hasChosenKind
            ) { viewModel.choose(kind) }
        }
    }

    private func subtitle(for kind: PropertyKind) -> String {
        switch kind {
        case .condo:      "Condo or townhome"
        case .multiUnit:  "Duplex to apartments"
        case .house:      "Single-family home"
        case .commercial: "Retail or office"
        }
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        switch viewModel.step {
        case .kind:
            StageLink(title: "I'll add one later") { viewModel.skipProperty() }
        case .saving, .paywall:
            EmptyView()
        case .notifications:
            StageButton(title: "Turn on notifications", isProminent: true) {
                Task { await viewModel.enableNotifications() }
            }
            StageLink(title: "Not now", action: viewModel.declineNotifications)
        default:
            StageButton(title: viewModel.step == .units ? "Add property" : "Continue", isEnabled: viewModel.canContinue) {
                viewModel.advance()
            }
        }
    }

    // MARK: Notification Preview

    /// A preview of the banner they'll get; the system prompt shows only
    /// if they tap "Turn on notifications" (playbook §7).
    private var notificationPreview: some View {
        let property = viewModel.createdProperty?.name
        return HStack(alignment: .top, spacing: 12) {
            PurrpertyLogoTile(size: 38, animates: false)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Purrperty").font(DS.Typography.brand(.subheadline, weight: .semibold))
                    Spacer()
                    Text("now").font(DS.Typography.brand(.footnote, weight: .regular)).foregroundStyle(DS.Colors.textSecondary)
                }
                Text("Rent received").font(DS.Typography.brand(.subheadline, weight: .semibold))
                Text(property.map { "Unit 1 at \($0) just paid this month's rent." } ?? "Unit 2 just paid this month's rent.")
                    .font(DS.Typography.brand(.subheadline, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .stagePanel()
        .shadow(color: DS.Colors.groundShadow, radius: 10, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example notification: Rent received")
    }
}

// MARK: - Founder's Note

/// A short note signed by a person, not a brand.
private struct FounderNoteCard: View {

    let firstName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hi \(firstName),")
                .font(DS.Typography.brand(.headline, weight: .semibold))
            Text("Thanks for giving Purrperty a try. I built it so looking after your rentals takes minutes, not evenings. I hope it does exactly that for you.")
                .font(DS.Typography.brand(.callout, weight: .regular))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(FounderNote.signature)
                    .font(DS.Typography.brand(.title3, weight: .semibold))
                    .foregroundStyle(DS.Colors.brandInk)
                Text(FounderNote.title)
                    .font(DS.Typography.brand(.footnote, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .stagePanel()
        .accessibilityElement(children: .combine)
    }
}

/// Who signs the note at the aha moment.
enum FounderNote {
    static let signature = "Nabeel"
    static let title = "Founder, Purrperty"
}
