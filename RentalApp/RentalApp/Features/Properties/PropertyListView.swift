//
//  PropertyListView.swift
//  RentalApp (Purrperty)
//
//  Properties — Portfolio list: animated search, filter chips,
//  sort menu, and floating property cards.
//

import SwiftUI

struct PropertyListView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.toasts) private var toasts
    @Environment(\.container) private var container

    /// Which sheet is open. One enum rather than three Bools so two can
    /// never be true at once.
    @State private var sheet: Sheet?
    @State private var pendingConfirmation: DSConfirmation?

    private enum Sheet: Identifiable {
        case create
        case edit(Property)
        case archived

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let p): "edit-\(p.id)"
            case .archived: "archived"
            }
        }
    }
    @State private var viewModel: PropertyListViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: PropertyListViewModel(
            repository: container.properties,
            notifications: container.notifications
        ))
    }

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {

                    // Portfolio summary strip.
                    summaryStrip
                        .dsEntrance(index: 0)

                    // Search + sort.
                    HStack(spacing: DS.Spacing.md) {
                        DSSearchBar(text: $viewModel.searchText, placeholder: "Search properties…")

                        sortMenu
                    }
                    .dsEntrance(index: 1)

                    // Filter chips.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(PropertyFilter.allCases) { filter in
                                DSChip(
                                    title: filter.rawValue,
                                    icon: filter.icon,
                                    isSelected: viewModel.filter == filter
                                ) {
                                    viewModel.filter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .dsEntrance(index: 2)

                    // Cards.
                    if viewModel.isLoading {
                        DSCardSkeleton(cards: 3)
                    } else if let error = viewModel.error {
                        DSErrorView(error: error) { await viewModel.retry() }
                    } else if viewModel.isEmpty {
                        DSEmptyState(
                            icon: DS.Icons.properties,
                            title: "No matches",
                            message: "Try a different search or filter — your properties are still here."
                        )
                        .padding(.top, DS.Spacing.xxl)
                    } else {
                        LazyVStack(spacing: DS.Spacing.lg) {
                            ForEach(Array(viewModel.filteredProperties.enumerated()), id: \.element.id) { index, property in
                                PropertyCard(property: property) {
                                    if viewModel.isSelecting {
                                        viewModel.toggleSelection(property.id)
                                    } else {
                                        router.push(.propertyDetail(propertyID: property.id))
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    if viewModel.isSelecting {
                                        SelectionTick(isOn: viewModel.isSelected(property.id))
                                            .padding(DS.Spacing.md)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        sheet = .edit(property)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Button {
                                        archive(property)
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }

                                    Button {
                                        viewModel.beginSelecting()
                                        viewModel.toggleSelection(property.id)
                                    } label: {
                                        Label("Select", systemImage: "checkmark.circle")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        confirmDelete(property)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .dsEntrance(index: min(3 + index, 12))
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                .task { await viewModel.loadMoreIfNeeded(currentItem: property) }
                            }

                            DSPaginationFooter(isLoading: viewModel.isLoadingMore)
                        }
                    }
                }
                .padding(DS.Spacing.lg)
                .animation(DS.Motion.smooth, value: viewModel.filteredProperties.map(\.id))
            }
            .refreshable { await viewModel.refresh() }
        }
        .task { await viewModel.load() }
        // A reload rather than a per-row upsert: `Property` carries derived
        // aggregates (occupancy, revenue, open requests) that a single
        // `properties` row cannot supply, so splicing the row in would show
        // a correct name beside stale numbers. The engine has already
        // coalesced the burst, so this is one refetch per batch.
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .properties) {
                await viewModel.refresh()
            }
        }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .units) {
                await viewModel.refresh()
            }
        }
        .navigationTitle("Properties")
        .navigationSubtitle("\(viewModel.propertyCount) properties · \(viewModel.totalUnits) units")
        .toolbar {
            if viewModel.isSelecting {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.endSelecting() }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: AppSymbol.more.rawValue) {
                        Button("Select", systemImage: "checkmark.circle") {
                            viewModel.beginSelecting()
                        }
                        Button("Archived properties", systemImage: AppSymbol.archive.rawValue) {
                            sheet = .archived
                        }
                    }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add property", systemImage: AppSymbol.add.rawValue) {
                        sheet = .create
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isSelecting {
                BulkActionBar(
                    count: viewModel.selectionCount,
                    onArchive: archiveSelected,
                    onCancel: { viewModel.endSelecting() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DS.Motion.bouncy, value: viewModel.isSelecting)
        .dsConfirmation($pendingConfirmation)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .create:
                PropertyFormView(mode: .create) { viewModel.didSave($0) }
            case .edit(let property):
                PropertyFormView(
                    mode: .edit(propertyID: property.id),
                    existing: property
                ) { viewModel.didSave($0) }
            case .archived:
                ArchivedPropertiesView(viewModel: viewModel)
            }
        }
    }

    // MARK: Actions

    private func archive(_ property: Property) {
        Task {
            let outcome = await viewModel.archive(property)
            toasts.report(outcome, success: "Archived") { archive(property) }
        }
    }

    private func archiveSelected() {
        Task {
            let outcome = await viewModel.archiveSelected()
            toasts.report(outcome, success: "Archived")
        }
    }

    /// Delete is irreversible, so it is the one row action that stops to
    /// ask. Archive does not — it has Undo instead, which is a better
    /// trade for something the user does often.
    private func confirmDelete(_ property: Property) {
        pendingConfirmation = DSConfirmation(
            title: "Delete \(property.name)?",
            message: "This can't be undone. Units and history are removed with it. Archive instead if you might want it back.",
            confirmTitle: "Delete"
        ) {
            Task {
                let outcome = await viewModel.delete(property)
                toasts.report(outcome, success: "\(property.name) deleted")
            }
        }
    }

    // MARK: Summary Strip

    private var summaryStrip: some View {
        DSCard(style: .raised, padding: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.lg) {
                summaryItem(
                    value: "\(Int(viewModel.portfolioOccupancy * 100))%",
                    label: "Occupancy",
                    kind: .success
                )
                divider
                summaryItem(
                    value: "\(viewModel.totalOccupied)/\(viewModel.totalUnits)",
                    label: "Units filled",
                    kind: .info
                )
                divider
                summaryItem(
                    value: viewModel.monthlyRevenueText,
                    label: "Monthly",
                    kind: .neutral
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.Colors.outline)
            .frame(width: 0.5, height: 32)
    }

    private func summaryItem(value: String, label: String, kind: DSStatusKind) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Typography.statValueSmall)
                .foregroundStyle(DS.Colors.textPrimary)

            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(PropertySortField.allCases) { option in
                Button {
                    viewModel.sortField = option
                } label: {
                    if viewModel.sortField == option {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            Image(systemName: DS.Icons.sort)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.Colors.brand)
                .frame(width: 46, height: 46)
                .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(DS.Colors.outline, lineWidth: 1)
                )
        }
        .accessibilityLabel("Sort properties")
    }
}
