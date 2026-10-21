//
//  PortfolioRepositories.swift
//  RentalApp (Purrperty)
//
//  Repositories — Property, Tenant, and Dashboard data sources.
//
//  Each conforms to its Core protocol and does the work a networked
//  implementation would: applies the query, pages the result, caches
//  it, and simulates latency so the loading states in the UI are
//  exercised on every run rather than only in production.
//

import SwiftUI
import Observation

// MARK: - Latency

/// Stands in for network round-trip time.
///
/// The delay is chosen by *kind of call* rather than passed as a raw
/// `Duration`, so every repository asks for "a list round-trip" instead
/// of inventing its own number — one place to tune, and call sites read
/// as intent.
enum SimulatedLatency {

    enum Kind {
        /// Collection fetch — the slowest, and the one whose skeleton
        /// state the UI must handle well.
        case list
        /// Single-record fetch.
        case detail
        /// Mutation round-trip.
        case write

        var duration: Duration {
            switch self {
            case .list: .milliseconds(420)
            case .detail: .milliseconds(260)
            case .write: .milliseconds(340)
            }
        }
    }

    /// Sleeps, and forwards cancellation so a superseded query stops.
    static func wait(_ kind: Kind) async throws {
        try await Task.sleep(for: kind.duration)
    }
}

// MARK: - Properties

@MainActor
@Observable
final class InMemoryPropertyRepository: PropertyRepositoryProtocol {

    private let cache: RepositoryCache

    init(cache: RepositoryCache = .shared) {
        self.cache = cache
    }

    private static let namespace = "properties"

    // MARK: Mutation overlay
    //
    // `Projections` reads the immutable seeded graph, so writes are held
    // as an overlay composed on top of it rather than by mutating the
    // seed. That keeps the mock graph fully functional — previews and
    // `.inMemory` get working buttons, not dead ones — without a second
    // source of truth for the seed data itself.

    @ObservationIgnored @WorkspaceLocal private var created: [Property] = []
    @ObservationIgnored @WorkspaceLocal private var edits: [String: PropertyDraft] = [:]
    @ObservationIgnored @WorkspaceLocal private var archivedIDs: Set<String> = []
    @ObservationIgnored @WorkspaceLocal private var deletedIDs: Set<String> = []
    @ObservationIgnored @WorkspaceLocal private var unitOverlay: [String: [PropertyUnit]] = [:]
    @ObservationIgnored @WorkspaceLocal private var deletedUnitIDs: Set<String> = []
    /// Seeded units removed per property, so its unit count follows.
    @ObservationIgnored @WorkspaceLocal private var removedSeededUnits: [String: Int] = [:]

    func properties(matching query: PropertyQuery, forceRefresh: Bool) async throws -> Page<Property> {
        try await SimulatedLatency.wait(.list)
        try Task.checkCancellation()

        let all = try await cached(forceRefresh: forceRefresh)
        return Self.apply(query, to: all).page(query.page)
    }

    func property(id: String) async throws -> Property {
        try await SimulatedLatency.wait(.detail)
        let all = try await cached(forceRefresh: false)
        guard let match = all.first(where: { $0.id == id }) else {
            throw AppError.notFound("Property")
        }
        return match
    }

    func portfolioSummary(forceRefresh: Bool) async throws -> PropertyPortfolioSummary {
        let all = try await cached(forceRefresh: forceRefresh)
        let units = all.reduce(0) { $0 + $1.unitCount }
        let occupied = all.reduce(0) { $0 + $1.occupiedCount }
        let revenue = all.reduce(0.0) { $0 + $1.monthlyRevenue }

        return PropertyPortfolioSummary(
            propertyCount: all.count,
            totalUnits: units,
            occupiedUnits: occupied,
            monthlyRevenueText: revenue.cadThousands
        )
    }

    // MARK: Related

    func units(forPropertyID id: String) async throws -> [PropertyUnit] {
        try await SimulatedLatency.wait(.detail)
        // Hidden seeded units are filtered before the overlay joins, since
        // an edited unit's overlay copy keeps the seeded ID.
        let seeded = Projections.units(forPropertyID: id).filter { !deletedUnitIDs.contains($0.id) }
        return seeded + (unitOverlay[id] ?? [])
    }

    func unit(id: String) async throws -> UnitDetail {
        try await SimulatedLatency.wait(.detail)
        let propertyID: String
        let unit: PropertyUnit
        if let (overlayPropertyID, units) = unitOverlay.first(where: { $0.value.contains { $0.id == id } }),
           let match = units.first(where: { $0.id == id }) {
            (propertyID, unit) = (overlayPropertyID, match)
        } else if !deletedUnitIDs.contains(id), let seeded = await seededUnit(id: id) {
            (propertyID, unit) = (seeded.propertyID, seeded.unit)
        } else {
            throw AppError.notFound("Unit")
        }
        let property = try await self.property(id: propertyID)
        return UnitDetail(unit: unit, propertyID: propertyID, propertyName: property.name)
    }

    func tenantRows(forPropertyID id: String) async throws -> [PropertyTenantRow] {
        try await SimulatedLatency.wait(.detail)
        return Projections.tenantRows(forPropertyID: id)
    }

    func requestRows(forPropertyID id: String) async throws -> [PropertyRequestRow] {
        try await SimulatedLatency.wait(.detail)
        return Projections.requestRows(forPropertyID: id)
    }

    func documents(forPropertyID id: String) async throws -> [PropertyDocRow] {
        try await SimulatedLatency.wait(.detail)
        return Projections.documentRows(forPropertyID: id)
    }

    func occupancyTrend(forPropertyID id: String) async throws -> [OccupancyTrendPoint] {
        try await SimulatedLatency.wait(.detail)
        return Projections.occupancyTrend(forPropertyID: id)
    }

    func revenueTrend(forPropertyID id: String) async throws -> [RevenuePoint] {
        try await SimulatedLatency.wait(.detail)
        return Projections.revenueTrend(forPropertyID: id)
    }

    // MARK: - Writes

    func archivedProperties() async throws -> [Property] {
        try await SimulatedLatency.wait(.list)
        let seeded = await cache.fetch(key: Self.namespace) { Projections.properties() }
        return (seeded + created)
            .filter { archivedIDs.contains($0.id) }
            .map(applyingEdit)
    }

    @discardableResult
    func createProperty(_ draft: PropertyDraft) async throws -> Property {
        try await SimulatedLatency.wait(.write)
        try validate(draft)

        let property = Property(
            id: "prop_\(UUID().uuidString.prefix(8).lowercased())",
            name: draft.name,
            neighborhood: draft.neighborhood ?? draft.city,
            address: "\(draft.addressLine1), \(draft.city)",
            kind: draft.kind,
            unitCount: 0,
            occupiedCount: 0,
            monthlyRevenue: 0,
            openRequests: 0,
            urgentRequests: 0,
            yearBuilt: draft.yearBuilt ?? 0,
            paletteIndex: created.count
        )
        created.append(property)
        return property
    }

    func updateProperty(id: String, with draft: PropertyDraft) async throws -> Property {
        try await SimulatedLatency.wait(.write)
        try validate(draft)

        edits[id] = draft
        if let index = created.firstIndex(where: { $0.id == id }) {
            created[index] = applyingEdit(created[index])
        }
        let all = try await cached(forceRefresh: false)
        guard let updated = all.first(where: { $0.id == id }) else {
            throw AppError.notFound("Property")
        }
        return updated
    }

    func archiveProperty(id: String) async throws {
        try await SimulatedLatency.wait(.write)
        archivedIDs.insert(id)
    }

    func restoreProperty(id: String) async throws {
        try await SimulatedLatency.wait(.write)
        archivedIDs.remove(id)
    }

    func deleteProperty(id: String) async throws {
        try await SimulatedLatency.wait(.write)

        // Mirrors the server rule so the mock exercises the same failure
        // path the real backend enforces in `delete_property()`.
        let occupied = Projections.tenantRows(forPropertyID: id)
        guard occupied.isEmpty else {
            throw AppError.validation(
                "This property has \(occupied.count) active lease(s). Archive it instead."
            )
        }
        deletedIDs.insert(id)
        archivedIDs.remove(id)
    }

    @discardableResult
    func createUnit(_ draft: UnitDraft, propertyID: String) async throws -> PropertyUnit {
        try await SimulatedLatency.wait(.write)
        guard !draft.label.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AppError.validation("Give the unit a label.")
        }

        let unit = PropertyUnit(
            id: "unit_\(UUID().uuidString.prefix(8).lowercased())",
            name: draft.label,
            beds: draft.bedrooms,
            baths: Int(truncating: draft.bathrooms as NSDecimalNumber),
            sqft: draft.squareFeet ?? 0,
            rent: Int(truncating: draft.marketRent as NSDecimalNumber),
            tenantName: nil,
            status: .vacant
        )
        unitOverlay[propertyID, default: []].append(unit)
        return unit
    }

    func updateUnit(id: String, with draft: UnitDraft) async throws -> PropertyUnit {
        try await SimulatedLatency.wait(.write)

        // Editing a unit's details doesn't change who lives there.
        func replacing(_ original: PropertyUnit?) -> PropertyUnit {
            PropertyUnit(
                id: id,
                name: draft.label,
                beds: draft.bedrooms,
                baths: Int(truncating: draft.bathrooms as NSDecimalNumber),
                sqft: draft.squareFeet ?? 0,
                rent: Int(truncating: draft.marketRent as NSDecimalNumber),
                tenantName: original?.tenantName,
                status: original?.status ?? .vacant,
                building: original?.building
            )
        }
        for (propertyID, units) in unitOverlay {
            if let index = units.firstIndex(where: { $0.id == id }) {
                let replacement = replacing(units[index])
                unitOverlay[propertyID]?[index] = replacement
                return replacement
            }
        }
        // A seeded unit: hide the original and hold the edited copy in the
        // overlay under the property it belongs to.
        guard let (propertyID, original) = await seededUnit(id: id) else {
            throw AppError.notFound("Unit")
        }
        let replacement = replacing(original)
        deletedUnitIDs.insert(id)
        unitOverlay[propertyID, default: []].append(replacement)
        return replacement
    }

    func deleteUnit(id: String) async throws {
        try await SimulatedLatency.wait(.write)
        if let propertyID = unitOverlay.first(where: { $0.value.contains { $0.id == id } })?.key {
            unitOverlay[propertyID]?.removeAll { $0.id == id }
        } else if let (propertyID, _) = await seededUnit(id: id) {
            deletedUnitIDs.insert(id)
            removedSeededUnits[propertyID, default: 0] += 1
        }
    }

    /// The seeded unit with this ID and the property it belongs to.
    private func seededUnit(id: String) async -> (propertyID: String, unit: PropertyUnit)? {
        let seeded = await cache.fetch(key: Self.namespace) { Projections.properties() }
        for property in seeded {
            if let unit = Projections.units(forPropertyID: property.id).first(where: { $0.id == id }) {
                return (property.id, unit)
            }
        }
        return nil
    }

    /// The same field rules the database enforces with CHECK constraints,
    /// so the mock fails where the server would.
    private func validate(_ draft: PropertyDraft) throws {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else {
            throw AppError.validation("Give the property a name of at least 2 characters.")
        }
        guard !draft.addressLine1.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AppError.validation("A street address is required.")
        }
    }

    // MARK: Internals

    private func cached(forceRefresh: Bool) async throws -> [Property] {
        let seeded = await cache.fetch(key: Self.namespace, forceRefresh: forceRefresh) {
            Projections.properties()
        }
        return visible(from: seeded)
    }

    /// Seed rows + created rows, with edits applied and archived/deleted
    /// rows removed.
    private func visible(from seeded: [Property]) -> [Property] {
        (seeded + created)
            .filter { !archivedIDs.contains($0.id) && !deletedIDs.contains($0.id) }
            .map(applyingEdit)
            .map(applyingUnitChanges)
    }

    /// Unit counts that follow units added to or removed from a property.
    /// Added units start vacant, so occupancy only changes when an
    /// occupied unit is removed.
    private func applyingUnitChanges(_ property: Property) -> Property {
        // Edited seeded units sit in the overlay under their original ID
        // and replace a unit already counted; only new units add to it.
        let added = unitOverlay[property.id]?.filter { !deletedUnitIDs.contains($0.id) }.count ?? 0
        let removed = removedSeededUnits[property.id] ?? 0
        guard added != 0 || removed != 0 else { return property }
        let unitCount = max(0, property.unitCount + added - removed)
        return Property(
            id: property.id,
            name: property.name,
            neighborhood: property.neighborhood,
            address: property.address,
            kind: property.kind,
            unitCount: unitCount,
            occupiedCount: min(property.occupiedCount, unitCount),
            monthlyRevenue: property.monthlyRevenue,
            openRequests: property.openRequests,
            urgentRequests: property.urgentRequests,
            yearBuilt: property.yearBuilt,
            paletteIndex: property.paletteIndex
        )
    }

    private func applyingEdit(_ property: Property) -> Property {
        guard let draft = edits[property.id] else { return property }
        return Property(
            id: property.id,
            name: draft.name,
            neighborhood: draft.neighborhood ?? property.neighborhood,
            address: "\(draft.addressLine1), \(draft.city)",
            kind: draft.kind,
            unitCount: property.unitCount,
            occupiedCount: property.occupiedCount,
            monthlyRevenue: property.monthlyRevenue,
            openRequests: property.openRequests,
            urgentRequests: property.urgentRequests,
            yearBuilt: draft.yearBuilt ?? property.yearBuilt,
            paletteIndex: property.paletteIndex
        )
    }

    /// Search, filter, and sort — the work a `WHERE`/`ORDER BY` will do.
    static func apply(_ query: PropertyQuery, to source: [Property]) -> [Property] {
        var result = source

        if let term = query.searchTerm {
            result = result.filter {
                $0.name.matches(term) || $0.neighborhood.matches(term) || $0.address.matches(term)
            }
        }

        switch query.filter {
        case .all: break
        case .fullyOccupied: result = result.filter(\.isFull)
        case .hasVacancy: result = result.filter { $0.vacantCount > 0 }
        case .hasIssues: result = result.filter { $0.urgentRequests > 0 || $0.openRequests > 2 }
        }

        let ascending = query.sort.direction.isAscending
        switch query.sort.field {
        case .name:
            result.sort { ascending ? $0.name < $1.name : $0.name > $1.name }
        case .occupancy:
            result.sort { ascending ? $0.occupancyRate < $1.occupancyRate : $0.occupancyRate > $1.occupancyRate }
        case .revenue:
            result.sort { ascending ? $0.monthlyRevenue < $1.monthlyRevenue : $0.monthlyRevenue > $1.monthlyRevenue }
        case .units:
            result.sort { ascending ? $0.unitCount < $1.unitCount : $0.unitCount > $1.unitCount }
        }

        return result
    }
}

// MARK: - Tenants

@MainActor
@Observable
final class InMemoryTenantRepository: TenantRepositoryProtocol {

    private let cache: RepositoryCache
    /// Who owes rent comes from the rent roll, so recording a payment
    /// clears a tenant's overdue status everywhere at once.
    private let payments: PaymentRepositoryProtocol
    @ObservationIgnored @WorkspaceLocal private var created: [Tenant] = []

    // MARK: Leasing overlay
    //
    // Renewals and moves are held on top of the seeded graph, like the
    // property overlay: the current lease per tenant, the units taken and
    // freed by moves, and the events they add to each timeline.

    @ObservationIgnored @WorkspaceLocal private var leaseOverrides: [String: LeaseSummary] = [:]
    @ObservationIgnored @WorkspaceLocal private var occupiedUnitIDs: Set<String> = []
    @ObservationIgnored @WorkspaceLocal private var freedUnits: [String: VacantUnit] = [:]
    @ObservationIgnored @WorkspaceLocal private var addedEvents: [String: [TenantEvent]] = [:]

    init(payments: PaymentRepositoryProtocol, cache: RepositoryCache = .shared) {
        self.payments = payments
        self.cache = cache
    }

    private static let namespace = "tenants"

    func tenants(matching query: TenantQuery, forceRefresh: Bool) async throws -> Page<Tenant> {
        try await SimulatedLatency.wait(.list)
        try Task.checkCancellation()

        let all = try await cached(forceRefresh: forceRefresh)
        return Self.apply(query, to: all).page(query.page)
    }

    func tenant(id: String) async throws -> Tenant {
        try await SimulatedLatency.wait(.detail)
        let all = try await cached(forceRefresh: false)
        guard let match = all.first(where: { $0.id == id }) else {
            throw AppError.notFound("Tenant")
        }
        return match
    }

    func summary(forceRefresh: Bool) async throws -> TenantSummary {
        let all = try await cached(forceRefresh: forceRefresh)
        return TenantSummary(
            total: all.count,
            active: all.filter { $0.status == .active }.count,
            overdue: all.filter { $0.status == .overdue }.count,
            renewalsSoon: all.filter { $0.isRenewalDue }.count
        )
    }

    // MARK: Related

    func timeline(forTenantID id: String) async throws -> [TenantEvent] {
        try await SimulatedLatency.wait(.detail)
        return (addedEvents[id] ?? []) + Projections.timeline(forTenantID: id)
    }

    func documents(forTenantID id: String) async throws -> [PropertyDocRow] {
        try await SimulatedLatency.wait(.detail)
        return Projections.documents(forTenantID: id)
    }

    func maintenanceHistory(forTenantID id: String) async throws -> [PropertyRequestRow] {
        try await SimulatedLatency.wait(.detail)
        return Projections.maintenanceHistory(forTenantID: id)
    }

    // MARK: Writes

    func create(_ draft: TenantDraft) async throws {
        try await SimulatedLatency.wait(.write)
        guard try await vacantUnits().contains(where: { $0.id == draft.unitID }) else {
            throw AppError.validation("\(draft.unit) isn't vacant any more. Choose another unit.")
        }
        // The unit is taken from here on.
        occupiedUnitIDs.insert(draft.unitID)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        created.insert(
            Tenant(
                id: draft.email.lowercased(),
                name: draft.name,
                email: draft.email,
                phone: draft.phone,
                propertyName: draft.propertyName,
                unitName: draft.unit.hasPrefix("Unit") ? draft.unit : "Unit \(draft.unit)",
                rent: draft.rent,
                deposit: draft.rent,
                leaseStart: formatter.string(from: draft.leaseStart),
                leaseEnd: formatter.string(from: draft.leaseEnd),
                leaseProgress: 0,
                status: .active,
                isPremium: false,
                onTimeRate: 100,
                isRenewalDue: Tenant.isRenewalDue(leaseEnd: draft.leaseEnd)
            ),
            at: 0
        )

        // Keep the agreement too, so a tenant added here can be renewed
        // or moved like any other.
        let id = draft.email.lowercased()
        let propertyID = Projections.properties().first { $0.name == draft.propertyName }?.id ?? ""
        leaseOverrides[id] = LeaseSummary(
            leaseID: "lease-\(UUID().uuidString.lowercased())",
            tenantID: id,
            propertyID: propertyID,
            propertyName: draft.propertyName,
            unitID: "unit-\(id)",
            unitName: draft.unit.hasPrefix("Unit") ? draft.unit : "Unit \(draft.unit)",
            start: draft.leaseStart,
            end: draft.leaseEnd,
            kind: .fixedTerm,
            rent: draft.rent,
            deposit: draft.rent,
            isRentControlExempt: Projections.isRentControlExempt(propertyID: propertyID)
        )
        cache.invalidate(prefix: Self.namespace)
    }

    // MARK: Leasing

    func lease(forTenantID id: String) async throws -> LeaseSummary {
        try await SimulatedLatency.wait(.detail)
        guard let lease = currentLease(forTenantID: id) else {
            throw AppError.notFound("Lease")
        }
        return lease
    }

    func vacantUnits() async throws -> [VacantUnit] {
        try await SimulatedLatency.wait(.detail)
        let seeded = Projections.vacantUnits().filter { !occupiedUnitIDs.contains($0.id) }
        let freed = freedUnits.values.filter { !occupiedUnitIDs.contains($0.id) }
        return (seeded + freed).sorted { lhs, rhs in
            lhs.propertyName != rhs.propertyName
                ? lhs.propertyName < rhs.propertyName
                : lhs.unitName.localizedStandardCompare(rhs.unitName) == .orderedAscending
        }
    }

    func renewLease(forTenantID id: String, with draft: LeaseRenewalDraft) async throws -> LeaseSummary {
        guard let current = currentLease(forTenantID: id) else {
            throw AppError.notFound("Lease")
        }
        try Self.validate(draft, after: current)
        try await SimulatedLatency.wait(.write)

        let renewed = LeaseSummary(
            leaseID: "lease-\(UUID().uuidString.lowercased())",
            tenantID: id,
            propertyID: current.propertyID,
            propertyName: current.propertyName,
            unitID: current.unitID,
            unitName: current.unitName,
            start: draft.start,
            end: draft.kind == .fixedTerm ? draft.end : nil,
            kind: draft.kind,
            rent: draft.rent,
            deposit: current.deposit,
            isRentControlExempt: current.isRentControlExempt
        )
        leaseOverrides[id] = renewed

        let change = draft.rent - current.rent
        record(
            TenantEvent(
                icon: AppSymbol.lease.rawValue, kind: .success,
                title: "Lease renewed",
                detail: "\(renewed.termText) · \(Self.currency(draft.rent))/mo"
                    + (change == 0 ? "" : " (\(change > 0 ? "+" : "−")\(Self.currency(abs(change))))"),
                date: FakeDateFormat.monthDay(.now)
            ),
            forTenantID: id
        )
        cache.invalidate(prefix: Self.namespace)
        return renewed
    }

    func moveTenant(id: String, with draft: UnitTransferDraft) async throws -> LeaseSummary {
        guard let current = currentLease(forTenantID: id) else {
            throw AppError.notFound("Lease")
        }
        let available = try await vacantUnits()
        guard let target = available.first(where: { $0.id == draft.targetUnitID }) else {
            throw AppError.validation("Choose a vacant unit to move to.")
        }
        guard draft.rent > 0 else {
            throw AppError.validation("Enter the monthly rent for the new unit.")
        }
        guard draft.moveDate > current.start else {
            throw AppError.validation("The move has to come after the current lease started.")
        }
        try await SimulatedLatency.wait(.write)

        let moved = LeaseSummary(
            leaseID: "lease-\(UUID().uuidString.lowercased())",
            tenantID: id,
            propertyID: target.propertyID,
            propertyName: target.propertyName,
            unitID: target.id,
            unitName: target.unitName,
            start: draft.moveDate,
            end: Calendar.current.date(byAdding: DateComponents(year: 1, day: -1), to: draft.moveDate),
            kind: .fixedTerm,
            rent: draft.rent,
            deposit: draft.carriesDeposit
                ? OntarioTenancyRules.carriedDeposit(current.deposit, newRent: draft.rent).carried
                : draft.rent,
            isRentControlExempt: Projections.isRentControlExempt(propertyID: target.propertyID)
        )
        leaseOverrides[id] = moved
        occupiedUnitIDs.insert(target.id)
        occupiedUnitIDs.remove(current.unitID)
        let freed = Projections.units(forPropertyID: current.propertyID).first { $0.id == current.unitID }
        freedUnits[current.unitID] = VacantUnit(
            id: current.unitID,
            propertyID: current.propertyID,
            propertyName: current.propertyName,
            unitName: current.unitName,
            bedrooms: freed?.beds ?? 1,
            marketRent: freed?.rent ?? current.rent
        )

        record(
            TenantEvent(
                icon: "arrow.left.arrow.right", kind: .info,
                title: "Moving to \(target.unitName)",
                detail: "From \(current.unitName) on \(draft.moveDate.formatted(date: .abbreviated, time: .omitted))",
                date: FakeDateFormat.monthDay(.now)
            ),
            forTenantID: id
        )
        cache.invalidate(prefix: Self.namespace)
        return moved
    }

    // MARK: Internals

    private func currentLease(forTenantID id: String) -> LeaseSummary? {
        leaseOverrides[id] ?? Projections.leaseSummary(forTenantID: id)
    }

    private func record(_ event: TenantEvent, forTenantID id: String) {
        addedEvents[id, default: []].insert(event, at: 0)
    }

    /// The rules the `leases` table's CHECK constraints enforce.
    private static func validate(_ draft: LeaseRenewalDraft, after current: LeaseSummary) throws {
        guard draft.rent > 0 else {
            throw AppError.validation("Enter the monthly rent.")
        }
        guard draft.start > current.start else {
            throw AppError.validation("The renewal has to start after the current lease did.")
        }
        if draft.kind == .fixedTerm, draft.end <= draft.start {
            throw AppError.validation("The end date has to be after the start date.")
        }
    }

    private static func currency(_ dollars: Int) -> String {
        dollars.formatted(.currency(code: "CAD").precision(.fractionLength(0)))
    }

    /// A tenant row with its lease replaced by a renewal or move.
    private func applyingLease(to tenant: Tenant) -> Tenant {
        guard let lease = leaseOverrides[tenant.id] else { return tenant }
        let monthYear = Date.FormatStyle.dateTime.month(.abbreviated).year()
        return Tenant(
            id: tenant.id,
            name: tenant.name,
            email: tenant.email,
            phone: tenant.phone,
            propertyName: lease.propertyName,
            unitName: lease.unitName,
            rent: lease.rent,
            deposit: lease.deposit,
            leaseStart: lease.start.formatted(monthYear),
            leaseEnd: lease.end?.formatted(monthYear) ?? "Month-to-month",
            leaseProgress: lease.end.map { Domain.DateRange(start: lease.start, end: $0).progress() } ?? 0,
            status: tenant.status == .notice ? .active : tenant.status,
            isPremium: tenant.isPremium,
            onTimeRate: tenant.onTimeRate,
            isRenewalDue: Tenant.isRenewalDue(leaseEnd: lease.end)
        )
    }

    private func cached(forceRefresh: Bool) async throws -> [Tenant] {
        let roll = try await payments.rentRoll(for: .now, forceRefresh: forceRefresh)
        let owing = Set(roll.rows.filter(\.isOwing).map(\.tenantID))
        // Not cached: standing changes with every recorded payment, and
        // the projection is a single pass over the tenants.
        let base = Projections.tenants(owing: owing)
        return (created + base).map(applyingLease)
    }

    static func apply(_ query: TenantQuery, to source: [Tenant]) -> [Tenant] {
        var result = source

        if let term = query.searchTerm {
            result = result.filter {
                $0.name.matches(term) || $0.propertyName.matches(term) || $0.unitName.matches(term)
            }
        }

        switch query.filter {
        case .all: break
        case .active: result = result.filter { $0.status == .active }
        case .notice: result = result.filter { $0.status == .notice }
        case .overdue: result = result.filter { $0.status == .overdue }
        case .premium: result = result.filter(\.isPremium)
        }

        let ascending = query.sort.direction.isAscending
        switch query.sort.field {
        case .name:
            result.sort { ascending ? $0.name < $1.name : $0.name > $1.name }
        case .rent:
            result.sort { ascending ? $0.rent < $1.rent : $0.rent > $1.rent }
        case .leaseProgress:
            result.sort { ascending ? $0.leaseProgress < $1.leaseProgress : $0.leaseProgress > $1.leaseProgress }
        }

        return result
    }
}

// MARK: - Dashboard

@MainActor
@Observable
final class InMemoryDashboardRepository: DashboardRepositoryProtocol {

    private let cache: RepositoryCache
    /// Rent collected comes from the same source as the rent roll, so the
    /// two never disagree.
    private let payments: PaymentRepositoryProtocol
    /// Property and maintenance counts come from their own repositories,
    /// so Home agrees with the Properties and Maintenance tabs after edits.
    private let properties: PropertyRepositoryProtocol
    private let maintenance: MaintenanceRepositoryProtocol
    @ObservationIgnored @WorkspaceLocal private var completedTaskIDs: Set<UUID> = []

    init(
        payments: PaymentRepositoryProtocol,
        properties: PropertyRepositoryProtocol,
        maintenance: MaintenanceRepositoryProtocol,
        cache: RepositoryCache = .shared
    ) {
        self.payments = payments
        self.properties = properties
        self.maintenance = maintenance
        self.cache = cache
    }

    private static let namespace = "dashboard"

    func snapshot(forceRefresh: Bool) async throws -> DashboardSnapshot {
        try await SimulatedLatency.wait(.list)
        try Task.checkCancellation()

        let cached = await cache.fetch(key: Self.namespace, forceRefresh: forceRefresh) {
            Self.build()
        }

        // Local completions layer over the fetched snapshot.
        let tasks = cached.tasks.map { task -> UpcomingTask in
            var copy = task
            if completedTaskIDs.contains(task.id) { copy.isDone = true }
            return copy
        }

        // Live figures from the repositories each tab reads, layered over
        // the cached snapshot, so Home never disagrees with them.
        let roll = try await payments.rentRoll(for: .now, forceRefresh: forceRefresh)
        let portfolio = try await properties.portfolioSummary(forceRefresh: forceRefresh)
        let tickets = try await maintenance.tickets(
            matching: MaintenanceQuery(
                filter: MaintenanceFilter(),
                sort: SortOrder(.priority),
                page: PageRequest(page: 0, size: 1_000)
            ),
            forceRefresh: forceRefresh
        ).items
        let open = tickets.filter { $0.status != .done }
        let urgent = open.filter { $0.priority == .urgent }.count

        let stats = cached.stats.map { stat -> DashboardStat in
            switch stat.title {
            case Self.rentCollectedTitle:
                DashboardStat(
                    title: stat.title,
                    value: roll.expected == 0 ? "—" : roll.collectionRate.formatted(.percent.precision(.fractionLength(0))),
                    icon: stat.icon, gradient: stat.gradient,
                    // Nothing due isn't the same as everything paid.
                    trend: roll.expected == 0 ? "None due" : roll.owingCount == 0 ? "All paid" : "\(roll.owingCount) owing",
                    trendKind: roll.expected == 0 ? .info : roll.owingCount == 0 ? .success : .warning
                )
            case Self.occupancyTitle:
                DashboardStat(
                    title: stat.title,
                    value: portfolio.occupancyRate.formatted(.percent.precision(.fractionLength(0))),
                    icon: stat.icon, gradient: stat.gradient,
                    trend: "\(portfolio.totalUnits - portfolio.occupiedUnits) vacant",
                    trendKind: .info
                )
            case Self.openRequestsTitle:
                DashboardStat(
                    title: stat.title,
                    value: "\(open.count)",
                    icon: stat.icon, gradient: stat.gradient,
                    trend: urgent > 0 ? "\(urgent) urgent" : "None urgent",
                    trendKind: urgent > 0 ? .danger : .success
                )
            default:
                stat
            }
        }

        let summary = cached.portfolio
        let turnover = min(summary.turnoverUnits, portfolio.totalUnits - portfolio.occupiedUnits)
        let livePortfolio = PortfolioSummary(
            greetingName: summary.greetingName,
            portfolioValue: summary.portfolioValue,
            monthlyRevenue: summary.monthlyRevenue,
            revenueTrend: summary.revenueTrend,
            propertyCount: portfolio.propertyCount,
            unitCount: portfolio.totalUnits,
            occupancyRate: portfolio.occupancyRate,
            occupiedUnits: portfolio.occupiedUnits,
            vacantUnits: portfolio.totalUnits - portfolio.occupiedUnits - turnover,
            turnoverUnits: turnover
        )

        // Same buckets as the board's columns. "Done this week" needs a
        // resolution date the ticket model doesn't carry, so it stays seeded.
        let doneThisWeek = cached.maintenanceCounts.first { $0.kind == .success }?.count ?? 0
        let maintenanceCounts: [MaintenanceStatusCount] = [
            .init(label: "New", count: open.filter { $0.status == .new }.count, kind: .info),
            .init(label: "In Progress", count: open.filter { $0.status == .inProgress }.count, kind: .warning),
            .init(label: "Scheduled", count: open.filter { $0.status == .scheduled }.count, kind: .neutral),
            .init(label: "Done this week", count: doneThisWeek, kind: .success)
        ]

        return DashboardSnapshot(
            portfolio: livePortfolio,
            revenue: cached.revenue,
            stats: stats,
            insights: cached.insights,
            maintenanceCounts: maintenanceCounts,
            activity: cached.activity,
            tasks: tasks
        )
    }

    func toggleTask(_ id: UUID) async throws {
        if completedTaskIDs.contains(id) {
            completedTaskIDs.remove(id)
        } else {
            completedTaskIDs.insert(id)
        }
    }

    private static let rentCollectedTitle = "Rent Collected"
    private static let occupancyTitle = "Occupancy"
    private static let openRequestsTitle = "Open Requests"

    private static func build() -> DashboardSnapshot {
        let summary = Projections.portfolioSummary()
        let counts = Projections.maintenanceCounts()
        let open = counts.filter { $0.kind != .success }.reduce(0) { $0 + $1.count }
        let urgent = Projections.tickets().filter { $0.priority == .urgent && $0.status != .done }.count
        let tenants = Projections.tenants()
        let tenantCount = tenants.count
        // The Tenants screen's "renewing": 60 days or fewer left.
        let renewals = tenants.filter { $0.isRenewalDue }.count

        let stats = [
            DashboardStat(title: occupancyTitle, value: "\(Int(summary.occupancyRate * 100))%",
                          icon: DS.Icons.occupancy, gradient: DS.Gradients.brand,
                          trend: "+2.1%", trendKind: .success),
            DashboardStat(title: openRequestsTitle, value: "\(open)",
                          icon: DS.Icons.maintenance, gradient: DS.Gradients.warm,
                          trend: urgent > 0 ? "\(urgent) urgent" : "None urgent",
                          trendKind: urgent > 0 ? .danger : .success),
            // Filled in from the rent roll on every read.
            DashboardStat(title: rentCollectedTitle, value: "—",
                          icon: DS.Icons.payment, gradient: DS.Gradients.success,
                          trend: "This month", trendKind: .info),
            // Every tenant on a current lease, as the Tenants screen counts
            // them. "Active" there means in good standing, a subset.
            DashboardStat(title: "Tenants", value: "\(tenantCount)",
                          icon: DS.Icons.tenants, gradient: DS.Gradients.ai,
                          trend: "\(renewals) renewing", trendKind: .info)
        ]

        return DashboardSnapshot(
            portfolio: summary,
            revenue: Projections.revenueSeries(),
            stats: stats,
            insights: DashboardMockData.insights,
            maintenanceCounts: counts,
            activity: Projections.activityFeed(),
            tasks: Projections.upcomingTasks()
        )
    }
}
