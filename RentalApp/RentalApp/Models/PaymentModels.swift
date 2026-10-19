//
//  PaymentModels.swift
//  RentalApp (Purrperty)
//
//  Payments — The month's rent roll, a tenant's ledger, and what the
//  record-payment form collects.
//
//  Amounts are whole dollars. Purrperty records money a landlord has
//  received; it doesn't move money itself.
//

import Foundation

// MARK: - Method

/// How a tenant paid. Mirrors `Domain.Payment.Method` without `.unknown`,
/// which a person never picks.
enum PaymentMethod: String, CaseIterable, Identifiable, Sendable {
    case eTransfer = "Interac e-Transfer"
    case preAuthorizedDebit = "Pre-authorized debit"
    case cheque = "Cheque"
    case cash = "Cash"
    case card = "Card"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .eTransfer: "arrow.left.arrow.right.circle"
        case .preAuthorizedDebit: "building.columns"
        case .cheque: "doc.text"
        case .cash: "banknote"
        case .card: "creditcard"
        }
    }

    /// What the reference field asks for.
    var referencePrompt: String {
        switch self {
        case .eTransfer: "Reference number"
        case .preAuthorizedDebit: "Transaction ID"
        case .cheque: "Cheque number"
        case .cash: "Receipt number"
        case .card: "Authorization code"
        }
    }

    /// Analytics value — a closed set, never free text.
    var analyticsValue: String {
        switch self {
        case .eTransfer: "e_transfer"
        case .preAuthorizedDebit: "pad"
        case .cheque: "cheque"
        case .cash: "cash"
        case .card: "card"
        }
    }
}

// MARK: - Rent Status

/// Where one month's rent stands for one tenant.
enum RentStatus: Equatable, Sendable {
    case paid(on: Date)
    case partial(paid: Int)
    /// Not due yet.
    case upcoming
    case overdue(daysLate: Int)

    var isOutstanding: Bool {
        switch self {
        case .paid, .upcoming: false
        case .partial, .overdue: true
        }
    }

    /// Sort order for the roll: what needs attention first.
    var urgency: Int {
        switch self {
        case .overdue: 0
        case .partial: 1
        case .upcoming: 2
        case .paid: 3
        }
    }
}

// MARK: - Rent Roll

/// One earlier month's rent that's still owing.
struct Arrear: Sendable, Equatable {
    let month: Date
    let dueOn: Date
    let amount: Int
}

/// One tenant's rent for the month.
struct RentRollRow: Identifiable, Sendable, Equatable {
    /// Lease id plus month, so a tenant appears once per month.
    let id: String
    let tenantID: String
    let tenantName: String
    let propertyName: String
    let unitName: String
    let dueOn: Date
    let amountDue: Int
    let amountPaid: Int
    let status: RentStatus
    /// How they usually pay, for the record form's default.
    let usualMethod: PaymentMethod
    /// Their message thread, when one exists; reminders go there.
    let conversationID: String?
    /// When a reminder was last sent for this month.
    var remindedAt: Date?
    /// Rent still owing from earlier months, oldest first.
    var arrears: [Arrear] = []

    /// Still owing for this month.
    var outstanding: Int { max(amountDue - amountPaid, 0) }
    var arrearsTotal: Int { arrears.reduce(0) { $0 + $1.amount } }
    /// Everything owing, this month included once it's due.
    var totalOwing: Int { (status.isOutstanding ? outstanding : 0) + arrearsTotal }
    var isOwing: Bool { totalOwing > 0 }

    /// The month a payment should go against: the oldest still owing.
    var oldestOwingMonth: Date? {
        arrears.first?.month ?? (status.isOutstanding ? dueOn.startOfMonth : nil)
    }

    var firstName: String {
        tenantName.split(separator: " ").first.map(String.init) ?? tenantName
    }
}

/// The month at a glance.
struct RentRoll: Sendable, Equatable {
    let month: Date
    let rows: [RentRollRow]

    var expected: Int { rows.reduce(0) { $0 + $1.amountDue } }
    var collected: Int { rows.reduce(0) { $0 + min($1.amountPaid, $1.amountDue) } }
    /// This month's rent that's due and unpaid.
    var outstanding: Int { rows.filter(\.status.isOutstanding).reduce(0) { $0 + $1.outstanding } }
    /// Rent still owing from earlier months.
    var arrears: Int { rows.reduce(0) { $0 + $1.arrearsTotal } }
    var owingCount: Int { rows.filter(\.isOwing).count }

    var collectionRate: Double {
        expected == 0 ? 0 : Double(collected) / Double(expected)
    }

    static func empty(_ month: Date) -> RentRoll { RentRoll(month: month, rows: []) }
}

// MARK: - Ledger

/// One line of a tenant's account: something charged or something paid.
struct LedgerEntry: Identifiable, Sendable, Equatable {

    enum Kind: Sendable, Equatable {
        case rentCharge
        /// An NSF administration charge for a returned payment.
        case feeCharge
        case payment(PaymentMethod)
        /// A payment that came back (NSF, returned debit).
        case returned(reason: String)
    }

    let id: String
    let date: Date
    let kind: Kind
    let title: String
    /// Positive increases what the tenant owes; negative reduces it.
    let amount: Int
    var reference: String?
    var note: String?
    /// When the entry takes effect on the account. A payment that arrives
    /// before rent is due is applied on the due date, so it sits after the
    /// charge it pays. Defaults to `date`.
    var appliedOn: Date?
    /// What's owed after this entry, oldest first.
    var balanceAfter: Int = 0

    var isPayment: Bool {
        if case .payment = kind { true } else { false }
    }
}

/// A tenant's account: entries newest first, plus the totals that matter.
struct TenantLedger: Sendable, Equatable {
    let tenantID: String
    let tenantName: String
    let unitName: String
    let propertyName: String
    let monthlyRent: Int
    let depositHeld: Int
    let entries: [LedgerEntry]
    /// What's owed now. Zero or less means up to date.
    let balance: Int
    /// The oldest month with rent still owing, if any.
    let oldestUnpaidMonth: Date?
    let conversationID: String?
}

extension TenantLedger {

    /// A plain-text receipt for a payment. Ontario landlords must give one
    /// free when a tenant asks (RTA s. 109); tenants can share their own.
    func receipt(for entry: LedgerEntry, issuedBy landlord: String) -> String {
        guard case .payment(let method) = entry.kind else { return "" }
        var lines = [
            "Rent receipt",
            "",
            "Received from: \(tenantName)",
            "Rental unit: \(unitName), \(propertyName)",
            "Amount: \((-entry.amount).formatted(.currency(code: "CAD")))",
            "Date received: \(entry.date.formatted(date: .long, time: .omitted))",
            "Method: \(method.rawValue)"
        ]
        if let reference = entry.reference { lines.append("Reference: \(reference)") }
        if let note = entry.note { lines.append("Note: \(note)") }
        lines += ["", "Issued by \(landlord)"]
        return lines.joined(separator: "\n")
    }
}

// MARK: - Draft

/// What the record-payment form collects.
struct PaymentDraft: Sendable, Equatable {
    var tenantID: String
    /// The month's rent this payment is for.
    var month: Date
    var amount: Int
    var method: PaymentMethod
    var receivedOn: Date = .now
    var reference = ""
    var note = ""
}

// MARK: - Months

extension Date {
    /// Midnight on the first of this date's month.
    var startOfMonth: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? self
    }

    /// "October 2026".
    var monthTitle: String {
        formatted(.dateTime.month(.wide).year())
    }
}
