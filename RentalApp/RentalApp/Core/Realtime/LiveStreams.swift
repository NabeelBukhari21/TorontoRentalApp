//
//  LiveStreams.swift
//  RentalApp (RentOS)
//
//  Core/Realtime — Turning a topic into a live view.
//
//  The engine is generic; this file is where each of the seven live
//  surfaces attaches. Registration is intentionally tiny — a topic, a
//  decoder, and what to do with the row — because that is the part a new
//  feature has to write, and anything harder means people won't bother.
//
//  Handlers must be idempotent. The resync window overlaps the live stream
//  on purpose (an inclusive cursor is the only safe kind), so a change can
//  legitimately arrive twice. `AsyncListModel.upsert` and `remove(id:)` are
//  both idempotent, which is why they are the recommended primitives.
//

import SwiftUI

// MARK: - Live List Binding

/// Attaches a topic to an `AsyncListModel`, so a list updates itself.
///
/// The decode closure is supplied by the caller because only it knows how a
/// row maps to the presentation model — the same DTO→model boundary the
/// repositories own.
@MainActor
enum LiveList {

    /// Standard behaviour for a list of records: upsert on insert/update,
    /// remove on delete or soft-delete.
    static func subscription<Element: Identifiable & Sendable>(
        topic: RealtimeTopic,
        list: AsyncListModel<Element>,
        decode: @escaping @Sendable (Data) -> Element?,
        onChanged: @escaping @MainActor () -> Void = {}
    ) -> RealtimeSubscription where Element.ID == String {

        RealtimeSubscription(topic: topic) { changes in
            var didChange = false

            for change in changes {
                switch change.kind {
                case .delete:
                    list.remove(id: change.recordID)
                    didChange = true

                case .insert, .update:
                    guard let payload = change.payload else { continue }

                    // A soft delete arrives as an UPDATE setting deleted_at.
                    // Treating it as an upsert would resurrect an archived
                    // row in the middle of the list.
                    if Self.isSoftDeleted(payload) {
                        list.remove(id: change.recordID)
                        didChange = true
                        continue
                    }

                    guard let element = decode(payload) else { continue }
                    list.upsert(element)
                    didChange = true
                }
            }

            if didChange { onChanged() }
        }
    }

    /// Coarser binding for screens that recompute wholesale — the dashboard,
    /// or a detail screen whose derived figures cannot be patched from one
    /// row. Reloading once per coalesced batch is cheaper than being clever.
    static func reloadSubscription(
        topic: RealtimeTopic,
        reload: @escaping @MainActor () async -> Void
    ) -> RealtimeSubscription {
        RealtimeSubscription(topic: topic) { _ in
            await reload()
        }
    }

    private static func isSoftDeleted(_ payload: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
        else { return false }
        guard let value = object["deleted_at"] else { return false }
        return !(value is NSNull)
    }
}

// MARK: - Resync Source

/// Supplies the delta fetch the engine runs after a disconnect.
///
/// A protocol rather than a closure because it needs one method per topic's
/// table and a single closure would end up as a `switch` in the container.
protocol ResyncSource: Sendable {
    /// Rows in `topic` changed strictly after `since`, oldest first.
    /// Nil `since` means "the client has no cursor" — return a bounded
    /// recent window, not the entire table.
    func changes(for topic: RealtimeTopic, since: Date?) async -> [RealtimeChange]
}

/// Resync over PostgREST.
///
/// This is the piece that makes offline→online honest. It asks each table
/// for everything newer than the cursor, capped so a month-old cursor
/// cannot pull a hundred thousand rows onto a phone — past the cap the
/// client is better off dropping its cursor and refetching normally.
struct PostgRESTResyncSource: ResyncSource {

    private let fetch: @Sendable (String, Date?, Int) async -> [(id: String, updatedAt: Date, row: Data, origin: String?)]
    private let pageLimit: Int

    init(
        pageLimit: Int = 500,
        fetch: @escaping @Sendable (String, Date?, Int) async -> [(id: String, updatedAt: Date, row: Data, origin: String?)]
    ) {
        self.pageLimit = pageLimit
        self.fetch = fetch
    }

    func changes(for topic: RealtimeTopic, since: Date?) async -> [RealtimeChange] {
        let rows = await fetch(topic.table, since, pageLimit)
        return rows.map { row in
            RealtimeChange(
                topic: topic,
                // Everything from a resync is an upsert. Distinguishing
                // insert from update would need the previous state, and the
                // handlers are idempotent precisely so it doesn't matter.
                kind: .update,
                recordID: row.id,
                payload: row.row,
                cursor: row.updatedAt,
                originToken: row.origin
            )
        }
    }
}

/// Used by the in-memory graph: nothing changed while "offline", because
/// there is no server to have changed.
struct EmptyResyncSource: ResyncSource {
    func changes(for topic: RealtimeTopic, since: Date?) async -> [RealtimeChange] { [] }
}

// MARK: - Registration Helper

/// Registers a subscription for the lifetime of a view.
///
/// A `.task` that registers on appear and unregisters on disappear leaks
/// nothing and, importantly, stops a backgrounded screen from patching state
/// nobody is looking at.
extension View {
    func liveUpdates(
        _ engine: SyncEngine,
        _ subscription: @escaping @MainActor () -> RealtimeSubscription
    ) -> some View {
        modifier(LiveUpdatesModifier(engine: engine, makeSubscription: subscription))
    }
}

private struct LiveUpdatesModifier: ViewModifier {

    let engine: SyncEngine
    let makeSubscription: @MainActor () -> RealtimeSubscription

    @State private var token: UUID?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard token == nil else { return }
                token = engine.register(makeSubscription())
                engine.start()
            }
            .onDisappear {
                if let token { engine.unregister(token) }
                token = nil
            }
    }
}

// MARK: - The Seven Surfaces
//
// Documented in one place so it is obvious what is live and how. Each entry
// is the topic a feature registers plus the primitive it uses.
//
//   1. Live notifications      .notifications        → upsert + badge recount
//   2. Live maintenance        .maintenanceRequests  → upsert into the inbox
//                              .maintenanceUpdates   → reload the open ticket
//   3. Live messaging          .messages             → append to the thread
//                              .conversations        → reorder the list
//   4. Live dashboard metrics  dashboardInputs       → cache invalidate + reload
//   5. Live property updates   .properties, .units   → upsert into the list
//   6. Live tenant updates     .tenants, .leases     → upsert + summary recount
//   7. Live document uploads   .documents            → upsert into the grid
//
// Latency budget, end to end, on a good network:
//   optimistic paint      ~0ms      (local, already the case)
//   Postgres → socket     ~50-150ms
//   coalesce window       40-300ms  (per topic, see RealtimeTopic)
//   apply + render        ~16ms
// So a message lands in well under a quarter second, and a portfolio figure
// inside half a second — while a bulk change still costs one render, not
// twelve.

enum LiveSurface: String, CaseIterable {
    case notifications
    case maintenance
    case messaging
    case dashboard
    case properties
    case tenants
    case documents

    var topics: Set<RealtimeTopic> {
        switch self {
        case .notifications: [.notifications]
        case .maintenance:   [.maintenanceRequests, .maintenanceUpdates]
        case .messaging:     [.messages, .conversations]
        case .dashboard:     RealtimeTopic.dashboardInputs
        case .properties:    [.properties, .units]
        case .tenants:       [.tenants, .leases]
        case .documents:     [.documents]
        }
    }
}
