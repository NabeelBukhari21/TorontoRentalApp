//
//  LeaseModels.swift
//  RentalApp (Purrperty)
//
//  Leasing — A tenant's current agreement with real dates and amounts,
//  the units they could move to, and the Ontario rules the renewal and
//  move forms explain.
//

import Foundation

// MARK: - Term

enum LeaseTermKind: String, CaseIterable, Identifiable, Sendable {
    case fixedTerm = "Fixed term"
    case monthToMonth = "Month-to-month"

    var id: String { rawValue }
}

// MARK: - Lease Summary

/// The agreement a tenant is on now. `Tenant` carries display strings;
/// this carries what a form needs to change it.
struct LeaseSummary: Sendable, Equatable {
    let leaseID: String
    let tenantID: String
    let propertyID: String
    let propertyName: String
    let unitID: String
    let unitName: String
    let start: Date
    /// Nil for a month-to-month tenancy.
    let end: Date?
    let kind: LeaseTermKind
    /// Monthly rent, whole dollars.
    let rent: Int
    /// Last month's rent deposit held, whole dollars.
    let deposit: Int
    /// True when the unit was first lived in after 15 Nov 2018, which
    /// exempts it from Ontario's rent-increase guideline.
    let isRentControlExempt: Bool

    var termText: String {
        let start = start.formatted(.dateTime.month(.abbreviated).year())
        guard let end else { return "\(start) – month-to-month" }
        return "\(start) – \(end.formatted(.dateTime.month(.abbreviated).year()))"
    }
}

// MARK: - Unit Option

/// A vacant unit a tenant could move into.
struct VacantUnit: Identifiable, Sendable, Hashable {
    let id: String
    let propertyID: String
    let propertyName: String
    let unitName: String
    let bedrooms: Int
    /// Asking rent, whole dollars.
    let marketRent: Int
}

// MARK: - Ontario Rules

/// The parts of Ontario's Residential Tenancies Act the lease forms
/// explain. Kept in one place so they're easy to check and update each
/// summer, when the next year's guideline is published.
enum OntarioTenancyRules {

    /// The annual rent-increase guideline, in percent, by the year the
    /// increase takes effect.
    static let guidelinePercent: [Int: Double] = [
        2024: 2.5,
        2025: 2.5,
        2026: 2.1
    ]

    /// The most a landlord can charge for a returned cheque or debit, on top
    /// of the bank's own charges.
    static let maximumNSFCharge: Decimal = 20

    /// Days between serving Form N4 (unpaid rent) and the earliest
    /// termination date it can give, for a monthly tenancy.
    static let n4NoticeDays = 14

    /// Hours of written notice before entering a rental unit (RTA s. 27).
    static let entryNoticeHours = 24
    /// Entry with notice must be between these hours.
    static let entryWindow = 8..<20

    /// Why a visit at `date` can't go ahead as booked, or nil when it can.
    /// Notice isn't needed in an emergency or when the tenant has agreed to
    /// entry.
    static func entryProblem(at date: Date, now: Date = .now, tenantConsented: Bool, isEmergency: Bool) -> String? {
        guard !tenantConsented, !isEmergency else { return nil }
        let earliest = now.addingTimeInterval(TimeInterval(entryNoticeHours * 3600))
        if date < earliest {
            return "The tenant needs \(entryNoticeHours) hours' written notice. Choose \(earliest.formatted(date: .abbreviated, time: .shortened)) or later."
        }
        let hour = Calendar.current.component(.hour, from: date)
        if !entryWindow.contains(hour) {
            return "With notice, entry has to be between 8 a.m. and 8 p.m."
        }
        return nil
    }

    /// Written notice (Form N1) needed before a rent increase.
    static let increaseNoticeDays = 90

    /// The guideline for an increase taking effect on `date`, when known.
    static func guideline(for date: Date) -> Double? {
        guidelinePercent[Calendar.current.component(.year, from: date)]
    }

    /// A rent deposit can only cover the last month's rent, so it can't be
    /// more than one month's rent. Returns what can be carried to a new
    /// lease at `newRent`, and what has to be refunded.
    static func carriedDeposit(_ deposit: Int, newRent: Int) -> (carried: Int, refund: Int) {
        let carried = min(deposit, newRent)
        return (carried, deposit - carried)
    }

    /// The highest rent within the guideline, rounded down to the dollar.
    static func maximumRent(from current: Int, guideline: Double) -> Int {
        Int((Double(current) * (1 + guideline / 100)).rounded(.down))
    }
}
