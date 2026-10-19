//
//  SupabaseSearchRepository.swift
//  RentalApp (Purrperty)
//
//  Supabase — Global search over `global_search()`.
//
//  One RPC per keystroke-batch. Ranking, highlighting, and paging all happen
//  in Postgres, so this file is almost entirely decoding — which is the point:
//  the client's job is to render a result, not to compute one.
//

import Foundation
import Supabase

@MainActor
final class SupabaseSearchRepository: SearchRepositoryProtocol {

    private let client: SupabaseClient
    private let cache: RepositoryCache

    init(client: SupabaseClient, cache: RepositoryCache = .shared) {
        self.client = client
        self.cache = cache
    }

    func search(_ query: SearchQuery) async throws -> Page<SearchResult> {
        guard query.isSearchable else { return .empty }

        do {
            let rows = try await fetchRows(
                query,
                limit: query.page.size,
                offset: query.page.page * query.page.size
            )

            let items = rows.compactMap(\.asResult)
            // `total_count` is a window function over the full match set, so
            // `hasMore` is exact rather than the usual "we got a full page,
            // there's probably another" guess.
            let total = rows.first?.totalCount ?? items.count
            let consumed = query.page.page * query.page.size + items.count

            return Page(
                items: items,
                page: query.page.page,
                hasMore: consumed < total
            )
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func suggestions(prefix: String) async throws -> [SearchSuggestion] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        do {
            // Short-lived cache: the same prefix recurs constantly while
            // typing and backspacing, and this is the one search call that
            // fires on literally every keystroke.
            return try await cache.fetch(
                key: "search.suggest.\(trimmed.lowercased())",
                lifetime: 30
            ) {
                let rows: [SuggestionRow] = try await client
                    .rpc("search_suggestions", params: SuggestionParams(prefix: trimmed, limit: 6))
                    .execute()
                    .value

                return rows.compactMap { row in
                    guard let kind = SearchKind(rawValue: row.kind) else { return nil }
                    return SearchSuggestion(
                        id: "\(row.kind):\(row.entityID)",
                        text: row.title,
                        subtitle: row.subtitle,
                        source: .completion(kind)
                    )
                }
            }
        } catch {
            // Suggestions are a convenience. A failure here must not break the
            // search the user is actually performing.
            return []
        }
    }

    func counts(for query: SearchQuery) async throws -> [SearchKind: Int] {
        guard query.isSearchable else { return [:] }

        do {
            // Ask for one unscoped page large enough to bucket by kind. A
            // dedicated count RPC would be exact, but this keeps the chips
            // honest for the sizes that matter without a second index scan.
            var unscoped = query
            unscoped.kinds = []
            unscoped.page = PageRequest(page: 0, size: 100)

            unscoped.sort = .relevance
            let rows = try await fetchRows(unscoped, limit: 100, offset: 0)

            return rows.reduce(into: [:]) { counts, row in
                guard let kind = SearchKind(rawValue: row.kind) else { return }
                counts[kind, default: 0] += 1
            }
        } catch {
            return [:]
        }
    }
}

// MARK: - Dispatch

private extension SupabaseSearchRepository {

    /// A filter keyword ("expiring") names a state, not text, so it goes to
    /// `search_filtered`; anything else is a text search. Both return the
    /// same row shape.
    func fetchRows(_ query: SearchQuery, limit: Int, offset: Int) async throws -> [SearchRow] {
        let kinds = query.kinds.isEmpty ? nil : query.kinds.map(\.rawValue).sorted()

        if let filter = query.filter {
            return try await client
                .rpc("search_filtered", params: FilterParams(
                    filter: filter.keyword,
                    kinds: kinds,
                    sort: query.sort.rawValue,
                    limit: limit,
                    offset: offset
                ))
                .execute()
                .value
        }

        return try await client
            .rpc("global_search", params: SearchParams(
                query: query.trimmed,
                kinds: kinds,
                sort: query.sort.rawValue,
                limit: limit,
                offset: offset
            ))
            .execute()
            .value
    }
}

// MARK: - Wire Types

private struct FilterParams: Encodable {
    let filter: String
    let kinds: [String]?
    let sort: String
    let limit: Int
    let offset: Int

    enum CodingKeys: String, CodingKey {
        case filter = "p_filter"
        case kinds  = "p_kinds"
        case sort   = "p_sort"
        case limit  = "p_limit"
        case offset = "p_offset"
    }
}

private struct SearchParams: Encodable {
    let query: String
    let kinds: [String]?
    let sort: String
    let limit: Int
    let offset: Int

    enum CodingKeys: String, CodingKey {
        case query  = "p_query"
        case kinds  = "p_kinds"
        case sort   = "p_sort"
        case limit  = "p_limit"
        case offset = "p_offset"
    }
}

private struct SuggestionParams: Encodable {
    let prefix: String
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case prefix = "p_prefix"
        case limit  = "p_limit"
    }
}

private struct SearchRow: Decodable {
    let kind: String
    let entityID: String
    let title: String
    let subtitle: String?
    let headline: String?
    let status: String?
    let entityUpdatedAt: Date
    let rank: Double
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case kind, title, subtitle, headline, status, rank
        case entityID        = "entity_id"
        case entityUpdatedAt = "entity_updated_at"
        case totalCount      = "total_count"
    }

    /// Nil when the server sends a kind this build doesn't know — a newer
    /// backend enum must not crash an older client.
    var asResult: SearchResult? {
        guard let searchKind = SearchKind(rawValue: kind) else { return nil }
        return SearchResult(
            kind: searchKind,
            entityID: entityID,
            title: title,
            subtitle: subtitle,
            headline: headline ?? subtitle ?? title,
            status: status,
            updatedAt: entityUpdatedAt,
            rank: rank
        )
    }
}

private struct SuggestionRow: Decodable {
    let kind: String
    let entityID: String
    let title: String
    let subtitle: String?

    enum CodingKeys: String, CodingKey {
        case kind, title, subtitle
        case entityID = "entity_id"
    }
}
