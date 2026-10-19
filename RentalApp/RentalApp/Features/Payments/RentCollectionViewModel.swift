//
//  RentCollectionViewModel.swift
//  RentalApp (Purrperty)
//
//  Payments — The month's rent roll: who has paid, who hasn't, and what's
//  still outstanding.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class RentCollectionViewModel {

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case outstanding = "Owing"
        case upcoming = "Upcoming"
        case paid = "Paid"

        var id: String { rawValue }

        func includes(_ row: RentRollRow) -> Bool {
            switch self {
            case .all: true
            case .outstanding: row.isOwing
            case .upcoming: row.status == .upcoming
            case .paid: if case .paid = row.status { true } else { false }
            }
        }
    }

    // MARK: Dependencies

    private let payments: PaymentRepositoryProtocol
    private let reminders: RentReminderSender

    // MARK: State

    private(set) var roll: RentRoll
    private(set) var isLoading = false
    private(set) var loadError: AppError?
    var month: Date {
        didSet { if oldValue != month { Task { await load() } } }
    }
    var filter: Filter = .all
    var searchText = ""

    init(payments: PaymentRepositoryProtocol, reminders: RentReminderSender) {
        self.payments = payments
        self.reminders = reminders
        let month = Date.now.startOfMonth
        self.month = month
        self.roll = .empty(month)
    }

    // MARK: Derived

    /// The last six months and next month, newest first.
    var monthOptions: [Date] {
        (-1...6).compactMap { Calendar.current.date(byAdding: .month, value: -$0, to: Date.now.startOfMonth) }
    }

    var visibleRows: [RentRollRow] {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        return roll.rows.filter { row in
            filter.includes(row)
                && (term.isEmpty
                    || row.tenantName.localizedCaseInsensitiveContains(term)
                    || row.unitName.localizedCaseInsensitiveContains(term)
                    || row.propertyName.localizedCaseInsensitiveContains(term))
        }
    }

    func count(for filter: Filter) -> Int {
        roll.rows.filter { filter.includes($0) }.count
    }

    // MARK: Loading

    func load() async {
        isLoading = roll.rows.isEmpty || roll.month != month
        defer { isLoading = false }
        do {
            roll = try await payments.rentRoll(for: month, forceRefresh: false)
            loadError = nil
        } catch {
            loadError = error as? AppError ?? .unknown
        }
    }

    // MARK: Reminders

    /// Owing, with a thread to send into. Owing without one, the reminder
    /// is shared instead (Messages, Mail).
    func canRemind(_ row: RentRollRow) -> Bool {
        row.isOwing && row.conversationID != nil
    }

    func canShareReminder(_ row: RentRollRow) -> Bool {
        row.isOwing && row.conversationID == nil
    }

    func reminderText(for row: RentRollRow) -> String {
        RentReminderSender.message(
            firstName: row.firstName, owing: row.totalOwing,
            oldestDueOn: row.arrears.first?.dueOn ?? row.dueOn, unitName: row.unitName
        )
    }

    /// Nil on success, or why it failed.
    func sendReminder(to row: RentRollRow) async -> String? {
        guard let conversationID = row.conversationID else { return "No conversation with \(row.firstName) yet." }
        do {
            try await reminders.send(reminderText(for: row), toTenantID: row.tenantID, conversationID: conversationID, month: roll.month)
            await load()
            return nil
        } catch {
            return (error as? AppError ?? .unknown).errorDescription
        }
    }
}
