//
//  MaintenanceViewModels.swift
//  RentalApp (Purrperty)
//
//  Maintenance — Inbox and detail view models.
//
//  The board and the list read the same loaded page; grouping by
//  status is a presentation concern, so it happens here rather than
//  issuing four parallel queries.
//

import SwiftUI
import Observation
import OSLog

// MARK: - View Mode

enum MaintenanceViewMode: String, CaseIterable, Identifiable {
    case list = "List"
    case board = "Board"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .list: "list.bullet"
        case .board: "square.grid.3x1.below.line.grid.1x2"
        }
    }
}

// MARK: - Inbox

@MainActor
@Observable
final class MaintenanceInboxViewModel {

    private let repository: MaintenanceRepositoryProtocol
    private let notifications: NotificationRepositoryProtocol

    var mode: MaintenanceViewMode = .list {
        didSet { if mode == .board { Task { await loadAllPages() } } }
    }

    var searchText = "" {
        didSet { guard oldValue != searchText else { return }; scheduleReload(debounced: true) }
    }
    var priorityFilter: TicketPriority? {
        didSet { guard oldValue != priorityFilter else { return }; scheduleReload() }
    }

    private(set) var list: AsyncListModel<MaintenanceTicket>!
    private(set) var summary: MaintenanceSummary = .empty
    private(set) var unreadNotifications = 0

    private var reloadTask: Task<Void, Never>?

    init(
        repository: MaintenanceRepositoryProtocol,
        notifications: NotificationRepositoryProtocol
    ) {
        self.repository = repository
        self.notifications = notifications

        self.list = AsyncListModel<MaintenanceTicket>(pageSize: 40) { [weak self] page, forceRefresh in
            guard let self else { return .empty }
            let query = MaintenanceQuery(
                search: self.searchText,
                filter: MaintenanceFilter(priority: self.priorityFilter),
                sort: SortOrder(.priority),
                page: page
            )
            let result = try await self.repository.tickets(matching: query, forceRefresh: forceRefresh)
            self.summary = try await self.repository.summary(forceRefresh: forceRefresh)
            return result
        }
    }

    // MARK: Derived

    var filteredTickets: [MaintenanceTicket] { list.items }
    var isLoading: Bool { list.state.isLoading }
    var isRefreshing: Bool { list.isRefreshing }
    var isLoadingMore: Bool { list.isLoadingMore }
    var error: AppError? { list.error }
    var isEmpty: Bool { list.isEmpty }

    var openCount: Int { summary.open }
    var urgentCount: Int { summary.urgent }
    var unassignedCount: Int { summary.unassigned }
    var averageResolutionText: String { summary.averageResolutionText }

    /// Kanban grouping. The board has no scroll-to-load, so it loads every
    /// page first (see `loadAllPages`); otherwise a column would only show
    /// what happened to sort into the first page.
    func columnTickets(_ status: TicketStatus) -> [MaintenanceTicket] {
        list.items.filter { $0.status == status }
    }

    // MARK: Lifecycle

    func load() async {
        await list.load()
        if mode == .board { await loadAllPages() }
        unreadNotifications = (try? await notifications.unreadCount()) ?? 0
    }

    func refresh() async {
        await list.refresh()
        if mode == .board { await loadAllPages() }
        unreadNotifications = (try? await notifications.unreadCount()) ?? 0
    }

    private func loadAllPages() async {
        while list.hasMore, !Task.isCancelled {
            let before = list.items.count
            await list.loadMore()
            // A failed page leaves the count unchanged; stop rather than spin.
            if list.items.count == before { break }
        }
    }

    func retry() async { await list.retry() }

    func loadMoreIfNeeded(currentItem item: MaintenanceTicket) async {
        await list.loadMoreIfNeeded(currentItem: item)
    }

    // MARK: Intents

    func move(_ ticketID: String, to status: TicketStatus) async {
        try? await repository.move(ticketID, to: status)
        await list.reload()
        if mode == .board { await loadAllPages() }
    }

    private func scheduleReload(debounced: Bool = false) {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            if debounced {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
            }
            await self?.list.reload()
            if self?.mode == .board { await self?.loadAllPages() }
        }
    }
}

// MARK: - Detail

@MainActor
@Observable
final class MaintenanceDetailViewModel: VisitScheduling {

    private let repository: MaintenanceRepositoryProtocol
    private let messages: MessageRepositoryProtocol
    let visitTracker: RepairVisitTracker
    let ticketID: String

    private(set) var state: LoadState<MaintenanceTicket> = .idle
    private(set) var vendors: [Vendor] = []
    private(set) var timelineEvents: [TenantEvent] = []
    private(set) var isSubmitting = false
    /// Why the last visit booking failed. Kept apart from `state`, so a
    /// rejected time leaves the request on screen behind the sheet.
    private(set) var errorMessage: String?
    var isWorking: Bool { isSubmitting }

    var commentText = ""

    init(
        ticketID: String,
        repository: MaintenanceRepositoryProtocol,
        messages: MessageRepositoryProtocol,
        visitTracker: RepairVisitTracker
    ) {
        self.ticketID = ticketID
        self.repository = repository
        self.messages = messages
        self.visitTracker = visitTracker
    }

    var ticket: MaintenanceTicket? { state.value }
    var isLoading: Bool { state.isLoading }
    var error: AppError? { state.error }

    // MARK: Lifecycle

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            state = .loaded(try await repository.ticket(id: ticketID))
            vendors = try await repository.vendors()
            timelineEvents = try await repository.timeline(forTicketID: ticketID)
            await visitTracker.refresh()
        } catch {
            state = .failed(error as? AppError ?? .unknown)
        }
    }

    func retry() async {
        state = .idle
        await load()
    }

    /// Silent reload, driven by realtime.
    ///
    /// `MaintenanceDetailView` subscribes to both `.maintenanceUpdates` and
    /// `.maintenanceRequests` and calls this when either fires. Neither
    /// existing entry point works for that:
    ///
    /// • `load()` guards on `.idle`, so after the first load it does
    ///   nothing at all — the screen would simply never update.
    /// • `retry()` resets to `.loading`, which makes the view swap the
    ///   ticket for `DSListSkeleton`. Every live event would flash a
    ///   skeleton over content the user is reading.
    ///
    /// So this refetches and swaps the value in place, leaving the current
    /// ticket on screen until the new one arrives.
    func refresh() async {
        do {
            let ticket = try await repository.ticket(id: ticketID)
            // Timeline too: `.maintenanceUpdates` fires precisely when a
            // new timeline entry is written, so refreshing the ticket
            // without it would show a changed status above a stale history.
            let timeline = try await repository.timeline(forTicketID: ticketID)
            state = .loaded(ticket)
            timelineEvents = timeline
        } catch {
            // Deliberately NOT `state = .failed`. This refresh was triggered
            // by a server event, not by the user — replacing what they are
            // reading with a full-screen error because a background refetch
            // blipped is worse than briefly showing slightly stale data.
            // A user-initiated reload still surfaces the failure via
            // `retry()`.
            AppLog.sync.failure("Live refresh of ticket failed", error: error)
        }
    }

    // MARK: Lookups

    func vendor(id: String) -> Vendor? {
        vendors.first { $0.id == id }
    }

    func alternateVendors(for ticket: MaintenanceTicket, excluding suggestedID: String) -> [Vendor] {
        vendors.filter { $0.specialty == ticket.category && $0.id != suggestedID }
    }

    /// Who could take a request that hasn't been triaged: vendors for its
    /// trade, or every vendor when none match.
    func candidateVendors(for ticket: MaintenanceTicket) -> [Vendor] {
        let matching = vendors.filter { $0.specialty == ticket.category }
        return matching.isEmpty ? vendors : matching
    }

    /// The conversation with whoever reported it. Nil for a request staff
    /// reported themselves.
    func conversationID(for ticket: MaintenanceTicket) async -> String? {
        guard let tenantID = ticket.tenantID else { return nil }
        return try? await messages.conversationID(forTenantID: tenantID)
    }

    // MARK: Intents

    func move(to status: TicketStatus) async {
        await mutate { try await $0.move(self.ticketID, to: status) }
    }

    /// Scheduling needs a time: the staff screen asks for one with the
    /// same sheet the vendor uses, then books it here.
    func schedule(_ job: MaintenanceTicket, at date: Date, note: String) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        do {
            try await repository.bookVisit(job.id, at: date, note: note)
            await refresh()
            if let updated = ticket { await visitTracker.jobChanged(updated) }
            return true
        } catch {
            errorMessage = (error as? AppError ?? .unknown).errorDescription
            return false
        }
    }

    func assign(_ vendor: Vendor) async {
        await mutate { try await $0.assign(vendor.id, to: self.ticketID) }
    }

    func markReplySent() async {
        await mutate { try await $0.markReplySent(self.ticketID) }
    }

    func submitComment() async {
        let text = commentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        commentText = ""
        await mutate { try await $0.addComment(text, to: self.ticketID) }
    }

    /// Runs a write then re-reads the ticket, so the screen always
    /// reflects what the source actually stored.
    private func mutate(
        _ work: @escaping (MaintenanceRepositoryProtocol) async throws -> Void
    ) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await work(repository)
            let updated = try await repository.ticket(id: ticketID)
            state = .loaded(updated)
            timelineEvents = try await repository.timeline(forTicketID: ticketID)
            // A moved or finished job updates its Lock Screen visit.
            await visitTracker.jobChanged(updated)
        } catch {
            state = .failed(error as? AppError ?? .unknown)
        }
    }
}
