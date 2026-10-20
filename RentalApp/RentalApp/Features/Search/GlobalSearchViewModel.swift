//
//  GlobalSearchViewModel.swift
//  RentalApp (Purrperty)
//
//  Search — Query state, debouncing, and keyboard selection.
//
//  ─────────────────────────────────────────────────────────────────
//  DEBOUNCE IS NOT ENOUGH; YOU ALSO HAVE TO CANCEL
//  ─────────────────────────────────────────────────────────────────
//  Debouncing stops you firing a request per keystroke. It does not stop an
//  earlier, slower request landing *after* a later one and overwriting good
//  results with stale ones — the bug where typing "queen" briefly shows
//  results for "quee".
//
//  So each search cancels the one before it, and the response is discarded
//  unless it belongs to the current query. Both are needed; neither alone
//  is sufficient.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class GlobalSearchViewModel {

    // MARK: Query inputs

    var text = "" {
        didSet {
            guard oldValue != text else { return }
            selectedIndex = nil
            scheduleSearch(debounced: true)
        }
    }

    private(set) var scope: Set<SearchKind> = []
    private(set) var sort: SearchSort = .relevance
    private(set) var mode: SearchMode = .keyword

    // MARK: Results

    private(set) var state: LoadState<[SearchResult]> = .idle
    private(set) var counts: [SearchKind: Int] = [:]
    private(set) var suggestions: [SearchSuggestion] = []
    private(set) var isLoadingMore = false
    private(set) var hasMore = false

    /// Keyboard selection. Nil means nothing is focused, which is distinct
    /// from index 0 — arrowing down from nothing should land on the first
    /// row, not the second.
    var selectedIndex: Int?

    // MARK: Dependencies

    private let repository: SearchRepositoryProtocol
    let recents: RecentSearchStore

    private var searchTask: Task<Void, Never>?
    private var currentPage = 0

    init(repository: SearchRepositoryProtocol, recents: RecentSearchStore) {
        self.repository = repository
        self.recents = recents
    }

    // MARK: Derived

    var results: [SearchResult] { state.value ?? [] }

    /// Every match, not just the page loaded so far, so the summary agrees
    /// with the per-kind section headers.
    var totalCount: Int {
        let matching = scope.isEmpty ? Array(counts.values) : scope.compactMap { counts[$0] }
        return max(matching.reduce(0, +), results.count)
    }
    var isSearching: Bool { state.isLoading }
    var error: AppError? { state.error }

    /// Results grouped for display, in the kind order defined by `SearchKind`.
    var groups: [(kind: SearchKind, results: [SearchResult])] {
        Dictionary(grouping: results, by: \.kind)
            .sorted { $0.key.sortIndex < $1.key.sortIndex }
            .map { (kind: $0.key, results: $0.value) }
    }

    /// Flattened in display order, so keyboard selection matches what the
    /// eye sees rather than the raw ranked array.
    var flattenedResults: [SearchResult] {
        groups.flatMap(\.results)
    }

    var selectedResult: SearchResult? {
        guard let selectedIndex, flattenedResults.indices.contains(selectedIndex) else { return nil }
        return flattenedResults[selectedIndex]
    }

    /// Which empty state to show. One computed property rather than nested
    /// `if`s in the view, so the states stay mutually exclusive.
    enum Presentation: Equatable {
        case suggestions       // no query yet
        case tooShort          // one character
        case searching
        case results
        case noResults
        case failed(AppError)
    }

    var presentation: Presentation {
        if let error { return .failed(error) }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .suggestions }
        if trimmed.count < 2 { return .tooShort }
        if isSearching && results.isEmpty { return .searching }
        if results.isEmpty && state.isLoaded { return .noResults }
        return .results
    }

    /// Recents and shortcuts, shown on an empty field.
    var emptyStateSuggestions: [SearchSuggestion] {
        let recentItems = recents.recents.map {
            SearchSuggestion(id: "recent:\($0)", text: $0, subtitle: nil, source: .recent)
        }
        return recentItems + SearchShortcuts.all
    }

    // MARK: Controls

    func setScope(_ kind: SearchKind?) {
        // Nil is "All". Tapping the active chip clears it, which is what the
        // affordance implies.
        if let kind {
            scope = scope.contains(kind) ? [] : [kind]
        } else {
            scope = []
        }
        selectedIndex = nil
        scheduleSearch()
    }

    func setSort(_ newSort: SearchSort) {
        guard sort != newSort else { return }
        sort = newSort
        selectedIndex = nil
        scheduleSearch()
    }

    func setMode(_ newMode: SearchMode) {
        guard newMode.isAvailable, mode != newMode else { return }
        mode = newMode
        scheduleSearch()
    }

    func apply(_ suggestion: SearchSuggestion) {
        text = suggestion.text
        scheduleSearch()
    }

    func clear() {
        searchTask?.cancel()
        text = ""
        state = .idle
        counts = [:]
        suggestions = []
        selectedIndex = nil
    }

    // MARK: Keyboard

    /// Returns true when the key was consumed, so the view can stop the
    /// event escaping to the text field.
    @discardableResult
    func moveSelection(_ direction: MoveDirection) -> Bool {
        let count = flattenedResults.count
        guard count > 0 else { return false }

        switch direction {
        case .down:
            selectedIndex = selectedIndex.map { min($0 + 1, count - 1) } ?? 0
        case .up:
            // Arrowing up past the first row releases focus back to the
            // field, which is what every search UI on the platform does.
            if let current = selectedIndex {
                selectedIndex = current == 0 ? nil : current - 1
            } else {
                return false
            }
        }
        return true
    }

    enum MoveDirection { case up, down }

    /// Commits the current query to history. Called on submit and on open.
    func commitToRecents() {
        recents.record(text)
    }

    // MARK: Loading

    func loadSuggestions() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        suggestions = (try? await repository.suggestions(prefix: trimmed)) ?? []
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isSearching else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        currentPage += 1
        let query = makeQuery(page: currentPage)

        guard let page = try? await repository.search(query) else {
            currentPage -= 1
            return
        }
        state = .loaded(results + page.items)
        hasMore = page.hasMore
    }

    func retry() async {
        scheduleSearch()
    }

    // MARK: Internals

    private func makeQuery(page: Int) -> SearchQuery {
        SearchQuery(
            text: text,
            kinds: scope,
            sort: sort,
            mode: mode,
            page: PageRequest(page: page, size: 20)
        )
    }

    /// Cancels the in-flight search and starts a new one.
    private func scheduleSearch(debounced: Bool = false) {
        searchTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            state = .idle
            counts = [:]
            suggestions = []
            hasMore = false
            return
        }

        searchTask = Task { [weak self] in
            guard let self else { return }

            if debounced {
                // 220ms: long enough to skip intermediate keystrokes at
                // normal typing speed, short enough that the pause before
                // results does not read as lag.
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
            }

            await self.performSearch(trimmed)
        }
    }

    private func performSearch(_ trimmed: String) async {
        currentPage = 0
        if results.isEmpty { state = .loading }

        let query = makeQuery(page: 0)

        async let pageResult = repository.search(query)
        async let countResult = repository.counts(for: query)
        async let suggestionResult = repository.suggestions(prefix: trimmed)

        do {
            let page = try await pageResult
            // The query moved on while this was in flight — discard it rather
            // than overwrite newer results with older ones.
            guard !Task.isCancelled,
                  text.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed
            else { return }

            state = .loaded(page.items)
            hasMore = page.hasMore
            counts = (try? await countResult) ?? [:]
            suggestions = (try? await suggestionResult) ?? []
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(AppError.from(error))
        }
    }
}
