//
//  OnboardingSteps.swift
//  RentalApp (Purrperty)
//
//  Onboarding — The content of each step, as list sections. The
//  container (`OnboardingView`) supplies the list, the navigation bar
//  with Back and progress, and the bottom bar with the main action.
//

import SwiftUI

// MARK: - Hello

/// The hook: Purr's hello clip and one outcome-led promise.
struct OnboardingHelloStep: View {

    let onStart: () -> Void
    let onSignIn: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Artwork gives way to text at accessibility sizes.
                MascotClipView(clip: .hello, size: typeSize.isAccessibilitySize ? 120 : 220)
                    .accessibilityLabel("Purr, the Purrperty cat, waving hello")

                Text("Never chase rent again.")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Rent, repairs and tenants, sorted in one place. I'm Purr, and I'll help.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .primaryActionBar {
            PrimaryActionButton(title: "Get started", action: onStart)
            Button("I already have an account", action: onSignIn)
                .frame(minHeight: 44)
        }
    }
}

// MARK: - Persona

struct OnboardingPersonaStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    var body: some View {
        Section {
            ForEach(OnboardingPersona.allCases) { persona in
                ChoiceRow(
                    symbol: persona.icon, tint: persona.tint,
                    title: persona.title, subtitle: persona.subtitle,
                    isSelected: viewModel.profile.persona == persona
                ) { viewModel.select(persona) }
            }
        }
    }
}

// MARK: - Units

struct OnboardingUnitsStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    var body: some View {
        Section {
            ForEach(OnboardingUnitRange.allCases) { range in
                ChoiceRow(
                    symbol: range.icon, tint: range.tint,
                    title: range.title, subtitle: range.subtitle,
                    isSelected: viewModel.profile.unitRange == range
                ) { viewModel.select(range) }
                .accessibilityLabel("\(range.title) units, \(range.subtitle)")
            }
        }
    }
}

// MARK: - Headaches

struct OnboardingHeadachesStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    var body: some View {
        Section {
            ForEach(OnboardingHeadache.allCases) { headache in
                ChoiceRow(
                    symbol: headache.icon, tint: headache.tint,
                    title: headache.title,
                    isSelected: viewModel.profile.headaches.contains(headache),
                    isMultiSelect: true
                ) { viewModel.toggle(headache) }
            }
        } footer: {
            Text("Choose as many as you like.")
        }
    }
}

// MARK: - Goal

struct OnboardingGoalStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    var body: some View {
        Section {
            ForEach(OnboardingGoal.allCases) { goal in
                ChoiceRow(
                    symbol: goal.icon, tint: goal.tint,
                    title: goal.title, subtitle: goal.subtitle,
                    isSelected: viewModel.profile.goal == goal
                ) { viewModel.select(goal) }
            }
        }
    }
}

// MARK: - Appearance

/// "Make it yours": Light, Dark or Automatic, like Settings → Display.
struct OnboardingPersonalizeStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    var body: some View {
        Section {
            ForEach(AppTheme.allCases) { theme in
                ChoiceRow(
                    symbol: theme.icon,
                    tint: theme == .dark ? .indigo : theme == .light ? .orange : .gray,
                    title: theme == .system ? "Automatic" : theme.rawValue,
                    subtitle: theme == .system ? "Match your iPhone's setting" : nil,
                    isSelected: viewModel.theme == theme
                ) { viewModel.theme = theme }
            }
        }
    }
}

// MARK: - Building

struct OnboardingBuildingStep: View {

    let tasks: [OnboardingBuildTask]

    var body: some View {
        Section {
            ForEach(tasks) { task in
                OnboardingChecklistRow(task: task)
            }
        }
    }
}

// MARK: - Unlocked

struct OnboardingUnlockedStep: View {

    let profile: OnboardingProfile

    var body: some View {
        Section {
            ForEach(profile.unlocks) { unlock in
                OnboardingUnlockRow(unlock: unlock)
            }
        }
    }
}

// MARK: - Sign-Up

/// The sign-up screen as a pitch (playbook §3): the outcome they chose,
/// reasons that are true today, and a short form with a live password
/// checklist.
struct OnboardingSignUpStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel
    let onSignedUp: (SignInOutcome) -> Void
    let onSignIn: () -> Void

    private enum Field { case name, email, password }
    @FocusState private var focus: Field?

    private var isTenant: Bool { viewModel.profile.persona == .tenant }

    var body: some View {
        @Bindable var auth = viewModel.auth

        Section {
            TextField("Name", text: $auth.name)
                .textContentType(.name)
                .submitLabel(.next)
                .focused($focus, equals: .name)
                .onSubmit { focus = .email }
                .onChange(of: auth.name) { _, _ in auth.nameError = nil }

            TextField("Email", text: $auth.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .email)
                .onSubmit { focus = .password }
                .onChange(of: auth.email) { _, _ in auth.emailError = nil }

            SecureField("Password", text: $auth.password)
                .textContentType(.newPassword)
                .submitLabel(.done)
                .focused($focus, equals: .password)
                .onChange(of: auth.password) { _, _ in auth.passwordError = nil }
        } header: {
            Text("Your account")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(auth.passwordRequirements) { requirement in
                    PasswordRequirementRow(requirement: requirement)
                }
                ForEach([auth.nameError, auth.emailError, auth.passwordError, auth.formError].compactMap { $0 }, id: \.self) { error in
                    Label(error, symbol: .caution)
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, 4)
        }

        Section {
            reason("Free to start, no card needed")
            reason(isTenant ? "Your landlord can invite you straight in" : "Your answers are already saved")
            reason(isTenant ? "Made in Toronto" : "Made in Toronto, for Canadian landlords")
        }

        Section {
            Button {
                Task { await signIn(with: .apple) }
            } label: {
                Label("Continue with Apple", systemImage: "apple.logo")
            }
            Button {
                Task { await signIn(with: .google) }
            } label: {
                Label("Continue with Google", systemImage: "g.circle")
            }
        } footer: {
            VStack(alignment: .leading, spacing: 12) {
                Text(.init("By continuing, you agree to the [Terms of Service](\(LegalDocument.termsOfService.url().absoluteString)) and [Privacy Policy](\(LegalDocument.privacyPolicy.url().absoluteString))."))
                Button("Already have an account? Sign in", action: onSignIn)
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private func reason(_ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private func signIn(with provider: SocialProvider) async {
        if let outcome = await viewModel.signIn(with: provider) {
            onSignedUp(outcome)
        }
    }
}
