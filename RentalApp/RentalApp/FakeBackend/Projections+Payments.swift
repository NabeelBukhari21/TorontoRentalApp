//
//  Projections+Payments.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — Rent rolls and ledgers from the seeded payments.
//
//  The seed holds one rent charge per lease per month (paid, returned or
//  not yet due), plus deposits and NSF charges. These turn that into the
//  month's roll and a tenant's account; the repository layers payments
//  recorded in the app on top.
//

import Foundation

extension Projections {

    private static var backend: FakeBackend { .shared }

    // MARK: - Rent Roll

    /// Every current lease's rent for `month`, as seeded.
    static func rentRoll(month: Date) -> [RentRollRow] {
        let month = month.startOfMonth
        let now = Date()

        return backend.leases
            .filter(\.status.isCurrent)
            .compactMap { lease -> RentRollRow? in
                guard let tenant = backend.tenantByID[lease.primaryTenantID],
                      let unit = backend.unitByID[lease.unitID],
                      let property = backend.propertyByID[lease.propertyID] else { return nil }

                let payments = backend.payments(for: lease.id)
                let charge = payments.first { $0.kind == .rent && $0.dueOn.startOfMonth == month }
                let rent = dollars(lease.rent)

                // A month the seed hasn't reached yet: rent falls due on the
                // lease's usual day, as long as the term covers it.
                let dueOn: Date
                if let charge {
                    dueOn = charge.dueOn
                } else {
                    let day = Calendar.current.component(.day, from: lease.term.start)
                    guard month > now.startOfMonth,
                          let projected = Calendar.current.date(byAdding: .day, value: day - 1, to: month),
                          projected >= lease.term.start, projected <= lease.term.end else { return nil }
                    dueOn = projected
                }

                let status: RentStatus
                let paid: Int
                switch charge?.status {
                case .paid:
                    status = .paid(on: charge?.paidAt ?? dueOn)
                    paid = rent
                case .failed, .scheduled, .processing, .unknown, .refunded, .none:
                    paid = 0
                    status = dueOn > now
                        ? .upcoming
                        : .overdue(daysLate: Calendar.current.dateComponents([.day], from: dueOn, to: now).day ?? 0)
                }

                // Earlier months' rent that never arrived.
                let arrears = payments
                    .filter { $0.kind == .rent && $0.status != .paid && $0.dueOn < month && $0.dueOn <= now }
                    .sorted { $0.dueOn < $1.dueOn }
                    .map { Arrear(month: $0.dueOn.startOfMonth, dueOn: $0.dueOn, amount: dollars($0.amount)) }

                return RentRollRow(
                    id: "\(lease.id.description)|\(month.timeIntervalSince1970)",
                    tenantID: tenant.id.description,
                    tenantName: tenant.fullName,
                    propertyName: property.name,
                    unitName: label(for: unit),
                    dueOn: dueOn,
                    amountDue: rent,
                    amountPaid: paid,
                    status: status,
                    usualMethod: method(from: payments.first(where: { $0.kind == .rent })?.method),
                    conversationID: conversationID(forTenant: tenant.id),
                    arrears: arrears
                )
            }
    }

    // MARK: - Ledger

    /// A tenant's current-lease account as seeded, oldest first, without
    /// running balances (the repository adds those after its overlay).
    static func ledger(forTenantID id: String) -> TenantLedger? {
        guard let tenant = backend.tenants.first(where: { $0.id.description == id }),
              let lease = backend.activeLease(for: tenant.id),
              let unit = backend.unitByID[lease.unitID],
              let property = backend.propertyByID[lease.propertyID] else { return nil }

        let now = Date()
        var entries: [LedgerEntry] = []

        for payment in backend.payments(for: lease.id).reversed() where payment.dueOn <= now {
            let amount = dollars(payment.amount)
            let base = payment.id.description

            switch payment.kind {
            case .rent:
                entries.append(LedgerEntry(
                    id: "\(base)-charge", date: payment.dueOn, kind: .rentCharge,
                    title: "\(payment.dueOn.formatted(.dateTime.month(.wide))) rent", amount: amount
                ))
                if payment.status == .paid {
                    let received = payment.paidAt ?? payment.dueOn
                    entries.append(LedgerEntry(
                        id: "\(base)-paid", date: received,
                        kind: .payment(method(from: payment.method)),
                        title: "Payment received", amount: -amount,
                        reference: payment.externalReference,
                        appliedOn: max(received, payment.dueOn)
                    ))
                } else if payment.status == .failed,
                          let reason = payment.failureReason, reason != "Payment not received" {
                    entries.append(LedgerEntry(
                        id: "\(base)-returned", date: payment.dueOn,
                        kind: .returned(reason: reason),
                        title: "Payment returned", amount: 0
                    ))
                }

            case .nsfFee:
                entries.append(LedgerEntry(
                    id: base, date: payment.dueOn, kind: .feeCharge,
                    title: "Returned payment charge", amount: amount
                ))

            // Deposits are held, not owed; the rest aren't part of rent.
            case .deposit, .lateFee, .utilities, .parking, .repairChargeback,
                 .refund, .reversal, .unknown:
                continue
            }
        }

        return TenantLedger(
            tenantID: id,
            tenantName: tenant.fullName,
            unitName: label(for: unit),
            propertyName: property.name,
            monthlyRent: dollars(lease.rent),
            depositHeld: dollars(lease.depositHeld),
            entries: entries,
            balance: 0,
            oldestUnpaidMonth: nil,
            conversationID: conversationID(forTenant: tenant.id)
        )
    }

    // MARK: Helpers

    private static func conversationID(forTenant id: Domain.Identifier<Domain.Tenant>) -> String? {
        backend.conversations
            .first { $0.participants.contains { $0.id == id.rawValue } }?
            .id.description
    }

    private static func method(from method: Domain.Payment.Method?) -> PaymentMethod {
        switch method {
        case .preAuthorizedDebit: .preAuthorizedDebit
        case .cheque: .cheque
        case .cash: .cash
        case .card: .card
        case .eTransfer, .unknown, .none: .eTransfer
        }
    }

    private static func dollars(_ money: Domain.Money) -> Int {
        Int(truncating: money.amount as NSDecimalNumber)
    }
}
