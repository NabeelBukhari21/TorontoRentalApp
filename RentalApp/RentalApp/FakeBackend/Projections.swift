//
//  Projections.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — Domain → presentation mapping.
//
//  The domain layer is deliberately free of UI concerns, so something
//  has to add icons, colours, and human-formatted dates. That job
//  lives here, in one place, rather than leaking into views. When the
//  real Supabase client arrives, only the *source* of the domain rows
//  changes; every projection below keeps working unchanged.
//

import SwiftUI

@MainActor
enum Projections {

    private static var backend: FakeBackend { .shared }

    // MARK: - Properties

    static func properties() -> [Property] {
        backend.properties.enumerated().map { index, property in
            let units = backend.units(in: property.id)
            let occupied = units.filter { $0.status.countsAsOccupied }.count
            let open = backend.requests(for: property.id).filter { $0.status.isOpen }
            let revenue = units
                .filter { $0.status.countsAsOccupied }
                .reduce(Decimal(0)) { $0 + $1.marketRent.amount }

            return Property(
                id: property.id.description,
                name: property.name,
                neighborhood: property.neighborhood ?? "Toronto",
                address: property.address.line1 + ", Toronto",
                kind: kind(from: property.kind),
                unitCount: units.count,
                occupiedCount: occupied,
                monthlyRevenue: (revenue as NSDecimalNumber).doubleValue / 1_000,
                openRequests: open.count,
                urgentRequests: open.filter { $0.priority.isCritical }.count,
                yearBuilt: property.yearBuilt ?? 1990,
                paletteIndex: index
            )
        }
    }

    private static func kind(from kind: Domain.Property.Kind) -> PropertyKind {
        switch kind {
        case .condo: .condo
        case .house: .house
        case .commercial: .commercial
        default: .multiUnit
        }
    }

    // MARK: - Units

    static func units(forPropertyID id: String) -> [PropertyUnit] {
        guard let property = backend.properties.first(where: { $0.id.description == id })
        else { return [] }

        let buildings = backend.buildings.filter { $0.propertyID == property.id }
        let buildingNames = Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0.name) })

        return backend.units(in: property.id).map { unit in
            let lease = backend.activeLeaseByUnit[unit.id]
            let tenantName = lease
                .flatMap { backend.tenantByID[$0.primaryTenantID]?.fullName }

            return PropertyUnit(
                id: unit.id.description,
                name: unit.label,
                beds: unit.bedrooms,
                baths: Int(truncating: unit.bathrooms as NSDecimalNumber),
                sqft: unit.squareFeet ?? 700,
                rent: Int(truncating: unit.marketRent.amount as NSDecimalNumber),
                tenantName: tenantName,
                status: unitStatus(unit.status),
                building: buildings.count > 1 ? buildingNames[unit.buildingID] : nil
            )
        }
    }

    private static func unitStatus(_ status: Domain.Unit.Status) -> PropertyUnit.UnitStatus {
        switch status {
        case .occupied: .occupied
        case .notice: .notice
        default: .vacant
        }
    }

    static func tenantRows(forPropertyID id: String) -> [PropertyTenantRow] {
        guard let property = backend.properties.first(where: { $0.id.description == id })
        else { return [] }

        return backend.units(in: property.id).compactMap { unit -> PropertyTenantRow? in
            guard let lease = backend.activeLeaseByUnit[unit.id],
                  let tenant = backend.tenantByID[lease.primaryTenantID] else { return nil }

            let overdue = backend.payments(for: lease.id).contains { $0.isOverdue() }
            return PropertyTenantRow(
                name: tenant.fullName,
                unit: unit.label,
                leaseEnds: FakeDateFormat.monthYear(lease.term.end),
                rentStatus: overdue ? "Rent overdue" : "Paid",
                rentKind: overdue ? .danger : .success
            )
        }
    }

    static func requestRows(forPropertyID id: String) -> [PropertyRequestRow] {
        guard let property = backend.properties.first(where: { $0.id.description == id })
        else { return [] }

        return backend.requests(for: property.id)
            .filter { $0.status.isOpen }
            .map { request in
                PropertyRequestRow(
                    title: request.title,
                    unit: request.unitID.flatMap { backend.unitByID[$0]?.label } ?? "Common area",
                    status: statusLabel(request.status),
                    kind: statusKind(request.status, priority: request.priority),
                    time: FakeDateFormat.relative(request.createdAt)
                )
            }
    }

    static func documentRows(forPropertyID id: String) -> [PropertyDocRow] {
        guard let property = backend.properties.first(where: { $0.id.description == id })
        else { return [] }

        return backend.documents
            .filter { $0.owner == .property(property.id) }
            .map { document in
                PropertyDocRow(
                    name: document.name,
                    icon: icon(for: document.category),
                    detail: "\(document.file.kind.rawValue.uppercased()) · \(byteLabel(document.file.byteSize)) · \(FakeDateFormat.monthYear(document.createdAt))"
                )
            }
    }

    static func occupancyTrend(forPropertyID id: String) -> [OccupancyTrendPoint] {
        guard let property = backend.properties.first(where: { $0.id.description == id })
        else { return [] }

        let units = backend.units(in: property.id)
        guard !units.isEmpty else { return [] }
        let current = Double(units.filter { $0.status.countsAsOccupied }.count) / Double(units.count)

        // Twelve months trending toward today's real figure.
        return (0..<12).map { index in
            let monthsBack = 11 - index
            let date = Calendar.current.date(byAdding: .month, value: -monthsBack, to: .now) ?? .now
            let drift = sin(Double(index) * 0.9 + Double(property.name.count)) * 0.05
            return OccupancyTrendPoint(
                month: FakeDateFormat.monthYear(date).prefix(3).description,
                rate: min(max(current - 0.04 + drift + Double(index) * 0.004, 0.55), 1.0)
            )
        }
    }

    static func revenueTrend(forPropertyID id: String) -> [RevenuePoint] {
        guard let property = backend.properties.first(where: { $0.id.description == id })
        else { return [] }

        let monthly = backend.units(in: property.id)
            .filter { $0.status.countsAsOccupied }
            .reduce(Decimal(0)) { $0 + $1.marketRent.amount }
        let base = (monthly as NSDecimalNumber).doubleValue / 1_000

        return (0..<6).map { index in
            let date = Calendar.current.date(byAdding: .month, value: index - 5, to: .now) ?? .now
            let wobble = sin(Double(index) * 0.85 + Double(property.name.count)) * 0.05
            return RevenuePoint(
                month: FakeDateFormat.monthYear(date).prefix(3).description,
                amount: base * (0.93 + wobble + Double(index) * 0.015)
            )
        }
    }

    // MARK: - Tenants

    static func tenants() -> [Tenant] {
        backend.tenants.compactMap { tenant -> Tenant? in
            guard let lease = backend.activeLease(for: tenant.id),
                  let unit = backend.unitByID[lease.unitID],
                  let property = backend.propertyByID[unit.propertyID] else { return nil }

            let overdue = backend.payments(for: lease.id).contains { $0.isOverdue() }
            let status: TenantStatus = {
                if overdue { return .overdue }
                if lease.status == .expiring { return .notice }
                return .active
            }()

            return Tenant(
                id: tenant.id.description,
                name: tenant.fullName,
                email: tenant.email,
                phone: tenant.phone ?? "—",
                propertyName: property.name,
                unitName: unit.label,
                rent: Int(truncating: lease.rent.amount as NSDecimalNumber),
                deposit: Int(truncating: lease.depositHeld.amount as NSDecimalNumber),
                leaseStart: FakeDateFormat.monthYear(lease.term.start),
                leaseEnd: FakeDateFormat.monthYear(lease.term.end),
                leaseProgress: lease.progress(),
                status: status,
                isPremium: tenant.isPriority,
                onTimeRate: tenant.onTimePaymentRate
            )
        }
        .sorted { $0.name < $1.name }
    }

    static func timeline(forTenantID id: String) -> [TenantEvent] {
        guard let tenant = backend.tenants.first(where: { $0.id.description == id }),
              let lease = backend.activeLease(for: tenant.id) else { return [] }

        var events: [TenantEvent] = []

        for payment in backend.payments(for: lease.id).prefix(4) where payment.status == .paid {
            events.append(
                TenantEvent(
                    icon: DS.Icons.payment, kind: .success,
                    title: "\(FakeDateFormat.monthYear(payment.dueOn)) rent received",
                    detail: "\(payment.amount.formatted()) · \(methodLabel(payment.method))",
                    date: FakeDateFormat.monthDay(payment.paidAt ?? payment.dueOn)
                )
            )
        }

        for request in backend.requests.filter({ $0.unitID == lease.unitID }).prefix(3) {
            events.append(
                TenantEvent(
                    icon: DS.Icons.maintenance,
                    kind: request.status == .completed ? .success : .warning,
                    title: request.title,
                    detail: request.status == .completed
                        ? "Resolved in \(request.resolutionHours ?? 0)h"
                        : statusLabel(request.status),
                    date: FakeDateFormat.monthDay(request.createdAt)
                )
            )
        }

        events.append(
            TenantEvent(
                icon: DS.Icons.lease, kind: .neutral,
                title: "Lease signed",
                detail: "\(FakeDateFormat.monthYear(lease.term.start)) – \(FakeDateFormat.monthYear(lease.term.end))",
                date: FakeDateFormat.monthDay(lease.signedAt ?? lease.term.start)
            )
        )
        events.append(
            TenantEvent(
                icon: "key.fill", kind: .neutral,
                title: "Moved in",
                detail: backend.unitByID[lease.unitID]?.label ?? "Unit",
                date: FakeDateFormat.monthDay(lease.term.start)
            )
        )

        return events
    }

    static func documents(forTenantID id: String) -> [PropertyDocRow] {
        guard let tenant = backend.tenants.first(where: { $0.id.description == id }),
              let lease = backend.activeLease(for: tenant.id) else { return [] }

        let owned = backend.documents.filter { $0.owner == .lease(lease.id) }
        let rows = owned.map { document in
            PropertyDocRow(
                name: document.name,
                icon: icon(for: document.category),
                detail: "PDF · \(byteLabel(document.file.byteSize)) · \(FakeDateFormat.monthYear(document.createdAt))"
            )
        }

        // Every tenant file has these, whether or not a row was generated.
        return rows + [
            PropertyDocRow(name: "Tenant insurance proof", icon: "shield.fill",
                           detail: "PDF · 320 KB · \(FakeDateFormat.monthYear(lease.term.start))"),
            PropertyDocRow(name: "Move-in inspection report", icon: "checklist",
                           detail: "PDF · 840 KB · \(FakeDateFormat.monthYear(lease.term.start))"),
            PropertyDocRow(name: "ID verification", icon: "person.text.rectangle.fill",
                           detail: "Verified · \(FakeDateFormat.monthYear(lease.term.start))")
        ]
    }

    static func maintenanceHistory(forTenantID id: String) -> [PropertyRequestRow] {
        guard let tenant = backend.tenants.first(where: { $0.id.description == id }),
              let lease = backend.activeLease(for: tenant.id) else { return [] }

        return backend.requests
            .filter { $0.unitID == lease.unitID }
            .prefix(6)
            .map { request in
                PropertyRequestRow(
                    title: request.title,
                    unit: backend.unitByID[lease.unitID]?.label ?? "Unit",
                    status: statusLabel(request.status),
                    kind: statusKind(request.status, priority: request.priority),
                    time: FakeDateFormat.monthDay(request.createdAt)
                )
            }
    }

    static func messagePreviews(forTenantID id: String) -> [TenantMessagePreview] {
        guard let tenant = backend.tenants.first(where: { $0.id.description == id }) else { return [] }

        let conversation = backend.conversations.first { conversation in
            conversation.participants.contains { $0.id == tenant.id.rawValue }
        }
        guard let conversation else { return [] }

        return backend.messages(in: conversation.id).suffix(3).map { message in
            TenantMessagePreview(
                text: message.body,
                time: FakeDateFormat.dayTime(message.createdAt),
                isFromTenant: message.senderRole == .tenant
            )
        }
    }

    // MARK: - Shared Helpers

    static func statusLabel(_ status: Domain.MaintenanceRequest.Status) -> String {
        switch status {
        case .new: "New"
        case .triaged: "Triaged"
        case .scheduled: "Scheduled"
        case .inProgress: "In progress"
        case .awaitingParts: "Awaiting parts"
        case .completed: "Resolved"
        case .cancelled: "Cancelled"
        case .unknown: "Unknown"
        }
    }

    static func statusKind(
        _ status: Domain.MaintenanceRequest.Status,
        priority: Domain.MaintenanceRequest.Priority
    ) -> DSStatusKind {
        if status == .completed { return .success }
        if priority.isCritical { return .danger }
        switch status {
        case .inProgress, .awaitingParts: return .warning
        case .scheduled, .triaged: return .info
        default: return .neutral
        }
    }

    static func methodLabel(_ method: Domain.Payment.Method) -> String {
        switch method {
        case .eTransfer: "Interac e-Transfer"
        case .preAuthorizedDebit: "Pre-authorized debit"
        case .card: "Card"
        case .cheque: "Cheque"
        case .cash: "Cash"
        case .unknown: "Other"
        }
    }

    static func icon(for category: Domain.Document.Category) -> String {
        switch category {
        case .lease: DS.Icons.lease
        case .insurance: "shield.fill"
        case .financial: DS.Icons.payment
        case .inspection: "checklist"
        case .identification: "person.text.rectangle.fill"
        case .photo: DS.Icons.camera
        case .invoice: "doc.text.fill"
        default: DS.Icons.documents
        }
    }

    static func byteLabel(_ bytes: Int) -> String {
        bytes > 1_000_000
            ? String(format: "%.1f MB", Double(bytes) / 1_000_000)
            : "\(bytes / 1_000) KB"
    }
}
