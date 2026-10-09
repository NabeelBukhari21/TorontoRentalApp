//
//  ServiceProtocols.swift
//  RentalApp (RentOS)
//
//  Core — Service interfaces. Services perform work (auth, uploads,
//  persistence, analytics); repositories own data. Features depend
//  on these protocols only.
//

import Foundation

// MARK: - Authentication

enum SocialProvider: String, Sendable {
    case apple
    case google

    var title: String {
        switch self {
        case .apple: "Continue with Apple"
        case .google: "Continue with Google"
        }
    }
}

/// Everything the app can ask of an identity provider.
///
/// Shaped so a Supabase `GoTrue` client can implement it verbatim:
/// credential sign-in returns either a session or an MFA challenge,
/// tokens refresh, and biometric unlock is a local gate in front of
/// a stored session rather than a separate credential path.
@MainActor
protocol AuthServiceProtocol: AnyObject {

    /// The session restored at launch, if any. Nil means signed out.
    var currentSession: AuthSession? { get }

    // Session lifecycle
    func restoreSession() async -> AuthSession?
    func refreshIfNeeded() async throws -> AuthSession?
    func signOut() async

    // Credentials
    func signIn(email: String, password: String) async throws -> SignInOutcome
    func signUp(name: String, email: String, password: String, role: AppRole) async throws -> SignInOutcome
    func signIn(with provider: SocialProvider) async throws -> SignInOutcome

    // Recovery
    func sendPasswordReset(to email: String) async throws
    func resetPassword(newPassword: String) async throws

    // Multi-factor
    func verifyMFA(code: String, for challenge: MFAChallenge) async throws -> AuthSession
    func resendMFACode(for challenge: MFAChallenge) async throws -> MFAChallenge

    // Organization binding — staff only
    func attachOrganization(id: String, name: String) async throws -> AuthSession

    // Biometrics
    var biometricKind: BiometricKind { get }
    func setBiometricEnabled(_ enabled: Bool) async throws
    func unlockWithBiometrics() async throws -> AuthSession
}

// MARK: - Organization Onboarding

struct OrganizationDraft: Sendable {
    var name: String
    var propertyTypeID: String?
    var portfolioSizeID: String?
    var inviteEmails: [String]
}

@MainActor
protocol OrganizationServiceProtocol: AnyObject {
    func createOrganization(_ draft: OrganizationDraft) async throws
}

// MARK: - Persistence

/// Key-value persistence — abstracted so navigation restoration and
/// preferences can be redirected to Keychain, files, or a test double.
protocol PersistenceServiceProtocol: AnyObject, Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    func removeObject(forKey key: String)
}

// MARK: - Analytics
//
// `AnalyticsServiceProtocol` used to live here with the signature
// `track(_ event: String, properties: [String: String])`. It was removed
// rather than deprecated, deliberately: leaving it in place would leave
// a compiling path that accepts arbitrary strings as event properties,
// and the entire point of the replacement is that no such path exists.
//
// The replacement is `AnalyticsService` (an actor) taking `AnalyticsEvent`
// (a closed enum), in Core/Analytics/. See AnalyticsEvent.swift for why
// events are types.
