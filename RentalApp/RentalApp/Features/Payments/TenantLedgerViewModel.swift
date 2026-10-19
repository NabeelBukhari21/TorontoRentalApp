//
//  TenantLedgerViewModel.swift
//  RentalApp (Purrperty)
//
//  Payments — One tenant's account: every rent charge and payment, the
//  balance, and receipts for what they've paid.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class TenantLedgerViewModel {

    // MARK: Dependencies

    private let payments: PaymentRepositoryProtocol
    private let reminders: RentReminderSender
    /// Who issues receipts.
    private let landlordName: String
    let tenantID: String

    // MARK: State

    private(set) var ledger: TenantLedger?
    private(set) var loadError: AppError?

    init(tenantID: String, payments: PaymentRepositoryProtocol, reminders: RentReminderSender, landlordName: String) {
        self.tenantID = tenantID
        self.payments = payments
        self.reminders = reminders
        self.landlordName = landlordName
    }

    // MARK: Loading

    func load() async {
        do {
            ledger = try await payments.ledger(forTenantID: tenantID)
            loadError = nil
        } catch {
            loadError = error as? AppError ?? .unknown
        }
    }

    // MARK: Derived

    /// Rent is owing. (A balance that's only an NSF charge isn't rent, so
    /// it isn't recorded here and can't go on a Form N4.)
    var isOwing: Bool { ledger?.oldestUnpaidMonth != nil }

    var firstName: String {
        ledger?.tenantName.split(separator: " ").first.map(String.init) ?? "the tenant"
    }

    /// The month a new payment is recorded against: the oldest still owing.
    var monthToRecord: Date { ledger?.oldestUnpaidMonth ?? .now.startOfMonth }

    var canRemind: Bool { isOwing && ledger?.conversationID != nil }

    var reminderText: String {
        guard let ledger else { return "" }
        let month = monthToRecord
        let dueOn = ledger.entries.last { $0.kind == .rentCharge && $0.date.startOfMonth == month }?.date ?? month
        return RentReminderSender.message(
            firstName: firstName, owing: ledger.balance, oldestDueOn: dueOn, unitName: ledger.unitName
        )
    }

    // MARK: Intents

    /// Nil on success, or why it failed.
    func sendReminder() async -> String? {
        guard let ledger, let conversationID = ledger.conversationID else {
            return "No conversation with \(firstName) yet."
        }
        do {
            try await reminders.send(reminderText, toTenantID: tenantID, conversationID: conversationID, month: .now)
            return nil
        } catch {
            return (error as? AppError ?? .unknown).errorDescription
        }
    }

    func receipt(for entry: LedgerEntry) -> String {
        ledger?.receipt(for: entry, issuedBy: landlordName) ?? ""
    }
}
