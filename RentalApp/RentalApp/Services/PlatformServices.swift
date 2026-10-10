//
//  PlatformServices.swift
//  RentalApp (Purrperty)
//
//  Services — Persistence and analytics adapters.
//

import Foundation
import OSLog

// MARK: - Persistence

/// UserDefaults-backed persistence. Swap for Keychain or a file store
/// without touching callers.
final class UserDefaultsPersistenceService: PersistenceServiceProtocol {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func removeObject(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}

/// In-memory persistence for previews and tests.
final class EphemeralPersistenceService: PersistenceServiceProtocol, @unchecked Sendable {

    private var storage: [String: Data] = [:]

    func data(forKey key: String) -> Data? { storage[key] }
    func set(_ data: Data?, forKey key: String) { storage[key] = data }
    func removeObject(forKey key: String) { storage[key] = nil }
}

// MARK: - Analytics
//
// `ConsoleAnalyticsService` was here. It is gone, and its removal is a
// security fix rather than a refactor.
//
// It logged every analytics property with `privacy: .public`:
//
//     logger.debug("event=\(event, privacy: .public) props=\(properties.description, privacy: .public)")
//
// `properties` was `[String: String]`, so whatever any call site chose
// to put in it — a tenant name, an email, a unit address — was written
// in clear text to the unified log, where it is readable via Console.app
// by anyone with the unlocked device and is captured in sysdiagnose
// archives that users routinely email to support.
//
// The replacement is `OSLogAnalyticsSink` in Core/Analytics/. It still
// logs values as `.public`, which is safe there only because
// `AnalyticsValue` structurally cannot hold free-form text.
