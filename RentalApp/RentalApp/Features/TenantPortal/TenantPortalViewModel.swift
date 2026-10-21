//
//  TenantPortalViewModel.swift
//  RentalApp (Purrperty)
//
//  Tenant Portal — Everything a tenant sees about their own tenancy:
//  lease, rent account, requests for their unit, and their landlord.
//
//  One model for the whole portal, so the four tabs always agree. It
//  reads through the same repositories the staff app uses, scoped to
//  this tenant; on the server, RLS is what enforces that scope.
//

import SwiftUI
import Observation
import OSLog

@MainActor
@Observable
final class TenantPortalViewModel {

    enum Phase: Equatable {
        case loading
        /// Signed in, but no landlord has linked this account to a lease.
        case notLinked
        case ready
        case failed(String)
    }

    // MARK: Dependencies

    private let portal: TenantPortalRepositoryProtocol
    private let tenants: TenantRepositoryProtocol
    private let payments: PaymentRepositoryProtocol
    private let maintenance: MaintenanceRepositoryProtocol
    let visitTracker: RepairVisitTracker
    let session: AuthSession

    // MARK: State

    private(set) var phase: Phase = .loading
    private(set) var account: PortalAccount?
    private(set) var lease: LeaseSummary?
    private(set) var ledger: TenantLedger?
    private(set) var requests: [MaintenanceTicket] = []

    init(
        session: AuthSession,
        portal: TenantPortalRepositoryProtocol,
        tenants: TenantRepositoryProtocol,
        payments: PaymentRepositoryProtocol,
        maintenance: MaintenanceRepositoryProtocol,
        visitTracker: RepairVisitTracker
    ) {
        self.visitTracker = visitTracker
        self.session = session
        self.portal = portal
        self.tenants = tenants
        self.payments = payments
        self.maintenance = maintenance
    }

    // MARK: Loading

    func load() async {
        do {
            guard let account = try await portal.account(for: session) else {
                phase = .notLinked
                return
            }
            self.account = account
            async let lease = tenants.lease(forTenantID: account.tenantID)
            async let ledger = payments.ledger(forTenantID: account.tenantID)
            let loadedLease = try await lease
            self.lease = loadedLease
            self.ledger = try await ledger
            // Only what was reported since they moved in: earlier requests
            // belong to whoever lived there before.
            self.requests = try await loadRequests(unitID: loadedLease.unitID)
                .filter { $0.createdAt.map { $0 >= loadedLease.start } ?? true }
            phase = .ready
            for request in requests { await visitTracker.jobChanged(request) }
            await visitTracker.refresh()
        } catch is CancellationError {
            // The view went away mid-load; the next appearance tries again.
        } catch {
            AppLog.sync.failure("Tenant portal load failed", error: error)
            if phase != .ready {
                phase = .failed((error as? AppError ?? .unknown).errorDescription ?? "")
            }
        }
    }

    private func loadRequests(unitID: String) async throws -> [MaintenanceTicket] {
        let query = MaintenanceQuery(
            filter: MaintenanceFilter(unitID: unitID),
            sort: SortOrder(.createdAt, .descending),
            page: PageRequest(page: 0, size: 100)
        )
        return try await maintenance.tickets(matching: query, forceRefresh: false).items
    }

    // MARK: Derived

    var firstName: String {
        let name = account?.tenantName ?? session.fullName
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    var openRequests: [MaintenanceTicket] { requests.filter { $0.status != .done } }
    var closedRequests: [MaintenanceTicket] { requests.filter { $0.status == .done } }

    /// The next date rent falls due, on the lease's usual day.
    var nextRentDue: Date? {
        guard let lease else { return nil }
        let calendar = Calendar.current
        let day = calendar.component(.day, from: lease.start)
        let today = calendar.startOfDay(for: .now)
        for offset in 0...2 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: today.startOfMonth),
                  let due = calendar.date(byAdding: .day, value: day - 1, to: month) else { continue }
            if due > today { return due }
        }
        return nil
    }

    var isRenewalDue: Bool {
        guard let end = lease?.end else { return false }
        let days = Calendar.current.dateComponents([.day], from: .now, to: end).day ?? .max
        return days <= 60 && days >= 0
    }

    /// Where a new request is reported: this tenant's home, fixed.
    var requestLocation: RequestLocation? {
        guard let lease, let account else { return nil }
        return RequestLocation(
            propertyID: lease.propertyID,
            propertyName: lease.propertyName,
            unitID: lease.unitID,
            unitName: lease.unitName,
            tenantName: account.tenantName
        )
    }
}
