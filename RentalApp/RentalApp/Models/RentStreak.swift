//
//  RentStreak.swift
//  RentalApp (Purrperty)
//
//  Payments — How many months in a row every tenant's rent arrived on or
//  before its due date, worked out from the rent roll. Nothing is
//  estimated: a month with any late, partial or missing rent ends it.
//

import Foundation

struct RentStreak: Equatable, Sendable {

    /// One month, newest last.
    struct Month: Identifiable, Equatable, Sendable {
        let month: Date
        let isOnTime: Bool
        var id: Date { month }
    }

    /// Months in a row, up to now.
    let count: Int
    /// The last few months that had rent due, oldest first.
    let months: [Month]

    static let none = RentStreak(count: 0, months: [])

    /// Looks back this far at most.
    static let window = 12

    /// What a roll says about its month. Nil while nothing is settled: no
    /// rent was due, or some of it still isn't.
    static func verdict(on roll: RentRoll, calendar: Calendar = .current) -> Bool? {
        guard !roll.rows.isEmpty else { return nil }
        var isWaiting = false
        for row in roll.rows {
            switch row.status {
            case .paid(let on):
                if calendar.startOfDay(for: on) > calendar.startOfDay(for: row.dueOn) { return false }
            case .upcoming: isWaiting = true
            case .partial:
                // Part paid before it's due is fine; after, it's late.
                if calendar.startOfDay(for: row.dueOn) < calendar.startOfDay(for: .now) { return false }
                isWaiting = true
            case .overdue: return false
            }
        }
        return isWaiting ? nil : true
    }

    @MainActor
    static func load(from payments: PaymentRepositoryProtocol, now: Date = .now, calendar: Calendar = .current) async -> RentStreak {
        var months: [Month] = []
        for back in 0..<window {
            guard let date = calendar.date(byAdding: .month, value: -back, to: now.startOfMonth),
                  let roll = try? await payments.rentRoll(for: date, forceRefresh: false) else { break }
            guard let onTime = verdict(on: roll) else {
                // This month may still be coming in; before that, an empty
                // month is where the records start.
                if back == 0 { continue } else { break }
            }
            months.append(Month(month: date, isOnTime: onTime))
        }
        return RentStreak(count: months.prefix { $0.isOnTime }.count, months: months.reversed())
    }
}
