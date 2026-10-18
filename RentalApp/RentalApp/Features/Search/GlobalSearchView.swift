//
//  GlobalSearchView.swift
//  RentalApp (Purrperty)
//
//  Search — The Search tab.
//
//  System search, end to end: the `.searchable` field (which the search
//  tab places in the tab bar on iPhone), search scopes for the entity
//  types that matched, an inset-grouped `List` of results, and
//  `ContentUnavailableView` for every empty state. Results push onto the
//  Search tab's own stack, so going back returns to the query.
//
//  Keyboard navigation comes from `List` itself: arrow keys move
//  through rows and Return opens one on a hardware keyboard.
//

import SwiftUI

// MARK: - Tab Root

/// Builds the search screen from the environment's container.
struct SearchTabRoot: View {
    @Environment(\.container) private var container

    var body: some View {
        GlobalSearchView(container: container)
    }
}

// MARK: - Search

struct GlobalSearchView: View {

    @State private var viewModel: GlobalSearchViewModel

    init(container: AppContainer) {
        _viewModel = State(initialValue: GlobalSearchViewModel(
            repository: container.search,
            recents: container.recentSearches
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            switch viewModel.presentation {
            case .suggestions:
                suggestionSections
            case .results:
                resultSections
            case .tooShort, .searching, .noResults, .failed:
                EmptyView()
            }
        }
        .listStyle(.insetGrouped)
        .overlay { emptyState }
        .navigationTitle("Search")
        .navigationSubtitle(resultSummary)
        .searchable(text: $viewModel.text, prompt: "Properties, tenants, requests")
        .searchScopes(scope, activation: .onSearchPresentation) {
            Text("All").tag(SearchKind?.none)
            ForEach(SearchKind.allCases.filter { (viewModel.counts[$0] ?? 0) > 0 }) { kind in
                Text(kind.label).tag(SearchKind?.some(kind))
            }
        }
        .onSubmit(of: .search) { viewModel.commitToRecents() }
        .toolbar {
            if viewModel.presentation == .results {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: sort) {
                            ForEach(SearchSort.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", symbol: .sort)
                    }
                }
            }
        }
    }

    // MARK: Bindings

    /// Single-selection scopes over the view model's scope set.
    private var scope: Binding<SearchKind?> {
        Binding(
            get: { viewModel.scope.first },
            set: { newValue in
                if let newValue {
                    if !viewModel.scope.contains(newValue) { viewModel.setScope(newValue) }
                } else {
                    viewModel.setScope(nil)
                }
            }
        )
    }

    private var sort: Binding<SearchSort> {
        Binding(get: { viewModel.sort }, set: { viewModel.setSort($0) })
    }

    private var resultSummary: String {
        guard viewModel.presentation == .results else { return "" }
        let count = viewModel.results.count
        return count == 1 ? "1 result" : "\(count) results"
    }

    // MARK: Suggestions

    @ViewBuilder
    private var suggestionSections: some View {
        if !viewModel.recents.recents.isEmpty {
            Section {
                ForEach(viewModel.recents.recents, id: \.self) { recent in
                    Button {
                        viewModel.apply(.init(id: "recent:\(recent)", text: recent, subtitle: nil, source: .recent))
                    } label: {
                        Label {
                            Text(recent).foregroundStyle(Color.primary)
                        } icon: {
                            Image(symbol: .schedule).foregroundStyle(Color.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Remove", systemImage: AppSymbol.delete.rawValue, role: .destructive) {
                            viewModel.recents.remove(recent)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Recent")
                    Spacer()
                    Button("Clear") { viewModel.recents.clear() }
                        .font(.subheadline)
                        .textCase(nil)
                }
            }
        }

        Section("Suggestions") {
            ForEach(SearchShortcuts.all) { shortcut in
                Button {
                    viewModel.apply(shortcut)
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            // Explicit colours: inside a List button, the
                            // hierarchical styles resolve to the tint.
                            Text(shortcut.text).foregroundStyle(Color.primary)
                            if let subtitle = shortcut.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: shortcut.icon)
                    }
                }
            }
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultSections: some View {
        ForEach(viewModel.groups, id: \.kind) { group in
            Section {
                ForEach(group.results) { result in
                    resultRow(result)
                }
            } header: {
                Text("\(group.kind.label) (\(viewModel.counts[group.kind] ?? group.results.count))")
            }
        }

        if viewModel.hasMore || viewModel.isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .listRowBackground(Color.clear)
            .task { await viewModel.loadMore() }
        }
    }

    @ViewBuilder
    private func resultRow(_ result: SearchResult) -> some View {
        let label = Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !result.headline.isEmpty {
                    Text(Self.highlighted(result.headline))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        } icon: {
            Image(systemName: result.kind.icon)
                .foregroundStyle(.tint)
        }

        if let route = result.route {
            NavigationLink(value: route) { label }
                .simultaneousGesture(TapGesture().onEnded { viewModel.commitToRecents() })
        } else {
            // No screen for this kind yet: shown, but not a dead link.
            label
                .foregroundStyle(.secondary)
                .accessibilityHint("Not available yet")
        }
    }

    /// The server marks matched terms with « and »; they're shown in the
    /// primary colour and emphasised, so the match is visible without a
    /// second accent colour.
    private static func highlighted(_ headline: String) -> AttributedString {
        var output = AttributedString()
        var isMatch = false
        for segment in headline.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "«" || $0 == "»" }) {
            var piece = AttributedString(String(segment))
            if isMatch {
                piece.inlinePresentationIntent = .stronglyEmphasized
                piece.foregroundColor = .primary
            }
            output.append(piece)
            isMatch.toggle()
        }
        return output
    }

    // MARK: Empty States

    @ViewBuilder
    private var emptyState: some View {
        switch viewModel.presentation {
        case .tooShort:
            ContentUnavailableView(
                "Keep typing",
                systemImage: AppSymbol.search.rawValue,
                description: Text("Type two or more characters to search.")
            )
        case .searching:
            ProgressView()
        case .noResults:
            ContentUnavailableView {
                Label("No results for \u{201C}\(viewModel.text)\u{201D}", symbol: .search)
            } description: {
                Text(viewModel.scope.isEmpty
                     ? "Check the spelling or try a shorter term."
                     : "Nothing in this category matches.")
            } actions: {
                if !viewModel.scope.isEmpty {
                    Button("Search everything") { viewModel.setScope(nil) }
                        .buttonStyle(.bordered)
                }
            }
        case .failed(let error):
            ContentUnavailableView {
                Label("Couldn't search", symbol: .caution)
            } description: {
                Text(error.errorDescription ?? "Something went wrong.")
            } actions: {
                Button("Try again") { Task { await viewModel.retry() } }
                    .buttonStyle(.bordered)
            }
        case .suggestions, .results:
            EmptyView()
        }
    }
}

// MARK: - Previews

#Preview("Search") {
    NavigationStack {
        GlobalSearchView(container: .preview)
    }
    .environment(AppRouter())
}
