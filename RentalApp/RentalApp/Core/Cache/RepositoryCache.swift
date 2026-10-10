//
//  RepositoryCache.swift
//  RentalApp (Purrperty)
//
//  Core — Time-to-live cache shared by every repository.
//
//  Two jobs. First, stop re-fetching a list the user just navigated
//  away from and back to. Second, and more importantly, give the app
//  a single place where staleness policy lives — when the real API
//  arrives, "how long is a property list good for?" is answered here
//  rather than being re-litigated in twelve view models.
//
//  Writes invalidate by prefix, so mutating one ticket clears every
//  cached maintenance query without touching tenants or documents.
//

import Foundation

@MainActor
final class RepositoryCache {

    /// Shared instance. Injected into repositories through the
    /// container, never reached for directly from a feature.
    static let shared = RepositoryCache()

    private struct Entry {
        let value: Any
        let storedAt: Date
        let lifetime: TimeInterval

        func isFresh(asOf now: Date) -> Bool {
            now.timeIntervalSince(storedAt) < lifetime
        }
    }

    private var entries: [String: Entry] = [:]

    /// Default freshness window. Short enough that a demo feels live,
    /// long enough that tab switching doesn't re-hit the source.
    static let defaultLifetime: TimeInterval = 60

    init() {}

    // MARK: Read

    /// Returns a cached value only if it is still fresh.
    func value<T>(for key: String, as type: T.Type = T.self) -> T? {
        guard let entry = entries[key], entry.isFresh(asOf: .now) else {
            entries[key] = nil
            return nil
        }
        return entry.value as? T
    }

    // MARK: Write

    func store<T>(_ value: T, for key: String, lifetime: TimeInterval = defaultLifetime) {
        entries[key] = Entry(value: value, storedAt: .now, lifetime: lifetime)
    }

    // MARK: Invalidate

    /// Drops every entry whose key starts with `prefix`.
    /// Repositories namespace their keys, so `invalidate("maintenance")`
    /// clears exactly that domain.
    func invalidate(prefix: String) {
        for key in entries.keys where key.hasPrefix(prefix) {
            entries[key] = nil
        }
    }

    func invalidateAll() {
        entries.removeAll()
    }

    // MARK: Fetch-Through

    /// Returns the cached value, or runs `load` and caches the result.
    ///
    /// `forceRefresh` is what pull-to-refresh passes — it bypasses the
    /// read but still repopulates the cache, so a refresh benefits
    /// every screen that shares the key.
    func fetch<T>(
        key: String,
        lifetime: TimeInterval = defaultLifetime,
        forceRefresh: Bool = false,
        load: () async throws -> T
    ) async rethrows -> T {
        if !forceRefresh, let cached = value(for: key, as: T.self) {
            return cached
        }
        let fresh = try await load()
        store(fresh, for: key, lifetime: lifetime)
        return fresh
    }
}

// MARK: - Key Building

extension RepositoryCache {

    /// Builds a stable cache key from a namespace and query parts.
    /// Order matters, so callers pass components in a fixed order.
    static func key(_ namespace: String, _ components: [String]) -> String {
        ([namespace] + components).joined(separator: "|")
    }
}
