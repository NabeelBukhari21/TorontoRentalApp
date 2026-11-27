//
//  CopilotAnswers.swift
//  RentalApp (Purrperty)
//
//  Repositories — Copilot's answers without a model: the questions
//  landlords ask most, answered from the workspace's own records, with
//  the names and numbers behind them. Anything it can't answer, it says
//  so, rather than guessing. A model-backed repository answers the same
//  questions through `PortfolioCopilotTask` once the backend is set up.
//

import Foundation

@MainActor
enum CopilotAnswers {

    /// What a question is about, judged by its words.
    enum Topic: CaseIterable {
        case owing, repairs, vacancy, renewals, income, occupancy
    }

    static func topic(of question: String) -> Topic? {
        let q = question.lowercased()
        func has(_ words: String...) -> Bool { words.contains { q.contains($0) } }
        if has("owe", "owing", "paid", "pay ", "late", "behind", "arrear", "overdue", "collect") { return .owing }
        if has("repair", "urgent", "maintenance", "fix", "broken", "leak", "ticket", "request") { return .repairs }
        if has("vacan", "empty", "available", "unrented", "unit free", "free unit") { return .vacancy }
        if has("lease", "renew", "expir", "ending", "move out", "move-out") { return .renewals }
        if has("revenue", "income", "earn", "make a month", "money", "cash") { return .income }
        if has("occupan", "rented", "full") { return .occupancy }
        return nil
    }

    static func answer(_ question: String, now: Date = .now) -> String {
        if let topic = topic(of: question) { return answer(topic, now: now) }
        if let named = aboutAProperty(question) { return named }
        if let named = aboutATenant(question, now: now) { return named }
        return """
            I can't answer that from your records yet. Ask me who owes rent, \
            which repairs are urgent, which units are empty, whose lease is \
            ending, or about a property or tenant by name.
            """
    }

    static func answer(_ topic: Topic, now: Date = .now) -> String {
        switch topic {
        case .owing:
            let owing = Projections.rentRoll(month: now).filter(\.isOwing).sorted { $0.totalOwing > $1.totalOwing }
            guard !owing.isEmpty else { return "Everyone has paid this month. Nobody owes anything from before either." }
            let total = owing.reduce(0) { $0 + $1.totalOwing }
            let names = owing.prefix(3).map { "\($0.tenantName) (\(cad($0.totalOwing)), \($0.unitName) at \($0.propertyName))" }
            let more = owing.count > 3 ? ", and \(owing.count - 3) more" : ""
            return "\(owing.count) \(owing.count == 1 ? "tenant owes" : "tenants owe") \(cad(total)) in all: \(list(names))\(more). Ontario doesn't allow late fees, so a reminder from Rent is the next step."

        case .repairs:
            let open = Projections.tickets().filter { $0.status != .done }
            guard !open.isEmpty else { return "No repairs are open. Everything reported has been fixed." }
            let urgent = open.filter { $0.priority == .urgent }
            let unassigned = open.filter { $0.vendor == nil }.count
            if urgent.isEmpty {
                return "\(open.count) repairs are open and none are urgent. \(unassigned) still need a vendor."
            }
            let worst = urgent.prefix(3).map { "\($0.title.lowercased()) at \($0.propertyName)" }
            return "\(open.count) repairs are open, \(urgent.count) urgent: \(list(worst))\(urgent.count > 3 ? ", and more" : ""). \(unassigned) of the open ones still need a vendor."

        case .vacancy:
            let vacant = Projections.vacantUnits()
            guard !vacant.isEmpty else { return "Every unit is rented." }
            let byHome = Dictionary(grouping: vacant, by: \.propertyName).sorted { $0.value.count > $1.value.count }
            let homes = byHome.prefix(3).map { "\($0.value.count) at \($0.key)" }
            let asking = vacant.reduce(0) { $0 + $1.marketRent }
            return "\(vacant.count) \(vacant.count == 1 ? "unit is" : "units are") empty: \(list(homes))\(byHome.count > 3 ? ", and others" : ""). At asking rent that's \(cad(asking)) a month not coming in."

        case .renewals:
            let due = Projections.tenants().filter(\.isRenewalDue)
            guard !due.isEmpty else { return "No leases end in the next 60 days." }
            let names = due.prefix(4).map { "\($0.name) (\($0.unitName), ends \($0.leaseEnd))" }
            return "\(due.count) \(due.count == 1 ? "lease ends" : "leases end") within 60 days: \(list(names))\(due.count > 4 ? ", and more" : ""). Renew from each tenant's page; it checks the increase against Ontario's guideline."

        case .income:
            let summary = Projections.portfolioSummary()
            let roll = Projections.rentRoll(month: now)
            let collected = roll.reduce(0) { $0 + $1.amountPaid }
            let expected = roll.reduce(0) { $0 + $1.amountDue }
            return "Your homes bring in about \(cad(Int(summary.monthlyRevenue * 1000))) a month. This month \(cad(collected)) of \(cad(expected)) has been collected."

        case .occupancy:
            let summary = Projections.portfolioSummary()
            return "\(summary.occupiedUnits) of \(summary.unitCount) units are rented (\(Int((summary.occupancyRate * 100).rounded()))%) across \(summary.propertyCount) properties. \(summary.vacantUnits) are empty."
        }
    }

    /// A question naming one of the properties.
    private static func aboutAProperty(_ question: String) -> String? {
        let q = question.lowercased()
        guard let property = Projections.properties().first(where: { q.contains($0.name.lowercased()) }) else { return nil }
        let repairs = property.openRequests == 0 ? "no open repairs" : "\(property.openRequests) open repairs\(property.urgentRequests > 0 ? ", \(property.urgentRequests) urgent" : "")"
        return "\(property.name) in \(property.neighborhood) has \(property.occupiedCount) of \(property.unitCount) units rented, brings in about \(cad(Int(property.monthlyRevenue * 1000))) a month, and has \(repairs)."
    }

    /// A question naming one of the tenants.
    private static func aboutATenant(_ question: String, now: Date) -> String? {
        let q = question.lowercased()
        guard let tenant = Projections.tenants().first(where: { tenant in
            let parts = tenant.name.lowercased().split(separator: " ")
            return q.contains(tenant.name.lowercased()) || parts.count > 1 && parts.allSatisfy { q.contains($0) }
        }) else { return nil }
        let row = Projections.rentRoll(month: now).first { $0.tenantID == tenant.id }
        let owes = row.map { $0.isOwing ? "owes \(cad($0.totalOwing))" : "is paid up this month" } ?? "has no rent this month"
        return "\(tenant.name) rents \(tenant.unitName) at \(tenant.propertyName) for \(cad(tenant.rent)) a month, \(owes), and pays on time \(tenant.onTimeRate)% of the time. The lease ends \(tenant.leaseEnd)."
    }

    private static func cad(_ amount: Int) -> String {
        amount.formatted(.currency(code: "CAD").precision(.fractionLength(0)).presentation(.narrow))
    }

    private static func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and))
    }
}
