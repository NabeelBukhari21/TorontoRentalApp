//
//  GlobalSearchView.swift
//  RentalApp (Purrperty)
//
//  Search — The global search sheet.
//
//  Keyboard navigation is built in rather than added later because it
//  changes the structure: rows need a selection state, the list needs to
//  scroll a selection into view, and the text field must not swallow the
//  arrow keys. Retrofitting that means rewriting the row and the list.
//

import SwiftUI

struct GlobalSearchView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GlobalSearchViewModel
    @FocusState private var isFieldFocused: Bool

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: GlobalSearchViewModel(
            repository: container.search,
            recents: container.recentSearches
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSAmbientBackground()

                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)

                    if viewModel.presentation == .results {
                        controls
                            .padding(.top, DS.Spacing.md)
                    }

                    content
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .task {
            // Focus on open — a search sheet that needs a tap before you can
            // type is a search sheet nobody uses twice.
            try? await Task.sleep(for: .milliseconds(120))
            isFieldFocused = true
        }
    }

    // MARK: Field

    private var searchField: some View {
        DSSearchBar(
            text: $viewModel.text,
            placeholder: "Properties, tenants, requests…"
        )
        .focused($isFieldFocused)
        .submitLabel(.search)
        .onSubmit {
            // Return opens the highlighted row if there is one, otherwise
            // just commits the query to history.
            if let selected = viewModel.selectedResult {
                open(selected)
            } else {
                viewModel.commitToRecents()
            }
        }
        // Arrow keys move the selection instead of the caret. Returning
        // `.handled` is what stops the field consuming them.
        .onKeyPress(.downArrow) {
            viewModel.moveSelection(.down) ? .handled : .ignored
        }
        .onKeyPress(.upArrow) {
            viewModel.moveSelection(.up) ? .handled : .ignored
        }
        .onKeyPress(.escape) {
            if viewModel.text.isEmpty {
                dismiss()
            } else {
                viewModel.clear()
            }
            return .handled
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: DS.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    DSChip(
                        title: "All",
                        isSelected: viewModel.scope.isEmpty
                    ) { viewModel.setScope(nil) }

                    // Only kinds that actually matched. Showing eight chips
                    // where six are empty makes the two that matter harder
                    // to find.
                    ForEach(SearchKind.allCases.filter { (viewModel.counts[$0] ?? 0) > 0 }) { kind in
                        DSChip(
                            title: "\(kind.label) \(viewModel.counts[kind] ?? 0)",
                            icon: kind.icon,
                            isSelected: viewModel.scope.contains(kind)
                        ) { viewModel.setScope(kind) }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }

            HStack {
                Text("\(viewModel.results.count) result\(viewModel.results.count == 1 ? "" : "s")")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textTertiary)

                Spacer()

                Menu {
                    ForEach(SearchSort.allCases) { option in
                        Button {
                            viewModel.setSort(option)
                        } label: {
                            if viewModel.sort == option {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: DS.Icons.sort)
                            .font(.system(size: 11, weight: .semibold))
                        Text(viewModel.sort.label)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(DS.Colors.brand)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.presentation {
        case .suggestions:
            suggestionList

        case .tooShort:
            DSEmptyState(
                icon: DS.Icons.search,
                title: "Keep typing",
                message: "Two characters or more finds something useful."
            )
            .frame(maxHeight: .infinity)

        case .searching:
            DSListSkeleton(rows: 5)
                .padding(DS.Spacing.lg)
                .frame(maxHeight: .infinity, alignment: .top)

        case .noResults:
            noResults

        case .failed(let error):
            DSErrorView(error: error) { await viewModel.retry() }
                .frame(maxHeight: .infinity)

        case .results:
            resultList
        }
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.md, pinnedViews: [.sectionHeaders]) {
                    ForEach(viewModel.groups, id: \.kind) { group in
                        Section {
                            ForEach(group.results) { result in
                                SearchResultRow(
                                    result: result,
                                    isSelected: viewModel.selectedResult?.id == result.id
                                ) {
                                    open(result)
                                }
                                .id(result.id)
                            }
                        } header: {
                            SearchSectionHeader(
                                kind: group.kind,
                                count: viewModel.counts[group.kind] ?? group.results.count
                            )
                        }
                    }

                    DSPaginationFooter(isLoading: viewModel.isLoadingMore)
                        .task { await viewModel.loadMore() }
                }
                .padding(DS.Spacing.lg)
            }
            // Keeps the keyboard-selected row visible as it moves past the
            // fold. Without this, arrowing down silently walks off screen.
            .onChange(of: viewModel.selectedIndex) { _, _ in
                guard let selected = viewModel.selectedResult else { return }
                withAnimation(DS.Motion.snappy) {
                    proxy.scrollTo(selected.id, anchor: .center)
                }
            }
        }
    }

    private var suggestionList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if !viewModel.recents.recents.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text("RECENT").dsOverline()
                            Spacer()
                            Button("Clear") { viewModel.recents.clear() }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }

                        ForEach(viewModel.recents.recents, id: \.self) { recent in
                            SearchSuggestionRow(
                                suggestion: .init(
                                    id: "recent:\(recent)", text: recent,
                                    subtitle: nil, source: .recent
                                ),
                                onTap: { viewModel.apply(.init(
                                    id: "recent:\(recent)", text: recent,
                                    subtitle: nil, source: .recent
                                )) },
                                onRemove: { viewModel.recents.remove(recent) }
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("TRY").dsOverline()
                    ForEach(SearchShortcuts.all) { shortcut in
                        SearchSuggestionRow(
                            suggestion: shortcut,
                            onTap: { viewModel.apply(shortcut) },
                            onRemove: nil
                        )
                    }
                }
            }
            .padding(DS.Spacing.lg)
        }
    }

    private var noResults: some View {
        VStack(spacing: DS.Spacing.lg) {
            DSEmptyState(
                icon: DS.Icons.search,
                title: "No matches for \u{201C}\(viewModel.text)\u{201D}",
                message: viewModel.scope.isEmpty
                    ? "Check the spelling, or try a shorter term."
                    : "Nothing in this category. Try searching everything."
            )

            // A scoped empty result is nearly always the scope's fault, so
            // offer the fix rather than making the user find the chip.
            if !viewModel.scope.isEmpty {
                DSButton(title: "Search everything", variant: .secondary, size: .medium) {
                    viewModel.setScope(nil)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Actions

    private func open(_ result: SearchResult) {
        viewModel.commitToRecents()
        guard let route = result.route else { return }
        dismiss()
        // After the sheet is gone, so the push animates from the screen
        // underneath rather than fighting the dismissal.
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            router.push(route)
        }
    }
}

// MARK: - Previews

#Preview("Global search") {
    GlobalSearchView(container: .preview)
        .environment(AppRouter())
}
