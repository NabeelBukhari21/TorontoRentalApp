//
//  SupabaseSyncSupport.swift
//  RentalApp (Purrperty)
//
//  Supabase — Gap resync and outbox replay.
//

import Foundation
import Supabase

// MARK: - Resync Source

/// Delta fetch over PostgREST: "everything in this table newer than X".
///
/// RLS scopes the query, so this cannot pull another organization's rows even
/// though it never mentions `organization_id`.
struct SupabaseResyncSource: ResyncSource {

    private let client: SupabaseClient
    private let pageLimit: Int

    init(client: SupabaseClient, pageLimit: Int = 500) {
        self.client = client
        self.pageLimit = pageLimit
    }

    func changes(for topic: RealtimeTopic, since: Date?) async -> [RealtimeChange] {
        do {
            var query = client.from(topic.table).select()

            if let since {
                // `gt`, not `gte`: the cursor is the newest row already
                // applied, so re-fetching it wastes a row on every resync.
                // The handlers are idempotent regardless, but this keeps the
                // payload honest.
                query = query.gt("updated_at", value: SupabaseCoding.timestampString(since))
            } else {
                // No cursor means a cold start. Take a bounded recent window
                // rather than the whole table — the normal paged load fills in
                // the rest, and a fresh install must not download a year of
                // history to render one screen.
                let window = Date().addingTimeInterval(-60 * 60 * 24 * 7)
                query = query.gt("updated_at", value: SupabaseCoding.timestampString(window))
            }

            let response = try await query
                .order("updated_at", ascending: true)
                .limit(pageLimit)
                .execute()

            guard let rows = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]]
            else { return [] }

            return rows.compactMap { row in
                guard let id = Self.stringID(row["id"]),
                      let updatedRaw = row["updated_at"] as? String,
                      let updatedAt = SupabaseCoding.parseTimestamp(updatedRaw),
                      let payload = try? JSONSerialization.data(withJSONObject: row)
                else { return nil }

                return RealtimeChange(
                    topic: topic,
                    kind: .update,
                    recordID: id,
                    payload: payload,
                    cursor: updatedAt,
                    originToken: row["origin_token"] as? String
                )
            }
        } catch {
            // A failed resync is not fatal: the engine retries on the next
            // reconnect, and the banner already says live updates are
            // degraded. Throwing here would take down the whole pump.
            return []
        }
    }

    private static func stringID(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let uuid = value as? UUID { return uuid.uuidString }
        return nil
    }
}

// MARK: - Outbox Executor

/// Replays a queued mutation.
///
/// The entry's `id` doubles as an idempotency key — sent as `origin_token`,
/// so a replay whose original response was lost is recognisable rather than
/// duplicated.
struct SupabaseOutboxExecutor: OutboxExecuting {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func execute(_ entry: OutboxEntry) async -> OutboxResult {
        do {
            switch entry.operation {
            case .create:
                _ = try await client.from(entry.topic)
                    .insert(RawJSONBody(entry.payload, originToken: entry.id.uuidString))
                    .execute()

            case .update, .action:
                guard let recordID = entry.recordID else { return .rejected(.unknown) }
                _ = try await client.from(entry.topic)
                    .update(RawJSONBody(entry.payload, originToken: entry.id.uuidString))
                    .eq("id", value: recordID)
                    .execute()

            case .archive, .restore, .delete:
                guard let recordID = entry.recordID else { return .rejected(.unknown) }
                let function: String
                switch entry.operation {
                case .archive: function = "archive_property"
                case .restore: function = "restore_property"
                default:       function = "delete_property"
                }
                _ = try await client
                    .rpc(function, params: ["p_property_id": recordID])
                    .execute()
            }
            return .applied

        } catch {
            let mapped = SupabaseErrorMapper.map(error)
            switch mapped {
            case .network:
                // Still offline, or timed out. Keep the entry.
                return .retryLater
            case .unauthorized, .invalidCredentials:
                // The session died while this sat queued. Retrying with the
                // same dead token fails identically, so hold it until the next
                // drain — which only happens after a successful reconnect.
                return .retryLater
            default:
                // Validation, RLS denial, missing FK. Retrying cannot fix
                // these, and retrying forever hides a real problem.
                return .rejected(mapped)
            }
        }
    }
}

/// Wraps an already-encoded JSON body and injects the origin token.
///
/// The payload was encoded when the mutation was made, possibly by an older
/// app version. Re-encoding it through a typed struct would risk dropping a
/// field that version knew about — so it is passed through and only added to.
private struct RawJSONBody: Encodable {

    private let object: [String: AnyCodableJSON]

    init(_ data: Data, originToken: String) {
        var decoded = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        decoded["origin_token"] = originToken
        self.object = decoded.mapValues(AnyCodableJSON.init)
    }

    func encode(to encoder: any Encoder) throws {
        try object.encode(to: encoder)
    }
}

// MARK: - Timestamp helpers

extension SupabaseCoding {

    /// PostgREST wants an ISO-8601 timestamp as a filter value.
    static func timestampString(_ date: Date) -> String {
        syncTimestampFormatter.string(from: date)
    }

    /// Parses what Postgres actually sends, which is not always what
    /// `ISO8601DateFormatter` accepts by default.
    static func parseTimestamp(_ raw: String) -> Date? {
        let normalised = raw.replacingOccurrences(of: " ", with: "T")
        if let date = syncTimestampFormatter.date(from: normalised) { return date }
        if let date = syncPlainFormatter.date(from: normalised) { return date }
        // Postgres emits bare `+00` offsets, which need padding to `+00:00`.
        if normalised.hasSuffix("+00") {
            let padded = normalised + ":00"
            return syncTimestampFormatter.date(from: padded) ?? syncPlainFormatter.date(from: padded)
        }
        return nil
    }

    nonisolated(unsafe) private static let syncTimestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let syncPlainFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
