//
//  SessionViewModel.swift
//  RentalApp (Purrperty)
//
//  Auth — The session coordinator.
//
//  ─────────────────────────────────────────────────────────────────
//  ONE OWNER OF "WHERE AM I?"
//  ─────────────────────────────────────────────────────────────────
//  Before this existed, `RootNavigation` held a `LaunchPhase` enum and
//  advanced through it linearly: splash → onboarding → auth → org →
//  main. That's a script, not a state machine — it can't express
//  "returning user with a valid session" or "signed out from settings"
//  without extra flags.
//
//  Here the *session* decides the phase. Every screen reports an event
//  (finished onboarding, produced a session, created an organization,
//  signed out) and the resulting `AuthState` is what the root renders.
//  There is exactly one place that decides what the user sees.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class SessionViewModel {

    // MARK: State

    private(set) var state: AuthState = .checking

    /// Non-nil while a sign-out is in flight, so the UI can disable
    /// controls without inventing its own flag.
    private(set) var isSigningOut = false

    /// Surfaced by the MFA screen.
    private(set) var mfaError: String?
    private(set) var isVerifyingMFA = false

    /// Offered on the login screen when a stored session is biometric-
    /// gated — the fast path back in for a returning user.
    private(set) var canUnlockWithBiometrics = false

    // MARK: Dependencies

    private let auth: AuthServiceProtocol
    private let store: SessionStoring
    private let analytics: AnalyticsService
    private let onboarding: OnboardingProfileStore

    init(
        auth: AuthServiceProtocol,
        store: SessionStoring,
        analytics: AnalyticsService,
        onboarding: OnboardingProfileStore
    ) {
        self.auth = auth
        self.store = store
        self.analytics = analytics
        self.onboarding = onboarding
    }

    // MARK: Derived

    var session: AuthSession? { state.session }
    var role: AppRole? { session?.role }
    var biometricKind: BiometricKind { auth.biometricKind }
    var lastSignedInEmail: String? { store.lastSignedInEmail }

    // MARK: Launch

    /// Runs behind the splash animation. The only entry point that can
    /// leave `.checking`.
    func bootstrap() async {
        // DEBUG-only: start at a specific flow while developing it,
        // without touching the stored session. See `DebugLaunchOverride`.
        if let override = DebugLaunchOverride.current {
            await apply(override)
            return
        }

        let restored = await auth.restoreSession()
        canUnlockWithBiometrics = restored?.biometricEnabled ?? false

        if let restored {
            // Detached: analytics must never delay the launch path, and
            // `AnalyticsService` is an actor so awaiting it here would
            // put a hop between the session check and the first frame.
            Task { await analytics.track(.sessionRestored(role: restored.role)) }
            transition(to: route(for: restored))
        } else if store.hasCompletedOnboarding {
            transition(to: .unauthenticated)
        } else {
            transition(to: .onboarding)
        }
    }

    /// Called when someone leaves onboarding for the sign-in screen
    /// ("I already have an account"). The flag is persisted so it never
    /// replays — including after a sign-out.
    func completeOnboarding() {
        markOnboardingSeen()
        transition(to: .unauthenticated)
    }

    /// Called when onboarding ends with a brand-new account. Staff go on
    /// to "getting started" once their workspace exists; tenants go
    /// straight in.
    func finishOnboarding(with outcome: SignInOutcome) {
        markOnboardingSeen()
        handleSignUp(outcome)
    }

    /// Sign-up from anywhere — onboarding or the auth screens. Flags the
    /// new account for the getting-started flow before routing it.
    func handleSignUp(_ outcome: SignInOutcome) {
        if case .session(let session) = outcome, session.role.isStaff {
            onboarding.pendingActivationUserID = session.userID
        }
        handle(outcome)
    }

    private func markOnboardingSeen() {
        store.hasCompletedOnboarding = true
        Task { await analytics.track(.onboardingCompleted) }
    }

    // MARK: Getting Started

    /// The getting-started flow is done, or was skipped. It never
    /// replays for this account.
    func completeGettingStarted(addedProperty: Bool) {
        guard case .gettingStarted(let session) = state else { return }
        onboarding.pendingActivationUserID = nil
        Task { await analytics.track(.activationCompleted(addedProperty: addedProperty)) }
        transition(to: .authenticated(session))
    }

    // MARK: Sign-In Results

    /// Single funnel for everything the auth screens produce.
    func handle(_ outcome: SignInOutcome) {
        switch outcome {
        case .session(let session):
            adopt(session)
        case .mfaRequired(let challenge):
            mfaError = nil
            transition(to: .awaitingMFA(challenge))
        }
    }

    private func adopt(_ session: AuthSession) {
        Task {
            // Identity is attached first so the sign-in event carries it —
            // but `identify` is itself a no-op without personalization
            // consent, so this does not leak an account ID on its own.
            await analytics.identify(userID: session.userID)
            await analytics.track(.signedIn(role: session.role, method: .password))
        }
        transition(to: route(for: session))
    }

    // MARK: Multi-Factor

    func verifyMFA(code: String) async {
        guard case .awaitingMFA(let challenge) = state else { return }

        isVerifyingMFA = true
        mfaError = nil
        defer { isVerifyingMFA = false }

        do {
            let session = try await auth.verifyMFA(code: code, for: challenge)
            adopt(session)
        } catch {
            mfaError = message(for: error)
        }
    }

    func resendMFACode() async {
        guard case .awaitingMFA(let challenge) = state else { return }

        mfaError = nil
        do {
            let refreshed = try await auth.resendMFACode(for: challenge)
            transition(to: .awaitingMFA(refreshed), animated: false)
        } catch {
            mfaError = message(for: error)
        }
    }

    /// Backing out of the MFA step returns to the credential screen.
    func cancelMFA() {
        mfaError = nil
        transition(to: .unauthenticated)
    }

    // MARK: Organization

    /// Called by the org-setup flow once the workspace exists. Binding
    /// the org to the session is what moves a staff user from
    /// `.needsOrganization` to `.authenticated`.
    func attachOrganization(id: String, name: String) async {
        do {
            let session = try await auth.attachOrganization(id: id, name: name)
            Task { await analytics.track(.organizationCreated(portfolioSize: 0)) }
            transition(to: route(for: session))
        } catch {
            // The workspace was created; only the binding failed. Let
            // the user in rather than trapping them in the wizard.
            if var session = self.session {
                session.organizationID = id
                session.organizationName = name
                transition(to: .authenticated(session))
            }
        }
    }

    // MARK: Biometrics

    func unlockWithBiometrics() async {
        do {
            let session = try await auth.unlockWithBiometrics()
            adopt(session)
        } catch {
            canUnlockWithBiometrics = false
        }
    }

    func setBiometricEnabled(_ enabled: Bool) async {
        try? await auth.setBiometricEnabled(enabled)
        if let updated = auth.currentSession {
            canUnlockWithBiometrics = updated.biometricEnabled
            transition(to: route(for: updated), animated: false)
        }
    }

    // MARK: Sign Out

    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }

        await analytics.track(.signedOut)
        // Detach identity on the way out. Awaited, unlike the other call
        // sites: a sign-out that returns before analytics forgets who
        // this was would attribute the *next* user's early events to the
        // previous one.
        await analytics.identify(userID: nil)

        await auth.signOut()
        canUnlockWithBiometrics = false
        // Onboarding stays completed — signing out isn't a fresh install.
        transition(to: .unauthenticated)
    }

    // MARK: Internals

    /// Staff without a workspace can't use the app yet; everyone else
    /// goes straight in. Centralized so no caller has to remember it.
    private func route(for session: AuthSession) -> AuthState {
        if session.needsOrganization { return .needsOrganization(session) }
        if session.role.isStaff, onboarding.pendingActivationUserID == session.userID {
            return .gettingStarted(session)
        }
        return .authenticated(session)
    }

    /// DEBUG launch override. Flows that need an account restore the
    /// stored session (the mock backend always has one).
    private func apply(_ override: DebugLaunchOverride) async {
        switch override {
        case .onboarding:
            transition(to: .onboarding)
        case .login:
            transition(to: .unauthenticated)
        case .gettingStarted:
            if let restored = await auth.restoreSession() {
                transition(to: .gettingStarted(restored))
            } else {
                transition(to: .unauthenticated)
            }
        case .home:
            // The management app: a stored staff session, otherwise the
            // demo owner (a stored tenant or vendor session would open
            // their portal instead).
            if let restored = await auth.restoreSession(), restored.role.isStaff {
                transition(to: .authenticated(restored))
            } else {
                await signInDemo(email: "owner@rentos.ca")
            }
        case .tenant:
            await signInDemo(email: "tenant@rentos.ca")
        case .vendor:
            await signInDemo(email: "vendor@rentos.ca")
        }
    }

    /// DEBUG launch override: signs in one of the mock demo accounts.
    private func signInDemo(email: String) async {
        if case .session(let account)? = try? await auth.signIn(email: email, password: MockAccountDirectory.demoPassword) {
            transition(to: .authenticated(account))
        } else {
            transition(to: .unauthenticated)
        }
    }

    private func transition(to next: AuthState, animated: Bool = true) {
        guard next != state else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.55)) { state = next }
        } else {
            state = next
        }
    }

    private func message(for error: Error) -> String {
        (error as? AppError)?.errorDescription ?? AppError.unknown.errorDescription!
    }
}
