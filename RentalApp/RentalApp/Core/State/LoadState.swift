//
//  LoadState.swift
//  RentalApp (RentOS)
//
//  Core — The single vocabulary for asynchronous screen state.
//
//  Every screen in RentOS is in exactly one of four states: it hasn't
//  asked yet, it's asking, it has data, or it failed. Modelling that
//  as an enum instead of three loose booleans (`isLoading`,
//  `hasError`, `items.isEmpty`) makes impossible combinations
//  unrepresentable — you can never render a spinner over an error
//  over stale rows.
//
//  `refresh` is deliberately NOT a case: refreshing keeps showing the
//  data you already have, so it is a separate flag on the view model.
//

import Foundation

// MARK: - Load State

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(AppError)
}

extension LoadState {

    /// Data if we have it, regardless of what is happening now.
    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var error: AppError? {
        if case .failed(let error) = self { return error }
        return nil
    }

    /// True only for the *first* load. Refreshes keep showing content.
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isLoaded: Bool { value != nil }

    var hasFailed: Bool { error != nil }

    /// Transforms the payload while preserving the state case.
    func map<T>(_ transform: (Value) -> T) -> LoadState<T> {
        switch self {
        case .idle: .idle
        case .loading: .loading
        case .loaded(let value): .loaded(transform(value))
        case .failed(let error): .failed(error)
        }
    }
}

extension LoadState: Equatable where Value: Equatable {
    static func == (lhs: LoadState<Value>, rhs: LoadState<Value>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading): true
        case (.loaded(let a), .loaded(let b)): a == b
        case (.failed(let a), .failed(let b)): a == b
        default: false
        }
    }
}

extension LoadState where Value: Collection {
    /// Loaded but with nothing in it — the empty-state trigger.
    var isEmpty: Bool {
        guard let value else { return false }
        return value.isEmpty
    }
}

// MARK: - Paging

/// One slice of a larger collection.
///
/// Carries `hasMore` rather than a total count because most real APIs
/// (including PostgREST with `Range` headers) can answer "is there
/// another page?" far more cheaply than "how many rows exist?".
struct Page<Element> {
    let items: [Element]
    let page: Int
    let hasMore: Bool

    init(items: [Element], page: Int, hasMore: Bool) {
        self.items = items
        self.page = page
        self.hasMore = hasMore
    }

    static var empty: Page<Element> {
        Page(items: [], page: 0, hasMore: false)
    }
}

/// What the caller wants next.
/// Sendable only when its contents are.
///
/// A hard `where Element: Sendable` constraint forced every consumer to
/// require Sendable too — including `AsyncListModel`, which is
/// `@MainActor` end to end and never moves an element across an
/// isolation boundary. Conditional conformance keeps the guarantee
/// where it is real without imposing it where it is not.
extension Page: Sendable where Element: Sendable {}

/// Codable only when its contents are — same reasoning as Sendable above.
/// Needed so the offline cache can persist a whole page, including whether
/// more exist, rather than just the items.
extension Page: Codable where Element: Codable {}

struct PageRequest: Sendable, Equatable {
    let page: Int
    let size: Int

    init(page: Int = 0, size: Int = 25) {
        self.page = page
        self.size = size
    }

    var offset: Int { page * size }

    var next: PageRequest { PageRequest(page: page + 1, size: size) }

    /// Everything in one go — for small, bounded collections.
    static let unpaged = PageRequest(page: 0, size: .max)
}

// MARK: - Slicing Helper

extension Array where Element: Sendable {

    /// Applies a page request to an in-memory array.
    /// The networked implementation will do this server-side instead.
    func page(_ request: PageRequest) -> Page<Element> {
        guard request.size != .max else {
            return Page(items: self, page: 0, hasMore: false)
        }
        let start = Swift.min(request.offset, count)
        let end = Swift.min(start + request.size, count)
        return Page(
            items: Array(self[start..<end]),
            page: request.page,
            hasMore: end < count
        )
    }
}
