//
//  SupabaseQuery.swift
//  RentalApp (Purrperty)
//
//  Supabase — Error mapping and query translation.
//
//  ─────────────────────────────────────────────────────────────────
//  WHERE THE WORK HAPPENS
//  ─────────────────────────────────────────────────────────────────
//  `QuerySpec` was designed so search, filter, sort, and paging could
//  travel to the server as data. This file is the payoff: it turns that
//  value into PostgREST parameters. Nothing here filters an array.
//
//  Paging uses `range(from:to:)` with an exact count so `Page.hasMore`
//  is answered by Postgres rather than guessed from "did we get a full
//  page?" — which is wrong on the last page whenever the total happens
//  to be an exact multiple of the page size.
//

import Foundation
import Supabase
import PostgREST

// MARK: - Error Mapping

enum SupabaseErrorMapper {

    /// Collapses transport and Postgres errors into the app's `AppError`.
    ///
    /// RLS denials arrive as an empty result or a 42501, never as a
    /// helpful "you lack permission" — that is deliberate on the server's
    /// part, and we mirror it rather than leaking which rows exist.
    static func map(_ error: Error) -> AppError {
        if let error = error as? AppError { return error }
        if error is CancellationError { return .unknown }

        if let postgrest = error as? PostgrestError {
            switch postgrest.code {
            case "42501", "PGRST301":            return .unauthorized
            case "PGRST116":                     return .notFound("The record")
            case "23505":                        return .validation("That already exists.")
            case "23503":                        return .validation("A related record is missing.")
            case "23514", "22P02":               return .validation("Some values weren't valid.")
            default:                             break
            }
            if let message = postgrest.message.nilIfEmpty {
                return .validation(message)
            }
            return .unknown
        }

        if let auth = error as? AuthError {
            switch auth.errorCode {
            case .invalidCredentials, .noAuthorization: return .invalidCredentials
            case .emailExists, .userAlreadyExists:      return .validation("An account already exists for that email.")
            case .weakPassword:                         return .validation("Choose a stronger password.")
            case .sessionExpired, .sessionNotFound:     return .unauthorized
            case .overRequestRateLimit:                 return .validation("Too many attempts. Try again in a minute.")
            default:                                    return .validation(auth.message)
            }
        }

        let urlError = error as NSError
        if urlError.domain == NSURLErrorDomain { return .network }
        return .unknown
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Paging

extension PageRequest {

    /// `.unpaged` carries `size == .max`, which would ask PostgREST for a
    /// range ending at `Int.max`. Clamp it to something a server will
    /// actually accept — these callers are bounded collections anyway
    /// (a property's units, a ticket's comments).
    private var effectiveSize: Int { min(size, 1000) }

    /// Inclusive PostgREST range bounds.
    var rangeLowerBound: Int { page * effectiveSize }
    var rangeUpperBound: Int { page * effectiveSize + effectiveSize - 1 }
}

// MARK: - Search

enum SupabaseSearch {

    /// Builds an `or=(a.ilike.*term*,b.ilike.*term*)` clause.
    ///
    /// The term is stripped of PostgREST's delimiters first. Without
    /// that, a search for `a,b` would be parsed as two conditions and a
    /// search containing `)` could close the filter group early — the
    /// PostgREST equivalent of an injection.
    static func orILike(columns: [String], term: String) -> String {
        let safe = term.filter { !#"(),.*"\:"#.contains($0) }
        return columns.map { "\($0).ilike.*\(safe)*" }.joined(separator: ",")
    }

    /// Sanitises a term for a single `ilike` value.
    static func like(_ term: String) -> String {
        "*" + term.filter { !#"(),.*"\:"#.contains($0) } + "*"
    }
}

// MARK: - Query Application

extension PostgrestTransformBuilder {

    /// Applies sort + paging from a `QuerySpec`.
    ///
    /// A secondary sort on `id` is always appended: without a tiebreaker
    /// Postgres may return rows in a different order between two pages of
    /// the same query, which shows up as duplicated or skipped rows in an
    /// infinitely scrolling list.
    func applying<F, S>(_ query: QuerySpec<F, S>, idColumn: String = "id") -> PostgrestTransformBuilder {
        self
            .order(query.sort.field.rawValue, ascending: query.sort.direction.isAscending)
            .order(idColumn, ascending: true)
            .range(from: query.page.rangeLowerBound, to: query.page.rangeUpperBound)
    }
}

// MARK: - Page Assembly

enum SupabasePage {

    /// Builds a `Page` from a decoded response plus the exact count
    /// PostgREST reported.
    static func make<Element>(
        items: [Element],
        totalCount: Int?,
        request: PageRequest
    ) -> Page<Element> {
        let hasMore: Bool
        if let totalCount {
            hasMore = request.rangeUpperBound + 1 < totalCount
        } else {
            // No count header — fall back to the imperfect heuristic.
            hasMore = items.count == request.size
        }
        return Page(items: items, page: request.page, hasMore: hasMore)
    }
}
