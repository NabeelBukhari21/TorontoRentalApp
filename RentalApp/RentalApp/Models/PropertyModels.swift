//
//  PropertyModels.swift
//  RentalApp (Purrperty)
//
//  Properties — Presentation models + Toronto mock data.
//  A PropertyService will replace `PropertyMockData` later.
//

import SwiftUI

// MARK: - Models

enum PropertyKind: String, Codable, CaseIterable {
    case condo = "Condo"
    case multiUnit = "Multi-unit"
    case house = "House"
    case commercial = "Commercial"

    var icon: String {
        switch self {
        case .condo: "building.fill"
        case .multiUnit: DS.Icons.properties
        case .house: "house.fill"
        case .commercial: "storefront.fill"
        }
    }

    /// The `property_kind` enum value Postgres expects.
    ///
    /// Deliberately not `rawValue` — that is the display string ("Multi-unit")
    /// and changing a label must never silently change a database value. This
    /// mapping was previously written out by hand inside `OfflineGate`; one
    /// copy, here, next to the cases it maps.
    var dbValue: String {
        switch self {
        case .condo:      "condo"
        case .multiUnit:  "multi_unit"
        case .house:      "house"
        case .commercial: "commercial"
        }
    }
}

struct Property: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    let neighborhood: String
    let address: String
    let kind: PropertyKind
    let unitCount: Int
    let occupiedCount: Int
    let monthlyRevenue: Double // $K
    let openRequests: Int
    let urgentRequests: Int
    let yearBuilt: Int
    let paletteIndex: Int

    var occupancyRate: Double {
        unitCount == 0 ? 0 : Double(occupiedCount) / Double(unitCount)
    }

    var vacantCount: Int { unitCount - occupiedCount }

    /// A property with no units yet is empty, not full.
    var isFull: Bool { unitCount > 0 && vacantCount == 0 }
}

struct PropertyUnit: Identifiable, Sendable, Codable {
    let id: String
    let name: String
    let beds: Int
    let baths: Int
    let sqft: Int
    let rent: Int
    let tenantName: String?
    let status: UnitStatus
    /// Set only when the property has more than one building, where unit
    /// labels repeat ("Unit 101" in Tower A and in Tower B).
    var building: String? = nil

    /// The label to show wherever units of one property are listed together.
    var displayName: String {
        building.map { "\(name) · \($0)" } ?? name
    }

    enum UnitStatus: String, Codable {
        case occupied = "Occupied"
        case vacant = "Vacant"
        case notice = "Notice given"

        var kind: DSStatusKind {
            switch self {
            case .occupied: .success
            case .vacant: .warning
            case .notice: .info
            }
        }
    }
}

struct PropertyTenantRow: Identifiable {
    let id = UUID()
    let name: String
    let unit: String
    let leaseEnds: String
    let rentStatus: String
    let rentKind: DSStatusKind
}

struct PropertyRequestRow: Identifiable {
    let id = UUID()
    let title: String
    let unit: String
    let status: String
    let kind: DSStatusKind
    let time: String
}

struct PropertyDocRow: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let detail: String
}

struct OccupancyTrendPoint: Identifiable {
    let id = UUID()
    let month: String
    let rate: Double
}

// MARK: - Palettes (photo placeholders)

enum PropertyPalettes {
    /// Defined in the design system, where the stored-index contract is
    /// documented. Six entries, same as before, so every saved
    /// `paletteIndex` still resolves to a slot.
    static let all: [[Color]] = DS.Gradients.placeholderStops

    static func gradient(_ index: Int) -> LinearGradient {
        LinearGradient(
            colors: all[index % all.count],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Mock Data

enum PropertyMockData {

    static let properties: [Property] = [
        Property(
            id: "maple-duplex", name: "Maple Duplex", neighborhood: "Leslieville",
            address: "48 Maple Grove Ave, Toronto", kind: .multiUnit,
            unitCount: 6, occupiedCount: 6, monthlyRevenue: 11.2,
            openRequests: 2, urgentRequests: 1, yearBuilt: 1962, paletteIndex: 0
        ),
        Property(
            id: "queen-west-lofts", name: "Queen West Lofts", neighborhood: "Queen West",
            address: "1187 Queen St W, Toronto", kind: .condo,
            unitCount: 12, occupiedCount: 10, monthlyRevenue: 21.4,
            openRequests: 3, urgentRequests: 0, yearBuilt: 2011, paletteIndex: 1
        ),
        Property(
            id: "danforth-triplex", name: "Danforth Triplex", neighborhood: "The Danforth",
            address: "622 Danforth Ave, Toronto", kind: .multiUnit,
            unitCount: 3, occupiedCount: 3, monthlyRevenue: 6.8,
            openRequests: 0, urgentRequests: 0, yearBuilt: 1948, paletteIndex: 2
        ),
        Property(
            id: "harbourfront-tower", name: "Harbourfront Suite 2204", neighborhood: "Harbourfront",
            address: "218 Queens Quay W, Toronto", kind: .condo,
            unitCount: 1, occupiedCount: 1, monthlyRevenue: 2.9,
            openRequests: 1, urgentRequests: 0, yearBuilt: 2017, paletteIndex: 3
        ),
        Property(
            id: "annex-victorian", name: "Annex Victorian", neighborhood: "The Annex",
            address: "31 Brunswick Ave, Toronto", kind: .house,
            unitCount: 4, occupiedCount: 3, monthlyRevenue: 7.6,
            openRequests: 1, urgentRequests: 1, yearBuilt: 1905, paletteIndex: 4
        ),
        Property(
            id: "liberty-flats", name: "Liberty Village Flats", neighborhood: "Liberty Village",
            address: "5 Hanna Ave, Toronto", kind: .multiUnit,
            unitCount: 22, occupiedCount: 22, monthlyRevenue: 38.9,
            openRequests: 4, urgentRequests: 0, yearBuilt: 2006, paletteIndex: 5
        )
    ]

    static func property(id: String) -> Property? {
        properties.first { $0.id == id }
    }

    // MARK: Per-property detail mocks

    private static let tenantPool = [
        "Sarah Chen", "Marcus Johnson", "Priya Patel", "Liam O'Connor",
        "Amara Diallo", "Noah Kim", "Isabella Rossi", "Wei Zhang",
        "Fatima Al-Rashid", "Jack Thompson", "Aisha Mohamed", "Lucas Silva",
        "Emma Tremblay", "Raj Sharma", "Olivia Bennett", "Diego Fernandez",
        "Hannah Lee", "Kwame Mensah", "Sofia Petrov", "Ethan Wright",
        "Zara Hussain", "Felix Nguyen"
    ]

    static func units(for property: Property) -> [PropertyUnit] {
        (0..<property.unitCount).map { index in
            let isVacant = index >= property.occupiedCount
            let givingNotice = !isVacant && index == property.occupiedCount - 1 && property.unitCount > 3
            let floor = index / 4 + 1
            let unitNumber = "\(floor)0\(index % 4 + 1)"

            return PropertyUnit(
                id: "\(property.id)-\(unitNumber)",
                name: property.unitCount == 1 ? "Suite 2204" : "Unit \(unitNumber)",
                beds: 1 + (index % 3),
                baths: 1 + (index % 2),
                sqft: 550 + (index % 4) * 175,
                rent: 1850 + (index % 5) * 240,
                tenantName: isVacant ? nil : tenantPool[index % tenantPool.count],
                status: isVacant ? .vacant : (givingNotice ? .notice : .occupied)
            )
        }
    }

    static func tenants(for property: Property) -> [PropertyTenantRow] {
        units(for: property).compactMap { unit in
            guard let tenant = unit.tenantName else { return nil }
            let monthIndex = abs(unit.id.hashValue) % 12
            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            let isLate = unit.rent > 2500 && monthIndex % 5 == 0

            return PropertyTenantRow(
                name: tenant,
                unit: unit.name,
                leaseEnds: "\(months[monthIndex]) 2027",
                rentStatus: isLate ? "Rent overdue" : "Paid",
                rentKind: isLate ? .danger : .success
            )
        }
    }

    static func requests(for property: Property) -> [PropertyRequestRow] {
        let templates: [(String, String, DSStatusKind, String)] = [
            ("Water leak under kitchen sink", "New", .danger, "26m ago"),
            ("Dishwasher not draining", "In progress", .warning, "2d ago"),
            ("Hallway light flickering", "Scheduled", .info, "3d ago"),
            ("Balcony door seal replacement", "In progress", .warning, "5d ago")
        ]
        let unitNames = units(for: property).map(\.name)

        return (0..<property.openRequests).map { index in
            let template = templates[index % templates.count]
            return PropertyRequestRow(
                title: template.0,
                unit: unitNames[index % max(unitNames.count, 1)],
                status: template.1,
                kind: index == 0 && property.urgentRequests > 0 ? .danger : template.2,
                time: template.3
            )
        }
    }

    static func documents(for property: Property) -> [PropertyDocRow] {
        [
            PropertyDocRow(name: "Master lease agreement", icon: DS.Icons.lease, detail: "PDF · 1.2 MB · Mar 2026"),
            PropertyDocRow(name: "Insurance certificate", icon: "shield.fill", detail: "PDF · 480 KB · Jan 2026"),
            PropertyDocRow(name: "Property tax statement", icon: DS.Icons.payment, detail: "PDF · 220 KB · Jun 2026"),
            PropertyDocRow(name: "\(property.name) — inspection photos", icon: DS.Icons.camera, detail: "12 photos · May 2026")
        ]
    }

    static func occupancyTrend(for property: Property) -> [OccupancyTrendPoint] {
        let months = ["Aug", "Sep", "Oct", "Nov", "Dec", "Jan",
                      "Feb", "Mar", "Apr", "May", "Jun", "Jul"]
        let base = property.occupancyRate

        return months.enumerated().map { index, month in
            let wobble = sin(Double(index) * 1.1 + Double(property.paletteIndex)) * 0.06
            let rate = min(max(base - 0.05 + wobble + Double(index) * 0.004, 0.6), 1.0)
            return OccupancyTrendPoint(month: month, rate: rate)
        }
    }

    static func revenueTrend(for property: Property) -> [RevenuePoint] {
        let months = ["Feb", "Mar", "Apr", "May", "Jun", "Jul"]
        return months.enumerated().map { index, month in
            let wobble = sin(Double(index) * 0.9 + Double(property.paletteIndex)) * 0.05
            return RevenuePoint(month: month, amount: property.monthlyRevenue * (0.92 + wobble + Double(index) * 0.016))
        }
    }
}
