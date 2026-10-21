//
//  SupabasePropertyRepository.swift
//  RentalApp (Purrperty)
//
//  Supabase — Portfolio data source.
//
//  ─────────────────────────────────────────────────────────────────
//  NOTHING IS FILTERED ON THE DEVICE
//  ─────────────────────────────────────────────────────────────────
//  Every search term, filter, sort field, and page boundary in
//  `PropertyQuery` becomes part of the PostgREST request. The app never
//  downloads a table and narrows it locally — that is both a
//  performance property and a security one, since RLS decides what the
//  query is even allowed to see.
//
//  Note what is absent: no `organization_id` appears anywhere below.
//  It cannot be forged because it is never sent. RLS derives it from
//  `auth.uid()` on every statement.
//

import Foundation
import Supabase

@MainActor
final class SupabasePropertyRepository: PropertyRepositoryProtocol {

    private let client: SupabaseClient
    private let cache: RepositoryCache
    /// Nil in contexts with no offline story (tests, some previews). The
    /// repository then behaves exactly as it did before — online only.
    private let offline: OfflineGate?

    init(
        client: SupabaseClient,
        cache: RepositoryCache = .shared,
        offline: OfflineGate? = nil
    ) {
        self.client = client
        self.cache = cache
        self.offline = offline
    }

    /// True when the last read came from disk because the network failed.
    var isShowingCachedData: Bool { offline?.isServingStaleData ?? false }

    /// Row versions seen by this client, so an update can prove it is
    /// editing what it last read. Populated by `property(id:)`.
    private var knownVersions: [String: Int] = [:]

    /// Stamped on writes so the realtime layer can drop our own echo.
    private let originToken = UUID().uuidString

    static let namespace = "supabase.properties"

    /// Columns pulled for a property card, including the aggregates from
    /// the `property_stats` view via an embedded resource.
    static let listColumns = """
        id, name, neighborhood, address_line1, address_city, kind, year_built, version,
        property_stats!inner(unit_count, occupied_count, monthly_revenue, open_request_count)
        """

    /// Columns for a unit row, including the live lease's tenant.
    static let unitColumns = """
        id, label, bedrooms, bathrooms, square_feet, market_rent, status,
        leases(id, status, rent, term_end, tenants(id, full_name))
        """

    // MARK: - List

    func properties(matching query: PropertyQuery, forceRefresh: Bool) async throws -> Page<Property> {
        // Only the default, unfiltered first page is cached for offline use.
        // Caching every search term would fill the budget with queries nobody
        // repeats, and evict the one list that actually matters on a subway.
        let isCacheable = query.searchTerm == nil
            && query.filter == .all
            && query.page.page == 0

        if let offline, isCacheable {
            let read = try await offline.read(
                key: OfflineKey.properties,
                forceRefresh: forceRefresh
            ) {
                try await self.fetchProperties(query)
            }
            return read.value
        }

        return try await fetchProperties(query)
    }

    private func fetchProperties(_ query: PropertyQuery) async throws -> Page<Property> {
        do {
            var builder = client
                .from("properties")
                .select(Self.listColumns, head: false, count: .exact)
                // IS NULL, written as a raw filter — the form used at every
                // soft-delete check in this file.
                //
                // `.is(column, value: nil)` does not compile against this
                // version of supabase-swift: that parameter is a
                // non-optional `any PostgrestFilterValue`, so `nil` has no
                // overload. The raw form emits exactly the same PostgREST
                // query (`?deleted_at=is.null`) and does not depend on how
                // the SDK happens to model null in a given release.
                .filter("deleted_at", operator: "is", value: "null")

            if let term = query.searchTerm {
                builder = builder.or(
                    SupabaseSearch.orILike(columns: ["name", "neighborhood", "address_line1"], term: term)
                )
            }

            // Filters are expressed against the stats view so "has a
            // vacancy" is answered by Postgres, not by loading every unit.
            switch query.filter {
            case .all:
                break
            case .fullyOccupied:
                builder = builder.filter("property_stats.occupied_count", operator: "eq", value: "property_stats.unit_count")
            case .hasVacancy:
                builder = builder.lt("property_stats.occupied_count", value: "property_stats.unit_count")
            case .hasIssues:
                builder = builder.gt("property_stats.open_request_count", value: 0)
            }

            let response = try await builder
                .applying(query, idColumn: "id")
                .execute()

            let rows = try SupabaseCoding.decoder.decode([PropertyRow].self, from: response.data)
            let items = rows.enumerated().map { index, row in
                Self.present(row, paletteIndex: query.page.rangeLowerBound + index)
            }
            return SupabasePage.make(items: items, totalCount: response.count, request: query.page)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func property(id: String) async throws -> Property {
        do {
            let row: PropertyRow = try await client
                .from("properties")
                .select(Self.listColumns)
                .eq("id", value: id)
                .filter("deleted_at", operator: "is", value: "null")
                .single()
                .execute()
                .value
            knownVersions[id] = row.version ?? knownVersions[id]
            return Self.present(row, paletteIndex: abs(id.hashValue) % 6)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func portfolioSummary(forceRefresh: Bool) async throws -> PropertyPortfolioSummary {
        try await cache.fetch(
            key: "\(Self.namespace).summary",
            forceRefresh: forceRefresh
        ) {
            do {
                // `maybeSingle` because a brand-new workspace has no
                // properties yet and the view returns no row at all.
                let row: PortfolioSummaryRow? = try await client
                    .from("portfolio_summary")
                    .select()
                    .limit(1)
                    .execute()
                    .value

                guard let row else { return .empty }
                return PropertyPortfolioSummary(
                    propertyCount: row.propertyCount,
                    totalUnits: row.totalUnits,
                    occupiedUnits: row.occupiedUnits,
                    monthlyRevenueText: Self.currency(row.monthlyRevenue)
                )
            } catch {
                throw SupabaseErrorMapper.map(error)
            }
        }
    }

    // MARK: - Detail tabs

    func units(forPropertyID id: String) async throws -> [PropertyUnit] {
        do {
            let rows: [UnitRow] = try await client
                .from("units")
                .select(Self.unitColumns)
                .eq("property_id", value: id)
                .filter("deleted_at", operator: "is", value: "null")
                .order("label", ascending: true)
                .execute()
                .value

            return rows.map(Self.present(unit:))
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func unit(id: String) async throws -> UnitDetail {
        do {
            // Two small reads: the unit in the shape the units tab uses, and
            // the property it belongs to.
            let row: UnitRow = try await client
                .from("units")
                .select(Self.unitColumns)
                .eq("id", value: id)
                .single()
                .execute()
                .value
            let owner: UnitOwnerRow = try await client
                .from("units")
                .select("property_id, properties(name)")
                .eq("id", value: id)
                .single()
                .execute()
                .value
            return UnitDetail(
                unit: Self.present(unit: row),
                propertyID: owner.propertyID.uuidString,
                propertyName: owner.properties?.name ?? "Property"
            )
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func tenantRows(forPropertyID id: String) async throws -> [PropertyTenantRow] {
        do {
            let rows: [LeaseWithTenantRow] = try await client
                .from("leases")
                .select("id, status, term_end, rent, tenants!inner(id, full_name), units!inner(id, label)")
                .eq("property_id", value: id)
                .in("status", values: ["active", "expiring"])
                .filter("deleted_at", operator: "is", value: "null")
                .order("term_end", ascending: true)
                .execute()
                .value

            return rows.map {
                PropertyTenantRow(
                    name: $0.tenants?.fullName ?? "—",
                    unit: $0.units?.label ?? "—",
                    leaseEnds: Self.monthYear($0.termEnd),
                    rentStatus: $0.status == "expiring" ? "Expiring" : "Current",
                    rentKind: $0.status == "expiring" ? .warning : .success,
                    tenantID: $0.tenants?.id.uuidString
                )
            }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func requestRows(forPropertyID id: String) async throws -> [PropertyRequestRow] {
        do {
            let rows: [MaintenanceWithUnitRow] = try await client
                .from("maintenance_requests")
                .select("id, title, status, priority, created_at, units(label)")
                .eq("property_id", value: id)
                .filter("deleted_at", operator: "is", value: "null")
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value

            return rows.map {
                PropertyRequestRow(
                    title: $0.title,
                    unit: $0.units?.label ?? "—",
                    status: Self.requestStatusLabel($0.status),
                    kind: Self.requestStatusKind($0.status, priority: $0.priority),
                    time: Self.relative($0.createdAt),
                    requestID: $0.id.uuidString
                )
            }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func documents(forPropertyID id: String) async throws -> [PropertyDocRow] {
        do {
            let rows: [DocumentRowDTO] = try await client
                .from("documents")
                .select("id, name, category, file_byte_size, created_at")
                .eq("owner_type", value: "property")
                .eq("owner_id", value: id)
                .filter("deleted_at", operator: "is", value: "null")
                .order("created_at", ascending: false)
                .execute()
                .value

            return rows.map {
                PropertyDocRow(
                    name: $0.name,
                    icon: Self.documentIcon($0.category),
                    // `PropertyDocRow` has no `month` — every other producer
                    // folds size and date into one `detail` string, and the
                    // row view renders only `name` and `detail`. Matching
                    // that convention keeps the UI byte-identical.
                    detail: "\(Self.byteLabel($0.byteSize)) · \(Self.monthYear($0.createdAt))"
                )
            }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func occupancyTrend(forPropertyID id: String) async throws -> [OccupancyTrendPoint] {
        do {
            let rows: [TrendPointRow] = try await client
                .rpc("property_occupancy_trend", params: ["p_property_id": id])
                .execute()
                .value
            return rows.map { OccupancyTrendPoint(month: Self.shortMonth($0.bucket), rate: $0.value) }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func revenueTrend(forPropertyID id: String) async throws -> [RevenuePoint] {
        do {
            let rows: [TrendPointRow] = try await client
                .rpc("property_revenue_trend", params: ["p_property_id": id])
                .execute()
                .value
            return rows.map { RevenuePoint(month: Self.shortMonth($0.bucket), amount: $0.value / 1_000) }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: - Presentation
    //
    // The mock path routes through `Projections`, which reads
    // `FakeBackend.shared` and so cannot be reused here. These mappings
    // are deliberately simpler than their mock counterparts: the
    // aggregates arrive already computed from `property_stats` instead of
    // being summed over locally-held units.

    static func present(unit row: UnitRow) -> PropertyUnit {
        PropertyUnit(
            id: row.id.uuidString,
            name: row.label,
            beds: row.bedrooms,
            baths: Int(truncating: row.bathrooms as NSDecimalNumber),
            sqft: row.squareFeet ?? 0,
            rent: Int(truncating: row.marketRent as NSDecimalNumber),
            tenantName: row.activeLease?.tenants?.fullName,
            status: unitStatus(row.status),
            tenantID: row.activeLease?.tenants?.id.uuidString
        )
    }

    static func present(_ row: PropertyRow, paletteIndex: Int) -> Property {
        let stats = row.stats
        let revenue = stats.map { ($0.monthlyRevenue as NSDecimalNumber).doubleValue } ?? 0

        return Property(
            id: row.id.uuidString,
            name: row.name,
            neighborhood: row.neighborhood ?? row.addressCity,
            address: "\(row.addressLine1), \(row.addressCity)",
            kind: propertyKind(row.kind),
            unitCount: stats?.unitCount ?? 0,
            occupiedCount: stats?.occupiedCount ?? 0,
            monthlyRevenue: revenue / 1_000,        // the card renders $K
            openRequests: stats?.openRequestCount ?? 0,
            urgentRequests: 0,                       // filled by the maintenance slice
            yearBuilt: row.yearBuilt ?? 0,
            paletteIndex: paletteIndex
        )
    }

    private static func propertyKind(_ raw: String) -> PropertyKind {
        switch raw {
        case "condo":      .condo
        case "house":      .house
        case "commercial": .commercial
        default:           .multiUnit
        }
    }

    static func unitStatus(_ raw: String) -> PropertyUnit.UnitStatus {
        switch raw {
        case "occupied": .occupied
        case "notice":   .notice
        default:         .vacant
        }
    }

    private static func requestStatusLabel(_ raw: String) -> String {
        switch raw {
        case "new":            "New"
        case "triaged":        "Triaged"
        case "scheduled":      "Scheduled"
        case "in_progress":    "In Progress"
        case "awaiting_parts": "Awaiting Parts"
        case "completed":      "Completed"
        case "cancelled":      "Cancelled"
        default:               "Open"
        }
    }

    private static func requestStatusKind(_ status: String, priority: String) -> DSStatusKind {
        if status == "completed" { return .success }
        if priority == "emergency" || priority == "urgent" { return .danger }
        if status == "in_progress" || status == "scheduled" { return .info }
        return .warning
    }

    private static func documentIcon(_ category: String) -> String {
        switch category {
        case "lease":          DS.Icons.lease
        case "invoice",
             "financial":      DS.Icons.payment
        case "photo":          DS.Icons.camera
        case "inspection":     "checklist"
        case "insurance":      "shield.fill"
        default:               DS.Icons.documents
        }
    }

    // MARK: Formatting

    private static func currency(_ value: Decimal) -> String {
        value.formatted(.currency(code: "CAD").precision(.fractionLength(0)))
    }

    private static func byteLabel(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year())
    }

    private static func shortMonth(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated))
    }

    private static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }
}

// MARK: - Local join rows

private struct LeaseWithTenantRow: Decodable, Sendable {
    let id: UUID
    let status: String
    let termEnd: Date
    let rent: Decimal
    let tenants: TenantNameRow?
    let units: UnitLabelRow?

    enum CodingKeys: String, CodingKey {
        case id, status, rent, tenants, units
        case termEnd = "term_end"
    }
}

private struct UnitLabelRow: Decodable, Sendable {
    let label: String
}

private struct UnitOwnerRow: Decodable, Sendable {
    let propertyID: UUID
    let properties: PropertyNameRow?

    enum CodingKeys: String, CodingKey {
        case properties
        case propertyID = "property_id"
    }
}

private struct PropertyNameRow: Decodable, Sendable {
    let name: String
}

private struct MaintenanceWithUnitRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let status: String
    let priority: String
    let createdAt: Date
    let units: UnitLabelRow?

    enum CodingKeys: String, CodingKey {
        case id, title, status, priority, units
        case createdAt = "created_at"
    }
}

// ============================================================================
//  MARK: - Writes
// ============================================================================
//
//  Two rules hold throughout:
//
//  • No `organization_id` is ever sent. The `force_org_id()` trigger
//    stamps it from `auth.uid()`, so a forged value is impossible rather
//    than merely rejected.
//  • Archive / restore / delete go through RPCs, not UPDATEs, because
//    each carries a rule (cascade units, refuse while a lease is live)
//    that must not live in the client.
//
//  Every write invalidates the cached aggregates. Skipping that is how a
//  header ends up claiming 12 properties after you deleted one.

extension SupabasePropertyRepository {

    func archivedProperties() async throws -> [Property] {
        do {
            let rows: [PropertyRow] = try await client
                .from("properties")
                .select(Self.listColumns)
                .not("deleted_at", operator: .is, value: "null")
                .order("deleted_at", ascending: false)
                .limit(100)
                .execute()
                .value
            return rows.enumerated().map { Self.present($1, paletteIndex: $0) }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    @discardableResult
    func createProperty(_ draft: PropertyDraft) async throws -> Property {
        do {
            let row: PropertyRow = try await client
                .from("properties")
                .insert(PropertyPayload(draft), returning: .representation)
                .select(Self.listColumns)
                .single()
                .execute()
                .value

            invalidateAggregates()
            return Self.present(row, paletteIndex: 0)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    /// Version-checked update.
    ///
    /// Sends the version the client last read. If the row has moved on, the
    /// server returns a conflict envelope rather than silently overwriting —
    /// which is the entire point of the `version` column, and was previously
    /// never exercised.
    func updateProperty(id: String, with draft: PropertyDraft) async throws -> Property {
        do {
            let expected = knownVersions[id]

            // No known version means this client never read the row in this
            // session (a deep link, say). Fall back to an unguarded write
            // rather than refusing — the alternative is a read purely to
            // obtain a number, doubling the latency of every such edit.
            guard let expected else {
                return try await unguardedUpdate(id: id, draft: draft)
            }

            let envelope: GuardedUpdateEnvelope = try await client
                .rpc("update_if_current", params: GuardedUpdateParams(
                    table: "properties",
                    id: id,
                    expectedVersion: expected,
                    patch: PropertyPayload(draft),
                    originToken: originToken
                ))
                .execute()
                .value

            if envelope.conflict {
                // Adopt the server's version before throwing. That way a
                // "keep mine" resolution simply calls this method again and
                // succeeds, instead of conflicting forever against a version
                // we already know is stale.
                if let current = envelope.currentVersion {
                    knownVersions[id] = current
                }

                // Hand the server's row back to the caller to diff and
                // resolve. Throwing a plain error here would lose it.
                throw PropertyConflict(
                    recordID: id,
                    remote: envelope.remote ?? Data(),
                    currentVersion: envelope.currentVersion ?? 0
                )
            }

            invalidateAggregates()
            guard let rowData = envelope.row,
                  let row = try? SupabaseCoding.decoder.decode(PropertyRow.self, from: rowData)
            else {
                // The write landed but the response was unreadable; re-read
                // rather than reporting a failure for a successful edit.
                return try await property(id: id)
            }
            knownVersions[id] = expected + 1
            return Self.present(row, paletteIndex: abs(id.hashValue) % 6)

        } catch let conflict as PropertyConflict {
            throw conflict
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    private func unguardedUpdate(id: String, draft: PropertyDraft) async throws -> Property {
        let row: PropertyRow = try await client
            .from("properties")
            .update(PropertyPayload(draft), returning: .representation)
            .eq("id", value: id)
            .select(Self.listColumns)
            .single()
            .execute()
            .value

        invalidateAggregates()
        return Self.present(row, paletteIndex: abs(id.hashValue) % 6)
    }

    func archiveProperty(id: String) async throws {
        try await queueable(
            describe: { .propertyArchive(id: id, summary: "Archive property") }
        ) {
            try await self.callVoid("archive_property", params: PropertyIDParam(propertyID: id))
        }
    }

    func restoreProperty(id: String) async throws {
        try await queueable(
            describe: { .propertyRestore(id: id, summary: "Restore property") }
        ) {
            try await self.callVoid("restore_property", params: PropertyIDParam(propertyID: id))
        }
    }

    func deleteProperty(id: String) async throws {
        // Deliberately NOT queueable. Delete is refused server-side when a
        // live lease exists, and that check cannot run offline — queueing it
        // would tell the user a property was deleted and then fail silently
        // hours later. Archive is the offline-safe alternative, and the UI
        // already recommends it.
        try await callVoid("delete_property", params: PropertyIDParam(propertyID: id))
    }

    /// Runs a mutation through the offline gate when one is available.
    ///
    /// Throws only on real failure — a *queued* write is a success, because
    /// the optimistic UI has already applied it and the outbox guarantees
    /// it lands.
    private func queueable(
        describe: @escaping () -> OutboxEntry,
        perform: @escaping () async throws -> Void
    ) async throws {
        guard let offline else {
            try await perform()
            return
        }

        let outcome = await offline.write(
            invalidating: [OfflineKey.properties, OfflineKey.propertySummary],
            describe: describe,
            perform: perform
        )

        if let error = outcome.error { throw error }
        invalidateAggregates()
    }

    // MARK: Units

    @discardableResult
    func createUnit(_ draft: UnitDraft, propertyID: String) async throws -> PropertyUnit {
        do {
            let row: UnitRow = try await client
                .from("units")
                .insert(UnitPayload(draft, propertyID: propertyID), returning: .representation)
                .select(Self.unitColumns)
                .single()
                .execute()
                .value

            invalidateAggregates()
            return Self.present(unit: row)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func updateUnit(id: String, with draft: UnitDraft) async throws -> PropertyUnit {
        do {
            let row: UnitRow = try await client
                .from("units")
                .update(UnitPayload(draft, propertyID: nil), returning: .representation)
                .eq("id", value: id)
                .select(Self.unitColumns)
                .single()
                .execute()
                .value

            invalidateAggregates()
            return Self.present(unit: row)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func deleteUnit(id: String) async throws {
        try await callVoid("delete_unit", params: UnitIDParam(unitID: id))
    }

    // MARK: Plumbing

    /// Runs a void RPC, mapping the error and clearing derived caches.
    private func callVoid(_ name: String, params: some Encodable & Sendable) async throws {
        do {
            _ = try await client.rpc(name, params: params).execute()
            invalidateAggregates()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    /// The header aggregates come from Postgres views, so anything that
    /// changes a row invalidates them — exactly as a real client would
    /// after a mutating request.
    private func invalidateAggregates() {
        cache.invalidate(prefix: Self.namespace)
    }
}

// MARK: - Write Payloads
//
// Separate from the read DTOs on purpose: a payload contains only the
// columns a user may set. `organization_id`, `created_at`, `deleted_at`
// and every derived aggregate are structurally absent, so they cannot be
// smuggled in by a future edit to this file.

private struct PropertyPayload: Encodable, Sendable {
    let name: String
    let kind: String
    let addressLine1: String
    let addressCity: String
    let addressPostalCode: String
    let neighborhood: String?
    let yearBuilt: Int?
    let squareFeet: Int?

    init(_ draft: PropertyDraft) {
        self.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = PropertyPayload.kindRawValue(draft.kind)
        self.addressLine1 = draft.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
        self.addressCity = draft.city.trimmingCharacters(in: .whitespacesAndNewlines)
        self.addressPostalCode = draft.postalCode.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.neighborhood = draft.neighborhood
        self.yearBuilt = draft.yearBuilt
        self.squareFeet = draft.squareFeet
    }

    /// `PropertyKind` is a four-case presentation enum; the database has
    /// seven. Mapping outward keeps the wider vocabulary available
    /// server-side without forcing the UI to show cases it has no design
    /// for.
    ///
    /// The mapping itself lives on `PropertyKind.dbValue`. It was written
    /// out by hand in three places — here, in `OfflineGate`, and in the
    /// conflict payload — which is three chances for a renamed case to
    /// diverge from the Postgres enum in only two of them.
    private static func kindRawValue(_ kind: PropertyKind) -> String {
        kind.dbValue
    }

    enum CodingKeys: String, CodingKey {
        case name, kind, neighborhood
        case addressLine1      = "address_line1"
        case addressCity       = "address_city"
        case addressPostalCode = "address_postal_code"
        case yearBuilt         = "year_built"
        case squareFeet        = "square_feet"
    }
}

private struct UnitPayload: Encodable, Sendable {
    let propertyID: String?
    let label: String
    let bedrooms: Int
    let bathrooms: Decimal
    let squareFeet: Int?
    let marketRent: Decimal
    let floor: Int?

    init(_ draft: UnitDraft, propertyID: String?) {
        self.propertyID = propertyID
        self.label = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bedrooms = draft.bedrooms
        self.bathrooms = draft.bathrooms
        self.squareFeet = draft.squareFeet
        self.marketRent = draft.marketRent
        self.floor = draft.floor
    }

    enum CodingKeys: String, CodingKey {
        case label, bedrooms, bathrooms, floor
        case propertyID = "property_id"
        case squareFeet = "square_feet"
        case marketRent = "market_rent"
    }
}

private struct PropertyIDParam: Encodable, Sendable {
    let propertyID: String
    enum CodingKeys: String, CodingKey { case propertyID = "p_property_id" }
}

private struct UnitIDParam: Encodable, Sendable {
    let unitID: String
    enum CodingKeys: String, CodingKey { case unitID = "p_unit_id" }
}

// MARK: - Guarded Update

/// Thrown when the server refuses a version-checked write.
///
/// A typed error rather than an `AppError` case so the caller is forced to
/// handle it — a conflict flattened into `.validation` would show the user
/// "couldn't save" and quietly drop their edit.
struct PropertyConflict: Error, Sendable {
    let recordID: String
    /// The server's current row, for diffing.
    let remote: Data
    let currentVersion: Int
}

private struct GuardedUpdateParams<Patch: Encodable>: Encodable {
    let table: String
    let id: String
    let expectedVersion: Int
    let patch: Patch
    let originToken: String

    enum CodingKeys: String, CodingKey {
        case table           = "p_table"
        case id              = "p_id"
        case expectedVersion = "p_expected_version"
        case patch           = "p_patch"
        case originToken     = "p_origin_token"
    }
}

private struct GuardedUpdateEnvelope: Decodable {
    let conflict: Bool
    let currentVersion: Int?
    let remote: Data?
    let row: Data?

    enum CodingKeys: String, CodingKey {
        case conflict, remote, row
        case currentVersion = "current_version"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conflict = try c.decodeIfPresent(Bool.self, forKey: .conflict) ?? false
        currentVersion = try c.decodeIfPresent(Int.self, forKey: .currentVersion)

        // `remote` and `row` arrive as arbitrary jsonb. Re-encode them to
        // Data so each caller decodes the shape it expects.
        remote = try Self.rawJSON(c, .remote)
        row = try Self.rawJSON(c, .row)
    }

    private static func rawJSON(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) throws -> Data? {
        guard let value = try? container.decode(AnyCodableJSON.self, forKey: key) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value.value)
    }
}
