//
//  Projections+Search.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — Search filters evaluated against the domain graph.
//
//  The in-memory twin of `search_filtered` in the search-filters migration:
//  same predicates, same result shape, same order. Each result's `rank`
//  encodes that natural order (soonest end, most urgent, longest overdue),
//  so "Best match" sorting means "most pressing first".
//

import Foundation

extension Projections {

    static func searchResults(for filter: SearchFilter, now: Date = .now) -> [SearchResult] {
        let ordered: [SearchResult] = switch filter {
        case .vacant:   vacantUnits()
        case .urgent:   urgentRequests(now: now)
        case .expiring: expiringLeases(now: now)
        case .overdue:  overdueTenants(now: now)
        }
        // Descending rank in list order, so a relevance sort is a no-op.
        return ordered.enumerated().map { index, result in
            result.ranked(Double(ordered.count - index))
        }
    }

    // MARK: Vacant

    /// Units with nobody in them: vacant, or turning over between tenants.
    private static func vacantUnits() -> [SearchResult] {
        let backend = FakeBackend.shared
        return backend.units
            .filter { $0.status == .vacant || $0.status == .turnover }
            .compactMap { unit -> SearchResult? in
                guard let property = backend.propertyByID[unit.propertyID] else { return nil }
                let bathrooms = Int(truncating: unit.bathrooms as NSDecimalNumber)
                return SearchResult(
                    kind: .unit,
                    entityID: unit.id.description,
                    title: "\(property.name) · \(unit.label)",
                    subtitle: "\(unit.bedrooms) bd · \(bathrooms) ba",
                    headline: "«\(unit.status == .turnover ? "Turnover" : "Vacant")» · \(wholeDollars(unit.marketRent))/mo",
                    status: unit.status.rawValue,
                    updatedAt: unit.updatedAt,
                    rank: 0
                )
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// "$2,370" — rent is quoted in whole dollars everywhere else in the app.
    private static func wholeDollars(_ money: Domain.Money) -> String {
        money.amount.formatted(.currency(code: money.currency.rawValue).precision(.fractionLength(0)))
    }

    // MARK: Urgent

    /// Open requests at high priority or above, most severe then newest.
    private static func urgentRequests(now: Date) -> [SearchResult] {
        let backend = FakeBackend.shared
        return backend.requests
            .filter { $0.status.isOpen && $0.priority <= .high }
            .sorted { lhs, rhs in
                lhs.priority == rhs.priority
                    ? lhs.createdAt > rhs.createdAt
                    : lhs.priority < rhs.priority
            }
            .map { request in
                let propertyName = backend.propertyByID[request.propertyID]?.name ?? "Property"
                let unit = request.unitID.flatMap { backend.unitByID[$0]?.label } ?? "Common area"
                return SearchResult(
                    kind: .maintenanceRequest,
                    entityID: request.id.description,
                    title: request.title,
                    subtitle: "\(propertyName) · \(unit)",
                    headline: "«\(request.priority.rawValue.capitalized)» · \(statusLabel(request.status)) · \(FakeDateFormat.relative(request.createdAt, now: now))",
                    status: request.status.rawValue,
                    updatedAt: request.updatedAt,
                    rank: 0
                )
            }
    }

    // MARK: Expiring

    /// Current leases whose term ends within the notice window, soonest first.
    private static func expiringLeases(now: Date) -> [SearchResult] {
        let backend = FakeBackend.shared
        let today = Calendar.current.startOfDay(for: now)
        return backend.leases
            .filter { lease in
                guard lease.status.isCurrent, lease.term.end >= today else { return false }
                return lease.daysRemaining(asOf: today) <= SearchFilter.expiringWindowDays
            }
            .sorted { $0.term.end < $1.term.end }
            .map { lease in
                let tenant = backend.tenantByID[lease.primaryTenantID]?.fullName ?? "Tenant"
                let unit = backend.unitByID[lease.unitID]
                let property = unit.flatMap { backend.propertyByID[$0.propertyID]?.name } ?? "Property"
                return SearchResult(
                    kind: .lease,
                    entityID: lease.id.description,
                    title: "\(tenant) — \(unit?.label ?? "Unit")",
                    subtitle: "\(property) to \(FakeDateFormat.monthYear(lease.term.end))",
                    headline: endsInText(days: lease.daysRemaining(asOf: today)),
                    status: lease.status.rawValue,
                    updatedAt: lease.updatedAt,
                    rank: 0
                )
            }
    }

    private static func endsInText(days: Int) -> String {
        switch days {
        case ...0: "«Ends today»"
        case 1:    "«Ends tomorrow»"
        default:   "«Ends in \(days) days»"
        }
    }

    // MARK: Overdue

    /// Tenants on a current lease with an unpaid, past-due payment, most
    /// days late first.
    private static func overdueTenants(now: Date) -> [SearchResult] {
        let backend = FakeBackend.shared
        let rows = backend.tenants.compactMap { tenant -> (SearchResult, Int)? in
            guard let lease = backend.activeLease(for: tenant.id) else { return nil }
            let overdue = backend.payments(for: lease.id).filter { $0.isOverdue(asOf: now) }
            guard !overdue.isEmpty else { return nil }

            let owed = overdue.reduce(Decimal(0)) { $0 + $1.amount.amount }
            let daysLate = overdue.map { $0.daysLate(asOf: now) }.max() ?? 0
            let total = Domain.Money(owed, currency: lease.rent.currency)
            let unit = backend.unitByID[lease.unitID]
            let property = unit.flatMap { backend.propertyByID[$0.propertyID]?.name } ?? "Property"

            let result = SearchResult(
                kind: .tenant,
                entityID: tenant.id.description,
                title: tenant.fullName,
                subtitle: "\(property) · \(unit?.label ?? "Unit")",
                headline: "«\(wholeDollars(total)) overdue» · \(daysLate) \(daysLate == 1 ? "day" : "days") late",
                status: TenantStatus.overdue.rawValue,
                updatedAt: tenant.updatedAt,
                rank: 0
            )
            return (result, daysLate)
        }
        return rows.sorted { $0.1 > $1.1 }.map(\.0)
    }
}

private extension SearchResult {

    func ranked(_ rank: Double) -> SearchResult {
        SearchResult(
            kind: kind, entityID: entityID, title: title, subtitle: subtitle,
            headline: headline, status: status, updatedAt: updatedAt, rank: rank
        )
    }
}
