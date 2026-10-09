//
//  DashboardMockData.swift
//  RentalApp
//
//  Dashboard — Presentation models + realistic mock data.
//  These are view-layer models; real domain models and a data service
//  will replace the `.mock` factories without touching the views.
//

import SwiftUI

// MARK: - Models

/// Portfolio-level figures shown across the dashboard header and hero.
struct PortfolioSummary {
    let greetingName: String
    let portfolioValue: String
    let monthlyRevenue: Double // $K
    let revenueTrend: String
    let propertyCount: Int
    let unitCount: Int
    let occupancyRate: Double
    let occupiedUnits: Int
    let vacantUnits: Int
    let turnoverUnits: Int
}

struct RevenuePoint: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double // in $K
}

struct DashboardStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let gradient: LinearGradient
    let trend: String
    let trendKind: DSStatusKind
}

struct AIInsight: Identifiable {
    let id = UUID()
    let icon: String
    let kind: DSStatusKind
    let title: String
    let message: String
    let actionTitle: String
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let icon: String
    let kind: DSStatusKind
    let title: String
    let subtitle: String
    let time: String
    let isNew: Bool
}

struct UpcomingTask: Identifiable {
    let id = UUID()
    let title: String
    let due: String
    let icon: String
    let isUrgent: Bool
    var isDone: Bool = false
}

struct MaintenanceStatusCount: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let kind: DSStatusKind
}

// MARK: - Mock Data

enum DashboardMockData {

    static let revenue: [RevenuePoint] = [
        RevenuePoint(month: "Dec", amount: 44.2),
        RevenuePoint(month: "Jan", amount: 45.1),
        RevenuePoint(month: "Feb", amount: 46.8),
        RevenuePoint(month: "Mar", amount: 46.2),
        RevenuePoint(month: "Apr", amount: 48.5),
        RevenuePoint(month: "May", amount: 49.8),
        RevenuePoint(month: "Jun", amount: 51.2),
        RevenuePoint(month: "Jul", amount: 52.4)
    ]

    static let stats: [DashboardStat] = [
        DashboardStat(
            title: "Occupancy",
            value: "94%",
            icon: DS.Icons.occupancy,
            gradient: DS.Gradients.brand,
            trend: "+2.1%",
            trendKind: .success
        ),
        DashboardStat(
            title: "Open Requests",
            value: "7",
            icon: DS.Icons.maintenance,
            gradient: DS.Gradients.warm,
            trend: "2 urgent",
            trendKind: .danger
        ),
        DashboardStat(
            title: "Rent Collected",
            value: "96%",
            icon: DS.Icons.payment,
            gradient: DS.Gradients.success,
            trend: "July",
            trendKind: .info
        ),
        DashboardStat(
            title: "Active Tenants",
            value: "45",
            icon: DS.Icons.tenants,
            gradient: DS.Gradients.ai,
            trend: "+3",
            trendKind: .success
        )
    ]

    static let insights: [AIInsight] = [
        AIInsight(
            icon: DS.Icons.lease,
            kind: .warning,
            title: "3 leases renew next month",
            message: "Sarah Chen, Marcus Johnson, and Priya Patel are up for renewal in August. Starting early improves retention by 40%.",
            actionTitle: "Draft renewals"
        ),
        AIInsight(
            icon: "wrench.fill",
            kind: .danger,
            title: "Water heater nearing end of life",
            message: "Maple Duplex's water heater is 11 years old with 2 recent service calls. Replacing now avoids an emergency in winter.",
            actionTitle: "Get quotes"
        ),
        AIInsight(
            icon: "chart.line.uptrend.xyaxis",
            kind: .success,
            title: "Queen West rents 6% under market",
            message: "Comparable 1-bedrooms in the area lease for $2,340. Two upcoming vacancies are a chance to adjust.",
            actionTitle: "See analysis"
        )
    ]

    static let maintenanceCounts: [MaintenanceStatusCount] = [
        MaintenanceStatusCount(label: "New", count: 3, kind: .info),
        MaintenanceStatusCount(label: "In Progress", count: 2, kind: .warning),
        MaintenanceStatusCount(label: "Scheduled", count: 2, kind: .neutral),
        MaintenanceStatusCount(label: "Done this week", count: 5, kind: .success)
    ]

    static let tasks: [UpcomingTask] = [
        UpcomingTask(
            title: "Unit 304 plumbing — vendor visit",
            due: "Today, 2:00 PM",
            icon: "wrench.fill",
            isUrgent: true
        ),
        UpcomingTask(
            title: "Annual inspection · Danforth Triplex",
            due: "Thu, 10:00 AM",
            icon: "checklist",
            isUrgent: false
        ),
        UpcomingTask(
            title: "Lease renewal — Sarah Chen",
            due: "Fri",
            icon: DS.Icons.lease,
            isUrgent: false
        ),
        UpcomingTask(
            title: "Send August rent reminders",
            due: "Jul 29",
            icon: DS.Icons.payment,
            isUrgent: false
        )
    ]

    static let activity: [ActivityItem] = [
        ActivityItem(
            icon: DS.Icons.payment,
            kind: .success,
            title: "Rent payment received",
            subtitle: "Unit 12 · Queen West Lofts · $2,180",
            time: "2m",
            isNew: true
        ),
        ActivityItem(
            icon: DS.Icons.maintenance,
            kind: .danger,
            title: "New urgent request",
            subtitle: "Water leak · Unit 304 · Maple Duplex",
            time: "26m",
            isNew: true
        ),
        ActivityItem(
            icon: DS.Icons.messages,
            kind: .info,
            title: "Message from Marcus Johnson",
            subtitle: "\u{201C}Thanks — the new dishwasher works great!\u{201D}",
            time: "1h",
            isNew: false
        ),
        ActivityItem(
            icon: DS.Icons.lease,
            kind: .success,
            title: "Lease signed",
            subtitle: "Unit 7 · Danforth Triplex · 12 months",
            time: "3h",
            isNew: false
        ),
        ActivityItem(
            icon: DS.Icons.tenant,
            kind: .neutral,
            title: "Viewing scheduled",
            subtitle: "Unit 2 · Queen West Lofts · Sat 11 AM",
            time: "5h",
            isNew: false
        )
    ]
}
