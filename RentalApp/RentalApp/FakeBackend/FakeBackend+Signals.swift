//
//  FakeBackend+Signals.swift
//  RentalApp (RentOS)
//
//  Fake Backend — Tasks, activity, and notifications.
//
//  These three are all *reactions* to state elsewhere in the dataset.
//  Nothing here invents a fact: an overdue-rent notification is built
//  from a payment that is genuinely past due, and a renewal task
//  points at a lease that really is inside its notice window.
//

import Foundation

extension FakeBackend {

    // MARK: - Tasks

    static func makeTasks(
        orgID: Domain.Identifier<Domain.Organization>,
        users: [Domain.User],
        leases: [Domain.Lease],
        tenants: [Domain.Tenant],
        requests: [Domain.MaintenanceRequest],
        rng: inout SeededRandom
    ) -> [Domain.Task] {

        var result: [Domain.Task] = []
        let tenantByID = Dictionary(uniqueKeysWithValues: tenants.map { ($0.id, $0) })
        let assignees = users.filter { $0.status == .active }

        // Renewals for leases actually inside the notice window.
        for lease in leases.filter({ $0.isRenewalDue() }).prefix(8) {
            guard let tenant = tenantByID[lease.primaryTenantID] else { continue }
            result.append(
                Domain.Task(
                    id: .init(rng.uuid()),
                    organizationID: orgID,
                    title: "Lease renewal — \(tenant.fullName)",
                    details: "Term ends \(FakeDateFormat.monthYear(lease.term.end)). Start the renewal conversation.",
                    status: rng.weighted([(.open, 5), (.inProgress, 2)]),
                    priority: lease.daysRemaining() < 30 ? .high : .normal,
                    assigneeUserID: assignees.randomElement(using: &rng)?.id,
                    dueAt: rng.date(daysAhead: 1...14),
                    subject: .lease(lease.id),
                    createdAt: rng.date(daysAgo: 1...10)
                )
            )
        }

        // Vendor follow-ups for scheduled work.
        for request in requests.filter({ $0.status == .scheduled }).prefix(6) {
            result.append(
                Domain.Task(
                    id: .init(rng.uuid()),
                    organizationID: orgID,
                    title: "\(request.title) — vendor visit",
                    details: "Confirm access and attendance.",
                    status: .open,
                    priority: request.priority.isCritical ? .urgent : .normal,
                    assigneeUserID: assignees.randomElement(using: &rng)?.id,
                    dueAt: request.scheduledFor,
                    subject: .maintenanceRequest(request.id),
                    createdAt: request.createdAt
                )
            )
        }

        // Recurring operational work.
        let routine: [(String, Int)] = [
            ("Send monthly rent reminders", 3),
            ("Review vendor insurance expiries", 9),
            ("Reconcile last month's payments", 5),
            ("Update market rent benchmarks", 14),
            ("Schedule seasonal HVAC servicing", 21)
        ]
        for (title, days) in routine {
            result.append(
                Domain.Task(
                    id: .init(rng.uuid()),
                    organizationID: orgID,
                    title: title,
                    status: rng.chance(0.25) ? .completed : .open,
                    priority: .normal,
                    assigneeUserID: assignees.randomElement(using: &rng)?.id,
                    dueAt: rng.date(daysAhead: days...days),
                    recurrence: .init(frequency: .monthly),
                    createdAt: rng.date(daysAgo: 2...20)
                )
            )
        }

        return result.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    // MARK: - Activity

    static func makeActivities(
        orgID: Domain.Identifier<Domain.Organization>,
        users: [Domain.User],
        tenants: [Domain.Tenant],
        leases: [Domain.Lease],
        payments: [Domain.Payment],
        requests: [Domain.MaintenanceRequest],
        units: [Domain.Unit],
        rng: inout SeededRandom
    ) -> [Domain.Activity] {

        var result: [Domain.Activity] = []
        let tenantByID = Dictionary(uniqueKeysWithValues: tenants.map { ($0.id, $0) })
        let unitByID = Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })

        // Recent rent receipts.
        let recentPaid = payments
            .filter { $0.status == .paid && $0.kind == .rent }
            .sorted { ($0.paidAt ?? .distantPast) > ($1.paidAt ?? .distantPast) }
            .prefix(18)

        for payment in recentPaid {
            guard let tenant = tenantByID[payment.tenantID] else { continue }
            let unitLabel = leases.first { $0.id == payment.leaseID }
                .flatMap { unitByID[$0.unitID]?.label } ?? "Unit"
            result.append(
                Domain.Activity(
                    organizationID: orgID,
                    isSystemGenerated: true,
                    verb: .paid,
                    subject: .tenant(tenant.id),
                    summary: "Rent payment received — \(unitLabel) · \(payment.amount.formatted())",
                    createdAt: payment.paidAt ?? payment.dueOn
                )
            )
        }

        // Recent maintenance movement.
        for request in requests.prefix(20) {
            result.append(
                Domain.Activity(
                    organizationID: orgID,
                    actorTenantID: request.reportedByTenantID,
                    verb: .created,
                    subject: .maintenanceRequest(request.id),
                    summary: "\(request.title) reported",
                    createdAt: request.createdAt
                )
            )
        }

        // Lease signings.
        for lease in leases.sorted(by: { ($0.signedAt ?? .distantPast) > ($1.signedAt ?? .distantPast) }).prefix(10) {
            guard let signedAt = lease.signedAt,
                  let unit = unitByID[lease.unitID] else { continue }
            result.append(
                Domain.Activity(
                    organizationID: orgID,
                    actorUserID: users.first?.id,
                    verb: .signed,
                    subject: .lease(lease.id),
                    summary: "Lease signed — \(unit.label) · 12 months",
                    createdAt: signedAt
                )
            )
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Notifications

    static func makeNotifications(
        orgID: Domain.Identifier<Domain.Organization>,
        users: [Domain.User],
        requests: [Domain.MaintenanceRequest],
        payments: [Domain.Payment],
        leases: [Domain.Lease],
        tenants: [Domain.Tenant],
        units: [Domain.Unit],
        rng: inout SeededRandom
    ) -> [Domain.Notification] {

        guard let owner = users.first else { return [] }

        var result: [Domain.Notification] = []
        let tenantByID = Dictionary(uniqueKeysWithValues: tenants.map { ($0.id, $0) })
        let unitByID = Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })

        func unitLabel(_ id: Domain.Identifier<Domain.Unit>?) -> String {
            id.flatMap { unitByID[$0]?.label } ?? "Common area"
        }

        // Urgent open work.
        for request in requests.filter({ $0.priority.isCritical && $0.status.isOpen }).prefix(4) {
            let tenantName = request.reportedByTenantID
                .flatMap { tenantByID[$0]?.fullName } ?? "Staff"
            result.append(
                Domain.Notification(
                    organizationID: orgID,
                    recipientUserID: owner.id,
                    category: .maintenance,
                    title: "Urgent: \(request.title.lowercased())",
                    body: "\(tenantName) · \(unitLabel(request.unitID)) · AI classified \(request.priority.rawValue)",
                    subject: .maintenanceRequest(request.id),
                    deepLink: "rentos://maintenance/\(request.id)",
                    priority: .critical,
                    readAt: nil,
                    createdAt: request.createdAt
                )
            )
        }

        // Money in.
        for payment in payments.filter({ $0.status == .paid && $0.kind == .rent })
            .sorted(by: { ($0.paidAt ?? .distantPast) > ($1.paidAt ?? .distantPast) })
            .prefix(5) {
            let tenantName = tenantByID[payment.tenantID]?.fullName ?? "Tenant"
            let paidAt = payment.paidAt ?? payment.dueOn
            result.append(
                Domain.Notification(
                    organizationID: orgID,
                    recipientUserID: owner.id,
                    category: .payment,
                    title: "Rent payment received",
                    body: "\(payment.amount.formatted()) from \(tenantName)",
                    priority: .normal,
                    readAt: rng.chance(0.6) ? paidAt.addingTimeInterval(3_600) : nil,
                    createdAt: paidAt
                )
            )
        }

        // Money late.
        for payment in payments.filter({ $0.isOverdue() }).prefix(3) {
            let tenantName = tenantByID[payment.tenantID]?.fullName ?? "Tenant"
            result.append(
                Domain.Notification(
                    organizationID: orgID,
                    recipientUserID: owner.id,
                    category: .payment,
                    title: "Rent overdue",
                    body: "\(tenantName) · \(payment.amount.formatted()) · \(payment.daysLate()) days late",
                    priority: .high,
                    readAt: nil,
                    createdAt: payment.dueOn.addingTimeInterval(86_400)
                )
            )
        }

        // Renewals approaching.
        for lease in leases.filter({ $0.isRenewalDue() }).prefix(4) {
            let tenantName = tenantByID[lease.primaryTenantID]?.fullName ?? "Tenant"
            result.append(
                Domain.Notification(
                    organizationID: orgID,
                    recipientUserID: owner.id,
                    category: .lease,
                    title: "Lease renewal approaching",
                    body: "\(tenantName) · \(unitLabel(lease.unitID)) · ends \(FakeDateFormat.monthYear(lease.term.end))",
                    subject: .lease(lease.id),
                    priority: .normal,
                    readAt: rng.chance(0.5) ? .now : nil,
                    createdAt: rng.date(daysAgo: 0...6)
                )
            )
        }

        // Copilot.
        result.append(
            Domain.Notification(
                organizationID: orgID,
                recipientUserID: owner.id,
                category: .aiInsight,
                title: "Copilot briefing ready",
                body: "\(requests.filter { $0.status.isOpen }.count) open requests and \(leases.filter { $0.isRenewalDue() }.count) renewals need review",
                priority: .normal,
                readAt: nil,
                createdAt: rng.date(daysAgo: 0...0).addingTimeInterval(-21_600)
            )
        )

        // Completed work, older.
        for request in requests.filter({ $0.status == .completed }).prefix(6) {
            result.append(
                Domain.Notification(
                    organizationID: orgID,
                    recipientUserID: owner.id,
                    category: .maintenance,
                    title: "Request resolved",
                    body: "\(request.title) · \(unitLabel(request.unitID))",
                    subject: .maintenanceRequest(request.id),
                    priority: .low,
                    readAt: request.resolvedAt,
                    createdAt: request.resolvedAt ?? request.createdAt
                )
            )
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }
}
