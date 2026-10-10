//
//  AsyncListModel.swift
//  RentalApp (Purrperty)
//
//  Core — Shared machinery for every paginated list screen.
//
//  Six screens need the same loop: load a first page, show a spinner,
//  show an error with retry, append on scroll, reset on query change,
//  and refresh without blanking the screen. Rather than reimplement
//  that six times, view models compose this and supply one closure
//  that fetches a page.
//
//  This is generic *state* machinery — it never touches a repository
//  itself. The owning view model injects the fetch, keeping the
//  protocol-only dependency rule intact.
//

import Foundation
import Observation

@MainActor
@Observable
final class AsyncListModel<Element: Identifiable> {

    // MARK: State

    private(set) var state: LoadState<[Element]> = .idle
    /// Distinct from `state.isLoading`: a refresh keeps content visible.
    private(set) var isRefreshing = false
    /// Distinct again: appending a page keeps content and shows a footer.
    private(set) var isLoadingMore = false
    private(set) var hasMore = false

    /// Items currently loaded. Empty while idle, loading, or failed.
    var items: [Element] { state.value ?? [] }

    var error: AppError? { state.error }
    var isEmpty: Bool { state.isLoaded && items.isEmpty }

    // MARK: Dependencies

    /// Supplied by the owning view model. Takes a page index, returns
    /// that page. The list model never knows what it is talking to.
    /// `@MainActor` on the closure is the whole reason `Element` needs no
    /// `Sendable` bound: pages are produced and consumed on the main
    /// actor, so an element never crosses an isolation boundary.
    private let fetch: @MainActor (PageRequest, Bool) async throws -> Page<Element>
    private let pageSize: Int

    private var currentPage = 0
    private var activeTask: Task<Void, Never>?

    init(
        pageSize: Int = 25,
        fetch: @escaping @MainActor (PageRequest, Bool) async throws -> Page<Element>
    ) {
        self.pageSize = pageSize
        self.fetch = fetch
    }

    // No `deinit` cancellation on purpose. The load task captures `self`
    // strongly, so this object cannot be deallocated while a task is in
    // flight — a `deinit` could only ever cancel an already-finished
    // task. Real cancellation happens on the main actor in `performLoad`
    // and `loadMore`, where a superseded query actually needs stopping.
    // (`deinit` is nonisolated and cannot touch `activeTask` anyway.)

    // MARK: Loading

    /// First load. Safe to call repeatedly — it no-ops once loaded,
    /// which is what makes `.task { await load() }` correct on a view
    /// that SwiftUI may re-create.
    func load() async {
        guard case .idle = state else { return }
        await performLoad(forceRefresh: false, showsSpinner: true)
    }

    /// Pull-to-refresh. Keeps existing rows on screen while it works.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await performLoad(forceRefresh: true, showsSpinner: false)
    }

    /// Explicit retry from the error state.
    func retry() async {
        state = .idle
        await performLoad(forceRefresh: true, showsSpinner: true)
    }

    /// Called when the query changes — resets paging and reloads.
    func reload() async {
        activeTask?.cancel()
        currentPage = 0
        await performLoad(forceRefresh: false, showsSpinner: !state.isLoaded)
    }

    /// Infinite scroll hook. Pass the row about to appear; this fires
    /// only when it is near the end and another page exists.
    func loadMoreIfNeeded(currentItem item: Element) async {
        guard hasMore, !isLoadingMore, state.isLoaded else { return }
        let threshold = max(items.count - 5, 0)
        guard items.firstIndex(where: { $0.id == item.id }).map({ $0 >= threshold }) == true
        else { return }
        await loadMore()
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let request = PageRequest(page: currentPage + 1, size: pageSize)
        do {
            let page = try await fetch(request, false)
            guard !Task.isCancelled else { return }
            state = .loaded(items + page.items)
            currentPage = page.page
            hasMore = page.hasMore
        } catch is CancellationError {
            return
        } catch {
            // A failed *append* must not destroy the rows already shown.
            hasMore = false
        }
    }

    // MARK: Optimistic Edits
    //
    // A mutation must be visible before the server confirms it, and the
    // list owns `state`, so the splice happens here rather than a view
    // model reaching into private storage. Each of these is a pure local
    // edit — the caller is responsible for the network call and for
    // handing back the snapshot if it fails.

    /// The current items, for a caller that needs to roll back later.
    var snapshot: [Element] { items }

    /// Replaces the loaded items, keeping the state case intact.
    ///
    /// No-ops unless already loaded: applying an optimistic edit to a list
    /// that is still loading would turn a spinner into a one-row list.
    func replaceItems(_ newItems: [Element]) {
        guard case .loaded = state else { return }
        state = .loaded(newItems)
    }

    /// Removes by id. Used by archive and delete.
    func remove(id: Element.ID) {
        replaceItems(items.filter { $0.id != id })
    }

    func remove(ids: Set<Element.ID>) {
        replaceItems(items.filter { !ids.contains($0.id) })
    }

    /// Replaces a row in place, or prepends it when it is new. Keeps the
    /// user's scroll position, which a reload would throw away.
    func upsert(_ element: Element) {
        if let index = items.firstIndex(where: { $0.id == element.id }) {
            var copy = items
            copy[index] = element
            replaceItems(copy)
        } else {
            replaceItems([element] + items)
        }
    }

    // MARK: Core

    private func performLoad(forceRefresh: Bool, showsSpinner: Bool) async {
        activeTask?.cancel()

        if showsSpinner { state = .loading }
        currentPage = 0

        let task = Task { @MainActor in
            do {
                let page = try await fetch(PageRequest(page: 0, size: pageSize), forceRefresh)
                guard !Task.isCancelled else { return }
                state = .loaded(page.items)
                currentPage = page.page
                hasMore = page.hasMore
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(error as? AppError ?? .unknown)
                hasMore = false
            }
        }

        activeTask = task
        await task.value
    }
}
