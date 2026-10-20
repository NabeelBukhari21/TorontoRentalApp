//
//  VendorPortalViewModel.swift
//  RentalApp (Purrperty)
//
//  Vendor Portal — A contractor's work: jobs sent to them, visits they've
//  booked, and the actions that move a job along. Every action goes
//  through the maintenance repository, so the landlord's inbox and the
//  tenant's portal see the same job change.
//

import SwiftUI
import Observation
import OSLog

@MainActor
@Observable
final class VendorPortalViewModel: VisitScheduling {

    enum Phase: Equatable {
        case loading
        /// Signed in, but no organization has added this vendor yet.
        case notLinked
        case ready
        case failed(String)
    }

    // MARK: Dependencies

    private let portal: VendorPortalRepositoryProtocol
    private let maintenance: MaintenanceRepositoryProtocol
    private let sync: SyncEngine
    let visitTracker: RepairVisitTracker
    let session: AuthSession

    // MARK: State

    private(set) var phase: Phase = .loading
    private(set) var account: VendorAccount?
    private(set) var jobs: [MaintenanceTicket] = []
    private(set) var isWorking = false
    var errorMessage: String?

    init(
        session: AuthSession,
        portal: VendorPortalRepositoryProtocol,
        maintenance: MaintenanceRepositoryProtocol,
        sync: SyncEngine,
        visitTracker: RepairVisitTracker
    ) {
        self.session = session
        self.portal = portal
        self.maintenance = maintenance
        self.sync = sync
        self.visitTracker = visitTracker
    }

    // MARK: Loading

    func load() async {
        do {
            guard let account = try await portal.account(for: session) else {
                phase = .notLinked
                return
            }
            self.account = account
            let query = MaintenanceQuery(
                filter: MaintenanceFilter(vendorID: account.vendorID),
                sort: SortOrder(.createdAt, .descending),
                page: PageRequest(page: 0, size: 200)
            )
            jobs = try await maintenance.tickets(matching: query, forceRefresh: true).items
            phase = .ready
            // Keep any Lock Screen visit in step: rebooked, or done.
            for job in jobs { await visitTracker.jobChanged(job) }
            await visitTracker.refresh()
        } catch is CancellationError {
            // The view went away mid-load; the next appearance tries again.
        } catch {
            AppLog.sync.failure("Vendor portal load failed", error: error)
            if phase != .ready {
                phase = .failed((error as? AppError ?? .unknown).errorDescription ?? "")
            }
        }
    }

    // MARK: Derived

    var firstName: String {
        let name = account?.contactName ?? session.fullName
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Sent to this vendor, waiting for them to accept or decline.
    var newJobs: [MaintenanceTicket] {
        jobs.filter { $0.status == .new }.sorted { $0.priority < $1.priority }
    }

    /// Booked visits, soonest first.
    var bookedJobs: [MaintenanceTicket] {
        jobs.filter { $0.status == .scheduled }
            .sorted { ($0.scheduledVisit ?? .distantFuture) < ($1.scheduledVisit ?? .distantFuture) }
    }

    /// Accepted, no visit booked yet.
    var acceptedJobs: [MaintenanceTicket] {
        jobs.filter { $0.status == .inProgress }.sorted { $0.priority < $1.priority }
    }

    var doneJobs: [MaintenanceTicket] { jobs.filter { $0.status == .done } }

    func job(id: String) -> MaintenanceTicket? { jobs.first { $0.id == id } }

    // MARK: Intents

    func accept(_ job: MaintenanceTicket) async -> Bool {
        await perform { try await $0.accept(job.id, by: self.vendorName) }
    }

    func decline(_ job: MaintenanceTicket, reason: String) async -> Bool {
        let declined = await perform { try await $0.decline(job.id, by: self.vendorName, reason: reason) }
        if declined {
            await visitTracker.stopTracking(job.id)
            await visitTracker.cancelReminder(job.id)
        }
        return declined
    }

    func schedule(_ job: MaintenanceTicket, at date: Date, note: String) async -> Bool {
        await perform { try await $0.scheduleVisit(job.id, at: date, by: self.vendorName, note: note) }
    }

    func complete(_ job: MaintenanceTicket, notes: String) async -> Bool {
        await perform { try await $0.complete(job.id, by: self.vendorName, notes: notes) }
    }

    func addNote(_ text: String, to job: MaintenanceTicket) async -> Bool {
        await perform { try await $0.addVendorNote(text, to: job.id, by: self.vendorName) }
    }

    /// What the tenant and landlord see as the author of an update.
    private var vendorName: String {
        guard let account else { return session.fullName }
        return "\(account.contactName), \(account.company)"
    }

    /// Runs an action, tells the rest of the app, and reloads. Returns
    /// whether it worked; on failure `errorMessage` says why.
    private func perform(_ action: @escaping (MaintenanceRepositoryProtocol) async throws -> Void) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        do {
            try await action(maintenance)
            await sync.publishLocalChange(.maintenanceRequests)
            await load()
            return true
        } catch {
            errorMessage = (error as? AppError ?? .unknown).errorDescription
            return false
        }
    }
}
