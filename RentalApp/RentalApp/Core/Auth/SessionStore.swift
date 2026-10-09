//
//  SessionStore.swift
//  RentalApp (RentOS)
//
//  Core — Session persistence.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY THIS IS A PROTOCOL AND NOT `UserDefaults.standard`
//  ─────────────────────────────────────────────────────────────────
//  A session carries tokens. Tokens belong in the Keychain, not in a
//  plist. The protocol is what let that be true without any caller
//  knowing where the bytes go.
//
//  ⚠️ `SessionStore` below is the UserDefaults implementation. It is
//  for MOCK BACKENDS AND PREVIEWS ONLY, where every credential is
//  fabricated. It must never be used with a real backend.
//
//  The production implementation is `KeychainSessionStore`, and it is
//  what `AppContainer.live()` wires up. This file's original note said
//  the Keychain store would be written "when Supabase lands"; Supabase
//  landed and it was not, so real bearer tokens sat in a plist for
//  several releases' worth of work. See KeychainSessionStore.swift.
//

import Foundation

// MARK: - Contract

protocol SessionStoring: AnyObject, Sendable {
    func load() -> AuthSession?
    func save(_ session: AuthSession)
    func clear()

    /// Whether the user has completed onboarding. Kept beside the
    /// session because it answers the same launch-time question:
    /// "what do we show first?"
    var hasCompletedOnboarding: Bool { get set }

    /// The last email that signed in. Used to pre-fill the login field
    /// and to label the biometric unlock prompt.
    var lastSignedInEmail: String? { get set }
}

// MARK: - Implementation

/// Stores the session as JSON through the app's persistence service.
///
/// ⚠️ NOT FOR PRODUCTION. `PersistenceServiceProtocol` is UserDefaults,
/// which is an unencrypted plist. Use `KeychainSessionStore` with any
/// backend that issues real tokens. This type remains because the mock
/// backend and previews need a store and have nothing worth protecting.
///
/// - Note: Deliberately tolerant of decode failure. A session written
///   by an older build with a different shape must not brick launch —
///   a corrupt blob is treated as "signed out", not as an error.
final class SessionStore: SessionStoring, @unchecked Sendable {

    private enum Key {
        static let session = "rentos.auth.session.v1"
        static let onboarding = "rentos.auth.onboarding.completed.v1"
        static let lastEmail = "rentos.auth.last.email.v1"
    }

    private let persistence: PersistenceServiceProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(persistence: PersistenceServiceProtocol) {
        self.persistence = persistence

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: Session

    func load() -> AuthSession? {
        guard let data = persistence.data(forKey: Key.session) else { return nil }
        return try? decoder.decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        persistence.set(data, forKey: Key.session)
        lastSignedInEmail = session.email
    }

    func clear() {
        persistence.removeObject(forKey: Key.session)
        // `lastSignedInEmail` and onboarding state survive sign-out on
        // purpose — signing out shouldn't replay onboarding or make the
        // user retype an email they've already used on this device.
    }

    // MARK: Flags

    var hasCompletedOnboarding: Bool {
        get { boolValue(forKey: Key.onboarding) }
        set { setBool(newValue, forKey: Key.onboarding) }
    }

    var lastSignedInEmail: String? {
        get {
            persistence.data(forKey: Key.lastEmail)
                .flatMap { String(data: $0, encoding: .utf8) }
        }
        set {
            persistence.set(newValue?.data(using: .utf8), forKey: Key.lastEmail)
        }
    }

    // MARK: Helpers

    private func boolValue(forKey key: String) -> Bool {
        persistence.data(forKey: key)?.first == 1
    }

    private func setBool(_ value: Bool, forKey key: String) {
        persistence.set(Data([value ? 1 : 0]), forKey: key)
    }
}
