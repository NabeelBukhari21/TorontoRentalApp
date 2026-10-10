//
//  DomainPrimitives.swift
//  RentalApp (Purrperty)
//
//  Domain — Shared primitives for the entire domain layer.
//
//  ─────────────────────────────────────────────────────────────────
//  DESIGN CONTRACT — read before adding a model
//  ─────────────────────────────────────────────────────────────────
//  1. NAMESPACE. Every domain type lives under `Domain`. This keeps
//     domain names (`Domain.Property`, `Domain.Task`) free of clashes
//     with presentation models and with Swift's own `Task`.
//
//  2. PURE. Domain types import Foundation only — never SwiftUI.
//     No colours, icons, or formatting. Presentation concerns are
//     mapped in the feature layer.
//
//  3. CONFORMANCE. Every model is `Codable, Identifiable, Hashable,
//     Sendable` via the `DomainRecord` protocol.
//
//  4. RELATIONSHIPS BY ID. Models never embed other models. A lease
//     holds `unitID`, not a `Unit`. This guarantees an acyclic graph,
//     keeps payloads flat for PostgREST, and prevents the "load one
//     row, drag the database with it" problem.
//
//  5. SUPABASE SHAPE. `UUID` primary keys, snake_case `CodingKeys`,
//     `created_at` / `updated_at`, `organization_id` on every
//     tenant-scoped row for row-level security.
//
//  6. FORWARD COMPATIBILITY. Status enums decode unknown server
//     values to `.unknown` instead of throwing, so a backend deploy
//     can add a case without breaking shipped clients.
//
//  7. MONEY IS `Decimal`. Never `Double`. Amounts are stored in
//     `Money` with an explicit currency.
//

import Foundation

/// Namespace for the persistence-ready domain layer.
enum Domain {}

// MARK: - Typed Identifiers

extension Domain {

    /// A type-safe identifier.
    ///
    /// The phantom parameter makes `Identifier<Property>` and
    /// `Identifier<Unit>` different types, so the compiler rejects
    /// passing a property id where a unit id is required — a whole
    /// class of bug that plain `UUID` allows.
    struct Identifier<Subject>: Hashable, Codable, Sendable,
                                CustomStringConvertible,
                                ExpressibleByStringLiteral {

        let rawValue: UUID

        init(_ rawValue: UUID = UUID()) {
            self.rawValue = rawValue
        }

        /// Lenient init for seed data and deep links.
        init(stringLiteral value: String) {
            self.rawValue = UUID(uuidString: value) ?? UUID()
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.rawValue = try container.decode(UUID.self)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        var description: String { rawValue.uuidString }
    }
}

// MARK: - Record Protocol

extension Domain {

    /// Everything a persisted domain row must provide.
    ///
    /// `tableName` keeps the Supabase/PostgREST table name beside the
    /// model instead of scattered through repository call sites.
    protocol Record: Codable, Identifiable, Hashable, Sendable {
        associatedtype Subject
        static var tableName: String { get }
        var id: Domain.Identifier<Subject> { get }
        var createdAt: Date { get }
        var updatedAt: Date { get }
    }

    /// A row that belongs to a single tenant (organization).
    /// Supabase row-level security filters on `organization_id`.
    protocol OrganizationScoped {
        var organizationID: Domain.Identifier<Domain.Organization> { get }
    }

    /// A row that supports soft deletion rather than hard `DELETE`,
    /// so history and audit trails survive.
    protocol SoftDeletable {
        var deletedAt: Date? { get }
    }
}

extension Domain.SoftDeletable {
    /// `true` when the row is still active.
    var isActive: Bool { deletedAt == nil }
}

// MARK: - Forward-Compatible Enums

extension Domain {

    /// Adopted by string enums that the server may extend.
    ///
    /// Conformers get decoding that maps an unrecognised raw value to
    /// `.unknown` instead of throwing, so older clients keep working
    /// after a backend adds a case.
    protocol FallbackDecodable: RawRepresentable, Codable, Sendable
    where RawValue == String {
        static var unknown: Self { get }
    }
}

extension Domain.FallbackDecodable {

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Money

extension Domain {

    /// An amount plus its currency.
    ///
    /// `Decimal` avoids the binary-floating-point rounding errors that
    /// make `Double` unacceptable for money. Encoded as a Postgres
    /// `numeric` column plus a `char(3)` currency column.
    struct Money: Codable, Hashable, Sendable, Comparable {

        enum Currency: String, Codable, Sendable {
            case cad = "CAD"
            case usd = "USD"
        }

        var amount: Decimal
        var currency: Currency

        init(_ amount: Decimal, currency: Currency = .cad) {
            self.amount = amount
            self.currency = currency
        }

        static let zero = Money(0)

        static func < (lhs: Money, rhs: Money) -> Bool {
            lhs.amount < rhs.amount
        }

        /// Locale-aware display string, e.g. "$2,340.00".
        func formatted(locale: Locale = .current) -> String {
            amount.formatted(
                .currency(code: currency.rawValue).locale(locale)
            )
        }
    }
}

// MARK: - Address

extension Domain {

    /// A civic address with optional geocoding.
    ///
    /// Flattened into the owning table (`address_line1`, `address_city`…)
    /// rather than a join, because addresses are never queried alone.
    struct Address: Codable, Hashable, Sendable {

        var line1: String
        var line2: String?
        var city: String
        var province: String
        var postalCode: String
        var country: String
        var latitude: Double?
        var longitude: Double?

        init(
            line1: String,
            line2: String? = nil,
            city: String,
            province: String = "ON",
            postalCode: String,
            country: String = "CA",
            latitude: Double? = nil,
            longitude: Double? = nil
        ) {
            self.line1 = line1
            self.line2 = line2
            self.city = city
            self.province = province
            self.postalCode = postalCode
            self.country = country
            self.latitude = latitude
            self.longitude = longitude
        }

        /// Single-line form for lists and search.
        var singleLine: String {
            [line1, line2, city, province].compactMap(\.self).joined(separator: ", ")
        }

        enum CodingKeys: String, CodingKey {
            case line1 = "address_line1"
            case line2 = "address_line2"
            case city = "address_city"
            case province = "address_province"
            case postalCode = "address_postal_code"
            case country = "address_country"
            case latitude
            case longitude
        }
    }
}

// MARK: - Polymorphic Reference

extension Domain {

    /// Points at any domain row without creating a compile-time
    /// dependency on it.
    ///
    /// Used by `Document`, `Activity`, `Task`, and the AI models, all
    /// of which can attach to many different entity types. Storing
    /// `(type, id)` keeps those tables from needing a nullable foreign
    /// key per entity — and keeps the module graph acyclic.
    struct EntityReference: Codable, Hashable, Sendable {

        /// The kinds of row a reference can target.
        enum Kind: String, Codable, Sendable, CaseIterable {
            case organization
            case user
            case property
            case building
            case unit
            case tenant
            case lease
            case maintenanceRequest = "maintenance_request"
            case vendor
            case conversation
            case document
            case inspection
            case payment
            case task
        }

        var kind: Kind
        var id: UUID

        init(kind: Kind, id: UUID) {
            self.kind = kind
            self.id = id
        }

        enum CodingKeys: String, CodingKey {
            case kind = "subject_type"
            case id = "subject_id"
        }
    }
}

// MARK: - Reference Conveniences

extension Domain.EntityReference {

    static func property(_ id: Domain.Identifier<Domain.Property>) -> Self {
        .init(kind: .property, id: id.rawValue)
    }

    static func unit(_ id: Domain.Identifier<Domain.Unit>) -> Self {
        .init(kind: .unit, id: id.rawValue)
    }

    static func tenant(_ id: Domain.Identifier<Domain.Tenant>) -> Self {
        .init(kind: .tenant, id: id.rawValue)
    }

    static func lease(_ id: Domain.Identifier<Domain.Lease>) -> Self {
        .init(kind: .lease, id: id.rawValue)
    }

    static func maintenanceRequest(_ id: Domain.Identifier<Domain.MaintenanceRequest>) -> Self {
        .init(kind: .maintenanceRequest, id: id.rawValue)
    }
}

// MARK: - Attachment

extension Domain {

    /// A file stored in Supabase Storage.
    ///
    /// Embedded as `jsonb` on the owning row when the file is an
    /// inseparable part of it (a maintenance photo). Standalone files
    /// that need their own lifecycle use `Domain.Document` instead.
    struct Attachment: Codable, Hashable, Sendable, Identifiable {

        enum Kind: String, Codable, Sendable {
            case image
            case video
            case pdf
            case spreadsheet
            case other
        }

        var id: UUID
        var kind: Kind
        /// Path within the storage bucket — not a signed URL, which expires.
        var storagePath: String
        var fileName: String
        var byteSize: Int
        var uploadedAt: Date

        init(
            id: UUID = UUID(),
            kind: Kind,
            storagePath: String,
            fileName: String,
            byteSize: Int,
            uploadedAt: Date = .now
        ) {
            self.id = id
            self.kind = kind
            self.storagePath = storagePath
            self.fileName = fileName
            self.byteSize = byteSize
            self.uploadedAt = uploadedAt
        }

        enum CodingKeys: String, CodingKey {
            case id, kind
            case storagePath = "storage_path"
            case fileName = "file_name"
            case byteSize = "byte_size"
            case uploadedAt = "uploaded_at"
        }
    }
}

// MARK: - Date Range

extension Domain {

    /// A closed calendar range, used for lease terms and reporting.
    struct DateRange: Codable, Hashable, Sendable {

        var start: Date
        var end: Date

        init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }

        func contains(_ date: Date) -> Bool {
            date >= start && date <= end
        }

        /// Fraction elapsed, clamped to 0...1.
        func progress(asOf date: Date = .now) -> Double {
            let total = end.timeIntervalSince(start)
            guard total > 0 else { return 0 }
            return min(max(date.timeIntervalSince(start) / total, 0), 1)
        }

        var dayCount: Int {
            Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        }
    }
}

// MARK: - Coding Support

extension Domain {

    /// JSON coders configured for Supabase/PostgREST.
    enum Coding {

        /// Fresh instances rather than shared singletons: `JSONDecoder`
        /// and `JSONEncoder` are not `Sendable`, and a decode may run on
        /// any executor once a real network layer exists. Constructing
        /// one per call is far cheaper than the request it accompanies.
        static var decoder: JSONDecoder {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let raw = try decoder.singleValueContainer().decode(String.self)
                if let date = iso8601Fractional.date(from: raw) { return date }
                if let date = iso8601Plain.date(from: raw) { return date }
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "Unrecognised timestamp: \(raw)")
                )
            }
            return decoder
        }

        static var encoder: JSONEncoder {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(iso8601Fractional.string(from: date))
            }
            return encoder
        }

        // `ISO8601DateFormatter` is documented as thread-safe for
        // formatting and parsing, so these two stay shared — they are
        // hit once per date field and rebuilding them would dominate
        // decode cost.
        nonisolated(unsafe) private static let iso8601Fractional: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        nonisolated(unsafe) private static let iso8601Plain: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()
    }
}
