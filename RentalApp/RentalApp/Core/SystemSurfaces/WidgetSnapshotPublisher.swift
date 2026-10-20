//
//  WidgetSnapshotPublisher.swift
//  RentalApp (Purrperty)
//
//  System Surfaces — Keeps the widgets current.
//
//  Builds a `PortfolioSnapshot` from the same repositories the screens
//  use, writes it to the shared App Group, and asks WidgetKit to reload.
//  Runs while a staff account is signed in: at sign-in, whenever rent or
//  maintenance changes, and when the app goes to the background. Signing
//  out (or a tenant/vendor session) clears it, so the Lock Screen never
//  shows a portfolio to someone who shouldn't see it.
//

import Foundation
import OSLog
import WidgetKit

@MainActor
final class WidgetSnapshotPublisher {

    private let payments: PaymentRepositoryProtocol
    private let maintenance: MaintenanceRepositoryProtocol
    private let sync: SyncEngine
    private var subscriptionIDs: [UUID] = []
    private var isActive = false

    init(payments: PaymentRepositoryProtocol, maintenance: MaintenanceRepositoryProtocol, sync: SyncEngine) {
        self.payments = payments
        self.maintenance = maintenance
        self.sync = sync
    }

    // MARK: Lifecycle

    /// Starts publishing for a staff session; clears for anyone else.
    func update(for session: AuthSession?) async {
        guard let session, session.role.isStaff else {
            stop()
            return
        }
        if !isActive {
            isActive = true
            for topic in [RealtimeTopic.leases, .maintenanceRequests] {
                subscriptionIDs.append(sync.register(RealtimeSubscription(topic: topic) { [weak self] _ in
                    await self?.publish()
                }))
            }
        }
        await publish()
    }

    func stop() {
        subscriptionIDs.forEach(sync.unregister)
        subscriptionIDs.removeAll()
        guard isActive || PortfolioSnapshot.load() != nil else { return }
        isActive = false
        PortfolioSnapshot.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Publishing

    /// Rebuilds the snapshot and reloads the widgets if anything changed.
    func publish() async {
        guard isActive else { return }
        do {
            let roll = try await payments.rentRoll(for: .now, forceRefresh: false)
            let summary = try await maintenance.summary(forceRefresh: false)
            let visits = try await upcomingVisits()

            let snapshot = PortfolioSnapshot(
                updatedAt: .now,
                month: roll.month,
                rentCollected: roll.collected,
                rentExpected: roll.expected,
                tenantsOwing: roll.owingCount,
                amountOwing: roll.outstanding + roll.arrears,
                openRequests: summary.open,
                urgentRequests: summary.urgent,
                unassignedRequests: summary.unassigned,
                upcomingVisits: visits
            )

            var previous = PortfolioSnapshot.load()
            previous?.updatedAt = snapshot.updatedAt
            guard previous != snapshot else { return }
            snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            AppLog.sync.failure("Widget snapshot failed", error: error)
        }
    }

    private func upcomingVisits() async throws -> [PortfolioSnapshot.Visit] {
        let query = MaintenanceQuery(
            filter: MaintenanceFilter(status: .scheduled),
            sort: SortOrder(.createdAt, .descending),
            page: PageRequest(page: 0, size: 200)
        )
        let now = Date.now
        return try await maintenance.tickets(matching: query, forceRefresh: false).items
            .compactMap { ticket -> PortfolioSnapshot.Visit? in
                guard let date = ticket.scheduledVisit, date > now else { return nil }
                return PortfolioSnapshot.Visit(
                    id: ticket.id,
                    title: ticket.title,
                    place: "\(ticket.unitName) · \(ticket.propertyName)",
                    date: date
                )
            }
            .sorted { $0.date < $1.date }
            .prefix(3)
            .map { $0 }
    }
}
