//
//  GettingStartedView.swift
//  RentalApp (Purrperty)
//
//  Getting started — First property, the aha celebration with the
//  founder's note, notification priming, then the trial paywall.
//

import SwiftUI

struct GettingStartedView: View {

    @State private var viewModel: GettingStartedViewModel
    private let container: AppContainer

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
        ZStack {
            SplashBackground()
            if viewModel.step != .paywall {
                SplashParticleField(particleCount: 12)
            }

            if viewModel.step == .paywall {
                PaywallFlowView(container: container, profile: viewModel.profile, source: "onboarding") { _ in
                    viewModel.finish()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    if viewModel.step.isPropertyStep {
                        topBar.transition(.opacity)
                    }
                    content
                }
            }

            if viewModel.step == .celebration {
                OrgConfettiBurst()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .animation(DS.Motion.smooth, value: viewModel.step)
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: DS.Spacing.md) {
            AuthBackButton { viewModel.goBack() }
                .opacity(viewModel.step == .kind ? 0 : 1)
                .disabled(viewModel.step == .kind)

            OnboardingProgressBar(progress: viewModel.progress, label: viewModel.stepLabel)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.sm)
    }

    @ViewBuilder
    private var content: some View {
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

        footer
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.lg)
            .frame(maxWidth: 560)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch viewModel.step {
        case .kind, .address, .name, .units:
            VStack(spacing: DS.Spacing.xl) {
                OnboardingQuestionHeader(mood: viewModel.mascotMood, question: viewModel.question, line: viewModel.mascotLine)
                propertyField
                if let error = viewModel.saveError {
                    AuthFormError(message: error)
                }
            }
        case .saving:
            VStack(spacing: DS.Spacing.xxl) {
                MascotView(mood: .working, size: 120, isInteractive: false)
                    .padding(.top, DS.Spacing.xxl)
                Text("Moving \(viewModel.draft.name) in…")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                OnboardingBuildChecklist(tasks: viewModel.saveTasks)
            }
        case .celebration:
            GettingStartedCelebration(propertyName: viewModel.createdProperty?.name ?? viewModel.draft.name, firstName: viewModel.firstName)
        case .notifications:
            GettingStartedNotificationPriming(propertyName: viewModel.createdProperty?.name)
        case .paywall:
            EmptyView()
        }
    }

    @ViewBuilder
    private var propertyField: some View {
        @Bindable var viewModel = viewModel

        switch viewModel.step {
        case .kind:
            VStack(spacing: DS.Spacing.md) {
                ForEach(Array(PropertyKind.allCases.enumerated()), id: \.element) { index, kind in
                    OnboardingChoiceCard(
                        icon: kind.icon, tint: tint(for: kind),
                        title: kind.rawValue, subtitle: subtitle(for: kind),
                        isSelected: viewModel.draft.kind == kind && viewModel.step != .kind
                    ) { viewModel.choose(kind) }
                    .dsEntrance(index: index)
                }
            }
        case .address:
            AuthCard {
                VStack(spacing: DS.Spacing.lg) {
                    AuthTextField(
                        label: "Street address", text: $viewModel.draft.addressLine1,
                        icon: "mappin.and.ellipse", textContentType: .fullStreetAddress
                    )
                    AuthTextField(
                        label: "Postal code (optional)", text: $viewModel.draft.postalCode,
                        icon: "envelope.open.fill", textContentType: .postalCode,
                        error: viewModel.postalCodeIsValid ? nil : "That doesn't look like a Canadian postal code",
                        showsValidCheck: !viewModel.draft.postalCode.isEmpty && viewModel.postalCodeIsValid
                    )
                    AuthTextField(label: "City", text: $viewModel.draft.city, icon: "building.columns.fill", textContentType: .addressCity)
                }
            }
        case .name:
            AuthCard {
                AuthTextField(label: "Property name", text: $viewModel.draft.name, icon: "tag.fill")
            }
        case .units:
            unitsStepper
        default:
            EmptyView()
        }
    }

    private var unitsStepper: some View {
        HStack(spacing: DS.Spacing.xl) {
            stepperButton("minus", delta: -1, disabled: viewModel.unitCount <= 1)

            Text("\(viewModel.unitCount)")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(DS.Colors.textPrimary)
                .contentTransition(.numericText(value: Double(viewModel.unitCount)))
                .frame(minWidth: 120)
                .accessibilityLabel("\(viewModel.unitCount) units")

            stepperButton("plus", delta: 1, disabled: viewModel.unitCount >= GettingStartedViewModel.maxUnits)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).strokeBorder(DS.Colors.outline, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: viewModel.unitCount)
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            viewModel.changeUnits(by: direction == .increment ? 1 : -1)
        }
    }

    private func stepperButton(_ icon: String, delta: Int, disabled: Bool) -> some View {
        Button { viewModel.changeUnits(by: delta) } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(DS.Colors.textOnBrand)
                .frame(width: 56, height: 56)
                .background(DS.Colors.brand, in: Circle())
        }
        .buttonStyle(DSPressStyle(scale: 0.9))
        .buttonRepeatBehavior(.enabled)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(delta > 0 ? "More units" : "Fewer units")
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        switch viewModel.step {
        case .kind:
            Button("I'll add one later") { viewModel.skipProperty() }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.vertical, DS.Spacing.md)
        case .address, .name, .units:
            DSButton(
                title: viewModel.step == .units ? "Add my property" : "Continue",
                variant: .primary, size: .large, isFullWidth: true
            ) { viewModel.advance() }
            .disabled(!viewModel.canContinue)
        case .celebration:
            DSButton(title: "Keep going", icon: "arrow.right", variant: .primary, size: .large, isFullWidth: true) {
                viewModel.advance()
            }
        case .notifications:
            VStack(spacing: DS.Spacing.sm) {
                DSButton(title: "Turn on notifications", icon: "bell.fill", variant: .primary, size: .large, isFullWidth: true) {
                    Task { await viewModel.enableNotifications() }
                }
                Button("Not now") { viewModel.declineNotifications() }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.vertical, DS.Spacing.sm)
            }
        case .saving, .paywall:
            EmptyView()
        }
    }

    // MARK: Kind Styling

    private func tint(for kind: PropertyKind) -> Color {
        switch kind {
        case .condo:      DS.Colors.accentSky
        case .multiUnit:  DS.Colors.accentSunny
        case .house:      DS.Colors.accentMint
        case .commercial: DS.Colors.accentCoral
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

    @State private var celebrated = false

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            MascotView(mood: .excited, size: 200)
                .padding(.top, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.sm) {
                Text("\(propertyName) is live!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Your first property is on Purrperty.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .dsEntrance(index: 1)

            FounderNoteCard(firstName: firstName)
                .dsEntrance(index: 3)
        }
        .sensoryFeedback(.success, trigger: celebrated)
        .onAppear { celebrated = true }
    }
}

/// A short, handwritten-style note. Signed by a person, not a brand.
private struct FounderNoteCard: View {

    let firstName: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Hi \(firstName),")
                .font(.custom("Noteworthy-Bold", size: 20, relativeTo: .title3))

            Text("Thank you for giving Purrperty a try. I built it so looking after your rentals takes minutes, not evenings. I hope it does exactly that for you.")
                .font(.custom("Noteworthy-Light", size: 17, relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) {
                Text(FounderNote.signature)
                    .font(.custom("SnellRoundhand-Bold", size: 30, relativeTo: .title))
                    .foregroundStyle(DS.Colors.brandInk)
                Text(FounderNote.title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Colors.accentSunny.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Colors.accentSunny.opacity(0.5), lineWidth: 1)
        )
        .rotationEffect(.degrees(-1.2))
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
/// they tap "Turn on" (playbook §7).
private struct GettingStartedNotificationPriming: View {

    let propertyName: String?

    @State private var bannerVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            ZStack(alignment: .top) {
                MascotView(mood: .happy, size: 170)
                    .padding(.top, 96)

                banner
                    .offset(y: bannerVisible ? 0 : -40)
                    .opacity(bannerVisible ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.sm) {
                Text("Never miss a rent payment")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Get a nudge the moment rent lands, a repair comes in or a tenant messages you. You choose which in Settings.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : DS.Motion.bouncy.delay(0.4)) { bannerVisible = true }
        }
    }

    private var banner: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            PurrpertyLogoTile(size: 40, animates: false)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Purrperty")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("now")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Text("Rent received ✅")
                    .font(.system(size: 15, weight: .semibold))
                Text(propertyName.map { "Unit 1 at \($0) just paid this month's rent." } ?? "Unit 2 just paid this month's rent.")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(DS.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(DS.Colors.outline, lineWidth: 1))
        .dsShadow(DS.Shadows.floating)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example notification: Rent received")
    }
}
