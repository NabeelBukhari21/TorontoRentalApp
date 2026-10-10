//
//  PropertyViewModels.swift
//  RentalApp (Purrperty)
//
//  Properties — List and detail view models.
//
//  Search, filter, and sort are pushed *into* the repository as a
//  query rather than applied to an already-loaded array. Changing any
//  of them resets to page one and reloads, which is the only way the
//  same code keeps working once the data set outgrows memory.
//

import SwiftUI
import Observation

// MARK: - List

@MainActor
@Observable
final class PropertyListViewModel {

    // MARK: Dependencies

    private let repository: PropertyRepositoryProtocol
    private let notifications: NotificationRepositoryProtocol

    // MARK: Query inputs

    var searchText = "" {
        didSet { guard oldValue != searchText else { return }; scheduleReload(debounced: true) }
    }
    var filter: PropertyFilter = .all {
        didSet { guard oldValue != filter else { return }; scheduleReload() }
    }
    var sortField: PropertySortField = .name {
        didSet { guard oldValue != sortField else { return }; scheduleReload() }
    }

    // MARK: State

    private(set) var list: AsyncListModel<Property>!
    private(set) var summary: PropertyPortfolioSummary = .empty
    private(set) var unreadNotifications = 0

    // MARK: Selection
    //
    // Bulk mode is a mode, not a gesture: entering it changes what a tap
    // means, so it has to be explicit and obvious to leave.
    private(set) var isSelecting = false
    private(set) var selectedIDs: Set<String> = []

    /// Archived rows, loaded on demand for the restore sheet.
    private(set) var archived: [Property] = []
    private(set) var isLoadingArchived = false

    private var reloadTask: Task<Void, Never>?

    // MARK: Init

    init(
        repository: PropertyRepositoryProtocol,
        notifications: NotificationRepositoryProtocol
    ) {
        self.repository = repository
        self.notifications = notifications

        self.list = AsyncListModel<Property> { [weak self] page, forceRefresh in
            guard let self else { return .empty }
            let query = PropertyQuery(
                search: self.searchText,
                filter: self.filter,
                sort: SortOrder(self.sortField, self.sortField == .name ? .ascending : .descending),
                page: page
            )
            let result = try await self.repository.properties(matching: query, forceRefresh: forceRefresh)
            self.summary = try await self.repository.portfolioSummary(forceRefresh: forceRefresh)
            return result
        }
    }

    // MARK: Derived — property names preserved for the view layer

    var properties: [Property] { list.items }
    /// Filtering now happens upstream; the name is kept so the view is unchanged.
    var filteredProperties: [Property] { list.items }

    var isLoading: Bool { list.state.isLoading }
    var isRefreshing: Bool { list.isRefreshing }
    var isLoadingMore: Bool { list.isLoadingMore }
    var error: AppError? { list.error }
    var isEmpty: Bool { list.isEmpty }

    var totalUnits: Int { summary.totalUnits }
    var totalOccupied: Int { summary.occupiedUnits }
    var portfolioOccupancy: Double { summary.occupancyRate }
    var monthlyRevenueText: String { summary.monthlyRevenueText }
    var propertyCount: Int { summary.propertyCount }

    // MARK: Lifecycle

    func load() async {
        await list.load()
        await refreshBadge()
    }

    func refresh() async {
        await list.refresh()
        await refreshBadge()
    }

    func retry() async {
        await list.retry()
    }

    func loadMoreIfNeeded(currentItem item: Property) async {
        await list.loadMoreIfNeeded(currentItem: item)
    }

    // MARK: - Selection

    func beginSelecting() {
        withAnimation(DS.Motion.snappy) { isSelecting = true }
    }

    func endSelecting() {
        withAnimation(DS.Motion.snappy) {
            isSelecting = false
            selectedIDs.removeAll()
        }
    }

    func toggleSelection(_ id: String) {
        withAnimation(DS.Motion.snappy) {
            if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
        }
    }

    var selectionCount: Int { selectedIDs.count }
    func isSelected(_ id: String) -> Bool { selectedIDs.contains(id) }

    // MARK: - Mutations
    //
    // Each returns a `MutationOutcome` for the view to hand to the toast
    // center. The row disappears immediately and comes back if the server
    // refuses — the snapshot taken before the splice is what makes that
    // rollback exact rather than a best guess.

    func archive(_ property: Property) async -> MutationOutcome {
        let before = list.snapshot
        list.remove(id: property.id)

        do {
            try await repository.archiveProperty(id: property.id)
            await refreshSummary()
            return .succeeded(undo: UndoToken(message: "\(property.name) archived") { [weak self] in
                guard let self else { return }
                try await self.repository.restoreProperty(id: property.id)
                self.list.upsert(property)
                await self.refreshSummary()
            })
        } catch {
            list.replaceItems(before)
            return .failed(AppError.from(error))
        }
    }

    func delete(_ property: Property) async -> MutationOutcome {
        let before = list.snapshot
        list.remove(id: property.id)

        do {
            try await repository.deleteProperty(id: property.id)
            await refreshSummary()
            // No undo: the row is gone server-side. Offering one would be
            // a lie, and this is why delete asks for confirmation while
            // archive does not.
            return .succeeded(undo: nil)
        } catch {
            list.replaceItems(before)
            return .failed(AppError.from(error))
        }
    }

    func restore(_ property: Property) async -> MutationOutcome {
        do {
            try await repository.restoreProperty(id: property.id)
            archived.removeAll { $0.id == property.id }
            list.upsert(property)
            await refreshSummary()
            return .succeeded(undo: nil)
        } catch {
            return .failed(AppError.from(error))
        }
    }

    /// Archives every selected row. Partial failure is reported honestly
    /// rather than rolled back wholesale: the ones that succeeded really
    /// are archived, and pretending otherwise would leave the list lying.
    func archiveSelected() async -> MutationOutcome {
        let targets = list.items.filter { selectedIDs.contains($0.id) }
        guard !targets.isEmpty else { return .succeeded(undo: nil) }

        let before = list.snapshot
        list.remove(ids: selectedIDs)
        endSelecting()

        var archivedOK: [Property] = []
        var firstError: AppError?

        for property in targets {
            do {
                try await repository.archiveProperty(id: property.id)
                archivedOK.append(property)
            } catch {
                firstError = firstError ?? AppError.from(error)
            }
        }

        await refreshSummary()

        if archivedOK.isEmpty {
            list.replaceItems(before)
            return .failed(firstError ?? .unknown)
        }

        // Put back anything that failed.
        if archivedOK.count < targets.count {
            let failed = targets.filter { p in !archivedOK.contains(where: { $0.id == p.id }) }
            failed.forEach { list.upsert($0) }
        }

        let count = archivedOK.count
        return .succeeded(undo: UndoToken(
            message: "\(count) propert\(count == 1 ? "y" : "ies") archived"
        ) { [weak self] in
            guard let self else { return }
            for property in archivedOK {
                try await self.repository.restoreProperty(id: property.id)
                self.list.upsert(property)
            }
            await self.refreshSummary()
        })
    }

    /// Called by the form after a create or edit so the list updates
    /// without a round trip.
    func didSave(_ property: Property) {
        list.upsert(property)
        Task { await refreshSummary() }
    }

    func loadArchived() async {
        guard !isLoadingArchived else { return }
        isLoadingArchived = true
        defer { isLoadingArchived = false }
        archived = (try? await repository.archivedProperties()) ?? []
    }

    private func refreshSummary() async {
        summary = (try? await repository.portfolioSummary(forceRefresh: true)) ?? summary
    }

    // MARK: Internals

    /// Debounces typing so a five-character search fires one query, not five.
    private func scheduleReload(debounced: Bool = false) {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            if debounced {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
            }
            await self?.list.reload()
        }
    }

    private func refreshBadge() async {
        unreadNotifications = (try? await notifications.unreadCount()) ?? 0
    }
}

// MARK: - Detail

@MainActor
@Observable
final class PropertyDetailViewModel {

    private let repository: PropertyRepositoryProtocol
    let propertyID: String

    private(set) var state: LoadState<Property> = .idle
    private(set) var units: [PropertyUnit] = []
    private(set) var tenantRows: [PropertyTenantRow] = []
    private(set) var requestRows: [PropertyRequestRow] = []
    private(set) var documentRows: [PropertyDocRow] = []
    private(set) var occupancyTrend: [OccupancyTrendPoint] = []
    private(set) var revenueTrend: [RevenuePoint] = []

    /// Tabs load on demand — opening Overview shouldn't fetch analytics.
    private var loadedTabs: Set<PropertyDetailTab> = []

    init(propertyID: String, repository: PropertyRepositoryProtocol) {
        self.propertyID = propertyID
        self.repository = repository
    }

    var property: Property? { state.value }
    var isLoading: Bool { state.isLoading }
    var error: AppError? { state.error }

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            state = .loaded(try await repository.property(id: propertyID))
        } catch {
            state = .failed(error as? AppError ?? .unknown)
        }
    }

    func retry() async {
        state = .idle
        loadedTabs.removeAll()
        await load()
    }

    func refresh() async {
        loadedTabs.removeAll()
        do {
            state = .loaded(try await repository.property(id: propertyID))
        } catch {
            state = .failed(error as? AppError ?? .unknown)
        }
    }

    /// Fetches a tab's data the first time it is shown.
    func loadTab(_ tab: PropertyDetailTab) async {
        guard !loadedTabs.contains(tab) else { return }
        loadedTabs.insert(tab)

        do {
            switch tab {
            case .overview, .documents:
                documentRows = try await repository.documents(forPropertyID: propertyID)
            case .units:
                units = try await repository.units(forPropertyID: propertyID)
            case .tenants:
                tenantRows = try await repository.tenantRows(forPropertyID: propertyID)
            case .maintenance:
                requestRows = try await repository.requestRows(forPropertyID: propertyID)
            case .analytics:
                occupancyTrend = try await repository.occupancyTrend(forPropertyID: propertyID)
                revenueTrend = try await repository.revenueTrend(forPropertyID: propertyID)
            }
        } catch {
            // A failing tab must not blank the screen; it shows its
            // empty state and can be re-entered to retry.
            loadedTabs.remove(tab)
        }
    }

    // MARK: - Property Mutations
    //
    // These throw rather than returning a `MutationOutcome`: the detail
    // screen dismisses on success, so there is no row left to roll back
    // and no undo to offer from a screen that no longer exists.

    func archive() async throws {
        try await repository.archiveProperty(id: propertyID)
    }

    func delete() async throws {
        try await repository.deleteProperty(id: propertyID)
    }

    // MARK: - Unit Mutations

    /// Splices a created or edited unit into the loaded tab.
    func didSaveUnit(_ unit: PropertyUnit) {
        if let index = units.firstIndex(where: { $0.id == unit.id }) {
            units[index] = unit
        } else {
            units.append(unit)
        }
        units.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Optimistically removes the unit, restoring it if the server refuses
    /// — which it will when a live lease is attached.
    func deleteUnit(_ unit: PropertyUnit) async -> MutationOutcome {
        let before = units
        units.removeAll { $0.id == unit.id }

        do {
            try await repository.deleteUnit(id: unit.id)
            return .succeeded(undo: nil)
        } catch {
            units = before
            return .failed(AppError.from(error))
        }
    }
}
