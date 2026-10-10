//
//  RealtimeEvent.swift
//  RentalApp (Purrperty)
//
//  Core/Realtime — The event vocabulary.
//
//  ─────────────────────────────────────────────────────────────────
//  A SUBSCRIPTION IS THE EASY HALF
//  ─────────────────────────────────────────────────────────────────
//  Opening a WebSocket and applying rows as they arrive takes an
//  afternoon. It is also wrong in four specific ways, and each one shows
//  up as a bug a user can see:
//
//  1. THE GAP. A socket cannot replay what happened while it was down.
//     Resuming a subscription is not resyncing — you also need a delta
//     fetch from a high-water mark. Without it, the app looks live and is
//     quietly stale, which is worse than visibly offline.
//  2. THE ECHO. Your own optimistic write comes back as an event. Applied
//     naively it produces a flicker, or a duplicate row if the id changed
//     server-side.
//  3. ORDER. Events are not guaranteed in order across reconnects. An
//     older row can arrive after a newer one and silently roll back an
//     edit the user just made.
//  4. VOLUME. One bulk archive of twelve properties is twelve events. A
//     dashboard that recomputes per event does twelve times the work and
//     visibly stutters.
//
//  `RealtimeChange` carries what is needed to solve all four: a cursor
//  for ordering and gap detection, and an origin token for echo
//  suppression.
//

import Foundation

// MARK: - Topic

/// One logical stream. Maps to a Postgres table, but named for the domain
/// so features never mention a table.
enum RealtimeTopic: String, CaseIterable, Sendable {
    case notifications
    case maintenanceRequests = "maintenance_requests"
    case maintenanceUpdates  = "maintenance_updates"
    case messages
    case conversations
    case properties
    case units
    case tenants
    case leases
    case documents

    var table: String { rawValue }

    /// Topics whose changes invalidate the dashboard aggregates.
    ///
    /// Metrics are derived from Postgres views, so any row change in these
    /// tables can move a number on the home screen.
    static let dashboardInputs: Set<RealtimeTopic> = [
        .properties, .units, .leases, .maintenanceRequests, .tenants
    ]

    /// How aggressively to coalesce this topic's events.
    ///
    /// Chat has to feel immediate, so it is barely debounced. Portfolio
    /// tables can wait a beat — nobody notices 300ms on an occupancy
    /// figure, and the batching saves a burst of redundant recomputes.
    var coalesceWindow: Duration {
        switch self {
        case .messages, .conversations:                 .milliseconds(40)
        case .notifications, .maintenanceUpdates:       .milliseconds(150)
        case .maintenanceRequests, .documents:          .milliseconds(250)
        case .properties, .units, .tenants, .leases:    .milliseconds(300)
        }
    }
}

// MARK: - Change

enum RealtimeChangeKind: String, Sendable {
    case insert
    case update
    case delete
}

/// A single row change.
struct RealtimeChange: Sendable {

    let topic: RealtimeTopic
    let kind: RealtimeChangeKind
    /// Primary key of the affected row.
    let recordID: String
    /// Decoded row. Nil for deletes, where Postgres sends only the key
    /// unless the table has REPLICA IDENTITY FULL.
    let payload: Data?
    /// The row's `updated_at`. This is the ordering key — see `SyncCursor`.
    let cursor: Date
    /// Set when this app instance caused the change, so the engine can
    /// drop its own echo. Carried in a column the writer sets.
    let originToken: String?

    /// True when this change was caused by this device.
    func isEcho(of localOrigin: String) -> Bool {
        originToken == localOrigin
    }
}

// MARK: - Cursor

/// The high-water mark per topic.
///
/// `updated_at` rather than a sequence number, because it is already on
/// every table and already maintained by a trigger the client cannot
/// forge. The cost is that two rows written in the same millisecond are
/// unordered relative to each other — acceptable here, since the resync
/// query is inclusive and the engine is idempotent (see
/// `SyncEngine.apply`).
struct SyncCursor: Codable, Sendable, Equatable {

    private var marks: [String: Date] = [:]

    init() {}

    func mark(for topic: RealtimeTopic) -> Date? {
        marks[topic.rawValue]
    }

    /// Advances only forward. An out-of-order event must not rewind the
    /// cursor, or the next resync would re-fetch rows already applied.
    mutating func advance(_ topic: RealtimeTopic, to date: Date) {
        let current = marks[topic.rawValue] ?? .distantPast
        if date > current { marks[topic.rawValue] = date }
    }

    mutating func reset(_ topic: RealtimeTopic) {
        marks.removeValue(forKey: topic.rawValue)
    }

    mutating func resetAll() {
        marks.removeAll()
    }
}

// MARK: - Connection State

/// What the socket is doing. Drives the banner, and gates the outbox.
enum RealtimeConnectionState: Equatable, Sendable {

    /// Not started, or deliberately stopped (signed out, backgrounded).
    case idle
    case connecting
    /// Live. `since` lets the UI avoid flashing "connected" on a blip.
    case connected(since: Date)
    /// Lost, will retry. `attempt` drives the backoff curve.
    case reconnecting(attempt: Int, nextRetry: Date)
    /// No network at all. Distinct from `.reconnecting` because the fix is
    /// the user's, and the message should say so.
    case offline
    /// Gave up. Requires an explicit retry.
    case failed(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isDegraded: Bool {
        switch self {
        case .connected, .idle: false
        case .connecting, .reconnecting, .offline, .failed: true
        }
    }

    /// Copy for the connection banner. Nil while healthy — a banner that
    /// says "connected" is noise.
    var bannerMessage: String? {
        switch self {
        case .idle, .connected:      nil
        case .connecting:            "Connecting…"
        case .reconnecting:          "Reconnecting…"
        case .offline:               "You're offline. Changes will sync when you reconnect."
        case .failed:                "Live updates are paused."
        }
    }
}

// MARK: - Backoff

/// Exponential backoff with full jitter.
///
/// Jitter is not decoration: without it, every client that dropped during
/// the same outage retries in lockstep and re-creates the thundering herd
/// that caused it. Full jitter (random in `0...delay`) is the variant that
/// spreads load best for this shape of problem.
struct RealtimeBackoff: Sendable {

    let base: TimeInterval
    let cap: TimeInterval
    let maxAttempts: Int

    init(base: TimeInterval = 0.5, cap: TimeInterval = 30, maxAttempts: Int = 12) {
        self.base = base
        self.cap = cap
        self.maxAttempts = maxAttempts
    }

    func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponential = min(cap, base * pow(2, Double(max(0, attempt - 1))))
        return Double.random(in: 0...exponential)
    }

    func hasExhausted(_ attempt: Int) -> Bool { attempt >= maxAttempts }
}

// MARK: - Client Contract

/// A realtime transport.
///
/// Provider-agnostic for the same reason the AI layer is: the app should
/// not care whether changes arrive over Supabase Realtime, a custom
/// WebSocket, or polling. Polling is a legitimate implementation of this
/// protocol and a useful fallback on a hostile network.
protocol RealtimeClientProtocol: AnyObject, Sendable {

    /// A token identifying this app instance, stamped on its own writes so
    /// their echoes can be dropped.
    var originToken: String { get }

    /// Opens the connection and begins delivering changes for `topics`.
    ///
    /// The returned stream finishes when the connection is torn down, which
    /// is the engine's signal to reconnect.
    func subscribe(topics: Set<RealtimeTopic>) async throws -> AsyncStream<RealtimeChange>

    func disconnect() async
}
