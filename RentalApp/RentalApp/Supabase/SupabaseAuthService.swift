//
//  SupabaseAuthService.swift
//  RentalApp (RentOS)
//
//  Supabase — Authentication, backed by GoTrue.
//
//  ─────────────────────────────────────────────────────────────────
//  THE SESSION IS ASSEMBLED SERVER-SIDE
//  ─────────────────────────────────────────────────────────────────
//  `AuthSession` carries a role and an organization. Neither is read
//  from anything the client controls — not from user metadata, not from
//  a column the app wrote. Both come from `current_session_context()`,
//  a SECURITY DEFINER function that derives them from `auth.uid()` and
//  the rows that actually grant access.
//
//  That matters because `AppRole` gates UI, and a user who could edit
//  their own JWT metadata could otherwise hand themselves the owner
//  experience. They would still be stopped by RLS on every query — but
//  showing a billing screen that then fails on load is not a defence,
//  it is a bug.
//
//  Token storage belongs to the SDK, which keeps them in the Keychain
//  and refreshes in the background. `SessionStoring` keeps only
//  non-sensitive launch hints (onboarding seen, last email, biometric
//  preference), which is why its tokens are left empty here.
//

import Foundation
import LocalAuthentication
import Supabase
import Auth

@MainActor
final class SupabaseAuthService: AuthServiceProtocol {

    private(set) var currentSession: AuthSession?

    private let client: SupabaseClient
    private let store: SessionStoring

    init(client: SupabaseClient, store: SessionStoring) {
        self.client = client
        self.store = store
    }

    // MARK: Session Lifecycle

    func restoreSession() async -> AuthSession? {
        do {
            // Throws when there is no stored session — the normal
            // "signed out" path, not an error worth surfacing.
            let authSession = try await client.auth.session
            let session = try await buildSession(from: authSession)
            currentSession = session
            store.lastSignedInEmail = session.email
            return session
        } catch {
            currentSession = nil
            return nil
        }
    }

    func refreshIfNeeded() async throws -> AuthSession? {
        guard currentSession != nil else { return nil }
        do {
            // The SDK refreshes on its own; asking for the session forces
            // the check and surfaces a hard expiry as a throw.
            let refreshed = try await client.auth.session
            let session = try await buildSession(from: refreshed)
            currentSession = session
            return session
        } catch {
            currentSession = nil
            throw SupabaseErrorMapper.map(error)
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        currentSession = nil
        store.clear()
    }

    // MARK: Credentials

    func signIn(email: String, password: String) async throws -> SignInOutcome {
        do {
            let response = try await client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password
            )
            // An account enrolled in MFA comes back at assurance level aal1
            // and must step up before it can read anything.
            if let challenge = try await pendingMFAChallenge() {
                return .mfaRequired(challenge)
            }
            return .session(try await activate(response))
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func signUp(name: String, email: String, password: String, role: AppRole) async throws -> SignInOutcome {
        do {
            let response = try await client.auth.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password,
                data: ["full_name": .string(name)]
            )
            // `data` only seeds the profile's display name — the database
            // trigger `handle_new_user` ignores anything role-shaped in it.
            guard let authSession = response.session else {
                // Email confirmation is on: there is no session yet.
                throw AppError.validation("Check your email to confirm your account, then sign in.")
            }
            let session = try await buildSession(from: authSession)
            currentSession = session
            store.save(session)
            return .session(session)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func signIn(with provider: SocialProvider) async throws -> SignInOutcome {
        do {
            let oauthProvider: Provider = provider == .apple ? .apple : .google
            let authSession = try await client.auth.signInWithOAuth(
                provider: oauthProvider,
                redirectTo: URL(string: "rentos://auth-callback")
            )
            if let challenge = try await pendingMFAChallenge() {
                return .mfaRequired(challenge)
            }
            let session = try await buildSession(from: authSession)
            currentSession = session
            store.save(session)
            return .session(session)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: Recovery

    func sendPasswordReset(to email: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(
                email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                redirectTo: URL(string: "rentos://password-reset")
            )
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func resetPassword(newPassword: String) async throws {
        do {
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: Multi-Factor

    /// The first unverified TOTP factor, if the account has one.
    private func pendingMFAChallenge() async throws -> MFAChallenge? {
        let levels = try await client.auth.mfa.getAuthenticatorAssuranceLevel()
        // Already stepped up, or never enrolled.
        guard levels.currentLevel != levels.nextLevel, levels.nextLevel == "aal2" else {
            return nil
        }

        let factors = try await client.auth.mfa.listFactors()
        guard let factor = factors.totp.first else { return nil }

        let challenge = try await client.auth.mfa.challenge(params: .init(factorId: factor.id))
        return MFAChallenge(
            challengeID: challenge.id,
            method: .totp,
            hint: factor.friendlyName,
            // The factor id has to survive the round trip to `verifyMFA`,
            // and `MFAChallenge` intentionally has no field for provider
            // internals — so it is carried alongside.
            expiresAt: .now.addingTimeInterval(300)
        )
        .storingFactorID(factor.id)
    }

    func verifyMFA(code: String, for challenge: MFAChallenge) async throws -> AuthSession {
        guard let factorID = challenge.factorID else {
            throw AppError.validation("This verification session expired. Sign in again.")
        }
        do {
            let authSession = try await client.auth.mfa.verify(
                params: .init(factorId: factorID, challengeId: challenge.challengeID, code: code)
            )
            let session = try await buildSession(from: authSession)
            MFAFactorRegistry.shared.forget(challenge.challengeID)
            currentSession = session
            store.save(session)
            return session
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func resendMFACode(for challenge: MFAChallenge) async throws -> MFAChallenge {
        // TOTP codes are generated on the user's device — there is nothing
        // to resend. Issuing a fresh challenge is the meaningful action.
        guard let factorID = challenge.factorID else {
            throw AppError.validation("This verification session expired. Sign in again.")
        }
        do {
            let fresh = try await client.auth.mfa.challenge(params: .init(factorId: factorID))
            return MFAChallenge(
                challengeID: fresh.id,
                method: challenge.method,
                hint: challenge.hint,
                expiresAt: .now.addingTimeInterval(300)
            )
            .storingFactorID(factorID)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: Organization

    /// Called after the org-setup wizard has created the workspace.
    ///
    /// The id and name are re-read from the server rather than trusted
    /// from the caller: `create_organization()` is what actually made the
    /// row and granted ownership.
    func attachOrganization(id: String, name: String) async throws -> AuthSession {
        do {
            let authSession = try await client.auth.session
            let session = try await buildSession(from: authSession)

            // If the server disagrees with what the wizard thinks it
            // created, trust the server and say so — a silent mismatch
            // here would show the wrong workspace name for a whole session.
            if let serverOrg = session.organizationID, serverOrg != id {
                assertionFailure("Org mismatch: wizard reported \(id) (\(name)), server says \(serverOrg)")
            }
            guard session.organizationID != nil else {
                throw AppError.validation("The workspace wasn't created. Please try again.")
            }

            currentSession = session
            store.save(session)
            return session
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: Biometrics

    var biometricKind: BiometricKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:   return .faceID
        case .touchID:  return .touchID
        case .opticID:  return .opticID
        default:        return .none
        }
    }

    func setBiometricEnabled(_ enabled: Bool) async throws {
        guard var session = currentSession else { throw AppError.unauthorized }
        if enabled, !biometricKind.isAvailable {
            throw AppError.validation("This device doesn't have biometrics set up.")
        }
        session.biometricEnabled = enabled
        currentSession = session
        store.save(session)
    }

    /// Biometrics gate a session the SDK already holds; they are not a
    /// credential. If the refresh token has expired there is nothing to
    /// unlock and the user signs in again.
    func unlockWithBiometrics() async throws -> AuthSession {
        guard let hint = store.load(), hint.biometricEnabled else {
            throw AppError.unauthorized
        }

        let context = LAContext()
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock RentOS"
            )
            guard ok else { throw AppError.unauthorized }
        } catch {
            throw AppError.unauthorized
        }

        guard let session = await restoreSession() else { throw AppError.unauthorized }
        return session
    }

    // MARK: Session Assembly

    private func activate(_ response: Session) async throws -> AuthSession {
        let session = try await buildSession(from: response)
        currentSession = session
        store.save(session)
        return session
    }

    /// Combines the GoTrue session with the server's view of who this is.
    private func buildSession(from authSession: Session) async throws -> AuthSession {
        let context: SessionContextRow = try await client
            .rpc("current_session_context")
            .single()
            .execute()
            .value

        return AuthSession(
            userID: context.userID,
            email: context.email,
            fullName: context.fullName,
            role: AppRole(rawValue: context.appRole) ?? .tenant,
            organizationID: context.organizationID,
            organizationName: context.organizationName,
            // Tokens deliberately left to the SDK's Keychain store. Copying
            // them into our own persisted blob would create a second place
            // for a credential to leak from, for no benefit.
            accessToken: "",
            refreshToken: "",
            expiresAt: Date(timeIntervalSince1970: authSession.expiresAt),
            mfaEnrolled: (try? await hasVerifiedMFAFactor()) ?? false,
            biometricEnabled: store.load()?.biometricEnabled ?? false
        )
    }

    private func hasVerifiedMFAFactor() async throws -> Bool {
        let factors = try await client.auth.mfa.listFactors()
        return !factors.totp.isEmpty
    }
}

// MARK: - RPC Row

/// Mirrors `public.current_session_context()`.
private struct SessionContextRow: Decodable {
    let userID: String
    let email: String
    let fullName: String
    let appRole: String
    let organizationID: String?
    let organizationName: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case fullName = "full_name"
        case appRole = "app_role"
        case organizationID = "organization_id"
        case organizationName = "organization_name"
    }
}

// MARK: - Factor ID Registry

/// `MFAChallenge` is provider-agnostic by design, but GoTrue needs the
/// *factor* id back at verification time — and the challenge only
/// carries a *challenge* id.
///
/// Rather than leak a Supabase concept into `Core/Auth`, the pairing is
/// held here for the few seconds a challenge is live. A class, not an
/// extension: Swift has no stored properties in extensions, and this
/// deliberately does not belong on the model.
@MainActor
private final class MFAFactorRegistry {

    static let shared = MFAFactorRegistry()
    private var factorIDs: [String: String] = [:]

    func store(factorID: String, for challengeID: String) {
        factorIDs[challengeID] = factorID
    }

    func factorID(for challengeID: String) -> String? {
        factorIDs[challengeID]
    }

    /// Called once a challenge resolves so a stale pairing cannot be
    /// replayed against a later challenge.
    func forget(_ challengeID: String) {
        factorIDs.removeValue(forKey: challengeID)
    }
}

private extension MFAChallenge {

    @MainActor
    func storingFactorID(_ id: String) -> MFAChallenge {
        MFAFactorRegistry.shared.store(factorID: id, for: challengeID)
        return self
    }

    @MainActor
    var factorID: String? { MFAFactorRegistry.shared.factorID(for: challengeID) }
}
