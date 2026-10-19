//
//  UnitTransferViewModel.swift
//  RentalApp (Purrperty)
//
//  Tenants — State for moving a tenant to another unit.
//
//  A move ends the current lease the day before the move date and starts
//  a new one on the chosen unit, at that unit's asking rent unless the
//  manager changes it.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class UnitTransferViewModel {

    // MARK: Dependencies

    private let repository: TenantRepositoryProtocol
    private let sync: SyncEngine
    private let analytics: AnalyticsService
    let tenantID: String

    // MARK: State

    private(set) var current: LeaseSummary?
    private(set) var units: [VacantUnit] = []
    private(set) var loadError: String?
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    var errorMessage: String?

    var draft = UnitTransferDraft(moveDate: UnitTransferViewModel.firstOfNextMonth, rent: 0)

    init(
        tenantID: String,
        repository: TenantRepositoryProtocol,
        sync: SyncEngine,
        analytics: AnalyticsService
    ) {
        self.tenantID = tenantID
        self.repository = repository
        self.sync = sync
        self.analytics = analytics
    }

    // MARK: Loading

    func load() async {
        guard current == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let leaseRequest = repository.lease(forTenantID: tenantID)
            async let vacant = repository.vacantUnits()
            let lease = try await leaseRequest
            current = lease
            units = try await vacant.filter { $0.id != lease.unitID }
            // A move can't come before the current lease starts — after a
            // renewal that hasn't begun yet, that's later than next month.
            if draft.moveDate <= lease.start {
                draft.moveDate = Calendar.current.date(byAdding: .day, value: 1, to: lease.start) ?? lease.start
            }
        } catch {
            loadError = (error as? AppError ?? .unknown).errorDescription
        }
    }

    // MARK: Derived

    var target: VacantUnit? {
        units.first { $0.id == draft.targetUnitID }
    }

    /// Vacant units grouped by property, in display order.
    var unitsByProperty: [(property: String, units: [VacantUnit])] {
        Dictionary(grouping: units, by: \.propertyName)
            .map { ($0.key, $0.value) }
            .sorted { $0.property < $1.property }
    }

    /// The last day of the current lease.
    var currentLeaseEnds: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: draft.moveDate) ?? draft.moveDate
    }

    var canSubmit: Bool {
        target != nil && draft.rent > 0 && !isSubmitting
    }

    // MARK: Intents

    /// Choosing a unit starts the rent at its asking rent.
    func selectUnit(id: String?) {
        draft.targetUnitID = id
        if let target { draft.rent = target.marketRent }
    }

    func submit() async -> LeaseSummary? {
        guard canSubmit else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        do {
            let lease = try await repository.moveTenant(id: tenantID, with: draft)
            await analytics.track(.tenantMovedUnits)
            await sync.publishLocalChange(.leases)
            return lease
        } catch {
            errorMessage = (error as? AppError ?? .unknown).errorDescription
            return nil
        }
    }

    // MARK: Helpers

    private static var firstOfNextMonth: Date {
        let calendar = Calendar.current
        let next = calendar.date(byAdding: .month, value: 1, to: .now) ?? .now
        return calendar.date(from: calendar.dateComponents([.year, .month], from: next)) ?? next
    }
}
