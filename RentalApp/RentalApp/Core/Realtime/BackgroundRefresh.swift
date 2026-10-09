//
//  BackgroundRefresh.swift
//  RentalApp (RentOS)
//
//  Core/Realtime — Staying current while suspended.
//
//  iOS suspends the WebSocket the moment the app backgrounds, so realtime
//  covers the foreground only. A background refresh task closes the gap
//  cheaply: it runs the same delta resync the engine runs on reconnect, so
//  when the user reopens the app the first frame is already current instead
//  of showing yesterday's numbers while a spinner catches up.
//
//  Two constraints shape this:
//
//  • The system decides when. `earliestBeginDate` is a request, not a
//    schedule — anything that *must* arrive (an emergency ticket) needs a
//    push notification, not this.
//  • The budget is seconds. So the task resyncs and reschedules, and does
//    nothing speculative. An expiration handler is mandatory: a task killed
//    without one counts against future scheduling.
//

import Foundation
import BackgroundTasks
import Observation

@MainActor
@Observable
final class BackgroundRefreshCoordinator {

    /// Must match the `BGTaskSchedulerPermittedIdentifiers` entry in
    /// Info.plist, or `register` traps at launch.
    static let taskIdentifier = "ca.rentos.sync.refresh"

    /// Separate identifier for draining the outbox.
    ///
    /// A `BGProcessingTask`, not an app-refresh task: refresh windows are
    /// seconds, and a queue of a dozen writes on a slow connection needs
    /// minutes. Processing tasks also let us require network, which an
    /// upload queue obviously does.
    static let drainTaskIdentifier = "ca.rentos.sync.drain"

    private(set) var lastBackgroundRefresh: Date?

    private weak var engine: SyncEngine?
    private weak var outbox: MutationOutbox?
    private let persistence: PersistenceServiceProtocol
    private static let lastRunKey = "rentos.background.lastRun.v1"

    init(persistence: PersistenceServiceProtocol) {
        self.persistence = persistence
        if let data = persistence.data(forKey: Self.lastRunKey),
           let seconds = try? JSONDecoder().decode(Double.self, from: data) {
            lastBackgroundRefresh = Date(timeIntervalSince1970: seconds)
        }
    }

    /// Called once, at launch, before the scene appears.
    ///
    /// Registration after launch is ignored by the system, which is why this
    /// takes the engine rather than being created with it — the engine is
    /// built later in the graph.
    func register(engine: SyncEngine, outbox: MutationOutbox? = nil) {
        self.engine = engine
        self.outbox = outbox

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in
                await self?.handle(refreshTask)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.drainTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in
                await self?.handleDrain(processingTask)
            }
        }
    }

    /// Requests a background drain. Called when a write is queued, so the
    /// system knows there is work waiting even if the user never reopens
    /// the app.
    func scheduleDrainIfNeeded() {
        guard outbox?.hasPending == true else { return }

        let request = BGProcessingTaskRequest(identifier: Self.drainTaskIdentifier)
        request.requiresNetworkConnectivity = true
        // Not power-constrained: a handful of small writes is cheap, and
        // requiring a charger would strand the queue overnight for anyone
        // who does not plug in.
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)

        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleDrain(_ task: BGProcessingTask) async {
        let work = Task { @MainActor [weak self] in
            await self?.outbox?.drain()
        }

        task.expirationHandler = { work.cancel() }
        _ = await work.result

        // Reschedule while anything is still queued — a partially drained
        // queue is the normal outcome on a slow connection.
        if outbox?.hasPending == true {
            scheduleDrainIfNeeded()
        }
        task.setTaskCompleted(success: !work.isCancelled)
    }

    /// Ask for another run. Called after each completion and on background.
    func schedule(after interval: TimeInterval = 15 * 60) {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Simulator and low-power mode both refuse this. Not worth
            // surfacing — the foreground path still works.
        }
    }

    private func handle(_ task: BGAppRefreshTask) async {
        // Reschedule first. If the resync overruns and the task is killed,
        // a request is already queued for next time.
        schedule()

        let work = Task { @MainActor [weak self] in
            await self?.engine?.resyncAll(reason: "background")
            self?.recordRun()
        }

        task.expirationHandler = {
            work.cancel()
        }

        _ = await work.result
        task.setTaskCompleted(success: !work.isCancelled)
    }

    private func recordRun() {
        lastBackgroundRefresh = Date()
        persistence.set(
            try? JSONEncoder().encode(Date().timeIntervalSince1970),
            forKey: Self.lastRunKey
        )
    }
}
