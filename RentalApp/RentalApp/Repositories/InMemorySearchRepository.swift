//
//  InMemorySearchRepository.swift
//  RentalApp (Purrperty)
//
//  Repositories — Search over the seeded graph.
//
//  Deliberately imitates the *shape* of the Postgres ranking rather than
//  just filtering: title matches outrank body matches, prefix beats
//  substring, and recency breaks ties. A mock that returned unranked hits in
//  table order would let a ranking bug reach production looking fine in
//  every preview.
//
//  What it cannot imitate is stemming — "leaking" will not match "leaks"
//  here. That gap is the honest limit of a client-side index, and the reason
//  the real implementation is a database one.
//

import Foundation

@MainActor
final class InMemorySearchRepository: SearchRepositoryProtocol {

    private let cache: RepositoryCache

    init(cache: RepositoryCache = .shared) {
        self.cache = cache
    }

    private static let namespace = "search"

    // MARK: Search

    func search(_ query: SearchQuery) async throws -> Page<SearchResult> {
        guard query.isSearchable else { return .empty }
        try await SimulatedLatency.wait(.list)
        try Task.checkCancellation()

        if let filter = query.filter {
            return Self.sorted(Self.results(for: filter, kinds: query.kinds), by: query.sort)
                .page(query.page)
        }

        let term = query.trimmed.lowercased()
        var scored = corpus()
            .filter { query.kinds.isEmpty || query.kinds.contains($0.kind) }
            .compactMap { entry -> (SearchResult, Double)? in
                guard let score = Self.score(entry, term: term) else { return nil }
                return (entry.result(matching: term), score)
            }

        switch query.sort {
        case .relevance:
            scored.sort { lhs, rhs in
                lhs.1 == rhs.1
                    ? lhs.0.updatedAt > rhs.0.updatedAt
                    : lhs.1 > rhs.1
            }
        case .recent:
            scored.sort { $0.0.updatedAt > $1.0.updatedAt }
        case .title:
            scored.sort { $0.0.title.localizedStandardCompare($1.0.title) == .orderedAscending }
        }

        return scored.map(\.0).page(query.page)
    }

    func suggestions(prefix: String) async throws -> [SearchSuggestion] {
        let term = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard term.count >= 2 else { return [] }

        return corpus()
            .filter { $0.title.lowercased().hasPrefix(term) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(6)
            .map {
                SearchSuggestion(
                    id: "\($0.kind.rawValue):\($0.entityID)",
                    text: $0.title,
                    subtitle: $0.subtitle,
                    source: .completion($0.kind)
                )
            }
    }

    func counts(for query: SearchQuery) async throws -> [SearchKind: Int] {
        guard query.isSearchable else { return [:] }

        if let filter = query.filter {
            let total = Self.results(for: filter, kinds: []).count
            return total > 0 ? [filter.kind: total] : [:]
        }

        let term = query.trimmed.lowercased()

        return corpus()
            .filter { Self.score($0, term: term) != nil }
            .reduce(into: [:]) { counts, entry in
                counts[entry.kind, default: 0] += 1
            }
    }

    // MARK: Filters

    /// A filter keyword is answered by a predicate, not by text matching.
    /// Not cached: "ends within 60 days" goes stale with the clock and with
    /// every edit, and the walk is cheap next to the projection one.
    private static func results(for filter: SearchFilter, kinds: Set<SearchKind>) -> [SearchResult] {
        guard kinds.isEmpty || kinds.contains(filter.kind) else { return [] }
        return Projections.searchResults(for: filter)
    }

    private static func sorted(_ results: [SearchResult], by sort: SearchSort) -> [SearchResult] {
        switch sort {
        case .relevance:
            results.sorted { $0.rank > $1.rank }
        case .recent:
            results.sorted { $0.updatedAt > $1.updatedAt }
        case .title:
            results.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    // MARK: Scoring

    /// Mirrors the weighting in `global_search`: title (A) > subtitle (B) >
    /// body (C), with a prefix bonus and a recency nudge.
    private static func score(_ entry: Entry, term: String) -> Double? {
        let title = entry.title.lowercased()
        let subtitle = (entry.subtitle ?? "").lowercased()
        let body = entry.body.lowercased()

        var score = 0.0
        if title.hasPrefix(term)        { score += 1.0 }
        else if title.contains(term)    { score += 0.7 }
        if subtitle.contains(term)      { score += 0.4 }
        if body.contains(term)          { score += 0.2 }

        guard score > 0 else { return nil }

        // Same shape as the SQL: a small, decaying recency term that only
        // matters between otherwise-equal matches.
        let ageDays = Date().timeIntervalSince(entry.updatedAt) / 86_400
        score += max(0, 0.15 - (ageDays / 180) * 0.15)
        return score
    }

    // MARK: Corpus

    /// Flattens the seeded graph into searchable entries.
    ///
    /// Cached: it is rebuilt on every keystroke otherwise, and the projection
    /// walk is the expensive part, not the matching.
    private func corpus() -> [Entry] {
        cache.value(for: Self.namespace, as: [Entry].self) ?? {
            let built = Self.build()
            cache.store(built, for: Self.namespace, lifetime: 120)
            return built
        }()
    }

    private static func build() -> [Entry] {
        var entries: [Entry] = []

        for property in Projections.properties() {
            entries.append(Entry(
                kind: .property, entityID: property.id,
                title: property.name,
                subtitle: property.address,
                body: "\(property.neighborhood) \(property.kind.rawValue)",
                status: nil, updatedAt: Date()
            ))

            for unit in Projections.units(forPropertyID: property.id) {
                entries.append(Entry(
                    kind: .unit, entityID: unit.id,
                    title: "\(property.name) · \(unit.name)",
                    subtitle: "\(unit.beds) bd · \(unit.baths) ba",
                    body: unit.tenantName ?? "vacant",
                    status: unit.status.rawValue, updatedAt: Date()
                ))
            }
        }

        for tenant in Projections.tenants() {
            entries.append(Entry(
                kind: .tenant, entityID: tenant.id,
                title: tenant.name,
                subtitle: tenant.propertyName,
                body: "\(tenant.unitName) \(tenant.status.rawValue)",
                status: tenant.status.rawValue, updatedAt: Date()
            ))
        }

        return entries
    }

    // MARK: Entry

    private struct Entry: Codable, Sendable {
        let kind: SearchKind
        let entityID: String
        let title: String
        let subtitle: String?
        let body: String
        let status: String?
        let updatedAt: Date

        /// Builds a headline with the same `«»` markers Postgres emits, so
        /// the highlighting path is exercised identically in both graphs.
        func result(matching term: String) -> SearchResult {
            SearchResult(
                kind: kind,
                entityID: entityID,
                title: title,
                subtitle: subtitle,
                headline: Self.headline(for: body.isEmpty ? title : body, term: term),
                status: status,
                updatedAt: updatedAt,
                rank: 0
            )
        }

        private static func headline(for text: String, term: String) -> String {
            guard let range = text.range(of: term, options: .caseInsensitive) else {
                return text
            }
            return text.replacingCharacters(
                in: range,
                with: "«\(text[range])»"
            )
        }
    }
}
