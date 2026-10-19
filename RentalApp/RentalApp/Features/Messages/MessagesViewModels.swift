//
//  MessagesViewModels.swift
//  RentalApp (Purrperty)
//
//  Messages — Conversation list and chat thread view models.
//

import SwiftUI
import Observation

// MARK: - Conversation List

@MainActor
@Observable
final class ConversationListViewModel {

    private let repository: MessageRepositoryProtocol
    private let notifications: NotificationRepositoryProtocol

    var searchText = "" {
        didSet { guard oldValue != searchText else { return }; scheduleReload(debounced: true) }
    }
    var roleFilter: ChatRole? {
        didSet { guard oldValue != roleFilter else { return }; scheduleReload() }
    }
    var unreadOnly = false {
        didSet { guard oldValue != unreadOnly else { return }; scheduleReload() }
    }
    var selectedConversationID: String?

    private(set) var list: AsyncListModel<Conversation>!
    private(set) var totalUnread = 0
    private(set) var unreadNotifications = 0

    private var reloadTask: Task<Void, Never>?

    init(
        repository: MessageRepositoryProtocol,
        notifications: NotificationRepositoryProtocol
    ) {
        self.repository = repository
        self.notifications = notifications

        self.list = AsyncListModel<Conversation>(pageSize: 30) { [weak self] page, forceRefresh in
            guard let self else { return .empty }
            let query = MessageQuery(
                search: self.searchText,
                filter: MessageFilter(role: self.roleFilter, unreadOnly: self.unreadOnly),
                sort: SortOrder(.recency, .descending),
                page: page
            )
            let result = try await self.repository.conversations(matching: query, forceRefresh: forceRefresh)
            self.totalUnread = try await self.repository.totalUnread()
            return result
        }
    }

    var filteredConversations: [Conversation] { list.items }
    var isLoading: Bool { list.state.isLoading }
    var isRefreshing: Bool { list.isRefreshing }
    var error: AppError? { list.error }
    var isEmpty: Bool { list.isEmpty }

    func load() async {
        await list.load()
        unreadNotifications = (try? await notifications.unreadCount()) ?? 0
    }

    func refresh() async {
        await list.refresh()
        unreadNotifications = (try? await notifications.unreadCount()) ?? 0
    }

    func retry() async { await list.retry() }

    func loadMoreIfNeeded(currentItem item: Conversation) async {
        await list.loadMoreIfNeeded(currentItem: item)
    }

    func open(_ conversation: Conversation) {
        Task {
            try? await repository.markRead(conversation.id)
            totalUnread = (try? await repository.totalUnread()) ?? totalUnread
            await list.reload()
        }
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

// MARK: - Chat Thread

@MainActor
@Observable
final class ChatViewModel {

    private let repository: MessageRepositoryProtocol
    let conversationID: String
    /// Who is reading and writing: staff in the management app, the
    /// tenant in the portal.
    let viewer: MessageSender

    private(set) var state: LoadState<[ChatMessage]> = .idle
    private(set) var conversation: Conversation?

    var draft = ""

    init(conversationID: String, repository: MessageRepositoryProtocol, viewer: MessageSender = .staff) {
        self.conversationID = conversationID
        self.repository = repository
        self.viewer = viewer
    }

    /// The thread from the viewer's side: their own messages are "mine".
    var messages: [ChatMessage] {
        let thread = state.value ?? []
        guard viewer == .counterpart else { return thread }
        return thread.map { message in
            var flipped = message
            flipped.isMine.toggle()
            return flipped
        }
    }
    var isLoading: Bool { state.isLoading }
    var error: AppError? { state.error }
    var isTyping: Bool { repository.typingIn.contains(conversationID) }

    var canSend: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty }

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            conversation = try await repository.conversation(id: conversationID)
            state = .loaded(try await repository.messages(forConversationID: conversationID, forceRefresh: false))
            // Read state is the organization's inbox; a tenant opening the
            // thread mustn't clear what staff haven't seen.
            if viewer == .staff {
                try await repository.markRead(conversationID)
            }
        } catch {
            state = .failed(error as? AppError ?? .unknown)
        }
    }

    func refresh() async {
        guard let refreshed = try? await repository.messages(forConversationID: conversationID, forceRefresh: true)
        else { return }
        state = .loaded(refreshed)
    }

    func retry() async {
        state = .idle
        await load()
    }

    func send() async {
        let text = draft
        draft = ""
        try? await repository.send(text, attachment: nil, in: conversationID, from: viewer)
        await reloadThread()
    }

    func sendAttachment(_ attachment: ChatAttachment) async {
        try? await repository.send("", attachment: attachment, in: conversationID, from: viewer)
        await reloadThread()
    }

    /// Polls briefly so the simulated receipts and reply appear.
    private func reloadThread() async {
        for _ in 0..<8 {
            try? await Task.sleep(for: .milliseconds(600))
            guard let latest = try? await repository.messages(forConversationID: conversationID, forceRefresh: false)
            else { continue }
            state = .loaded(latest)
        }
    }
}
