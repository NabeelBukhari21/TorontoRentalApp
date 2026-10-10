//
//  BufferedAnalyticsSink.swift
//  RentalApp (Purrperty)
//
//  Core/Analytics — Batching, backpressure, and the network sink.
//
//  ─────────────────────────────────────────────────────────────────
//  ANALYTICS MUST NEVER COST THE USER ANYTHING
//  ─────────────────────────────────────────────────────────────────
//  One request per event is the naive implementation and it is wrong
//  on every axis that matters: it wakes the radio constantly (battery),
//  it competes with requests the user is actually waiting on, and on a
//  bad connection it produces a queue that never drains.
//
//  So events batch, flush on a timer or when the batch fills, and are
//  dropped rather than retried indefinitely. That last point is the one
//  people get wrong: analytics is *not* the outbox. A user's edit must
//  survive; a screen-view event must not survive at the cost of
//  unbounded disk growth. When the buffer is full the oldest events go.
//
//  ─────────────────────────────────────────────────────────────────
//  IN-MEMORY ONLY, DELIBERATELY
//  ─────────────────────────────────────────────────────────────────
//  Persisting analytics across launches means writing behavioural data
//  to disk, where it outlives the consent that permitted it and has to
//  be found and deleted on revocation. Losing the last few events of a
//  session that ended in a force-quit is a much smaller cost than that.
//  Crash *reports* are different and do persist — see `CrashReporter`.
//

import Foundation
import OSLog

// MARK: - Transport

/// Where a batch of events goes. Separated from the buffering policy so
/// the batching logic is testable without a network, and so swapping
/// Supabase for a vendor endpoint later touches one small type.
protocol AnalyticsTransport: Sendable {
    func send(_ batch: [AnalyticsEnvelope]) async throws
}

// MARK: - Buffered Sink

actor BufferedAnalyticsSink: AnalyticsSink {

    nonisolated let identifier = "buffered"

    private let transport: AnalyticsTransport
    private let batchSize: Int
    private let maxBuffered: Int
    private let flushInterval: Duration

    private var buffer: [AnalyticsEnvelope] = []
    private var flushTask: Task<Void, Never>?
    private var isFlushing = false

    init(
        transport: AnalyticsTransport,
        batchSize: Int = 20,
        maxBuffered: Int = 200,
        flushInterval: Duration = .seconds(30)
    ) {
        self.transport = transport
        self.batchSize = batchSize
        self.maxBuffered = maxBuffered
        self.flushInterval = flushInterval
    }

    // MARK: Sink

    func record(_ envelope: AnalyticsEnvelope) async {
        buffer.append(envelope)

        // Drop oldest. Newer events are more likely to describe the
        // thing currently going wrong, so they are the ones to keep.
        if buffer.count > maxBuffered {
            let overflow = buffer.count - maxBuffered
            buffer.removeFirst(overflow)
            AppLog.logger(.app).debug(
                "analytics buffer overflow, dropped \(overflow, privacy: .public)"
            )
        }

        if buffer.count >= batchSize {
            await flush()
        } else {
            scheduleFlush()
        }
    }

    func identify(userID: String?) async {
        // Identity rides on each envelope; nothing separate to send.
        // Flush first so events already buffered keep the identity they
        // were recorded under rather than retroactively gaining a new one.
        await flush()
    }

    func purge() async {
        flushTask?.cancel()
        flushTask = nil
        let dropped = buffer.count
        buffer.removeAll()
        if dropped > 0 {
            AppLog.privacy.notice("analytics buffer purged (\(dropped, privacy: .public) events)")
        }
    }

    // MARK: Flushing

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [flushInterval] in
            try? await Task.sleep(for: flushInterval)
            guard !Task.isCancelled else { return }
            await self.flush()
        }
    }

    /// Sends one batch. Failures drop the batch rather than retrying.
    ///
    /// Retrying analytics is how a buffer becomes unbounded: the network
    /// is down, every flush fails, and events keep arriving. The data is
    /// aggregate and approximate by nature — a lost batch changes a
    /// number slightly, an unbounded buffer takes the app down.
    func flush() async {
        flushTask?.cancel()
        flushTask = nil

        guard !isFlushing, !buffer.isEmpty else { return }
        isFlushing = true
        defer { isFlushing = false }

        let batch = Array(buffer.prefix(batchSize))
        buffer.removeFirst(batch.count)

        do {
            try await transport.send(batch)
        } catch {
            AppLog.logger(.app).failure("Analytics batch dropped", error: error)
        }

        // More waiting and the last attempt worked — keep going.
        if !buffer.isEmpty {
            scheduleFlush()
        }
    }
}
