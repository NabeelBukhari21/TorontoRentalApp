//
//  KeychainSessionStore.swift
//  RentalApp (Purrperty)
//
//  Core/Auth — Where the tokens actually live.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY THIS FILE EXISTS
//  ─────────────────────────────────────────────────────────────────
//  `SessionStore` carried this note:
//
//      "Today the concrete store writes through
//       PersistenceServiceProtocol (UserDefaults) because there is no
//       real token to protect yet — every credential is fabricated.
//       When Supabase lands, KeychainSessionStore conforms to this
//       same protocol..."
//
//  Supabase landed. This file was never written, so live Supabase
//  access and refresh tokens have been serialized into UserDefaults —
//  a plain `.plist` inside the app container. That file is readable:
//
//  • from an unencrypted local backup, without the device passcode;
//  • by any process with filesystem access on a jailbroken device;
//  • by anything running in the app's own container.
//
//  A refresh token is a long-lived bearer credential. Possession of one
//  is possession of the account until it is revoked, and RLS does not
//  help — every policy in the schema authorizes on the strength of that
//  token being genuine.
//
//  ─────────────────────────────────────────────────────────────────
//  THE ACCESSIBILITY CLASS IS THE WHOLE DECISION
//  ─────────────────────────────────────────────────────────────────
//  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, and each half is
//  load-bearing:
//
//  • AfterFirstUnlock, not WhenUnlocked — the outbox drain runs as a
//    BGProcessingTask, which the system schedules while the device is
//    locked. WhenUnlocked would make those reads fail with errSecInteractionNotAllowed,
//    and the queued writes would never sync.
//
//  • ThisDeviceOnly — excludes the item from iCloud Keychain sync and
//    from encrypted backups restored onto a different device. A
//    credential that follows a restore onto someone else's hardware is
//    a credential that outlived its trust boundary.
//

import Foundation
import Security
import OSLog

// MARK: - Store

/// Keychain-backed session persistence.
///
/// Only the session — which carries the tokens — goes to the Keychain.
/// The onboarding flag and the remembered email stay in UserDefaults:
/// they are not credentials, and the Keychain is a small, slow, awkward
/// store that should hold secrets and nothing else.
final class KeychainSessionStore: SessionStoring, @unchecked Sendable {

    private enum Key {
        /// Bump the suffix if `AuthSession`'s shape changes
        /// incompatibly; a stale item then reads as "signed out" rather
        /// than as a decode error at launch.
        static let account = "rentos.auth.session.v1"
        static let onboarding = "rentos.auth.onboarding.completed.v1"
        static let lastEmail = "rentos.auth.last.email.v1"
        /// Marks that the one-time migration off UserDefaults has run.
        static let migrated = "rentos.auth.keychain.migrated.v1"
    }

    private let service: String
    private let persistence: PersistenceServiceProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        persistence: PersistenceServiceProtocol,
        service: String = Bundle.main.bundleIdentifier ?? "ca.rentos.app"
    ) {
        self.service = service
        self.persistence = persistence

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: Session

    func load() -> AuthSession? {
        guard let data = read(account: Key.account) else { return nil }

        // Same tolerance as before: a blob written by an older build must
        // not brick launch. But delete it on the way out, or a permanently
        // undecodable item is re-read on every launch forever.
        guard let session = try? decoder.decode(AuthSession.self, from: data) else {
            AppLog.auth.notice("Stored session could not be decoded; clearing")
            delete(account: Key.account)
            return nil
        }
        return session
    }

    func save(_ session: AuthSession) {
        guard let data = try? encoder.encode(session) else {
            AppLog.auth.error("Could not encode session for storage")
            return
        }
        write(data, account: Key.account)
        lastSignedInEmail = session.email
    }

    func clear() {
        delete(account: Key.account)
        // Onboarding state and the remembered email survive sign-out on
        // purpose — signing out is not a fresh install.
    }

    // MARK: Non-secret flags

    var hasCompletedOnboarding: Bool {
        get { persistence.data(forKey: Key.onboarding)?.first == 1 }
        set { persistence.set(Data([newValue ? 1 : 0]), forKey: Key.onboarding) }
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

    // MARK: Keychain primitives

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func read(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            // Do not fall back to any other store on failure. A read that
            // fails must look like "not signed in", never like a reason
            // to consult a less protected copy.
            AppLog.auth.error("Keychain read failed: \(status, privacy: .public)")
            return nil
        }
    }

    /// Add-or-update. `SecItemAdd` returns `errSecDuplicateItem` when the
    /// account already exists, so the update path is required — not an
    /// optimisation.
    private func write(_ data: Data, account: String) {
        let query = baseQuery(account: account)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        guard updateStatus == errSecItemNotFound else {
            AppLog.auth.error("Keychain update failed: \(updateStatus, privacy: .public)")
            return
        }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        if addStatus != errSecSuccess {
            AppLog.auth.error("Keychain add failed: \(addStatus, privacy: .public)")
        }
    }

    private func delete(account: String) {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            AppLog.auth.error("Keychain delete failed: \(status, privacy: .public)")
        }
    }

    // MARK: Migration

    /// Moves an existing UserDefaults session into the Keychain, once.
    ///
    /// Without this, every already-installed user keeps their tokens in
    /// the plist until they happen to sign out — so the vulnerability
    /// would persist across the very release that fixes it. The old copy
    /// is removed whether or not the move succeeds: leaving a plaintext
    /// token behind because the Keychain write failed is strictly worse
    /// than making the user sign in again.
    private func migrateFromUserDefaultsIfNeeded() {
        guard persistence.data(forKey: Key.migrated) == nil else { return }
        defer {
            persistence.set(Data([1]), forKey: Key.migrated)
        }

        guard let legacy = persistence.data(forKey: Key.account) else { return }

        if read(account: Key.account) == nil {
            write(legacy, account: Key.account)
        }
        persistence.removeObject(forKey: Key.account)

        AppLog.auth.notice("Migrated session from UserDefaults to Keychain")
    }
}
