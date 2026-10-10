//
//  Query.swift
//  RentalApp (Purrperty)
//
//  Core — Search, filter, and sort expressed as data.
//
//  A query is a *value* passed to the repository, not logic performed
//  after the fact in a view model. That distinction is what lets the
//  same call become a PostgREST request later: `?name=ilike.*queen*`
//  &`order=rent.desc`&`limit=25` is a direct translation of the
//  struct below. If filtering lived in the view model, every screen
//  would silently keep downloading the whole table forever.
//

import Foundation

// MARK: - Sort

enum SortDirection: String, Sendable, Codable {
    case ascending = "asc"
    case descending = "desc"

    var isAscending: Bool { self == .ascending }
}

/// A sortable field plus its direction.
struct SortOrder<Field: RawRepresentable & Sendable>: Sendable
where Field.RawValue == String {
    let field: Field
    let direction: SortDirection

    init(_ field: Field, _ direction: SortDirection = .ascending) {
        self.field = field
        self.direction = direction
    }

    /// PostgREST `order` parameter, ready for the future client.
    var parameter: String { "\(field.rawValue).\(direction.rawValue)" }
}

// MARK: - Query Specification

/// Everything a list screen asks a repository for.
///
/// Generic over the feature's own `Filter` and `Field` enums so each
/// domain keeps its own vocabulary while sharing this envelope.
struct QuerySpec<Filter: Sendable, Field: RawRepresentable & Sendable>: Sendable
where Field.RawValue == String {

    var search: String
    var filter: Filter
    var sort: SortOrder<Field>
    var page: PageRequest

    init(
        search: String = "",
        filter: Filter,
        sort: SortOrder<Field>,
        page: PageRequest = PageRequest()
    ) {
        self.search = search
        self.filter = filter
        self.sort = sort
        self.page = page
    }

    /// Normalised search term — empty means "no search".
    var searchTerm: String? {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    /// Same query, next page. Used by infinite scroll.
    var nextPage: Self {
        var copy = self
        copy.page = page.next
        return copy
    }

    /// Same query, back to the first page. Used whenever search,
    /// filter, or sort changes — otherwise page 3 of the old query
    /// gets appended to page 1 of the new one.
    var firstPage: Self {
        var copy = self
        copy.page = PageRequest(page: 0, size: page.size)
        return copy
    }
}

/// Query identity, so a view model can tell whether a change actually
/// invalidates the cached result.
extension QuerySpec: Equatable where Filter: Equatable, Field: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.search == rhs.search
            && lhs.filter == rhs.filter
            && lhs.sort.field == rhs.sort.field
            && lhs.sort.direction == rhs.sort.direction
            && lhs.page == rhs.page
    }
}

// MARK: - Matching Helper

extension String {
    /// Case- and diacritic-insensitive containment, matching what a
    /// user expects from a search box (and what `ilike` does).
    func matches(_ term: String) -> Bool {
        range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
