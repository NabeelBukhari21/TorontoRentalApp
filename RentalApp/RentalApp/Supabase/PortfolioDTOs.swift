//
//  PortfolioDTOs.swift
//  RentalApp (RentOS)
//
//  Supabase — Wire types for the portfolio tables.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY DTOs AND NOT `Domain` MODELS DIRECTLY
//  ─────────────────────────────────────────────────────────────────
//  The `Domain` models were built to be Supabase-shaped, and mostly are
//  — snake_case keys, a `tableName`, fallback-decoding enums. But three
//  of their value types synthesise *nested* JSON:
//
//      Money      → {"amount": …, "currency": "CAD"}
//      DateRange  → {"start": …, "end": …}
//      Address    → {"address_line1": …, …}
//
//  A nested `rent` cannot be sorted or filtered by PostgREST without a
//  jsonb path expression, and the whole point of `QuerySpec` is that
//  `order=rent.desc` happens in Postgres. So the columns are flat and
//  these DTOs do the assembling.
//
//  That makes this file the anti-corruption layer: the database schema
//  and the domain model are free to disagree, and exactly one place
//  knows about it.
//

import Foundation

// MARK: - Property

/// A row of `properties`, left-joined with the `property_stats` view.
///
/// The aggregates come from Postgres rather than being summed on device:
/// the header must describe the entire portfolio, not the page that
/// happens to be loaded.
struct PropertyRow: Decodable, Sendable {

    let id: UUID
    let name: String
    let neighborhood: String?
    let addressLine1: String
    let addressCity: String
    let kind: String
    let yearBuilt: Int?
    /// Optimistic-concurrency counter. Optional because older cached rows
    /// and some projections do not carry it.
    let version: Int?

    /// Present when the query selected the embedded stats view.
    let stats: PropertyStatsRow?

    enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, kind, version
        case addressLine1 = "address_line1"
        case addressCity  = "address_city"
        case yearBuilt    = "year_built"
        case stats        = "property_stats"
    }

    /// PostgREST returns an embedded one-to-one as either an object or a
    /// single-element array depending on how it infers the relationship.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self, forKey: .id)
        name          = try c.decode(String.self, forKey: .name)
        neighborhood  = try c.decodeIfPresent(String.self, forKey: .neighborhood)
        addressLine1  = try c.decodeIfPresent(String.self, forKey: .addressLine1) ?? ""
        addressCity   = try c.decodeIfPresent(String.self, forKey: .addressCity) ?? "Toronto"
        kind          = try c.decodeIfPresent(String.self, forKey: .kind) ?? "unknown"
        yearBuilt     = try c.decodeIfPresent(Int.self, forKey: .yearBuilt)
        version       = try c.decodeIfPresent(Int.self, forKey: .version)

        if let single = try? c.decodeIfPresent(PropertyStatsRow.self, forKey: .stats) {
            stats = single
        } else if let many = try? c.decodeIfPresent([PropertyStatsRow].self, forKey: .stats) {
            // `try?` flattens the nested optional, so `many` is already a
            // plain array here — `many?.first` does not compile.
            stats = many.first
        } else {
            stats = nil
        }
    }
}

struct PropertyStatsRow: Decodable, Sendable {
    let unitCount: Int
    let occupiedCount: Int
    let monthlyRevenue: Decimal
    let openRequestCount: Int

    enum CodingKeys: String, CodingKey {
        case unitCount        = "unit_count"
        case occupiedCount    = "occupied_count"
        case monthlyRevenue   = "monthly_revenue"
        case openRequestCount = "open_request_count"
    }
}

/// A row of the `portfolio_summary` view.
struct PortfolioSummaryRow: Decodable, Sendable {
    let propertyCount: Int
    let totalUnits: Int
    let occupiedUnits: Int
    let monthlyRevenue: Decimal

    enum CodingKeys: String, CodingKey {
        case propertyCount  = "property_count"
        case totalUnits     = "total_units"
        case occupiedUnits  = "occupied_units"
        case monthlyRevenue = "monthly_revenue"
    }
}

// MARK: - Unit

struct UnitRow: Decodable, Sendable {

    let id: UUID
    let label: String
    let bedrooms: Int
    let bathrooms: Decimal
    let squareFeet: Int?
    let marketRent: Decimal
    let status: String
    /// Embedded from `leases → tenants`, so the occupant arrives with the
    /// unit instead of costing one query per row.
    let leases: [LeaseTenantRow]

    enum CodingKeys: String, CodingKey {
        case id, label, bedrooms, bathrooms, status, leases
        case squareFeet = "square_feet"
        case marketRent = "market_rent"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        label       = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        bedrooms    = try c.decodeIfPresent(Int.self, forKey: .bedrooms) ?? 0
        bathrooms   = try c.decodeIfPresent(Decimal.self, forKey: .bathrooms) ?? 1
        squareFeet  = try c.decodeIfPresent(Int.self, forKey: .squareFeet)
        marketRent  = try c.decodeIfPresent(Decimal.self, forKey: .marketRent) ?? 0
        status      = try c.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        leases      = try c.decodeIfPresent([LeaseTenantRow].self, forKey: .leases) ?? []
    }

    /// The live lease, if any. RLS has already limited what is visible.
    var activeLease: LeaseTenantRow? {
        leases.first { $0.status == "active" || $0.status == "expiring" }
    }
}

struct LeaseTenantRow: Decodable, Sendable {
    let id: UUID
    let status: String
    let rent: Decimal
    let termEnd: Date
    let tenants: TenantNameRow?

    enum CodingKeys: String, CodingKey {
        case id, status, rent, tenants
        case termEnd = "term_end"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id      = try c.decode(UUID.self, forKey: .id)
        status  = try c.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        rent    = try c.decodeIfPresent(Decimal.self, forKey: .rent) ?? 0
        termEnd = try c.decodeIfPresent(Date.self, forKey: .termEnd) ?? .now

        if let single = try? c.decodeIfPresent(TenantNameRow.self, forKey: .tenants) {
            tenants = single
        } else if let many = try? c.decodeIfPresent([TenantNameRow].self, forKey: .tenants) {
            // See the note above: `try?` has already flattened this.
            tenants = many.first
        } else {
            tenants = nil
        }
    }
}

struct TenantNameRow: Decodable, Sendable {
    let id: UUID
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
    }
}

// MARK: - Supporting rows for the property detail tabs

struct PropertyTenantRowDTO: Decodable, Sendable {
    let tenantName: String
    let unitLabel: String
    let termEnd: Date
    let paymentStatus: String?

    enum CodingKeys: String, CodingKey {
        case tenantName    = "tenant_name"
        case unitLabel     = "unit_label"
        case termEnd       = "term_end"
        case paymentStatus = "payment_status"
    }
}

struct MaintenanceRowDTO: Decodable, Sendable {
    let id: UUID
    let title: String
    let status: String
    let priority: String
    let createdAt: Date
    let unitLabel: String?

    enum CodingKeys: String, CodingKey {
        case id, title, status, priority
        case createdAt = "created_at"
        case unitLabel = "unit_label"
    }
}

struct DocumentRowDTO: Decodable, Sendable {
    let id: UUID
    let name: String
    let category: String
    let byteSize: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case byteSize  = "file_byte_size"
        case createdAt = "created_at"
    }
}

struct TrendPointRow: Decodable, Sendable {
    let bucket: Date
    let value: Double

    enum CodingKeys: String, CodingKey {
        case bucket, value
    }
}
