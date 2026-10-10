//
//  SupabaseRealtimeClient.swift
//  RentalApp (Purrperty)
//
//  Supabase — Realtime transport over `postgres_changes`.
//
//  RLS applies to the stream, so a subscriber receives exactly the rows it
//  could have SELECTed. Realtime therefore inherits the authorization model
//  in `03_rls.sql` rather than needing one of its own — and any table
//  without a SELECT policy streams nothing, silently, which is the failure
//  mode to watch for when adding a topic.
//

import Foundation
import Supabase
import Realtime

final class SupabaseRealtimeClient: RealtimeClientProtocol, @unchecked Sendable {

    /// Regenerated per launch. Per-launch rather than per-install because
    /// the point is to recognise echoes of writes *this process* made — a
    /// token that survived a relaunch would suppress events the previous
    /// session caused, which this session still needs to apply.
    let originToken = UUID().uuidString

    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?

    init(client: SupabaseClient) {
        self.client = client
    }

    func subscribe(topics: Set<RealtimeTopic>) async throws -> AsyncStream<RealtimeChange> {
        await disconnect()

        // One channel for all topics. Supabase bills and rate-limits per
        // channel, and ten channels would also mean ten independent
        // reconnects for the engine to coordinate.
        let channel = client.realtimeV2.channel("rentos:sync")
        self.channel = channel

        // Build the listeners before subscribing — postgres_changes bindings
        // must exist at join time or the server never sends them.
        var streams: [AsyncStream<AnyAction>] = []
        for topic in topics {
            streams.append(
                channel.postgresChange(AnyAction.self, schema: "public", table: topic.table)
            )
        }

        // `subscribeWithError` throws — that is the whole difference between
        // it and `subscribe()`. Letting it propagate is correct here:
        // `subscribe(topics:)` is already `throws`, and `SyncEngine.pump`
        // treats a thrown subscribe as a dropped connection and retries with
        // backoff. Swallowing it would leave the engine believing it is
        // connected to a channel that never came up.
        try await channel.subscribeWithError()

        let (stream, continuation) = AsyncStream<RealtimeChange>.makeStream()

        // Fan the per-table streams into one, and finish the merged stream
        // when the channel closes so `SyncEngine.pump` sees the drop and
        // reconnects.
        let merge = Task { [originToken] in
            await withTaskGroup(of: Void.self) { group in
                for (index, actionStream) in streams.enumerated() {
                    let topic = Array(topics)[index]
                    group.addTask {
                        for await action in actionStream {
                            if let change = Self.map(action, topic: topic, localOrigin: originToken) {
                                continuation.yield(change)
                            }
                        }
                    }
                }
                await group.waitForAll()
            }
            continuation.finish()
        }

        continuation.onTermination = { _ in
            merge.cancel()
        }

        return stream
    }

    func disconnect() async {
        guard let channel else { return }
        await channel.unsubscribe()
        self.channel = nil
    }

    // MARK: Mapping

    private static func map(
        _ action: AnyAction,
        topic: RealtimeTopic,
        localOrigin: String
    ) -> RealtimeChange? {

        switch action {
        case .insert(let payload):
            return make(topic: topic, kind: .insert, record: payload.record)
        case .update(let payload):
            return make(topic: topic, kind: .update, record: payload.record)
        case .delete(let payload):
            // REPLICA IDENTITY FULL means the old row is present, so a delete
            // carries enough to know which list to remove it from.
            return make(topic: topic, kind: .delete, record: payload.oldRecord)
        default:
            return nil
        }
    }

    private static func make(
        topic: RealtimeTopic,
        kind: RealtimeChangeKind,
        record: [String: AnyJSON]
    ) -> RealtimeChange? {

        guard let id = record["id"]?.stringValue else { return nil }

        // `updated_at` is the ordering key. A row without one cannot be
        // ordered against anything, so it is dropped rather than applied at
        // an arbitrary position.
        guard let updatedRaw = record["updated_at"]?.stringValue,
              let updatedAt = Self.parseTimestamp(updatedRaw) else { return nil }

        let payload = try? JSONSerialization.data(
            withJSONObject: record.mapValues(Self.plainValue)
        )

        return RealtimeChange(
            topic: topic,
            kind: kind,
            recordID: id,
            payload: payload,
            cursor: updatedAt,
            originToken: record["origin_token"]?.stringValue
        )
    }

    /// Unwraps `AnyJSON` into Foundation types so the payload can be
    /// re-encoded and handed to a normal `Decodable`.
    private static func plainValue(_ json: AnyJSON) -> Any {
        switch json {
        case .string(let value): value
        case .integer(let value): value
        case .double(let value): value
        case .bool(let value): value
        case .object(let value): value.mapValues(plainValue)
        case .array(let value): value.map(plainValue)
        case .null: NSNull()
        }
    }

    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Postgres emits `timestamptz` over the wire without a `T` separator
    /// and with a variable number of fractional digits, so the stock
    /// ISO-8601 parser rejects it outright.
    private static func parseTimestamp(_ raw: String) -> Date? {
        let normalised = raw.replacingOccurrences(of: " ", with: "T")
        if let date = fractional.date(from: normalised) { return date }
        if let date = plain.date(from: normalised) { return date }
        // Bare `+00` offsets need padding to `+00:00`.
        if normalised.hasSuffix("+00") {
            let padded = normalised + ":00"
            return fractional.date(from: padded) ?? plain.date(from: padded)
        }
        return nil
    }
}

// MARK: - Offline Client

/// Used by the in-memory graph and previews.
///
/// Returns a stream that never emits and never finishes, so `SyncEngine`
/// reports `.connected` and simply never receives anything — previews get a
/// healthy-looking app with no socket.
final class InertRealtimeClient: RealtimeClientProtocol, @unchecked Sendable {

    let originToken = "preview"

    func subscribe(topics: Set<RealtimeTopic>) async throws -> AsyncStream<RealtimeChange> {
        AsyncStream { _ in }
    }

    func disconnect() async {}
}
