//
//  BreadcrumbTrail.swift
//  RentalApp (Purrperty)
//
//  Core/Diagnostics — What was happening just before it broke.
//
//  ─────────────────────────────────────────────────────────────────
//  A STACK TRACE SAYS WHERE, BREADCRUMBS SAY HOW
//  ─────────────────────────────────────────────────────────────────
//  "Crashed in PropertyListView.body" is nearly useless on its own.
//  "Went offline → queued three writes → reconnected → drained the
//  outbox → crashed in PropertyListView.body" is a reproduction.
//
//  ─────────────────────────────────────────────────────────────────
//  BREADCRUMBS ARE A PRIVACY SURFACE
//  ─────────────────────────────────────────────────────────────────
//  This is the part that gets built carelessly. Breadcrumbs feel like
//  debug output, so people interpolate whatever is at hand — the
//  property name, the tenant, the search query — and it ends up on
//  disk and then on a server. So the type accepts the same closed
//  `AnalyticsValue` vocabulary the analytics layer uses: no free-form
//  strings, by construction.
//
//  The ring buffer is bounded, so a long session cannot grow memory
//  without limit, and the oldest crumbs are the least useful anyway.
//

import Foundation
import OSLog

// MARK: - Crumb

struct Breadcrumb: Sendable, Codable, Equatable {

    enum Level: String, Sendable, Codable {
        case debug
        case info
        case warning
        case error
    }

    let timestamp: Date
    let category: String
    let message: String
    let level: Level

    /// Compact single-line form for a crash report.
    var rendered: String {
        let seconds = String(format: "%.3f", timestamp.timeIntervalSince1970)
        return "\(seconds) [\(level.rawValue)] \(category): \(message)"
    }
}

// MARK: - Trail

/// A bounded ring buffer of recent app events.
///
/// `@MainActor` because it is written from view lifecycle and view
/// models, which are already there — an actor hop per breadcrumb would
/// cost more than the breadcrumb is worth.
@MainActor
final class BreadcrumbTrail {

    private let capacity: Int
    private var crumbs: [Breadcrumb] = []
    private let persistence: PersistenceServiceProtocol

    /// Retained separately so a crash report can be attributed when
    /// consent allows. Never written to disk by this type.
    private(set) var lastKnownUserID: String?

    private static let storageKey = "diagnostics.breadcrumbs.v1"

    init(persistence: PersistenceServiceProtocol, capacity: Int = 50) {
        self.persistence = persistence
        self.capacity = capacity
        self.crumbs.reserveCapacity(capacity)
    }

    // MARK: Record

    /// Records an event.
    ///
    /// `message` is `StaticString`: a compile-time literal. This is the
    /// enforcement, not a convention — a caller physically cannot pass
    /// an interpolated string containing a tenant's name, because
    /// `StaticString` does not accept interpolation. Variable data goes
    /// through `values`, which takes the non-identifying `AnalyticsValue`.
    func record(
        _ message: StaticString,
        category: LogCategory = .app,
        level: Breadcrumb.Level = .info,
        values: [String: AnalyticsValue] = [:]
    ) {
        let rendered: String
        if values.isEmpty {
            rendered = "\(message)"
        } else {
            let pairs = values
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.stringValue)" }
                .joined(separator: " ")
            rendered = "\(message) \(pairs)"
        }

        crumbs.append(Breadcrumb(
            timestamp: Date(),
            category: category.rawValue,
            message: rendered,
            level: level
        ))

        // Drop the oldest. `removeFirst` on an Array is O(n), but n is
        // 50 and this runs at human speed, so a real ring buffer would
        // be complexity for no measurable gain.
        if crumbs.count > capacity {
            crumbs.removeFirst(crumbs.count - capacity)
        }
    }

    func setUser(_ userID: String?) {
        lastKnownUserID = userID
    }

    // MARK: Persistence

    /// Writes the current trail so it survives the crash.
    ///
    /// Called on backgrounding and after each `.error` crumb, NOT on
    /// every crumb — writing 50 records to disk on every screen
    /// transition would be a real cost for a marginal gain in fidelity.
    func persist() {
        do {
            let data = try JSONEncoder().encode(crumbs)
            persistence.set(data, forKey: Self.storageKey)
        } catch {
            AppLog.diagnostics.failure("Could not persist breadcrumbs", error: error)
        }
    }

    /// Reads and clears the previous run's trail.
    func restorePrevious() -> [String] {
        guard let data = persistence.data(forKey: Self.storageKey) else { return [] }
        persistence.removeObject(forKey: Self.storageKey)

        do {
            return try JSONDecoder().decode([Breadcrumb].self, from: data).map(\.rendered)
        } catch {
            return []
        }
    }

    /// For the current run — used when reporting a non-fatal.
    var current: [String] { crumbs.map(\.rendered) }

    /// Consent revocation must remove data already collected, not only
    /// stop future collection.
    func purge() {
        crumbs.removeAll()
        lastKnownUserID = nil
        persistence.removeObject(forKey: Self.storageKey)
        AppLog.privacy.notice("Breadcrumb trail purged")
    }
}
