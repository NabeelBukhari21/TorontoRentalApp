//
//  OfflineGate.swift
//  RentalApp (Purrperty)
//
//  Core/Offline — Where "offline" stops being a state and becomes behaviour.
//
//  ─────────────────────────────────────────────────────────────────
//  THE PIECE THAT WAS MISSING
//  ─────────────────────────────────────────────────────────────────
//  Before this file, the app had a connectivity monitor, a persisted
//  outbox, a conflict policy and an offline banner — and none of them were
//  connected to a single read or write. The outbox in particular was never
//  enqueued into by anything, which meant it was a queue that could not
//  receive work: impressive-looking scaffolding around a hole.
//
//  This is the hole. Two rules, applied at the repository boundary:
//
//  READS   Try the network. On failure, serve the persisted cache and mark
//          the result stale. A stale answer the user can see beats a
//          spinner they cannot.
//
//  WRITES  If the network is unavailable, enqueue and report success. The
//          optimistic UI already applied the change; failing here would
//          roll back an edit the user will expect to find when they land.
//
//  ─────────────────────────────────────────────────────────────────
//  WHAT THIS DOES NOT DO
//  ─────────────────────────────────────────────────────────────────
//  It does not queue *reads*. A list requested offline that has never been
//  cached simply fails — replaying reads later would deliver results to a
//  screen the user left twenty minutes ago.
//
//  It does not merge concurrent edits. Queued writes replay in order and
//  are resolved by `ConflictPolicy` on arrival; text does not merge, and
//  pretending otherwise silently loses words.
//

import Foundation
import Observation

// MARK: - Gate

@MainActor
@Observable
final class OfflineGate {

    /// True when a read was served from cache because the network failed.
    /// Drives the "showing saved data" affordance.
    private(set) var isServingStaleData = false
    private(set) var lastSuccessfulFetch: Date?

    private let connectivity: ConnectivityMonitor
    private let cache: OfflineCache
    private let outbox: MutationOutbox

    init(connectivity: ConnectivityMonitor, cache: OfflineCache, outbox: MutationOutbox) {
        self.connectivity = connectivity
        self.cache = cache
        self.outbox = outbox
    }

    var isOnline: Bool { connectivity.isOnline }
    var pendingWrites: Int { outbox.pendingCount }

    // MARK: Reads

    /// Fetches, caching the result; falls back to the cache on failure.
    ///
    /// - Parameter key: cache key. Also the eviction namespace.
    /// - Parameter fetch: the live call.
    func read<Value: Codable & Sendable>(
        key: String,
        lifetime: TimeInterval? = nil,
        forceRefresh: Bool = false,
        fetch: () async throws -> Value
    ) async throws -> CachedRead<Value> {

        let ttl = lifetime ?? OfflineKey.lifetime(for: key)

        // Offline and not forced: go straight to disk. Attempting the network
        // first would cost a timeout — several seconds of spinner before the
        // same cached answer.
        if !connectivity.isOnline, !forceRefresh {
            if let envelope: CachedEnvelope<Value> = await cache.entry(for: key) {
                isServingStaleData = true
                return .stale(envelope.value, from: envelope.storedAt)
            }
            throw AppError.network
        }

        do {
            let value = try await fetch()
            await cache.store(value, for: key, lifetime: ttl)
            isServingStaleData = false
            lastSuccessfulFetch = Date()
            return .live(value)
        } catch {
            let mapped = AppError.from(error)

            // Only a *transport* failure falls back. A validation error or an
            // RLS denial means the request was wrong, and answering it from
            // cache would hide a real bug behind plausible-looking data.
            guard mapped == .network || mapped == .unknown,
                  let envelope: CachedEnvelope<Value> = await cache.entry(for: key)
            else {
                throw mapped
            }

            isServingStaleData = true
            return .stale(envelope.value, from: envelope.storedAt)
        }
    }

    /// Cache-only read, for a cold launch that needs something on screen
    /// before the first request returns.
    func cached<Value: Codable & Sendable>(
        key: String,
        as type: Value.Type = Value.self
    ) async -> CachedRead<Value>? {
        guard let envelope: CachedEnvelope<Value> = await cache.entry(for: key) else { return nil }
        return envelope.isFresh()
            ? .live(envelope.value)
            : .stale(envelope.value, from: envelope.storedAt)
    }

    // MARK: Writes

    /// Runs a mutation, or queues it if there is no network.
    ///
    /// - Parameter describe: how to record it for replay. Nil means the
    ///   operation cannot be queued — it must fail when offline. Uploads are
    ///   the obvious case: the file bytes are not something to hold in a
    ///   JSON queue.
    /// - Returns: `.applied` when it reached the server, `.queued` when it
    ///   was recorded for later. Both are successes from the UI's point of
    ///   view; the difference drives the pending badge.
    @discardableResult
    func write(
        invalidating prefixes: [String] = [],
        describe: (() -> OutboxEntry)? = nil,
        perform: () async throws -> Void
    ) async -> OfflineWriteOutcome {

        if !connectivity.isOnline {
            guard let describe else { return .failed(.network) }
            outbox.enqueue(describe())
            await invalidate(prefixes)
            return .queued
        }

        do {
            try await perform()
            await invalidate(prefixes)
            return .applied
        } catch {
            let mapped = AppError.from(error)

            // The network dropped mid-request. The write may or may not have
            // landed — which is exactly why every queued entry carries an
            // idempotency key, so replaying a request that already succeeded
            // is harmless.
            if mapped == .network, let describe {
                outbox.enqueue(describe())
                await invalidate(prefixes)
                return .queued
            }
            return .failed(mapped)
        }
    }

    private func invalidate(_ prefixes: [String]) async {
        for prefix in prefixes {
            await cache.invalidate(prefix: prefix)
        }
    }

    // MARK: Housekeeping

    /// Called on sign-out. Cached rows belong to the account that fetched
    /// them, and leaving them for the next user is a data leak, not a
    /// performance win.
    func clearForSignOut() async {
        await cache.removeAll()
        outbox.purge()
        isServingStaleData = false
        lastSuccessfulFetch = nil
    }
}

// MARK: - Outcome

enum OfflineWriteOutcome: Sendable, Equatable {
    /// Reached the server.
    case applied
    /// Recorded for replay. The UI already shows it.
    case queued
    case failed(AppError)

    /// Queued counts as success: the user's intent is recorded and will
    /// land. Treating it as failure would roll back an edit they can see.
    var isSuccess: Bool { !isFailure }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    var error: AppError? {
        if case .failed(let error) = self { return error }
        return nil
    }

    /// Bridges to the mutation spine so a queued write still produces a
    /// toast and an undo token like any other.
    func asMutationOutcome(undo: UndoToken? = nil) -> MutationOutcome {
        switch self {
        case .applied, .queued: .succeeded(undo: undo)
        case .failed(let error): .failed(error)
        }
    }

    /// What the toast should say. A queued write must not claim to be saved
    /// — the user needs to know it is waiting, or they will close the app
    /// believing it is done.
    func message(applied: String, queued: String) -> String {
        switch self {
        case .applied: applied
        case .queued:  queued
        case .failed(let error): error.errorDescription ?? "Couldn't save."
        }
    }
}

// MARK: - Entry Builders

/// Typed constructors for the outbox, so a caller cannot mis-spell a topic
/// or forget the payload.
extension OutboxEntry {

    static func propertyUpdate(id: String, draft: PropertyDraft, summary: String) -> OutboxEntry {
        OutboxEntry(
            topic: .properties,
            operation: .update,
            recordID: id,
            payload: (try? AICoding.encoder.encode(PropertyDraftPayload(draft))) ?? Data(),
            summary: summary
        )
    }

    static func propertyCreate(draft: PropertyDraft, summary: String) -> OutboxEntry {
        OutboxEntry(
            topic: .properties,
            operation: .create,
            recordID: nil,
            payload: (try? AICoding.encoder.encode(PropertyDraftPayload(draft))) ?? Data(),
            summary: summary
        )
    }

    static func propertyArchive(id: String, summary: String) -> OutboxEntry {
        OutboxEntry(topic: .properties, operation: .archive, recordID: id,
                    payload: Data(), summary: summary)
    }

    static func propertyRestore(id: String, summary: String) -> OutboxEntry {
        OutboxEntry(topic: .properties, operation: .restore, recordID: id,
                    payload: Data(), summary: summary)
    }

    static func propertyDelete(id: String, summary: String) -> OutboxEntry {
        OutboxEntry(topic: .properties, operation: .delete, recordID: id,
                    payload: Data(), summary: summary)
    }
}

/// Wire shape for a queued property write.
///
/// Separate from `PropertyDraft` because a queue entry must survive an app
/// update: this struct's job is to stay stable, while the draft is free to
/// gain fields the UI needs.
private struct PropertyDraftPayload: Codable, Sendable {
    let name: String
    let kind: String
    let addressLine1: String
    let addressCity: String
    let addressPostalCode: String
    let neighborhood: String?
    let yearBuilt: Int?
    let squareFeet: Int?

    init(_ draft: PropertyDraft) {
        self.name = draft.name
        self.kind = draft.kind.dbValue
        self.addressLine1 = draft.addressLine1
        self.addressCity = draft.city
        self.addressPostalCode = draft.postalCode
        self.neighborhood = draft.neighborhood
        self.yearBuilt = draft.yearBuilt
        self.squareFeet = draft.squareFeet
    }

    enum CodingKeys: String, CodingKey {
        case name, kind, neighborhood
        case addressLine1      = "address_line1"
        case addressCity       = "address_city"
        case addressPostalCode = "address_postal_code"
        case yearBuilt         = "year_built"
        case squareFeet        = "square_feet"
    }
}
