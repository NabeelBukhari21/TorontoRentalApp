//
//  PaymentRepository.swift
//  RentalApp (Purrperty)
//
//  Repositories — Rent rolls, ledgers and recorded payments.
//
//  Payments recorded in the app are held as an overlay on the seeded
//  history, like the property and lease overlays: the roll and the ledger
//  both read seed + overlay, so they always agree.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class InMemoryPaymentRepository: PaymentRepositoryProtocol {

    /// A payment recorded in the app.
    private struct Recorded {
        let id: String
        let tenantID: String
        let month: Date
        let amount: Int
        let method: PaymentMethod
        let receivedOn: Date
        let reference: String?
        let note: String?
    }

    private var recorded: [Recorded] = []
    /// Tenant id + month → when a reminder went out.
    private var reminders: [String: Date] = [:]

    // MARK: Reads

    func rentRoll(for month: Date, forceRefresh: Bool) async throws -> RentRoll {
        try await SimulatedLatency.wait(.list)
        let month = month.startOfMonth
        let rows = Projections.rentRoll(month: month)
            .map { applyingOverlay(to: $0, month: month) }
            .sorted(by: Self.needsAttentionFirst)
        return RentRoll(month: month, rows: rows)
    }

    func ledger(forTenantID id: String) async throws -> TenantLedger {
        try await SimulatedLatency.wait(.detail)
        guard let seeded = Projections.ledger(forTenantID: id) else {
            throw AppError.notFound("Account")
        }

        let added = recorded.filter { $0.tenantID == id }.map { payment in
            LedgerEntry(
                id: payment.id,
                date: payment.receivedOn,
                kind: .payment(payment.method),
                title: "Payment received",
                amount: -payment.amount,
                reference: payment.reference,
                note: payment.note
            )
        }
        // The oldest month owing comes from the rent roll, which attributes
        // each payment to the month it was for, so the two screens agree.
        let oldestOwing = Projections.rentRoll(month: .now)
            .first { $0.tenantID == id }
            .map { applyingOverlay(to: $0, month: Date.now.startOfMonth) }?
            .oldestOwingMonth
        return Self.settle(seeded, adding: added, oldestOwing: oldestOwing)
    }

    /// Owing first, then by this month's status, then by name.
    private static func needsAttentionFirst(_ lhs: RentRollRow, _ rhs: RentRollRow) -> Bool {
        if lhs.isOwing != rhs.isOwing { return lhs.isOwing }
        if lhs.status.urgency != rhs.status.urgency { return lhs.status.urgency < rhs.status.urgency }
        return lhs.tenantName < rhs.tenantName
    }

    // MARK: Writes

    func record(_ draft: PaymentDraft) async throws -> LedgerEntry {
        let month = draft.month.startOfMonth
        guard let row = Projections.rentRoll(month: month)
            .first(where: { $0.tenantID == draft.tenantID })
            .map({ applyingOverlay(to: $0, month: month) }) else {
            throw AppError.notFound("Rent for \(month.monthTitle)")
        }
        try Self.validate(draft, against: row)
        try await SimulatedLatency.wait(.write)

        let reference = draft.reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let payment = Recorded(
            id: "pay-\(UUID().uuidString.lowercased())",
            tenantID: draft.tenantID,
            month: month,
            amount: draft.amount,
            method: draft.method,
            receivedOn: draft.receivedOn,
            reference: reference.isEmpty ? nil : reference,
            note: note.isEmpty ? nil : note
        )
        recorded.append(payment)

        return LedgerEntry(
            id: payment.id,
            date: payment.receivedOn,
            kind: .payment(payment.method),
            title: "Payment received",
            amount: -payment.amount,
            reference: payment.reference,
            note: payment.note
        )
    }

    func noteReminder(forTenantID id: String, month: Date) async throws {
        reminders[Self.key(id, month.startOfMonth)] = .now
    }

    // MARK: Rules

    /// The checks the payments table enforces.
    private static func validate(_ draft: PaymentDraft, against row: RentRollRow) throws {
        guard draft.amount > 0 else {
            throw AppError.validation("Enter the amount received.")
        }
        guard draft.amount <= row.outstanding else {
            throw AppError.validation(row.outstanding == 0
                ? "\(row.dueOn.monthTitle) rent is already paid."
                : "That's more than the \(row.outstanding.formatted(.cad)) still owing for \(row.dueOn.monthTitle).")
        }
        guard draft.receivedOn <= .now else {
            throw AppError.validation("The date received can't be in the future.")
        }
    }

    // MARK: Overlay

    private func applyingOverlay(to row: RentRollRow, month: Date) -> RentRollRow {
        let payments = recorded.filter { $0.tenantID == row.tenantID && $0.month == month }
        var updated = row
        updated.remindedAt = reminders[Self.key(row.tenantID, month)]
        // Payments recorded against earlier months settle those arrears.
        updated.arrears = row.arrears.compactMap { arrear in
            let paid = recorded
                .filter { $0.tenantID == row.tenantID && $0.month == arrear.month }
                .reduce(0) { $0 + $1.amount }
            let left = arrear.amount - paid
            return left > 0 ? Arrear(month: arrear.month, dueOn: arrear.dueOn, amount: left) : nil
        }
        guard !payments.isEmpty else { return updated }

        let paid = min(row.amountPaid + payments.reduce(0) { $0 + $1.amount }, row.amountDue)
        let lastReceived = payments.map(\.receivedOn).max() ?? .now
        let status: RentStatus = paid >= row.amountDue ? .paid(on: lastReceived) : .partial(paid: paid)

        return RentRollRow(
            id: row.id, tenantID: row.tenantID, tenantName: row.tenantName,
            propertyName: row.propertyName, unitName: row.unitName,
            dueOn: row.dueOn, amountDue: row.amountDue, amountPaid: paid,
            status: status, usualMethod: row.usualMethod,
            conversationID: row.conversationID, remindedAt: updated.remindedAt,
            arrears: updated.arrears
        )
    }

    /// Adds payments, orders the account by when each entry takes effect,
    /// and works out running balances.
    private static func settle(_ ledger: TenantLedger, adding added: [LedgerEntry], oldestOwing: Date?) -> TenantLedger {
        var entries = (ledger.entries + added).sorted(by: Self.inAccountOrder)

        var balance = 0
        for index in entries.indices {
            balance += entries[index].amount
            entries[index].balanceAfter = balance
        }

        return TenantLedger(
            tenantID: ledger.tenantID,
            tenantName: ledger.tenantName,
            unitName: ledger.unitName,
            propertyName: ledger.propertyName,
            monthlyRent: ledger.monthlyRent,
            depositHeld: ledger.depositHeld,
            entries: entries.reversed(),
            balance: balance,
            oldestUnpaidMonth: balance > 0 ? oldestOwing : nil,
            conversationID: ledger.conversationID
        )
    }

    /// When each entry takes effect; charges before payments on the same day.
    private static func inAccountOrder(_ lhs: LedgerEntry, _ rhs: LedgerEntry) -> Bool {
        let left = lhs.appliedOn ?? lhs.date
        let right = rhs.appliedOn ?? rhs.date
        if left != right { return left < right }
        return !lhs.isPayment && rhs.isPayment
    }

    private static func key(_ tenantID: String, _ month: Date) -> String {
        "\(tenantID)|\(month.timeIntervalSince1970)"
    }
}
