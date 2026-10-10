//
//  SearchRepository.swift
//  RentalApp (Purrperty)
//
//  Core/Search — The contract.
//

import Foundation

@MainActor
protocol SearchRepositoryProtocol: AnyObject {

    /// Ranked results for a query. Paged, because a broad term across eight
    /// entity types can legitimately match hundreds of rows.
    func search(_ query: SearchQuery) async throws -> Page<SearchResult>

    /// Title-prefix completions, cheap enough to run per keystroke.
    func suggestions(prefix: String) async throws -> [SearchSuggestion]

    /// Per-kind counts for the whole result set, so the scope chips can show
    /// "Tenants 12" without fetching twelve pages.
    func counts(for query: SearchQuery) async throws -> [SearchKind: Int]
}
