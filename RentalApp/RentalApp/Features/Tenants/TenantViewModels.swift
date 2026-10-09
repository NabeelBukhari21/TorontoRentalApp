//
//  TenantViewModels.swift
//  RentalApp (RentOS)
//
//  Tenants — Directory, profile, and create-flow view models.
//

import SwiftUI
import Observation

// MARK: - Directory

@MainActor
@Observable
final class TenantListViewModel {

    private let repository: TenantRepositoryProtocol

    var searchText = "" {
        didSet { guard oldValue != searchText else { return }; scheduleReload(debounced: true) }
    }
    var filter: TenantFilter = .all {
        didSet { guard oldValue != filter else { return }; scheduleReload() }
    }
    var sortField: TenantSortField = .name {
        didSet { guard oldValue != sortField else { return }; scheduleReload() }
    }

    private(set) var list: AsyncListModel<Tenant>!
    private(set) var summary: TenantSummary = .empty

    private var reloadTask: Task<Void, Never>?

    init(repository: TenantRepositoryProtocol) {
        self.repository = repository

        self.list = AsyncListModel<Tenant> { [weak self] page, forceRefresh in
            guard let self else { return .empty }
            let query = TenantQuery(
                search: self.searchText,
                filter: self.filter,
                sort: SortOrder(self.sortField, self.sortField == .name ? .ascending : .descending),
                page: page
            )
            let result = try await self.repository.tenants(matching: query, forceRefresh: forceRefresh)
            self.summary = try await self.repository.summary(forceRefresh: forceRefresh)
            return result
        }
    }

    // MARK: Derived

    var tenants: [Tenant] { list.items }
    var filteredTenants: [Tenant] { list.items }

    var isLoading: Bool { list.state.isLoading }
    var isRefreshing: Bool { list.isRefreshing }
    var isLoadingMore: Bool { list.isLoadingMore }
    var error: AppError? { list.error }
    var isEmpty: Bool { list.isEmpty }

    var totalCount: Int { summary.total }
    var activeCount: Int { summary.active }
    var overdueCount: Int { summary.overdue }
    var renewalsSoonCount: Int { summary.renewalsSoon }

    // MARK: Lifecycle

    func load() async { await list.load() }
    func refresh() async { await list.refresh() }
    func retry() async { await list.retry() }

    func loadMoreIfNeeded(currentItem item: Tenant) async {
        await list.loadMoreIfNeeded(currentItem: item)
    }

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
}

// MARK: - Profile

@MainActor
@Observable
final class TenantDetailViewModel {

    private let repository: TenantRepositoryProtocol
    let tenantID: String

    private(set) var state: LoadState<Tenant> = .idle
    private(set) var timelineEvents: [TenantEvent] = []
    private(set) var documentRows: [PropertyDocRow] = []
    private(set) var maintenanceRows: [PropertyRequestRow] = []
    private(set) var messagePreviews: [TenantMessagePreview] = []

    private var loadedTabs: Set<TenantDetailTab> = []

    init(tenantID: String, repository: TenantRepositoryProtocol) {
        self.tenantID = tenantID
        self.repository = repository
    }

    var tenant: Tenant? { state.value }
    var isLoading: Bool { state.isLoading }
    var error: AppError? { state.error }

    /// The overview shows the three most recent events.
    var recentTimeline: [TenantEvent] { Array(timelineEvents.prefix(3)) }

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            state = .loaded(try await repository.tenant(id: tenantID))
            timelineEvents = try await repository.timeline(forTenantID: tenantID)
        } catch {
            state = .failed(error as? AppError ?? .unknown)
        }
    }

    func retry() async {
        state = .idle
        loadedTabs.removeAll()
        await load()
    }

    func loadTab(_ tab: TenantDetailTab) async {
        guard !loadedTabs.contains(tab) else { return }
        loadedTabs.insert(tab)

        do {
            switch tab {
            case .overview, .timeline:
                timelineEvents = try await repository.timeline(forTenantID: tenantID)
            case .maintenance:
                maintenanceRows = try await repository.maintenanceHistory(forTenantID: tenantID)
            case .documents:
                documentRows = try await repository.documents(forTenantID: tenantID)
            case .messages:
                messagePreviews = try await repository.messages(forTenantID: tenantID)
            }
        } catch {
            loadedTabs.remove(tab)
        }
    }
}

// MARK: - Create

@MainActor
@Observable
final class CreateTenantViewModel {

    private let repository: TenantRepositoryProtocol

    var name = ""
    var email = ""
    var phone = ""
    var property: String?
    var unit = ""
    var rent = ""
    var leaseStart = Date()
    var leaseEnd = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    private(set) var propertyNames: [String] = []
    private(set) var isSaving = false
    private(set) var isSaved = false
    private(set) var saveError: AppError?

    init(repository: TenantRepositoryProtocol) {
        self.repository = repository
    }

    var emailLooksValid: Bool {
        email.range(
            of: #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#,
            options: .regularExpression
        ) != nil
    }

    var canSave: Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 2
            && emailLooksValid
            && property != nil
            && !unit.isEmpty
            && Int(rent) != nil
            && !isSaving
    }

    func load() async {
        propertyNames = (try? await repository.propertyNames()) ?? []
    }

    func save() async {
        guard canSave, let property, let rentValue = Int(rent) else { return }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let draft = TenantDraft(
            name: name, email: email, phone: phone,
            propertyName: property, unit: unit, rent: rentValue,
            leaseStart: leaseStart, leaseEnd: leaseEnd
        )

        do {
            try await repository.create(draft)
            withAnimation(DS.Motion.bouncy) { isSaved = true }
        } catch {
            saveError = error as? AppError ?? .unknown
        }
    }
}
