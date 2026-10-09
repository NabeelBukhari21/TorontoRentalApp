//
//  CopilotRepository.swift
//  RentalApp (RentOS)
//
//  Repositories — Copilot intelligence source. Today it returns
//  authored analysis; a `RemoteCopilotRepository` calling a real model
//  conforms to the same protocol.
//

import Foundation

@MainActor
final class InMemoryCopilotRepository: CopilotRepositoryProtocol {

    private let cache: RepositoryCache

    init(cache: RepositoryCache = .shared) {
        self.cache = cache
    }

    private static let namespace = "copilot"

    func briefing(forceRefresh: Bool) async throws -> CopilotBriefing {
        // The copilot is the slowest surface in the app — it is doing
        // real analysis — so its simulated latency is deliberately the
        // longest, which is what the analyzing state on screen is for.
        try await Task.sleep(for: .milliseconds(900))
        try Task.checkCancellation()

        return await cache.fetch(key: Self.namespace, forceRefresh: forceRefresh) {
            CopilotBriefing(
                narrative: Self.narrative(),
                actions: Self.actions(),
                maintenanceInsights: Self.maintenanceInsights(),
                leaseInsights: Self.leaseInsights(),
                healthScore: 87,
                healthFactors: Self.healthFactors(),
                quickActions: Self.quickActions(),
                activity: Self.recentActivity()
            )
        }
    }

    func run(_ quickAction: AIQuickAction) async throws -> AIActivityEntry {
        try await Task.sleep(for: .seconds(1.1))
        return AIActivityEntry(icon: quickAction.icon, text: quickAction.logText, time: "Now")
    }

    // MARK: - Content

    private static func narrative() -> String {
        let summary = Projections.portfolioSummary()
        let counts = Projections.maintenanceCounts()
        let open = counts.filter { $0.kind != .success }.reduce(0) { $0 + $1.count }
        let urgent = Projections.tickets().filter { $0.priority == .urgent && $0.status != .done }.count
        let overdue = Projections.tenants().filter { $0.status == .overdue }.count
        let renewals = Projections.tenants().filter { $0.leaseProgress > 0.85 }.count

        return """
        Good morning. Portfolio occupancy is \(Int(summary.occupancyRate * 100))% across \
        \(summary.propertyCount) properties and \(summary.unitCount) units. \
        There are \(open) open maintenance requests, \(urgent) of them urgent. \
        \(overdue) tenant\(overdue == 1 ? " is" : "s are") behind on rent, and \
        \(renewals) lease\(renewals == 1 ? "" : "s") reach the renewal window within 60 days.
        """
    }

    private static func actions() -> [AIRecommendedAction] {
        var result: [AIRecommendedAction] = []

        if let late = Projections.tenants().first(where: { $0.status == .overdue }) {
            result.append(.init(
                icon: DS.Icons.payment, kind: .danger,
                title: "Send late-rent reminder",
                detail: "\(late.name) · \(late.unitName) · \(late.propertyName)",
                impact: "Recovers $\(late.rent)",
                acceptedLabel: "Reminder queued"
            ))
        }

        if let urgent = Projections.tickets().first(where: { $0.priority == .urgent && $0.status != .done }) {
            result.append(.init(
                icon: DS.Icons.maintenance, kind: .warning,
                title: "Confirm vendor for \(urgent.unitName)",
                detail: urgent.title,
                impact: "Resolves urgent request",
                acceptedLabel: "Visit confirmed"
            ))
        }

        if let renewal = Projections.tenants().first(where: { $0.leaseProgress > 0.85 }) {
            result.append(.init(
                icon: DS.Icons.lease, kind: .info,
                title: "Start renewal — \(renewal.name)",
                detail: "Lease ends \(renewal.leaseEnd) · \(renewal.onTimeRate)% on-time",
                impact: "Protects $\(renewal.rent * 12 / 1000)K/yr",
                acceptedLabel: "Renewal drafted"
            ))
        }

        result.append(.init(
            icon: "chart.line.uptrend.xyaxis", kind: .success,
            title: "Review under-market pricing",
            detail: "Several units sit below comparable listings",
            impact: "+$3.4K/yr potential",
            acceptedLabel: "Analysis saved"
        ))

        return result
    }

    private static func maintenanceInsights() -> [AIInsightRow] {
        let tickets = Projections.tickets()
        let open = tickets.filter { $0.status != .done }
        let topProperty = Dictionary(grouping: open, by: \.propertyName)
            .max { $0.value.count < $1.value.count }

        var rows: [AIInsightRow] = []

        if let topProperty, topProperty.value.count > 1 {
            rows.append(.init(
                icon: "drop.fill", kind: .warning,
                text: "\(topProperty.key) has \(topProperty.value.count) open requests — the highest in the portfolio. Worth a preventive inspection before winter."
            ))
        }

        rows.append(.init(
            icon: "timer", kind: .success,
            text: "Average resolution is 1.8 days — top quartile for portfolios of this size."
        ))
        rows.append(.init(
            icon: "person.badge.shield.checkmark.fill", kind: .info,
            text: "\(open.filter { $0.vendor == nil }.count) open requests have no vendor assigned yet."
        ))

        return rows
    }

    private static func leaseInsights() -> [AIInsightRow] {
        let tenants = Projections.tenants()
        let renewals = tenants.filter { $0.leaseProgress > 0.85 }
        let premium = tenants.filter { $0.isPremium }

        return [
            .init(icon: DS.Icons.lease, kind: .warning,
                  text: "\(renewals.count) leases reach renewal within 60 days. Renewals started early close 40% more often."),
            .init(icon: "chart.bar.fill", kind: .info,
                  text: "Portfolio average rent is $\(tenants.isEmpty ? 0 : tenants.reduce(0) { $0 + $1.rent } / tenants.count) across \(tenants.count) active tenancies."),
            .init(icon: "crown.fill", kind: .success,
                  text: "\(premium.count) tenants qualify for premium retention offers based on payment history.")
        ]
    }

    private static func healthFactors() -> [AIHealthFactor] {
        let summary = Projections.portfolioSummary()
        let tickets = Projections.tickets()
        let resolved = tickets.filter { $0.status == .done }.count
        let maintenanceScore = tickets.isEmpty ? 1.0 : Double(resolved) / Double(tickets.count)

        return [
            .init(name: "Occupancy", score: summary.occupancyRate,
                  kind: summary.occupancyRate > 0.9 ? .success : .warning),
            .init(name: "Collections", score: 0.96, kind: .success),
            .init(name: "Maintenance", score: maintenanceScore,
                  kind: maintenanceScore > 0.85 ? .success : .warning),
            .init(name: "Tenant sentiment", score: 0.91, kind: .success)
        ]
    }

    private static func quickActions() -> [AIQuickAction] {
        [
            .init(icon: "doc.badge.plus", title: "Draft renewal letter", logText: "Drafted renewal letter"),
            .init(icon: "text.append", title: "Summarize my week", logText: "Generated weekly operations summary"),
            .init(icon: "dollarsign.circle.fill", title: "Find savings", logText: "Scanned expenses — found $340/mo in savings"),
            .init(icon: DS.Icons.reports, title: "Generate report", logText: "Built portfolio report (PDF)")
        ]
    }

    private static func recentActivity() -> [AIActivityEntry] {
        let tickets = Projections.tickets().prefix(3)
        var entries: [AIActivityEntry] = tickets.map {
            .init(icon: DS.Icons.maintenance, text: "Classified \($0.title.lowercased())", time: $0.createdAgo)
        }
        entries.append(.init(icon: "chart.line.uptrend.xyaxis", text: "Reviewed portfolio pricing", time: "3h"))
        entries.append(.init(icon: DS.Icons.lease, text: "Built renewal pipeline", time: "6h"))
        return entries
    }
}
