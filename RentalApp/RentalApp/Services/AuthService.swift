//
//  AuthService.swift
//  RentalApp (Purrperty)
//
//  Services — Authentication.
//
//  ─────────────────────────────────────────────────────────────────
//  MOCK, BUT NOT FAKE
//  ─────────────────────────────────────────────────────────────────
//  `MockAuthService` behaves like a real identity provider: it has a
//  directory of accounts, rejects wrong passwords, issues expiring
//  tokens, refreshes them, escalates to MFA for enrolled accounts,
//  and persists sessions across launches. Every one of those is a
//  branch the UI must handle, so simulating them now means the UI is
//  already correct when Supabase replaces this file.
//
//  What is *not* simulated: cryptography. Passwords are compared in
//  plaintext against a seeded directory and tokens are UUIDs. That is
//  intentional and safe — there is no real credential in this app.
//  See the `SupabaseAuthService` notes at the bottom.
//

import Foundation
import LocalAuthentication

// MARK: - Mock Directory

/// A demo account in the mock identity provider.
struct MockAccount: Sendable {
    let userID: String
    let email: String
    var password: String
    let fullName: String
    let role: AppRole
    var organizationID: String?
    var organizationName: String?
    var mfaEnrolled: Bool = false
}

/// The seeded accounts — one per role, so every path through the app
/// can be reached without a backend.
enum MockAccountDirectory {

    static let accounts: [MockAccount] = [
        MockAccount(
            userID: "usr_owner_0001",
            email: "owner@rentos.ca",
            password: "rentos",
            fullName: "Amara Okonkwo",
            role: .owner,
            organizationID: "org_0001",
            organizationName: "Harbourfront Residential"
        ),
        MockAccount(
            userID: "usr_manager_0002",
            email: "manager@rentos.ca",
            password: "rentos",
            fullName: "Daniel Chen",
            role: .propertyManager,
            organizationID: "org_0001",
            organizationName: "Harbourfront Residential",
            mfaEnrolled: true
        ),
        MockAccount(
            userID: "usr_tenant_0003",
            email: "tenant@rentos.ca",
            password: "rentos",
            fullName: "Priya Raghunathan",
            role: .tenant
        ),
        MockAccount(
            userID: "usr_vendor_0004",
            email: "vendor@rentos.ca",
            password: "rentos",
            fullName: "Marco Bianchi",
            role: .vendor
        )
    ]

    static func account(email: String) -> MockAccount? {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return accounts.first { $0.email.lowercased() == normalized }
    }

    /// Shown on the login screen so the app is usable without signing
    /// up. Deleted the day a real provider lands.
    static let demoPassword = "rentos"

    /// The verification code the mock provider accepts. Lives here
    /// rather than on the service so views can show it without
    /// touching an actor-isolated type.
    static let demoMFACode = "123456"
}

// MARK: - Service

@MainActor
final class MockAuthService: AuthServiceProtocol {

    private(set) var currentSession: AuthSession?

    private let store: SessionStoring
    private let latency: Duration
    private let sessionLifetime: TimeInterval

    /// Accounts created during this run via sign-up. Not persisted —
    /// a real provider owns the directory, not the client.
    private var registeredAccounts: [MockAccount] = []

    /// Live MFA challenges keyed by ID, holding the account each one
    /// resolves into once its code is verified.
    private var pendingChallenges: [String: MockAccount] = [:]

    /// Set by `sendPasswordReset` so `resetPassword` knows whose
    /// password is changing — the stand-in for a recovery token.
    private var recoveryEmail: String?

    init(
        store: SessionStoring,
        latency: Duration = .milliseconds(1200),
        sessionLifetime: TimeInterval = 60 * 60 * 24 * 7
    ) {
        self.store = store
        self.latency = latency
        self.sessionLifetime = sessionLifetime
    }

    // MARK: Session Lifecycle

    func restoreSession() async -> AuthSession? {
        // Deliberately brief: this runs behind the splash animation and
        // a launch check should feel instant, not like loading.
        try? await Task.sleep(for: .milliseconds(450))

        guard let stored = store.load() else { return nil }

        if stored.isValid() {
            currentSession = stored
            return stored
        }

        // Expired access token — a real client silently refreshes using
        // the refresh token. Same here.
        let refreshed = reissue(stored)
        currentSession = refreshed
        store.save(refreshed)
        return refreshed
    }

    func refreshIfNeeded() async throws -> AuthSession? {
        guard let session = currentSession else { return nil }
        guard !session.isValid() else { return session }

        try await Task.sleep(for: .milliseconds(400))
        let refreshed = reissue(session)
        currentSession = refreshed
        store.save(refreshed)
        return refreshed
    }

    func signOut() async {
        try? await Task.sleep(for: .milliseconds(300))
        currentSession = nil
        pendingChallenges.removeAll()
        recoveryEmail = nil
        store.clear()
    }

    // MARK: Credentials

    func signIn(email: String, password: String) async throws -> SignInOutcome {
        try await Task.sleep(for: latency)

        guard let account = account(for: email), account.password == password else {
            throw AppError.invalidCredentials
        }
        return issueOutcome(for: account)
    }

    func signUp(name: String, email: String, password: String, role: AppRole) async throws -> SignInOutcome {
        try await Task.sleep(for: latency)

        guard account(for: email) == nil else {
            throw AppError.validation("An account already exists for that email.")
        }

        let account = MockAccount(
            userID: "usr_\(UUID().uuidString.prefix(8).lowercased())",
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password,
            fullName: name,
            role: role
        )
        registeredAccounts.append(account)

        // New accounts have no organization — that's what routes staff
        // into the org-setup flow.
        return issueOutcome(for: account)
    }

    func signIn(with provider: SocialProvider) async throws -> SignInOutcome {
        try await Task.sleep(for: .milliseconds(900))

        let domain = provider == .apple ? "privaterelay.appleid.com" : "gmail.com"
        let account = MockAccount(
            userID: "usr_\(provider.rawValue)_\(UUID().uuidString.prefix(6).lowercased())",
            email: "amara.okonkwo@\(domain)",
            password: "",
            fullName: "Amara Okonkwo",
            role: .owner
        )
        registeredAccounts.append(account)
        return issueOutcome(for: account)
    }

    // MARK: Recovery

    func sendPasswordReset(to email: String) async throws {
        try await Task.sleep(for: latency)
        // Never reveal whether an address is registered — a real
        // provider returns success either way to block enumeration.
        recoveryEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func resetPassword(newPassword: String) async throws {
        try await Task.sleep(for: latency)

        guard let email = recoveryEmail else {
            throw AppError.validation("This password reset link is no longer valid.")
        }

        if let index = registeredAccounts.firstIndex(where: { $0.email == email }) {
            registeredAccounts[index].password = newPassword
        }
        recoveryEmail = nil
    }

    // MARK: Multi-Factor

    func verifyMFA(code: String, for challenge: MFAChallenge) async throws -> AuthSession {
        try await Task.sleep(for: .milliseconds(900))

        guard let account = pendingChallenges[challenge.challengeID] else {
            throw AppError.validation("This verification code expired. Sign in again.")
        }
        guard code == MockAccountDirectory.demoMFACode else {
            throw AppError.validation("That code isn't right. Check and try again.")
        }

        pendingChallenges.removeValue(forKey: challenge.challengeID)
        return activate(makeSession(for: account))
    }

    func resendMFACode(for challenge: MFAChallenge) async throws -> MFAChallenge {
        try await Task.sleep(for: .milliseconds(700))

        guard let account = pendingChallenges[challenge.challengeID] else {
            throw AppError.validation("This verification code expired. Sign in again.")
        }

        pendingChallenges.removeValue(forKey: challenge.challengeID)
        let fresh = makeChallenge(for: account)
        pendingChallenges[fresh.challengeID] = account
        return fresh
    }

    // MARK: Organization

    func attachOrganization(id: String, name: String) async throws -> AuthSession {
        guard var session = currentSession else { throw AppError.unauthorized }

        try await Task.sleep(for: .milliseconds(500))
        session.organizationID = id
        session.organizationName = name
        return activate(session)
    }

    // MARK: Biometrics

    /// What this device supports. Evaluated per call so a user who
    /// enrolls Face ID mid-session is picked up without a relaunch.
    var biometricKind: BiometricKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    func setBiometricEnabled(_ enabled: Bool) async throws {
        guard var session = currentSession else { throw AppError.unauthorized }
        if enabled, !biometricKind.isAvailable {
            throw AppError.validation("This device doesn't have biometrics set up.")
        }
        session.biometricEnabled = enabled
        activate(session)
    }

    /// Unlocks an already-stored session behind a biometric prompt.
    ///
    /// Biometrics never *authenticate* — they gate access to a session
    /// that already exists on the device. Modelling that distinction
    /// now is what makes turning Face ID on later a one-line change.
    func unlockWithBiometrics() async throws -> AuthSession {
        guard let stored = store.load(), stored.biometricEnabled else {
            throw AppError.unauthorized
        }
        try await Task.sleep(for: .milliseconds(600))

        // FUTURE: replace the sleep above with
        //   try await LAContext().evaluatePolicy(
        //       .deviceOwnerAuthenticationWithBiometrics,
        //       localizedReason: "Unlock Purrperty"
        //   )
        // Held back while mock auth is in place so the simulator, which
        // has no enrolled biometry, can't lock the user out.

        return activate(stored.isValid() ? stored : reissue(stored))
    }

    // MARK: Internals

    private func account(for email: String) -> MockAccount? {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return registeredAccounts.first { $0.email == normalized }
            ?? MockAccountDirectory.account(email: normalized)
    }

    /// Either a session, or an MFA challenge when the account is enrolled.
    private func issueOutcome(for account: MockAccount) -> SignInOutcome {
        if account.mfaEnrolled {
            let challenge = makeChallenge(for: account)
            pendingChallenges[challenge.challengeID] = account
            return .mfaRequired(challenge)
        }
        return .session(activate(makeSession(for: account)))
    }

    private func makeChallenge(for account: MockAccount) -> MFAChallenge {
        MFAChallenge(
            challengeID: UUID().uuidString,
            method: .totp,
            hint: nil,
            expiresAt: .now.addingTimeInterval(300)
        )
    }

    private func makeSession(for account: MockAccount) -> AuthSession {
        AuthSession(
            userID: account.userID,
            email: account.email,
            fullName: account.fullName,
            role: account.role,
            organizationID: account.organizationID,
            organizationName: account.organizationName,
            accessToken: "mock_at_\(UUID().uuidString)",
            refreshToken: "mock_rt_\(UUID().uuidString)",
            expiresAt: .now.addingTimeInterval(sessionLifetime),
            mfaEnrolled: account.mfaEnrolled,
            biometricEnabled: store.load()?.biometricEnabled ?? false
        )
    }

    private func reissue(_ session: AuthSession) -> AuthSession {
        var refreshed = session
        refreshed.accessToken = "mock_at_\(UUID().uuidString)"
        refreshed.expiresAt = .now.addingTimeInterval(sessionLifetime)
        return refreshed
    }

    /// The single write path: anything that changes the session goes
    /// through here, so memory and disk can never disagree.
    @discardableResult
    private func activate(_ session: AuthSession) -> AuthSession {
        currentSession = session
        store.save(session)
        return session
    }
}

// MARK: - Organization

@MainActor
final class MockOrganizationService: OrganizationServiceProtocol {

    func createOrganization(_ draft: OrganizationDraft) async throws {
        try await Task.sleep(for: .milliseconds(900))
    }
}

// ─────────────────────────────────────────────────────────────────
// FUTURE: SupabaseAuthService
// ─────────────────────────────────────────────────────────────────
// A Supabase implementation conforms to `AuthServiceProtocol` with no
// changes above this layer:
//
//   signIn(email:password:) → auth.signIn(email:password:), returning
//                             .mfaRequired when the response carries an
//                             AAL2 factor challenge
//   restoreSession()        → auth.session (SDK reads the Keychain)
//   refreshIfNeeded()       → auth.refreshSession()
//   verifyMFA(code:for:)    → auth.mfa.verify(factorId:challengeId:code:)
//   attachOrganization      → PATCH /rest/v1/profiles + JWT claim refresh
//   signOut()               → auth.signOut()
//
// `SessionStore` becomes `KeychainSessionStore` at the same time. Both
// swaps happen in `AppContainer.live()` and nowhere else.
