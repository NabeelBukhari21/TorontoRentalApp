//
//  GettingStartedView.swift
//  RentalApp (Purrperty)
//
//  Getting started — First property (one question per screen), the aha
//  celebration with the founder's note, notification priming, then the
//  trial paywall. Same structure as onboarding: system navigation bar,
//  inset-grouped list with Purr and a large title, one action at the
//  bottom.
//

import SwiftUI

struct GettingStartedView: View {

    @State private var viewModel: GettingStartedViewModel
    private let container: AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .transition(.move(edge: .bottom))
        } else {
            NavigationStack {
                content
                    .id(viewModel.step)
                    .transition(reduceMotion ? .opacity : .push(from: viewModel.movesForward ? .trailing : .leading))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbar }
            }
            .overlay {
                if viewModel.step == .celebration {
                    OrgConfettiBurst()
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if viewModel.step.isPropertyStep && viewModel.step != .kind {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", systemImage: "chevron.backward") { viewModel.goBack() }
            }
        }
        if viewModel.step.isPropertyStep {
            ToolbarItem(placement: .principal) {
                OnboardingProgressView(progress: viewModel.progress, label: viewModel.stepLabel)
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .kind, .address, .name, .units:
            propertyStep
        case .saving:
            savingStep
        case .celebration:
            GettingStartedCelebration(
                propertyName: viewModel.createdProperty?.name ?? viewModel.draft.name,
                firstName: viewModel.firstName,
                onContinue: viewModel.advance
            )
        case .notifications:
            GettingStartedNotificationPriming(
                propertyName: viewModel.createdProperty?.name,
                onEnable: { Task { await viewModel.enableNotifications() } },
                onDecline: viewModel.declineNotifications
            )
        case .paywall:
            EmptyView()
        }
    }

    // MARK: Property Steps

    private var propertyStep: some View {
        @Bindable var viewModel = viewModel

        return List {
            Section {
                OnboardingHeader(mood: viewModel.mascotMood, title: viewModel.question, message: viewModel.mascotLine)
            }
            .onboardingHeaderSection()

            switch viewModel.step {
            case .kind:
                Section {
                    ForEach(PropertyKind.allCases, id: \.self) { kind in
                        OnboardingOptionRow(
                            symbol: kind.icon, tint: tint(for: kind),
                            title: kind.rawValue, subtitle: subtitle(for: kind),
                            isSelected: false
                        ) { viewModel.choose(kind) }
                    }
                }

            case .address:
                Section {
                    LabeledContent("Street") {
                        TextField("Street", text: $viewModel.draft.addressLine1, prompt: Text("Required"))
                            .textContentType(.fullStreetAddress)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Postal code") {
                        TextField("Postal code", text: $viewModel.draft.postalCode, prompt: Text("Optional"))
                            .textContentType(.postalCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("City") {
                        TextField("City", text: $viewModel.draft.city)
                            .textContentType(.addressCity)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    if !viewModel.postalCodeIsValid {
                        Label("That doesn't look like a Canadian postal code.", symbol: .caution)
                            .foregroundStyle(.red)
                    }
                }

            case .name:
                Section {
                    TextField("Property name", text: $viewModel.draft.name, prompt: Text("Property name"))
                        .submitLabel(.next)
                        .onSubmit { if viewModel.canContinue { viewModel.advance() } }
                } footer: {
                    Text("Shown in your list and on Home.")
                }

            case .units:
                Section {
                    Stepper(value: $viewModel.unitCount, in: 1...GettingStartedViewModel.maxUnits) {
                        LabeledContent("Units") {
                            Text(viewModel.unitCount, format: .number)
                                .contentTransition(.numericText(value: Double(viewModel.unitCount)))
                                .monospacedDigit()
                        }
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.unitCount)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("You can name each unit later, from the property.")
                        if let error = viewModel.saveError {
                            Label(error, symbol: .caution).foregroundStyle(.red)
                        }
                    }
                }

            default:
                EmptyView()
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .onboardingBottomBar {
            switch viewModel.step {
            case .kind:
                Button("I'll add one later") { viewModel.skipProperty() }
                    .frame(minHeight: 44)
            default:
                OnboardingPrimaryButton(title: viewModel.step == .units ? "Add property" : "Continue") {
                    viewModel.advance()
                }
                .disabled(!viewModel.canContinue)
            }
        }
    }

    // MARK: Saving

    private var savingStep: some View {
        List {
            Section {
                OnboardingHeader(mood: .working, title: "Adding \(viewModel.draft.name)")
            }
            .onboardingHeaderSection()

            Section {
                ForEach(viewModel.saveTasks) { task in
                    OnboardingChecklistRow(task: task)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarBackButtonHidden()
    }

    // MARK: Kind Styling

    private func tint(for kind: PropertyKind) -> Color {
        switch kind {
        case .condo:      .blue
        case .multiUnit:  .orange
        case .house:      .green
        case .commercial: .red
        }
    }

    private func subtitle(for kind: PropertyKind) -> String {
        switch kind {
        case .condo:      "A condo unit or townhome"
        case .multiUnit:  "Duplex to apartment block"
        case .house:      "A single-family home"
        case .commercial: "Retail, office or industrial"
        }
    }
}

// MARK: - Celebration

/// The aha moment: confetti, Purr leaping, and a personal note from the
/// founder (playbook §3).
private struct GettingStartedCelebration: View {

    let propertyName: String
    let firstName: String
    let onContinue: () -> Void

    @State private var celebrated = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MascotView(mood: .excited, size: 180)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("\(propertyName) is live")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your first property is on Purrperty.")
                        .foregroundStyle(.secondary)
                }

                FounderNoteCard(firstName: firstName)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.groupedBackground)
        .navigationBarBackButtonHidden()
        .onboardingBottomBar {
            OnboardingPrimaryButton(title: "Continue", action: onContinue)
        }
        .sensoryFeedback(.success, trigger: celebrated)
        .onAppear { celebrated = true }
    }
}

/// A short note signed by a person, not a brand.
private struct FounderNoteCard: View {

    let firstName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hi \(firstName),")
                .font(.headline)

            Text("Thanks for giving Purrperty a try. I built it so looking after your rentals takes minutes, not evenings. I hope it does exactly that for you.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(FounderNote.signature)
                    .font(.title3.italic())
                    .foregroundStyle(.tint)
                Text(FounderNote.title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
        .accessibilityElement(children: .combine)
    }
}

/// Who signs the note at the aha moment.
enum FounderNote {
    static let signature = "Nabeel"
    static let title = "Founder, Purrperty"
}

// MARK: - Notification Priming

/// A preview of a real notification first; the system prompt only if
/// they tap "Turn on notifications" (playbook §7).
private struct GettingStartedNotificationPriming: View {

    let propertyName: String?
    let onEnable: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                notificationPreview
                    .padding(.top, 24)

                MascotView(mood: .happy, size: 140)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Never miss a rent payment")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Get a nudge when rent lands, a repair comes in or a tenant messages you. You choose which in Settings.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.groupedBackground)
        .navigationBarBackButtonHidden()
        .onboardingBottomBar {
            OnboardingPrimaryButton(title: "Turn on notifications", action: onEnable)
            Button("Not now", action: onDecline)
                .frame(minHeight: 44)
        }
    }

    /// An illustration of the banner they'll get — plain content, not glass.
    private var notificationPreview: some View {
        HStack(alignment: .top, spacing: 12) {
            PurrpertyLogoTile(size: 38, animates: false)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Purrperty").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("now").font(.footnote).foregroundStyle(.secondary)
                }
                Text("Rent received").font(.subheadline.weight(.semibold))
                Text(propertyName.map { "Unit 1 at \($0) just paid this month's rent." } ?? "Unit 2 just paid this month's rent.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.secondaryGroupedBackground, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example notification: Rent received")
    }
}
