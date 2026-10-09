//
//  TenantModels.swift
//  RentalApp (RentOS)
//
//  Tenants — Presentation models + mock data.
//  A TenantService will replace `TenantMockData` later.
//

import SwiftUI

// MARK: - Models

enum TenantStatus: String, Codable, CaseIterable {
    case active = "Active"
    case notice = "Notice"
    case overdue = "Overdue"

    var kind: DSStatusKind {
        switch self {
        case .active: .success
        case .notice: .info
        case .overdue: .danger
        }
    }
}

struct Tenant: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    let email: String
    let phone: String
    let propertyName: String
    let unitName: String
    let rent: Int
    let deposit: Int
    let leaseStart: String
    let leaseEnd: String
    /// 0...1 — how far through the lease term we are.
    let leaseProgress: Double
    let status: TenantStatus
    /// High-value tenancy — gets the gold treatment.
    let isPremium: Bool
    let onTimeRate: Int // % of on-time payments
}

struct TenantEvent: Identifiable {
    let id = UUID()
    let icon: String
    let kind: DSStatusKind
    let title: String
    let detail: String
    let date: String
}

struct TenantMessagePreview: Identifiable {
    let id = UUID()
    let text: String
    let time: String
    let isFromTenant: Bool
}

// MARK: - Mock Data

enum TenantMockData {

    static let tenants: [Tenant] = [
        Tenant(
            id: "sarah-chen", name: "Sarah Chen", email: "sarah.chen@gmail.com",
            phone: "(416) 555-0184", propertyName: "Maple Duplex", unitName: "Unit 304",
            rent: 2340, deposit: 2340, leaseStart: "Aug 2025", leaseEnd: "Aug 2026",
            leaseProgress: 0.92, status: .active, isPremium: true, onTimeRate: 100
        ),
        Tenant(
            id: "marcus-johnson", name: "Marcus Johnson", email: "marcus.j@outlook.com",
            phone: "(416) 555-0142", propertyName: "Queen West Lofts", unitName: "Unit 102",
            rent: 2180, deposit: 2180, leaseStart: "Sep 2025", leaseEnd: "Sep 2026",
            leaseProgress: 0.84, status: .active, isPremium: false, onTimeRate: 96
        ),
        Tenant(
            id: "priya-patel", name: "Priya Patel", email: "priya.patel@gmail.com",
            phone: "(647) 555-0197", propertyName: "Danforth Triplex", unitName: "Unit 201",
            rent: 2450, deposit: 2450, leaseStart: "Aug 2025", leaseEnd: "Aug 2026",
            leaseProgress: 0.9, status: .active, isPremium: true, onTimeRate: 100
        ),
        Tenant(
            id: "liam-oconnor", name: "Liam O'Connor", email: "liam.oc@icloud.com",
            phone: "(416) 555-0121", propertyName: "Liberty Village Flats", unitName: "Unit 407",
            rent: 2820, deposit: 2820, leaseStart: "Jan 2026", leaseEnd: "Jan 2027",
            leaseProgress: 0.55, status: .overdue, isPremium: false, onTimeRate: 78
        ),
        Tenant(
            id: "amara-diallo", name: "Amara Diallo", email: "amara.d@gmail.com",
            phone: "(647) 555-0163", propertyName: "Annex Victorian", unitName: "Unit 2",
            rent: 1980, deposit: 1980, leaseStart: "Mar 2026", leaseEnd: "Mar 2027",
            leaseProgress: 0.36, status: .active, isPremium: false, onTimeRate: 100
        ),
        Tenant(
            id: "noah-kim", name: "Noah Kim", email: "noah.kim@proton.me",
            phone: "(416) 555-0176", propertyName: "Queen West Lofts", unitName: "Unit 305",
            rent: 2260, deposit: 2260, leaseStart: "Nov 2025", leaseEnd: "Nov 2026",
            leaseProgress: 0.7, status: .notice, isPremium: false, onTimeRate: 94
        ),
        Tenant(
            id: "isabella-rossi", name: "Isabella Rossi", email: "isa.rossi@gmail.com",
            phone: "(647) 555-0155", propertyName: "Harbourfront Suite 2204", unitName: "Suite 2204",
            rent: 2890, deposit: 2890, leaseStart: "Jun 2026", leaseEnd: "Jun 2027",
            leaseProgress: 0.12, status: .active, isPremium: true, onTimeRate: 100
        ),
        Tenant(
            id: "wei-zhang", name: "Wei Zhang", email: "wei.zhang@gmail.com",
            phone: "(416) 555-0139", propertyName: "Liberty Village Flats", unitName: "Unit 212",
            rent: 2540, deposit: 2540, leaseStart: "Oct 2025", leaseEnd: "Oct 2026",
            leaseProgress: 0.76, status: .active, isPremium: false, onTimeRate: 98
        ),
        Tenant(
            id: "fatima-alrashid", name: "Fatima Al-Rashid", email: "fatima.ar@outlook.com",
            phone: "(647) 555-0118", propertyName: "Maple Duplex", unitName: "Unit 201",
            rent: 2120, deposit: 2120, leaseStart: "May 2026", leaseEnd: "May 2027",
            leaseProgress: 0.2, status: .active, isPremium: false, onTimeRate: 100
        ),
        Tenant(
            id: "jack-thompson", name: "Jack Thompson", email: "jack.t@gmail.com",
            phone: "(416) 555-0102", propertyName: "Liberty Village Flats", unitName: "Unit 118",
            rent: 2380, deposit: 2380, leaseStart: "Jul 2025", leaseEnd: "Jul 2026",
            leaseProgress: 0.98, status: .notice, isPremium: false, onTimeRate: 91
        )
    ]

    static func tenant(id: String) -> Tenant? {
        tenants.first { $0.id == id }
    }

    // MARK: Timeline

    static func timeline(for tenant: Tenant) -> [TenantEvent] {
        [
            TenantEvent(
                icon: DS.Icons.payment, kind: .success,
                title: "July rent received",
                detail: "$\(tenant.rent) · Interac e-Transfer",
                date: "Jul 1"
            ),
            TenantEvent(
                icon: DS.Icons.maintenance, kind: .warning,
                title: "Maintenance request filed",
                detail: "Dishwasher not draining · resolved in 3 days",
                date: "Jun 18"
            ),
            TenantEvent(
                icon: DS.Icons.messages, kind: .info,
                title: "Message thread",
                detail: "Parking spot reassignment confirmed",
                date: "Jun 4"
            ),
            TenantEvent(
                icon: DS.Icons.payment, kind: .success,
                title: "June rent received",
                detail: "$\(tenant.rent) · Interac e-Transfer",
                date: "Jun 1"
            ),
            TenantEvent(
                icon: DS.Icons.lease, kind: .neutral,
                title: "Lease signed",
                detail: "\(tenant.leaseStart) – \(tenant.leaseEnd) · \(tenant.unitName)",
                date: tenant.leaseStart
            ),
            TenantEvent(
                icon: "key.fill", kind: .neutral,
                title: "Moved in",
                detail: "\(tenant.propertyName) · \(tenant.unitName)",
                date: tenant.leaseStart
            )
        ]
    }

    // MARK: Documents

    static func documents(for tenant: Tenant) -> [PropertyDocRow] {
        [
            PropertyDocRow(name: "Lease agreement — \(tenant.unitName)", icon: DS.Icons.lease, detail: "PDF · 1.1 MB · \(tenant.leaseStart)"),
            PropertyDocRow(name: "Tenant insurance proof", icon: "shield.fill", detail: "PDF · 320 KB · \(tenant.leaseStart)"),
            PropertyDocRow(name: "Move-in inspection report", icon: "checklist", detail: "PDF · 840 KB · \(tenant.leaseStart)"),
            PropertyDocRow(name: "ID verification", icon: "person.text.rectangle.fill", detail: "Verified · \(tenant.leaseStart)")
        ]
    }

    // MARK: Maintenance history

    static func maintenanceHistory(for tenant: Tenant) -> [PropertyRequestRow] {
        var rows = [
            PropertyRequestRow(
                title: "Dishwasher not draining", unit: tenant.unitName,
                status: "Resolved", kind: .success, time: "Jun 18"
            ),
            PropertyRequestRow(
                title: "Bathroom fan noise", unit: tenant.unitName,
                status: "Resolved", kind: .success, time: "Mar 9"
            )
        ]
        if tenant.status == .overdue || tenant.leaseProgress > 0.85 {
            rows.insert(
                PropertyRequestRow(
                    title: "Kitchen faucet leak", unit: tenant.unitName,
                    status: "In progress", kind: .warning, time: "2d ago"
                ),
                at: 0
            )
        }
        return rows
    }

    // MARK: Messages

    static func messages(for tenant: Tenant) -> [TenantMessagePreview] {
        [
            TenantMessagePreview(
                text: "Hi! Just confirming the vendor visit for Thursday at 2 PM works for me.",
                time: "Tue 4:12 PM", isFromTenant: true
            ),
            TenantMessagePreview(
                text: "Perfect — Mike from Rapid Plumbing will buzz \(tenant.unitName). Thanks!",
                time: "Tue 4:30 PM", isFromTenant: false
            ),
            TenantMessagePreview(
                text: "Great, see you then. 👍",
                time: "Tue 4:31 PM", isFromTenant: true
            )
        ]
    }
}
