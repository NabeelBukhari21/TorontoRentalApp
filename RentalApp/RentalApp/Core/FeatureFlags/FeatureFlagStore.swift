//
//  FeatureFlagStore.swift
//  RentalApp (RentOS)
//
//  Core/FeatureFlags — Resolution, refresh, and the SwiftUI seam.
//
//  ─────────────────────────────────────────────────────────────────
//  A FLAG MUST NEVER BE ASYNC AT THE POINT OF USE
//  ─────────────────────────────────────────────────────────────────
//  `if await flags.isEnabled(.x)` inside a `body` is impossible, and
//  making it possible by awaiting somewhere else means the UI renders
//  once with the wrong answer and then flickers. So resolution is
//  synchronous against an in-memory snapshot, and *refreshing* that
//  snapshot is the only async part. A flag read always returns
//  immediately, and the value is always one that was valid at the last
//  refresh.
//

import Foundation
import Observation
import SwiftUI
import OSLog

// MARK: - Remote Source

/// Supplies remote overrides. Protocol so the store is testable without
/// a network and so the backend can change without touching resolution.
protocol FeatureFlagRemoteSource: Sendable {
    /// Returns raw key→value pairs. Unknown keys are the source's
    /// business to return and the store's business to reject.
    func fetchOverrides() async throws -> [String: Bool]
}

/// Used when there is no backend configured.
struct NoRemoteFlagSource: FeatureFlagRemoteSource {
    func fetchOverrides() async throws -> [String: Bool] { [:] }
}

// MARK: - Store

@MainActor
@Observable
final class FeatureFlagStore {

    /// Remote values from the last successful refresh.
    private var remoteValues: [FeatureFlag: Bool] = [:]

    /// Developer overrides. Debug builds only.
    private var localOverrides: [FeatureFlag: Bool] = [:]

    private(set) var lastRefresh: Date?
    private(set) var isRefreshing = false

    private let remote: FeatureFlagRemoteSource
    private let persistence: PersistenceServiceProtocol
    private let environment: AppEnvironment

    /// Set by the container. Lets the store refuse to disable a
    /// data-critical flag while work is queued behind it.
    var pendingWorkCheck: (@MainActor () -> Bool)?

    private static let remoteKey = "flags.remote.v1"
    private static let overrideKey = "flags.overrides.v1"

    init(
        remote: FeatureFlagRemoteSource = NoRemoteFlagSource(),
        persistence: PersistenceServiceProtocol,
        environment: AppEnvironment = .current
    ) {
        self.remote = remote
        self.persistence = persistence
        self.environment = environment

        // Load the last known remote payload immediately. A cold launch
        // on a plane should behave like the last launch did, not snap
        // every flag back to its compiled default.
        self.remoteValues = Self.loadFlags(Self.remoteKey, from: persistence)
        if environment.allowsDebugTools {
            self.localOverrides = Self.loadFlags(Self.overrideKey, from: persistence)
        }
    }

    // MARK: Resolution

    /// The only method most code needs. Synchronous by design.
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        resolve(flag).value
    }

    /// Resolution with provenance, for the debug screen.
    func resolve(_ flag: FeatureFlag) -> FlagResolution {
        if environment.allowsDebugTools, let override = localOverrides[flag] {
            return FlagResolution(value: override, source: .localOverride)
        }
        if flag.isRemotelyControllable, let remoteValue = remoteValues[flag] {
            return FlagResolution(value: remoteValue, source: .remote)
        }
        return FlagResolution(value: flag.defaultValue, source: .compiledDefault)
    }

    // MARK: Refresh

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let raw = try await remote.fetchOverrides()
            var accepted: [FeatureFlag: Bool] = [:]

            for (key, value) in raw {
                // Unknown key: ignore, but say so. Silent ignores are how
                // a server-side typo becomes an afternoon of confusion.
                guard let flag = FeatureFlag(rawValue: key) else {
                    AppLog.app.notice("Ignoring unknown remote flag \(key, privacy: .public)")
                    continue
                }
                guard flag.isRemotelyControllable else {
                    AppLog.app.notice(
                        "Refusing remote control of \(key, privacy: .public)"
                    )
                    continue
                }
                // Refuse to disable something with queued work behind it.
                // Turning off offline writes while the outbox is full
                // would strand those writes with no path to the server.
                if flag.isDataCritical, value == false, pendingWorkCheck?() == true {
                    AppLog.app.notice(
                        "Deferring disable of \(key, privacy: .public): work still pending"
                    )
                    continue
                }
                accepted[flag] = value
            }

            remoteValues = accepted
            lastRefresh = Date()
            persist(accepted, to: Self.remoteKey)

        } catch {
            // Keep the previous snapshot. A failed refresh must not
            // reset the app to defaults — that would turn a brief
            // network blip into a feature-set change mid-session.
            AppLog.app.failure("Feature flag refresh failed", error: error)
        }
    }

    // MARK: Debug overrides

    func setOverride(_ value: Bool?, for flag: FeatureFlag) {
        guard environment.allowsDebugTools else { return }
        localOverrides[flag] = value
        persist(localOverrides, to: Self.overrideKey)
    }

    func clearOverrides() {
        guard environment.allowsDebugTools else { return }
        localOverrides.removeAll()
        persistence.removeObject(forKey: Self.overrideKey)
    }

    var hasOverrides: Bool { !localOverrides.isEmpty }

    // MARK: Persistence

    private func persist(_ flags: [FeatureFlag: Bool], to key: String) {
        let raw = flags.reduce(into: [String: Bool]()) { $0[$1.key.rawValue] = $1.value }
        guard let data = try? JSONEncoder().encode(raw) else { return }
        persistence.set(data, forKey: key)
    }

    private static func loadFlags(
        _ key: String,
        from persistence: PersistenceServiceProtocol
    ) -> [FeatureFlag: Bool] {
        guard
            let data = persistence.data(forKey: key),
            let raw = try? JSONDecoder().decode([String: Bool].self, from: data)
        else { return [:] }

        return raw.reduce(into: [FeatureFlag: Bool]()) { result, pair in
            // Same rejection on the way in: a flag removed from the enum
            // must not be resurrected by a stale cache.
            guard let flag = FeatureFlag(rawValue: pair.key) else { return }
            result[flag] = pair.value
        }
    }
}

// MARK: - SwiftUI

private struct FeatureFlagStoreKey: EnvironmentKey {
    // Deliberately no `defaultValue` singleton shared with the app. A
    // preview that silently reads production flags is a preview that
    // lies about what it is showing.
    @MainActor
    static let defaultValue = FeatureFlagStore(
        persistence: EphemeralPersistenceService()
    )
}

extension EnvironmentValues {
    var featureFlags: FeatureFlagStore {
        get { self[FeatureFlagStoreKey.self] }
        set { self[FeatureFlagStoreKey.self] = newValue }
    }
}

extension View {

    /// Renders content only when a flag is on.
    ///
    /// Note this removes the view rather than hiding it — a hidden view
    /// still runs its `body`, still fires its `.task`, and still fetches.
    /// "Disabled" has to mean the code does not run.
    @ViewBuilder
    func featureGated(
        _ flag: FeatureFlag,
        store: FeatureFlagStore
    ) -> some View {
        if store.isEnabled(flag) {
            self
        }
    }
}
