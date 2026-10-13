//
//  RootNavigation.swift
//  RentalApp (Purrperty)
//
//  Navigation — The application's root coordinator.
//
//  ─────────────────────────────────────────────────────────────────
//  THE SESSION IS THE LAUNCH FLOW
//  ─────────────────────────────────────────────────────────────────
//  This used to hold a `LaunchPhase` enum and step through it
//  linearly: splash → onboarding → auth → org setup → main. That's a
//  script. It can't express "returning user with a valid session skips
//  straight to main", and it has no way back when someone signs out
//  from Settings.
//
//  Now there is no phase state at all. `SessionViewModel.state` is
//  rendered directly, so signing out *is* returning to the auth
//  screen — no coordination, no flags, no chance of the two
//  disagreeing.
//
//  The splash is the one exception: it stays up until both the
//  animation has finished *and* the session check has resolved,
//  whichever is slower. A launch that resolves in 200ms shouldn't
//  flash the brand and vanish.
//
//  Module map:
//  • RootNavigation            — this launch coordinator
//  • AuthenticationNavigation  — the auth flow coordinator
//  • MainTabNavigation         — adaptive tab/split navigation shell
//  • Property/Tenant/Maintenance/Messages/Document/SettingsNavigation
//    — domain modules in NavigationModules.swift
//

import SwiftUI

/// The auth flow coordinator (Login / Role / Sign Up / Forgot / Reset).
typealias AuthenticationNavigation = AuthFlowView

/// The main app shell: per-tab NavigationStacks behind the glass tab bar
/// on iPhone, NavigationSplitView on iPad, plus presentation layers.
typealias MainTabNavigation = RootNavigationView

// MARK: - Root Coordinator

struct RootNavigation: View {

    private let container: AppContainer
    @State private var session: SessionViewModel

    /// The splash animation has played through. Tracked separately from
    /// the session check so neither can cut the other short.
    @State private var splashFinished = false

    /// The app-wide toast centre, taken from the container.
    ///
    /// Previously constructed here with `@State`, which made it a *second*
    /// instance: the coordinators posted to the container's copy and this
    /// one rendered nothing. A "centre" has to be singular to work, so it
    /// is owned by the composition root and injected like everything else.
    private var toasts: ToastCenter { container.toasts }

    init(container: AppContainer = .shared) {
        self.container = container
        _session = State(initialValue: SessionViewModel(
            auth: container.auth,
            store: container.sessionStore,
            analytics: container.analytics,
            onboarding: container.onboardingProfile
        ))
    }

    /// Hold the splash until the brand moment is done *and* we know
    /// where the user belongs.
    private var showsSplash: Bool {
        !splashFinished || session.state == .checking
    }

    var body: some View {
        ZStack {
            if showsSplash {
                SplashView { splashFinished = true }
                    .transition(
                        .asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 1.06))
                        )
                    )
            } else {
                destination
            }
        }
        .animation(.easeInOut(duration: 0.7), value: showsSplash)
        // One colour-scheme source for the whole app, launch flow included.
        // Previously this was applied only inside the main tab shell, and
        // the launch, onboarding and auth screens forced themselves dark —
        // so the Appearance setting never reached them. Light is the
        // default (see `InMemoryPreferencesRepository.theme`); System and
        // Dark remain available in Settings → Appearance.
        .preferredColorScheme(container.preferences.theme.colorScheme)
        .environment(session)
        .environment(\.toasts, toasts)
        .dsToastLayer()
        // Realtime: lifecycle first so the socket follows the scene, then
        // the banner, which reads the state the lifecycle drives.
        .dsRealtimeLifecycle(container.sync)
        .dsConnectionBanner(engine: container.sync, outbox: container.outbox)
        // Conflicts are queued from anywhere — a form, a background drain —
        // so the sheet that settles them lives above all of it.
        .dsConflictResolution(container.conflicts)
        // The session check runs behind the splash animation, so a
        // returning user pays nothing for it.
        .task { await session.bootstrap() }
        // Deep links land on the shared router; one that arrives during
        // the launch flow has its destination set before Main appears.
        .onOpenURL { url in
            AppRouter.shared.open(url)
        }
    }

    // MARK: Destination

    @ViewBuilder
    private var destination: some View {
        switch session.state {
        case .checking:
            // Unreachable — `showsSplash` covers it. Kept explicit so
            // the compiler enforces exhaustiveness if a case is added.
            Color.clear

        case .onboarding:
            OnboardingView(
                container: container,
                onSignedUp: { session.finishOnboarding(with: $0) },
                onSignIn: { session.completeOnboarding() }
            )
            .transition(.opacity)

        case .unauthenticated:
            AuthenticationNavigation(
                container: container,
                biometricUnlock: biometricUnlock,
                onAuthenticated: { session.handle($0) },
                onSignedUp: { session.handleSignUp($0) }
            )
            .transition(.opacity)

        case .awaitingMFA(let challenge):
            MFAFlowView(challenge: challenge, session: session)
                .transition(.opacity)

        case .needsOrganization:
            OrgSetupFlowView(
                container: container,
                suggestedSize: container.onboardingProfile.profile.unitRange?.portfolioSize
            ) { organizationID, organizationName in
                Task {
                    await session.attachOrganization(id: organizationID, name: organizationName)
                }
            }
            .transition(.opacity)

        case .gettingStarted(let account):
            GettingStartedView(container: container, session: account) { addedProperty in
                session.completeGettingStarted(addedProperty: addedProperty)
            }
            .transition(.opacity)

        case .authenticated:
            MainTabNavigation()
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
        }
    }

    /// Offered only when a biometric-gated session is actually stored on
    /// this device and the hardware supports it.
    private var biometricUnlock: BiometricUnlockOption? {
        guard session.canUnlockWithBiometrics, session.biometricKind.isAvailable else {
            return nil
        }
        return BiometricUnlockOption(kind: session.biometricKind) {
            Task { await session.unlockWithBiometrics() }
        }
    }
}

// MARK: - MFA Flow

/// Hosts the second-factor step on the same animated backdrop as the
/// credential screens, so escalating to MFA reads as one continuous
/// flow rather than a different part of the app.
private struct MFAFlowView: View {

    let challenge: MFAChallenge
    let session: SessionViewModel

    var body: some View {
        ZStack {
            SplashBackground()
            SplashParticleField(particleCount: 18)

            ScrollView(showsIndicators: false) {
                MFAChallengeView(challenge: challenge, session: session)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.xxl)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Previews

#Preview("Root Navigation") {
    RootNavigation(container: .preview)
}
