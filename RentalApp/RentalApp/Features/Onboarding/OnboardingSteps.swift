//
//  OnboardingSteps.swift
//  RentalApp (Purrperty)
//
//  Onboarding — The content of each step. Layout chrome (progress, back,
//  the Continue button) lives in `OnboardingView`; these views are only
//  what changes from step to step.
//

import SwiftUI

// MARK: - Hello

/// The hook: Purr's hello clip and one outcome-led promise.
struct OnboardingHelloStep: View {

    let onStart: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer(minLength: DS.Spacing.lg)

            MascotClipView(clip: .hello, size: 250)
                .dsEntrance(index: 0)

            VStack(spacing: DS.Spacing.md) {
                Text("Never chase\nrent again.")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .dsEntrance(index: 1)

                Text("Rent, repairs and tenants, sorted in one place. I'm Purr, and I'll help.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .dsEntrance(index: 2)
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer(minLength: DS.Spacing.lg)

            VStack(spacing: DS.Spacing.md) {
                DSButton(title: "Let's go", icon: "pawprint.fill", variant: .primary, size: .large, isFullWidth: true, action: onStart)

                Button("I already have an account", action: onSignIn)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.brandInk)
                    .padding(.vertical, DS.Spacing.sm)
            }
            .dsEntrance(index: 3)
        }
    }
}

// MARK: - Quiz Header

/// Purr asks; the user taps. One question per screen.
struct OnboardingQuestionHeader: View {

    let mood: MascotMood
    let question: String
    let line: String

    var body: some View {
        MascotGuide(mood: mood, title: question, message: line, mascotSize: 100)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Persona

struct OnboardingPersonaStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(Array(OnboardingPersona.allCases.enumerated()), id: \.element) { index, persona in
                OnboardingChoiceCard(
                    icon: persona.icon, tint: persona.tint,
                    title: persona.title, subtitle: persona.subtitle,
                    isSelected: viewModel.profile.persona == persona
                ) { viewModel.select(persona) }
                .dsEntrance(index: index)
            }
        }
    }
}

// MARK: - Units

struct OnboardingUnitsStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    private let columns = [GridItem(.flexible(), spacing: DS.Spacing.md), GridItem(.flexible(), spacing: DS.Spacing.md)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(Array(OnboardingUnitRange.allCases.enumerated()), id: \.element) { index, range in
                tile(range)
                    .dsEntrance(index: index)
            }
        }
    }

    private func tile(_ range: OnboardingUnitRange) -> some View {
        let isSelected = viewModel.profile.unitRange == range

        return Button { viewModel.select(range) } label: {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: range.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(DS.Colors.textOnAccent)
                    .frame(width: 60, height: 60)
                    .background(range.tint, in: Circle())
                    .scaleEffect(isSelected ? 1.08 : 1)

                Text(range.title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)

                Text(range.subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(isSelected ? DS.Colors.brand.opacity(0.08) : DS.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(isSelected ? DS.Colors.brand : DS.Colors.outline, lineWidth: isSelected ? 2.5 : 1)
            )
            .dsShadow(isSelected ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.18) : DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle(scale: 0.96))
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel("\(range.title) units, \(range.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Headaches

struct OnboardingHeadachesStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(Array(OnboardingHeadache.allCases.enumerated()), id: \.element) { index, headache in
                OnboardingChoiceCard(
                    icon: headache.icon, tint: headache.tint, iconColor: headache.iconColor,
                    title: headache.title,
                    isSelected: viewModel.profile.headaches.contains(headache),
                    isMultiSelect: true
                ) { viewModel.toggle(headache) }
                .dsEntrance(index: index)
            }
        }
    }
}

// MARK: - Goal

struct OnboardingGoalStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(Array(OnboardingGoal.allCases.enumerated()), id: \.element) { index, goal in
                OnboardingChoiceCard(
                    icon: goal.icon, tint: goal.tint,
                    title: goal.title, subtitle: goal.subtitle,
                    isSelected: viewModel.profile.goal == goal
                ) { viewModel.select(goal) }
                .dsEntrance(index: index)
            }
        }
    }
}

// MARK: - Make It Yours

struct OnboardingPersonalizeStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            OnboardingThemePreview()
                .dsEntrance(index: 0)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Appearance").dsOverline()
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(AppTheme.allCases) { theme in
                        themeButton(theme)
                    }
                }
            }
            .dsEntrance(index: 2)
        }
    }

    private func themeButton(_ theme: AppTheme) -> some View {
        let isSelected = viewModel.theme == theme

        return Button { viewModel.theme = theme } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: theme.icon)
                Text(theme.rawValue)
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? DS.Colors.textOnBrand : DS.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(
                Capsule().fill(isSelected ? DS.Colors.brand : DS.Colors.surfaceRaised)
            )
            .overlay(Capsule().strokeBorder(isSelected ? .clear : DS.Colors.outline, lineWidth: 1))
        }
        .buttonStyle(DSPressStyle(scale: 0.95))
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A miniature Home that repaints as the accent and appearance change,
/// so the choice is shown, not described.
private struct OnboardingThemePreview: View {

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Good morning")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Text("Home")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                Spacer()
                MascotFaceView(face: .happy, size: 40)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("RENT COLLECTED")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(DS.Colors.textOnBrand.opacity(0.85))
                Capsule()
                    .fill(DS.Colors.textOnBrand.opacity(0.25))
                    .frame(height: 10)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(DS.Colors.textOnBrand)
                            .frame(width: 170, height: 10)
                    }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Gradients.hero, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

            HStack(spacing: DS.Spacing.sm) {
                Text("All paid")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.brandInk)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.brand.opacity(0.14), in: Capsule())
                Spacer()
                Text("Add property")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textOnBrand)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.brand, in: Capsule())
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.background, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(DS.Colors.outline, lineWidth: 1)
        )
        .dsShadow(DS.Shadows.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of your Home screen in the chosen colours")
    }
}

// MARK: - Building

struct OnboardingBuildingStep: View {

    let tasks: [OnboardingBuildTask]

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            // 120pt: the laptop pose's largest crisp size until its
            // 1024px export arrives (MascotPose.nativePixels).
            MascotView(mood: .working, size: 120, isInteractive: false)
                .padding(.top, DS.Spacing.xxl)

            Text("Building your\nPurrperty…")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)

            OnboardingBuildChecklist(tasks: tasks)
        }
    }
}

// MARK: - Unlocked

struct OnboardingUnlockedStep: View {

    let profile: OnboardingProfile

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            MascotView(mood: .cheer, size: 150)

            VStack(spacing: DS.Spacing.sm) {
                Text("Here's what you unlocked")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                if let goal = profile.goal {
                    Text(goal.outcome)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: DS.Spacing.sm) {
                ForEach(Array(profile.unlocks.enumerated()), id: \.element.id) { index, unlock in
                    OnboardingUnlockRow(unlock: unlock)
                        .dsEntrance(index: index + 1)
                }
            }
        }
    }
}

// MARK: - Sign-Up

/// The sign-up screen as a pitch (playbook §3): one outcome, honest
/// reasons, and a short form with a live password checklist.
struct OnboardingSignUpStep: View {

    @Bindable var viewModel: OnboardingFlowViewModel
    let onSignedUp: (SignInOutcome) -> Void
    let onSignIn: () -> Void

    private var auth: AuthViewModel { viewModel.auth }

    var body: some View {
        @Bindable var auth = viewModel.auth

        VStack(spacing: DS.Spacing.xl) {
            MascotGuide(
                mood: .happy,
                title: "Last step!",
                message: "Save your setup and it'll be waiting every time you open the app.",
                mascotSize: 84
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsEntrance(index: 0)

            pitch
                .dsEntrance(index: 1)

            AuthCard {
                VStack(spacing: DS.Spacing.lg) {
                    AuthTextField(
                        label: "Your name", text: $auth.name, icon: "person.fill",
                        textContentType: .name, error: auth.nameError, shakeTrigger: auth.shakeTrigger
                    )
                    .onChange(of: auth.name) { _, _ in auth.nameError = nil }

                    AuthTextField(
                        label: "Email", text: $auth.email, icon: "envelope.fill",
                        keyboardType: .emailAddress, textContentType: .emailAddress,
                        error: auth.emailError, showsValidCheck: auth.emailLooksValid,
                        shakeTrigger: auth.shakeTrigger
                    )
                    .onChange(of: auth.email) { _, _ in auth.emailError = nil }

                    VStack(spacing: DS.Spacing.sm) {
                        AuthTextField(
                            label: "Password", text: $auth.password, icon: "lock.fill",
                            isSecure: true, textContentType: .newPassword,
                            error: auth.passwordError, shakeTrigger: auth.shakeTrigger
                        )
                        .onChange(of: auth.password) { _, _ in auth.passwordError = nil }

                        OnboardingPasswordChecklist(requirements: auth.passwordRequirements)
                    }

                    if let formError = auth.formError {
                        AuthFormError(message: formError)
                    }

                    DSButton(
                        title: "Create my account", variant: .primary, size: .large,
                        isFullWidth: true, isLoading: auth.isLoading
                    ) {
                        Task {
                            if let outcome = await viewModel.signUp() { onSignedUp(outcome) }
                        }
                    }

                    Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)

                    AuthDivider()

                    VStack(spacing: DS.Spacing.md) {
                        ForEach([SocialProvider.apple, .google], id: \.self) { provider in
                            AuthSocialButton(provider: provider, isLoading: auth.loadingProvider == provider) {
                                Task {
                                    if let outcome = await viewModel.signIn(with: provider) { onSignedUp(outcome) }
                                }
                            }
                        }
                    }
                }
            }
            .dsEntrance(index: 2)

            AuthFooterLink(prompt: "Already have an account?", actionTitle: "Sign in", action: onSignIn)
                .dsEntrance(index: 3)
        }
        .animation(DS.Motion.gentle, value: auth.formError)
    }

    /// The outcome they chose, and reasons that are true today. No
    /// invented user counts or ratings (playbook §3: real numbers only).
    private var isTenant: Bool { viewModel.profile.persona == .tenant }

    private var pitch: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // The tenant portal is still to come, so tenants get a promise
            // the app can keep today: joining their landlord.
            Text(isTenant
                 ? "Join your landlord on Purrperty"
                 : viewModel.profile.goal?.outcome ?? "Run your rentals without the stress")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(DS.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                reason("Free to start, no card needed")
                reason(isTenant
                       ? "Your landlord can invite you straight in"
                       : "Your answers and colours are already saved")
                reason(isTenant ? "Made in Toronto" : "Made in Toronto, for Canadian landlords")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reason(_ text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DS.Colors.accentMintInk)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
}
