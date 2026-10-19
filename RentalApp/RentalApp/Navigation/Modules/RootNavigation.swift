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
//  There is no splash screen. Per the HIG (Launching), the launch
//  screen is the system-generated one — a plain system background —
//  and while the session check runs (well under a second) the root
//  shows that same background, so launch reads as the app simply
//  appearing, then onboarding, sign-in or Home.
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

    /// The app-wide toast centre, taken from the container.
    ///
    /// Previously constructed here with `@State`, which made it a *second*
    /// instance: the coordinators posted to the container's copy and this
    /// one rendered nothing. A "centre" has to be singular to work, so it
    /// is owned by the composition root and injected like everything else.
    private var toasts: ToastCenter { container.toasts }

    init(container: AppContainer) {
        self.container = container
        _session = State(initialValue: SessionViewModel(
            auth: container.auth,
            store: container.sessionStore,
            analytics: container.analytics,
            onboarding: container.onboardingProfile
        ))
    }

    var body: some View {
        destination
        // One colour-scheme source for the whole app, launch flow included.
        // System is the default (see `InMemoryPreferencesRepository.theme`);
        // Light and Dark remain available in Settings → Appearance.
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
        // The session check runs while the launch background shows.
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
            // Matches the system-generated launch screen exactly, so the
            // hand-off from launch screen to app is invisible.
            Color.plainBackground
                .ignoresSafeArea()
                .accessibilityHidden(true)

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

        case .authenticated(let account) where account.role == .tenant:
            // Tenants get their own app. The management shell, its router
            // and its restored navigation are never built for them.
            TenantPortalView(session: account, container: container)
                .transition(.opacity.combined(with: .scale(scale: 1.02)))

        case .authenticated(let account) where account.role == .vendor:
            VendorPortalView(session: account, container: container)
                .transition(.opacity.combined(with: .scale(scale: 1.02)))

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
