//
//  Projections+Leasing.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — Leases and vacant units, for the renewal and move forms.
//

import Foundation

extension Projections {

    private static var backend: FakeBackend { .shared }

    /// The tenant's current lease, with real dates and amounts.
    static func leaseSummary(forTenantID id: String) -> LeaseSummary? {
        guard let tenant = backend.tenants.first(where: { $0.id.description == id }),
              let lease = backend.activeLease(for: tenant.id),
              let unit = backend.unitByID[lease.unitID],
              let property = backend.propertyByID[lease.propertyID] else { return nil }

        return LeaseSummary(
            leaseID: lease.id.description,
            tenantID: id,
            propertyID: property.id.description,
            propertyName: property.name,
            unitID: unit.id.description,
            unitName: label(for: unit),
            start: lease.term.start,
            end: lease.kind == .monthToMonth ? nil : lease.term.end,
            kind: lease.kind == .monthToMonth ? .monthToMonth : .fixedTerm,
            rent: dollars(lease.rent),
            deposit: dollars(lease.depositHeld),
            isRentControlExempt: isRentControlExempt(property)
        )
    }

    /// Every vacant unit, grouped by property name then unit label.
    static func vacantUnits() -> [VacantUnit] {
        backend.units
            .filter { $0.status == .vacant && backend.activeLeaseByUnit[$0.id] == nil }
            .compactMap { unit -> VacantUnit? in
                guard let property = backend.propertyByID[unit.propertyID] else { return nil }
                return VacantUnit(
                    id: unit.id.description,
                    propertyID: property.id.description,
                    propertyName: property.name,
                    unitName: label(for: unit),
                    bedrooms: unit.bedrooms,
                    marketRent: dollars(unit.marketRent)
                )
            }
            .sorted { lhs, rhs in
                lhs.propertyName != rhs.propertyName
                    ? lhs.propertyName < rhs.propertyName
                    : lhs.unitName.localizedStandardCompare(rhs.unitName) == .orderedAscending
            }
    }

    /// Whether a property's units fall under the post-2018 exemption.
    /// Uses the year built: a building finished in 2019 or later can only
    /// have been first occupied after the 15 Nov 2018 cutoff.
    static func isRentControlExempt(propertyID: String) -> Bool {
        backend.properties.first { $0.id.description == propertyID }.map(isRentControlExempt) ?? false
    }

    // MARK: Helpers

    private static func isRentControlExempt(_ property: Domain.Property) -> Bool {
        (property.yearBuilt ?? 0) >= 2019
    }

    /// "Unit 101 · Tower A" where the property has several buildings.
    static func label(for unit: Domain.Unit) -> String {
        let buildings = backend.buildings.filter { $0.propertyID == unit.propertyID }
        guard buildings.count > 1,
              let building = buildings.first(where: { $0.id == unit.buildingID }) else { return unit.label }
        return "\(unit.label) · \(building.name)"
    }

    private static func dollars(_ money: Domain.Money) -> Int {
        Int(truncating: money.amount as NSDecimalNumber)
    }
}
