//
//  SearchModels.swift
//  RentalApp (Purrperty)
//
//  Core/Search — One result type for eight entities.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY A UNIFORM RESULT AND NOT AN ENUM OF MODELS
//  ─────────────────────────────────────────────────────────────────
//  `enum SearchResult { case property(Property), case tenant(Tenant) … }`
//  looks type-safe and makes the result list unwritable: every row needs a
//  switch, ranking across cases is meaningless, and adding a ninth entity
//  touches every call site.
//
//  Instead each result is already presentational — title, subtitle,
//  highlighted snippet, and the route that opens it. The database returns
//  it in that shape, so the client does no per-kind work at all.
//

import SwiftUI

// MARK: - Kind

enum SearchKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case property
    case unit
    case tenant
    case lease
    case maintenanceRequest = "maintenance_request"
    case document
    case message
    case vendor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .property:           "Properties"
        case .unit:               "Units"
        case .tenant:             "Tenants"
        case .lease:              "Leases"
        case .maintenanceRequest: "Maintenance"
        case .document:           "Documents"
        case .message:            "Messages"
        case .vendor:             "Vendors"
        }
    }

    /// Singular, for a result row's type badge.
    var singular: String {
        switch self {
        case .property:           "Property"
        case .unit:               "Unit"
        case .tenant:             "Tenant"
        case .lease:              "Lease"
        case .maintenanceRequest: "Request"
        case .document:           "Document"
        case .message:            "Message"
        case .vendor:             "Vendor"
        }
    }

    var icon: String {
        switch self {
        case .property:           DS.Icons.properties
        case .unit:               DS.Icons.unit
        case .tenant:             DS.Icons.tenant
        case .lease:              DS.Icons.lease
        case .maintenanceRequest: DS.Icons.maintenance
        case .document:           DS.Icons.documents
        case .message:            DS.Icons.messages
        case .vendor:             DS.Icons.vendor
        }
    }

    /// Grouped by domain: portfolio violet, people sky, operations coral,
    /// files sunny, conversation mint.
    var accent: DSAccent {
        switch self {
        case .property, .unit:            .violet
        case .tenant, .lease:             .sky
        case .maintenanceRequest, .vendor: .coral
        case .document:                   .sunny
        case .message:                    .mint
        }
    }

    /// AA-safe foreground, also used at low opacity for the chip background.
    var tint: Color { accent.ink }

    /// Display order in grouped results — roughly how often a manager wants
    /// each one, so the common case is at the top without scrolling.
    var sortIndex: Int {
        switch self {
        case .property:           0
        case .unit:               1
        case .tenant:             2
        case .lease:              3
        case .maintenanceRequest: 4
        case .message:            5
        case .document:           6
        case .vendor:             7
        }
    }
}

// MARK: - Result

struct SearchResult: Identifiable, Sendable, Equatable {

    let kind: SearchKind
    let entityID: String
    let title: String
    let subtitle: String?
    /// Snippet with `«` / `»` around matched terms, from `ts_headline`.
    let headline: String
    let status: String?
    let updatedAt: Date
    let rank: Double

    var id: String { "\(kind.rawValue):\(entityID)" }

    /// Where tapping this goes.
    ///
    /// Nil for kinds with no dedicated screen yet — the row then renders
    /// disabled rather than navigating somewhere wrong, which is the one
    /// thing worse than not navigating at all.
    var route: AppRoute? {
        switch kind {
        case .property:           .propertyDetail(propertyID: entityID)
        case .unit:               .unitDetail(unitID: entityID)
        case .tenant:             .tenantDetail(tenantID: entityID)
        case .maintenanceRequest: .maintenanceDetail(requestID: entityID)
        case .message:            .conversation(conversationID: entityID)
        case .document:           .documents
        // A lease opens its tenant, and a vendor has no screen yet.
        case .lease:              nil
        case .vendor:             nil
        }
    }
}

// MARK: - Highlighting

enum SearchHighlight {

    /// Turns `ts_headline` output into styled text.
    ///
    /// The markers come from Postgres because only the server knows which
    /// lexemes actually matched: a client searching for "leaking" cannot
    /// know that "leaks" matched via stemming, so client-side range
    /// matching highlights the wrong words — or nothing.
    static func attributed(
        _ headline: String,
        highlight: Color = DS.Colors.brand
    ) -> AttributedString {

        var output = AttributedString()
        var isMatch = false

        // Split on the markers, alternating plain/highlighted.
        for segment in headline.split(
            omittingEmptySubsequences: false,
            whereSeparator: { $0 == "«" || $0 == "»" }
        ) {
            var piece = AttributedString(String(segment))
            if isMatch {
                piece.foregroundColor = highlight
                piece.font = .system(size: 13, weight: .bold)
            }
            output.append(piece)
            isMatch.toggle()
        }
        return output
    }

    /// Strips markers, for contexts that cannot render attributed text.
    static func plain(_ headline: String) -> String {
        headline.replacingOccurrences(of: "«", with: "")
            .replacingOccurrences(of: "»", with: "")
    }
}

// MARK: - Query

/// What the user is asking for.
enum SearchSort: String, Codable, Sendable, CaseIterable, Identifiable {
    case relevance
    case recent
    case title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relevance: "Best match"
        case .recent:    "Recent"
        case .title:     "Name"
        }
    }
}

/// Keyword today, semantic when embeddings land.
///
/// Carried through the whole stack now so enabling semantic search is a
/// server change plus a picker, not a refactor.
enum SearchMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case keyword
    /// Meaning-based. Requires embeddings; falls back to keyword until then.
    case semantic
    /// Both, blended by rank.
    case hybrid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keyword:  "Exact"
        case .semantic: "Meaning"
        case .hybrid:   "Smart"
        }
    }

    /// Only keyword is backed today. The picker hides the rest rather than
    /// offering a control that silently does nothing.
    var isAvailable: Bool { self == .keyword }
}

struct SearchQuery: Sendable, Equatable {
    var text: String
    /// Empty means every kind.
    var kinds: Set<SearchKind>
    var sort: SearchSort
    var mode: SearchMode
    var page: PageRequest

    init(
        text: String = "",
        kinds: Set<SearchKind> = [],
        sort: SearchSort = .relevance,
        mode: SearchMode = .keyword,
        page: PageRequest = PageRequest(page: 0, size: 20)
    ) {
        self.text = text
        self.kinds = kinds
        self.sort = sort
        self.mode = mode
        self.page = page
    }

    var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Two characters is the floor: one letter matches most of the corpus
    /// and costs a full-table trigram scan for a useless result set.
    var isSearchable: Bool { trimmed.count >= 2 }

    var firstPage: SearchQuery {
        var copy = self
        copy.page = PageRequest(page: 0, size: page.size)
        return copy
    }
}

// MARK: - Suggestions

/// What to show before there is a query, or alongside a short one.
struct SearchSuggestion: Identifiable, Sendable, Equatable {

    enum Source: Sendable, Equatable {
        /// Something the user searched before.
        case recent
        /// A title-prefix completion from the index.
        case completion(SearchKind)
        /// A canned jump, e.g. "Overdue rent".
        case shortcut
    }

    let id: String
    let text: String
    let subtitle: String?
    let source: Source

    var icon: String {
        switch source {
        case .recent:              DS.Icons.clock
        case .completion(let kind): kind.icon
        case .shortcut:            "bolt.fill"
        }
    }
}

// MARK: - Recent Searches

/// Persisted query history.
///
/// Stores the *query*, not the results: replaying a search is cheap and
/// always current, while cached results go stale and would show a deleted
/// property as if it still existed.
@MainActor
@Observable
final class RecentSearchStore {

    private(set) var recents: [String] = []

    private let persistence: PersistenceServiceProtocol
    private let limit: Int
    private static let key = "rentos.search.recents.v1"

    init(persistence: PersistenceServiceProtocol, limit: Int = 8) {
        self.persistence = persistence
        self.limit = limit
        load()
    }

    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }

        // Case-insensitive dedupe, most recent first.
        recents.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recents.insert(trimmed, at: 0)
        if recents.count > limit { recents = Array(recents.prefix(limit)) }
        save()
    }

    func remove(_ query: String) {
        recents.removeAll { $0 == query }
        save()
    }

    func clear() {
        recents.removeAll()
        save()
    }

    private func load() {
        guard let data = persistence.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else { return }
        recents = decoded
    }

    private func save() {
        persistence.set(try? JSONEncoder().encode(recents), forKey: Self.key)
    }
}

// MARK: - Shortcuts

enum SearchShortcuts {

    /// Offered on an empty field. Each is a real query, not a special case —
    /// so they behave exactly like something the user typed.
    static let all: [SearchSuggestion] = [
        .init(id: "sc-vacant",   text: "vacant",   subtitle: "Units without a tenant",   source: .shortcut),
        .init(id: "sc-urgent",   text: "urgent",   subtitle: "High-priority maintenance", source: .shortcut),
        .init(id: "sc-expiring", text: "expiring", subtitle: "Leases ending soon",        source: .shortcut),
        .init(id: "sc-overdue",  text: "overdue",  subtitle: "Tenants behind on rent",    source: .shortcut)
    ]
}
