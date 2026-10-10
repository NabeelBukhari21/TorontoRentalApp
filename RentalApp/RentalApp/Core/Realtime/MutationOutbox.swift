//
//  MutationOutbox.swift
//  RentalApp (Purrperty)
//
//  Core/Realtime — Offline writes.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY A QUEUE AND NOT JUST A RETRY
//  ─────────────────────────────────────────────────────────────────
//  A retry keeps one request alive. An outbox keeps the *user's intent*
//  alive across an app relaunch, which is the actual requirement: a
//  manager who archives three properties in a parking garage expects them
//  archived, not an error when they surface.
//
//  Three properties make it safe:
//
//  1. ORDER. Operations replay in the order they were made. "Create unit
//     402, then set its rent" is not commutative.
//  2. IDEMPOTENCY. Each entry carries a client-generated id used as an
//     idempotency key, so a replay that already reached the server does
//     not duplicate. Without this, a response lost on a flaky network
//     produces two properties.
//  3. COLLAPSING. Two edits to the same field of the same record only need
//     the last one. Archiving then restoring cancels out entirely.
//
//  What this is NOT: a general CRDT. Text does not merge here, and it does
//  not try. Collapsing is by (operation, record) pair only — anything
//  cleverer would be guessing at intent.
//

import Foundation
import Observation

// MARK: - Entry

/// One queued mutation.
struct OutboxEntry: Codable, Sendable, Identifiable {

    enum Operation: String, Codable, Sendable {
        case create
        case update
        case delete
        case archive
        case restore
        /// Ordering-sensitive domain action (assign vendor, change status).
        case action
    }

    let id: UUID
    let topic: String
    let operation: Operation
    let recordID: String?
    /// The encoded request body, replayed verbatim.
    let payload: Data
    /// Human-readable, for the pending-changes sheet.
    let summary: String
    let queuedAt: Date
    var attempts: Int
    var lastError: String?
    /// Earliest time this may be retried. Set after a retryable failure so a
    /// dead network does not spin the queue at full speed — which drains a
    /// battery and achieves nothing.
    var nextAttemptAt: Date?

    var isReady: Bool {
        (nextAttemptAt ?? .distantPast) <= Date()
    }

    init(
        id: UUID = UUID(),
        topic: RealtimeTopic,
        operation: Operation,
        recordID: String?,
        payload: Data,
        summary: String
    ) {
        self.id = id
        self.topic = topic.rawValue
        self.operation = operation
        self.recordID = recordID
        self.payload = payload
        self.summary = summary
        self.queuedAt = Date()
        self.attempts = 0
        self.nextAttemptAt = nil
    }

    /// Entries for the same record and operation supersede one another.
    var collapseKey: String {
        "\(topic):\(recordID ?? id.uuidString):\(operation.rawValue)"
    }
}

// MARK: - Executor

/// Replays one entry against the backend.
///
/// Supplied by the container. The outbox deliberately does not know how to
/// perform a mutation — it only knows how to remember one.
protocol OutboxExecuting: Sendable {
    /// - Returns: true when the entry is done with (applied, or rejected
    ///   permanently). False means "retry later".
    func execute(_ entry: OutboxEntry) async -> OutboxResult
}

enum OutboxResult: Sendable {
    case applied
    /// Server said no in a way retrying cannot fix (validation, RLS).
    /// Dropped and surfaced to the user rather than retried forever.
    case rejected(AppError)
    case retryLater
}

// MARK: - Outbox

@MainActor
@Observable
final class MutationOutbox {

    private(set) var entries: [OutboxEntry] = []
    private(set) var isDraining = false
    /// Entries the server permanently refused. Shown once, then cleared.
    private(set) var failures: [OutboxEntry] = []

    var pendingCount: Int { entries.count }
    var hasPending: Bool { !entries.isEmpty }

    /// Soonest moment a queued entry becomes eligible. Nil when something is
    /// ready now, or when the queue is empty.
    var nextRetryAt: Date? {
        entries.compactMap(\.nextAttemptAt).filter { $0 > Date() }.min()
    }

    /// Entries the user can see in the pending-changes sheet.
    var pendingSummaries: [(id: UUID, summary: String, queuedAt: Date, attempts: Int)] {
        entries.map { ($0.id, $0.summary, $0.queuedAt, $0.attempts) }
    }

    private let persistence: PersistenceServiceProtocol
    private let executor: OutboxExecuting
    private let maxAttempts: Int

    private static let storageKey = "rentos.outbox.v1"

    init(
        persistence: PersistenceServiceProtocol,
        executor: OutboxExecuting,
        maxAttempts: Int = 6
    ) {
        self.persistence = persistence
        self.executor = executor
        self.maxAttempts = maxAttempts
        load()
    }

    // MARK: Enqueue

    /// Records an intent. Collapses against an existing entry for the same
    /// record and operation.
    func enqueue(_ entry: OutboxEntry) {
        if let index = entries.firstIndex(where: { $0.collapseKey == entry.collapseKey }) {
            // Keep the queue position — order relative to *other* records
            // matters — but take the newer payload.
            entries[index] = entry
        } else if let inverse = inverseIndex(of: entry) {
            // Archive followed by restore (or vice versa) is a no-op. Drop
            // both rather than sending two requests that cancel out.
            entries.remove(at: inverse)
        } else {
            entries.append(entry)
        }
        save()
    }

    /// Finds an entry this one exactly undoes.
    private func inverseIndex(of entry: OutboxEntry) -> Int? {
        let opposite: OutboxEntry.Operation?
        switch entry.operation {
        case .archive: opposite = .restore
        case .restore: opposite = .archive
        default:       opposite = nil
        }
        guard let opposite, let recordID = entry.recordID else { return nil }
        return entries.firstIndex {
            $0.topic == entry.topic && $0.recordID == recordID && $0.operation == opposite
        }
    }

    // MARK: Drain

    /// Replays the queue in order. Called on reconnect, after the gap
    /// resync so replays land on current server state.
    func drain() async {
        guard !isDraining, !entries.isEmpty else { return }
        isDraining = true
        defer { isDraining = false }

        // Snapshot: enqueues during a drain must not be replayed twice, and
        // must not mutate the array we are walking.
        let batch = entries

        for entry in batch {
            guard entries.contains(where: { $0.id == entry.id }) else { continue }

            // Still cooling down. Stop rather than skip: entries replay in
            // order, and jumping over one would apply a later operation
            // before an earlier one it may depend on.
            guard entry.isReady else { return }

            switch await executor.execute(entry) {
            case .applied:
                remove(entry.id)

            case .rejected(let error):
                var failed = entry
                failed.lastError = error.errorDescription
                failures.append(failed)
                remove(entry.id)

            case .retryLater:
                bumpAttempt(entry.id)
                // Stop on the first retryable failure. Continuing would
                // apply later operations out of order — the one thing the
                // queue exists to prevent.
                return
            }
        }
    }

    func clearFailures() {
        failures.removeAll()
    }

    /// Discards everything. For sign-out, where replaying another user's
    /// queued writes would be a security problem, not just a bug.
    func purge() {
        entries.removeAll()
        failures.removeAll()
        save()
    }

    // MARK: Internals

    private func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    private func bumpAttempt(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].attempts += 1

        // Exponential with full jitter, capped. Jitter matters here for the
        // same reason it does on the socket: without it every client that
        // queued during one outage retries in lockstep when it clears.
        let exponential = min(300.0, 2.0 * pow(2.0, Double(entries[index].attempts - 1)))
        entries[index].nextAttemptAt = Date()
            .addingTimeInterval(Double.random(in: 0...exponential))

        if entries[index].attempts >= maxAttempts {
            var failed = entries[index]
            failed.lastError = "Gave up after \(maxAttempts) attempts."
            failures.append(failed)
            entries.remove(at: index)
        }
        save()
    }

    private func load() {
        guard let data = persistence.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([OutboxEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        // Persisted synchronously: the write that matters most is the one
        // made just before the app is killed.
        persistence.set(try? JSONEncoder().encode(entries), forKey: Self.storageKey)
    }
}

// MARK: - No-op Outbox

/// Used by the in-memory graph and previews, where there is no backend to
/// be offline from.
@MainActor
final class NoOutboxExecutor: OutboxExecuting {
    func execute(_ entry: OutboxEntry) async -> OutboxResult { .applied }
}
