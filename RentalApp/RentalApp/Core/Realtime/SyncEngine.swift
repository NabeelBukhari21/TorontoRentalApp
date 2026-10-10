//
//  SyncEngine.swift
//  RentalApp (Purrperty)
//
//  Core/Realtime — The coordinator.
//
//  One object owns the connection lifecycle and the correctness rules, so
//  no feature has to get them right individually:
//
//    connect → subscribe → coalesce → suppress echo → reject stale →
//    dispatch to subscribers → on drop: backoff → on reconnect: resync gap
//
//  Features register a `RealtimeSubscription` per topic and receive
//  already-filtered batches. A screen never sees its own echo, never sees
//  an out-of-order row, and never sees twelve events where one will do.
//

import SwiftUI
import Observation

// MARK: - Subscription

/// A feature's interest in a topic.
///
/// `apply` receives a coalesced batch rather than single changes, because
/// the whole point of the debounce is that the handler runs once for a
/// burst. Handlers must be idempotent — after a reconnect resync, a change
/// already applied can arrive again, and re-applying it must be harmless.
struct RealtimeSubscription: Identifiable, Sendable {

    let id = UUID()
    let topic: RealtimeTopic
    /// Applies a batch. Runs on the main actor: it is patching view state.
    let apply: @MainActor @Sendable ([RealtimeChange]) async -> Void

    init(
        topic: RealtimeTopic,
        apply: @escaping @MainActor @Sendable ([RealtimeChange]) async -> Void
    ) {
        self.topic = topic
        self.apply = apply
    }
}

// MARK: - Engine

@MainActor
@Observable
final class SyncEngine {

    // MARK: Observable state

    private(set) var state: RealtimeConnectionState = .idle
    /// Last time a change was successfully applied. Drives "Updated just
    /// now" affordances.
    private(set) var lastSyncedAt: Date?
    /// Counts events dropped as echoes or stale, for the diagnostics panel.
    private(set) var suppressedEchoes = 0
    private(set) var rejectedStale = 0

    // MARK: Dependencies

    private let client: RealtimeClientProtocol
    private let connectivity: ConnectivityMonitor
    private let cache: RepositoryCache
    private let outbox: MutationOutbox
    /// Delta fetch per topic, used to close the gap after a disconnect.
    /// Supplied by the container so the engine never touches a repository.
    private let resync: @MainActor (RealtimeTopic, Date?) async -> [RealtimeChange]

    private let backoff = RealtimeBackoff()
    private let persistence: PersistenceServiceProtocol

    // MARK: Internal state

    private var subscriptions: [UUID: RealtimeSubscription] = [:]
    private var cursor = SyncCursor()
    /// Per-record last-applied cursor, for stale rejection at row grain.
    /// Topic-level marks are too coarse: two rows in the same table move
    /// independently.
    private var appliedCursors: [String: Date] = [:]
    /// Pending batches awaiting their coalesce window.
    private var pending: [RealtimeTopic: [RealtimeChange]] = [:]
    private var coalesceTasks: [RealtimeTopic: Task<Void, Never>] = [:]

    private var pumpTask: Task<Void, Never>?
    private var attempt = 0

    private static let cursorKey = "rentos.sync.cursor.v1"

    init(
        client: RealtimeClientProtocol,
        connectivity: ConnectivityMonitor,
        cache: RepositoryCache = .shared,
        outbox: MutationOutbox,
        persistence: PersistenceServiceProtocol,
        resync: @escaping @MainActor (RealtimeTopic, Date?) async -> [RealtimeChange]
    ) {
        self.client = client
        self.connectivity = connectivity
        self.cache = cache
        self.outbox = outbox
        self.persistence = persistence
        self.resync = resync

        loadCursor()

        // Regaining a route is the strongest signal to resync — far better
        // than waiting out a backoff timer that may have minutes left.
        connectivity.onBecameReachable { [weak self] in
            guard let self else { return }
            self.attempt = 0
            self.start()
        }
    }

    // MARK: Registration

    func register(_ subscription: RealtimeSubscription) -> UUID {
        subscriptions[subscription.id] = subscription
        return subscription.id
    }

    func unregister(_ id: UUID) {
        subscriptions.removeValue(forKey: id)
    }

    private var activeTopics: Set<RealtimeTopic> {
        Set(subscriptions.values.map(\.topic))
    }

    // MARK: Lifecycle

    /// Idempotent. Safe to call from `.onAppear`, scene activation, and the
    /// reachability callback without guarding at each site.
    func start() {
        guard pumpTask == nil else { return }
        guard !activeTopics.isEmpty else { return }
        pumpTask = Task { [weak self] in await self?.pump() }
    }

    func stop() {
        pumpTask?.cancel()
        pumpTask = nil
        coalesceTasks.values.forEach { $0.cancel() }
        coalesceTasks.removeAll()
        pending.removeAll()
        Task { await client.disconnect() }
        state = .idle
    }

    /// Called when the app returns to the foreground.
    ///
    /// A socket that survived backgrounding is usually dead anyway — iOS
    /// suspends it — so this force-resyncs rather than trusting the state.
    func applicationDidBecomeActive() {
        attempt = 0
        start()
        Task { await resyncAll(reason: "foreground") }
    }

    func applicationDidEnterBackground() {
        // Hold the cursor so the next launch closes the gap instead of
        // re-fetching everything.
        saveCursor()
        stop()
    }

    // MARK: Connection pump

    /// The reconnect loop. One place, one policy.
    private func pump() async {
        while !Task.isCancelled {
            guard connectivity.isOnline else {
                state = .offline
                // Nothing to back off against without a route; the
                // reachability callback restarts us.
                return
            }

            state = attempt == 0
                ? .connecting
                : .reconnecting(attempt: attempt, nextRetry: Date())

            do {
                let stream = try await client.subscribe(topics: activeTopics)
                attempt = 0
                state = .connected(since: Date())

                // Close the gap *before* draining the outbox, so replayed
                // mutations apply on top of current server state rather
                // than clobbering changes made while we were away.
                await resyncAll(reason: "reconnect")
                await outbox.drain()

                for await change in stream {
                    guard !Task.isCancelled else { break }
                    enqueue(change)
                }

                // The stream finished: the connection dropped.
                guard !Task.isCancelled else { break }
                attempt += 1
            } catch {
                attempt += 1
                if backoff.hasExhausted(attempt) {
                    state = .failed(AppError.from(error).errorDescription ?? "Connection failed")
                    pumpTask = nil
                    return
                }
            }

            let delay = backoff.delay(forAttempt: attempt)
            state = .reconnecting(
                attempt: attempt,
                nextRetry: Date().addingTimeInterval(delay)
            )
            try? await Task.sleep(for: .seconds(delay))
        }
        pumpTask = nil
    }

    /// Manual retry from the banner, skipping the remaining backoff.
    func retryNow() {
        pumpTask?.cancel()
        pumpTask = nil
        attempt = 0
        start()
    }

    // MARK: Filtering and coalescing

    /// Applies the two correctness filters, then batches.
    private func enqueue(_ change: RealtimeChange) {
        // 1 · ECHO. Our own optimistic write already updated the UI. Applying
        //     the echo would re-render at best, and at worst overwrite a
        //     newer local edit the user made in the meantime.
        if change.isEcho(of: client.originToken) {
            suppressedEchoes += 1
            cursor.advance(change.topic, to: change.cursor)
            return
        }

        // 2 · STALE. Compared per record, not per topic: an older version of
        //     row A must be dropped even if row B has since moved the
        //     topic-level mark forward.
        let key = "\(change.topic.rawValue):\(change.recordID)"
        if let applied = appliedCursors[key], change.cursor <= applied {
            rejectedStale += 1
            return
        }
        appliedCursors[key] = change.cursor

        pending[change.topic, default: []].append(change)
        scheduleFlush(change.topic)
    }

    private func scheduleFlush(_ topic: RealtimeTopic) {
        coalesceTasks[topic]?.cancel()
        coalesceTasks[topic] = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: topic.coalesceWindow)
            guard !Task.isCancelled else { return }
            await self.flush(topic)
        }
    }

    private func flush(_ topic: RealtimeTopic) async {
        guard let batch = pending.removeValue(forKey: topic), !batch.isEmpty else { return }
        coalesceTasks.removeValue(forKey: topic)

        // Collapse repeats of the same row within the batch — a row updated
        // three times in 300ms only needs its final state.
        var latest: [String: RealtimeChange] = [:]
        for change in batch {
            let existing = latest[change.recordID]
            if existing == nil || change.cursor > existing!.cursor {
                latest[change.recordID] = change
            }
        }
        let collapsed = latest.values.sorted { $0.cursor < $1.cursor }

        for change in collapsed {
            cursor.advance(topic, to: change.cursor)
        }

        // Derived aggregates are read through the cache, so a row change in
        // any dashboard input has to invalidate it or the home screen keeps
        // showing yesterday's occupancy.
        if RealtimeTopic.dashboardInputs.contains(topic) {
            cache.invalidateAll()
        }

        await dispatch(collapsed, topic: topic)
        lastSyncedAt = Date()
        saveCursor()
    }

    private func dispatch(_ changes: [RealtimeChange], topic: RealtimeTopic) async {
        for subscription in subscriptions.values where subscription.topic == topic {
            await subscription.apply(changes)
        }
    }

    // MARK: Gap resync

    /// Fetches everything that changed while we were not listening.
    ///
    /// This is the piece a naive implementation omits, and its absence is
    /// invisible in testing — you only notice when a user's phone sleeps
    /// through a shift change and the app confidently shows stale data.
    func resyncAll(reason: String) async {
        for topic in activeTopics {
            let changes = await resync(topic, cursor.mark(for: topic))
            guard !changes.isEmpty else { continue }

            // Route through the same filters: the resync window overlaps
            // the live stream by design (the mark is inclusive), so
            // duplicates are expected and must be dropped, not applied.
            for change in changes { enqueue(change) }
            await flush(topic)
        }
        lastSyncedAt = Date()
    }

    /// Drops all cursors, forcing a full refetch. For "something is wrong,
    /// start over" — a sign-out, or an org switch.
    func invalidateAll() {
        cursor.resetAll()
        appliedCursors.removeAll()
        cache.invalidateAll()
        saveCursor()
    }

    // MARK: Cursor persistence

    private func loadCursor() {
        guard let data = persistence.data(forKey: Self.cursorKey),
              let decoded = try? JSONDecoder().decode(SyncCursor.self, from: data) else { return }
        cursor = decoded
    }

    private func saveCursor() {
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        persistence.set(data, forKey: Self.cursorKey)
    }
}

// MARK: - Scene Integration

extension View {

    /// Ties the engine to the app lifecycle.
    ///
    /// Applied once at the root. Without it the socket leaks across
    /// backgrounding and the first foreground shows stale data until
    /// something happens to trigger a refresh.
    func dsRealtimeLifecycle(_ engine: SyncEngine) -> some View {
        modifier(RealtimeLifecycleModifier(engine: engine))
    }
}

private struct RealtimeLifecycleModifier: ViewModifier {

    let engine: SyncEngine
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:     engine.applicationDidBecomeActive()
                case .background: engine.applicationDidEnterBackground()
                case .inactive:   break
                @unknown default: break
                }
            }
    }
}
