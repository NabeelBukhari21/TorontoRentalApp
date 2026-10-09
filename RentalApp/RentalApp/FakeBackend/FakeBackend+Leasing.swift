//
//  FakeBackend+Leasing.swift
//  RentalApp (RentOS)
//
//  Fake Backend — Tenants, leases, and the payment ledger.
//
//  Lease terms are staggered across the past three years so the
//  renewal pipeline looks like a real book of business: a handful
//  expiring inside 60 days, most mid-term, a few just started.
//  Payments are generated month by month from each lease's start,
//  which is what makes on-time rates and overdue balances real
//  numbers rather than decoration.
//

import Foundation

extension FakeBackend {

    static func makeLeasing(
        orgID: Domain.Identifier<Domain.Organization>,
        units: [Domain.Unit],
        rng: inout SeededRandom
    ) -> (tenants: [Domain.Tenant],
          leases: [Domain.Lease],
          payments: [Domain.Payment]) {

        var tenants: [Domain.Tenant] = []
        var leases: [Domain.Lease] = []
        var payments: [Domain.Payment] = []
        var usedNames = Set<String>()

        let calendar = Calendar.current
        let now = Date()

        for unit in units {
            // ~88% occupancy across the portfolio.
            guard rng.chance(0.88) else { continue }

            // Term start staggered over three years.
            let monthsAgo = rng.weighted([
                (rng.int(1...5), 3.0),    // recent move-ins
                (rng.int(6...11), 4.0),   // mid-term
                (rng.int(12...23), 3.0),  // renewed once
                (rng.int(24...34), 1.5)   // long tenure
            ])
            guard
                let start = calendar.date(byAdding: .month, value: -monthsAgo, to: now),
                let end = calendar.date(byAdding: .month, value: 12, to: start)
            else { continue }

            // Roommates on larger units.
            let occupantCount = unit.bedrooms >= 2 && rng.chance(0.3) ? 2 : 1
            var occupantIDs: [Domain.Identifier<Domain.Tenant>] = []

            for _ in 0..<occupantCount {
                let tenant = Self.makeTenant(
                    orgID: orgID, usedNames: &usedNames, rng: &rng
                )
                tenants.append(tenant)
                occupantIDs.append(tenant.id)
            }

            let daysToEnd = calendar.dateComponents([.day], from: now, to: end).day ?? 0
            let status: Domain.Lease.Status = {
                if daysToEnd < 0 { return .expired }
                if daysToEnd <= 60 { return .expiring }
                return .active
            }()

            let leaseID = Domain.Identifier<Domain.Lease>(rng.uuid())
            let rent = unit.marketRent

            leases.append(
                Domain.Lease(
                    id: leaseID,
                    organizationID: orgID,
                    unitID: unit.id,
                    propertyID: unit.propertyID,
                    primaryTenantID: occupantIDs[0],
                    tenantIDs: occupantIDs,
                    term: .init(start: start, end: end),
                    kind: monthsAgo > 12 ? .monthToMonth : .fixedTerm,
                    status: status,
                    rent: rent,
                    depositHeld: rent,
                    rentDueDay: 1,
                    signedAt: calendar.date(byAdding: .day, value: -rng.int(5...30), to: start),
                    moveInAt: start,
                    createdAt: start
                )
            )

            payments.append(contentsOf: Self.makePayments(
                orgID: orgID,
                lease: leases[leases.count - 1],
                tenantID: occupantIDs[0],
                propertyID: unit.propertyID,
                monthsElapsed: monthsAgo,
                rng: &rng
            ))
        }

        // Payment history determines each tenant's standing — computed
        // after the ledger exists, never invented up front.
        tenants = Self.applyPaymentStanding(
            to: tenants, leases: leases, payments: payments
        )

        return (tenants, leases, payments)
    }

    // MARK: - Tenant

    private static func makeTenant(
        orgID: Domain.Identifier<Domain.Organization>,
        usedNames: inout Set<String>,
        rng: inout SeededRandom
    ) -> Domain.Tenant {

        // Keep names unique so the directory never shows a duplicate.
        var name = ""
        var attempts = 0
        repeat {
            name = "\(rng.pick(TorontoSeeds.firstNames)) \(rng.pick(TorontoSeeds.lastNames))"
            attempts += 1
        } while usedNames.contains(name) && attempts < 40
        usedNames.insert(name)

        return Domain.Tenant(
            id: .init(rng.uuid()),
            organizationID: orgID,
            fullName: name,
            email: Self.email(for: name, domain: rng.pick(TorontoSeeds.emailDomains)),
            phone: "(\(rng.pick([416, 647, 437]))) 555-0\(rng.int(100...999))",
            emergencyContactName: rng.chance(0.6)
                ? "\(rng.pick(TorontoSeeds.firstNames)) \(rng.pick(TorontoSeeds.lastNames))"
                : nil,
            emergencyContactPhone: rng.chance(0.6) ? "(416) 555-0\(rng.int(100...999))" : nil,
            status: .current,
            onTimePaymentRate: 100,
            isPriority: rng.chance(0.18)
        )
    }

    // MARK: - Payments

    /// One rent charge per elapsed month, plus occasional late fees.
    private static func makePayments(
        orgID: Domain.Identifier<Domain.Organization>,
        lease: Domain.Lease,
        tenantID: Domain.Identifier<Domain.Tenant>,
        propertyID: Domain.Identifier<Domain.Property>,
        monthsElapsed: Int,
        rng: inout SeededRandom
    ) -> [Domain.Payment] {

        var result: [Domain.Payment] = []
        let calendar = Calendar.current
        let now = Date()

        // A minority of tenants are unreliable; most always pay on time.
        let reliability = rng.weighted([(0.99, 6.0), (0.94, 2.5), (0.82, 1.0)])
        let method: Domain.Payment.Method = rng.weighted([
            (.eTransfer, 5), (.preAuthorizedDebit, 3), (.card, 1), (.cheque, 1)
        ])

        // Deposit at signing.
        result.append(
            Domain.Payment(
                id: .init(rng.uuid()),
                organizationID: orgID,
                leaseID: lease.id,
                tenantID: tenantID,
                propertyID: propertyID,
                amount: lease.depositHeld,
                kind: .deposit,
                method: method,
                status: .paid,
                dueOn: lease.term.start,
                paidAt: lease.term.start,
                createdAt: lease.term.start
            )
        )

        for monthOffset in 0...max(monthsElapsed, 0) {
            guard let dueOn = calendar.date(byAdding: .month, value: monthOffset, to: lease.term.start)
            else { continue }
            guard dueOn <= calendar.date(byAdding: .day, value: 5, to: now)! else { break }

            let isFuture = dueOn > now
            let paidOnTime = rng.chance(reliability)

            var status: Domain.Payment.Status = .paid
            var paidAt: Date? = dueOn
            var failureReason: String?

            if isFuture {
                status = .scheduled
                paidAt = nil
            } else if !paidOnTime {
                // Most late payments eventually land; a few are still open.
                if rng.chance(0.7) {
                    status = .paid
                    paidAt = calendar.date(byAdding: .day, value: rng.int(2...11), to: dueOn)
                } else {
                    status = .failed
                    paidAt = nil
                    failureReason = rng.pick([
                        "Insufficient funds",
                        "Pre-authorized debit returned",
                        "Payment not received"
                    ])
                }
            } else {
                paidAt = calendar.date(byAdding: .hour, value: -rng.int(0...36), to: dueOn)
            }

            result.append(
                Domain.Payment(
                    id: .init(rng.uuid()),
                    organizationID: orgID,
                    leaseID: lease.id,
                    tenantID: tenantID,
                    propertyID: propertyID,
                    amount: lease.rent,
                    kind: .rent,
                    method: method,
                    status: status,
                    dueOn: dueOn,
                    paidAt: paidAt,
                    failureReason: failureReason,
                    createdAt: dueOn
                )
            )

            // Late fee follows an unpaid charge, as it would in practice.
            if status == .failed && rng.chance(0.5) {
                result.append(
                    Domain.Payment(
                        id: .init(rng.uuid()),
                        organizationID: orgID,
                        leaseID: lease.id,
                        tenantID: tenantID,
                        propertyID: propertyID,
                        amount: .init(75),
                        kind: .lateFee,
                        method: method,
                        status: .scheduled,
                        dueOn: calendar.date(byAdding: .day, value: 5, to: dueOn) ?? dueOn,
                        createdAt: dueOn
                    )
                )
            }
        }

        return result
    }

    // MARK: - Standing

    /// Rewrites each tenant's on-time rate and status from their real
    /// payment history, so the badge on screen matches the ledger.
    private static func applyPaymentStanding(
        to tenants: [Domain.Tenant],
        leases: [Domain.Lease],
        payments: [Domain.Payment]
    ) -> [Domain.Tenant] {

        var paymentsByTenant: [Domain.Identifier<Domain.Tenant>: [Domain.Payment]] = [:]
        for payment in payments where payment.kind == .rent {
            paymentsByTenant[payment.tenantID, default: []].append(payment)
        }

        var leaseByPrimary: [Domain.Identifier<Domain.Tenant>: Domain.Lease] = [:]
        for lease in leases {
            leaseByPrimary[lease.primaryTenantID] = lease
        }

        let now = Date()

        return tenants.map { tenant in
            var updated = tenant
            let history = paymentsByTenant[tenant.id] ?? []

            if !history.isEmpty {
                let settled = history.filter { $0.status == .paid }
                let onTime = settled.filter { ($0.paidAt ?? .distantFuture) <= $0.dueOn }
                updated.onTimePaymentRate = settled.isEmpty
                    ? 100
                    : Int((Double(onTime.count) / Double(settled.count) * 100).rounded())
            }

            let hasOverdue = history.contains { $0.isOverdue(asOf: now) }
            let lease = leaseByPrimary[tenant.id]

            if hasOverdue {
                updated.status = .current
            }
            if lease?.status == .expiring {
                updated.status = .notice
            }
            // Reliable, long-tenured renters are worth retaining.
            updated.isPriority = updated.onTimePaymentRate == 100
                && (lease.map { $0.term.progress(asOf: now) > 0.5 } ?? false)
                && tenant.isPriority

            return updated
        }
    }
}
