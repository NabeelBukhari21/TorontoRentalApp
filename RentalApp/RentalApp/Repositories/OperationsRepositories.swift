//
//  OperationsRepositories.swift
//  RentalApp (RentOS)
//
//  Repositories — Maintenance, Messaging, Documents, Notifications.
//
//  Writes mutate the local store and then invalidate their cache
//  namespace, which is exactly the sequence a networked version runs
//  after a successful `PATCH`.
//

import SwiftUI
import Observation

// MARK: - Maintenance

@MainActor
@Observable
final class InMemoryMaintenanceRepository: MaintenanceRepositoryProtocol {

    private let cache: RepositoryCache
    private var overrides: [String: MaintenanceTicket] = [:]

    init(cache: RepositoryCache = .shared) {
        self.cache = cache
    }

    private static let namespace = "maintenance"

    func tickets(matching query: MaintenanceQuery, forceRefresh: Bool) async throws -> Page<MaintenanceTicket> {
        try await SimulatedLatency.wait(.list)
        try Task.checkCancellation()

        let all = try await cached(forceRefresh: forceRefresh)
        return Self.apply(query, to: all).page(query.page)
    }

    func ticket(id: String) async throws -> MaintenanceTicket {
        try await SimulatedLatency.wait(.detail)
        let all = try await cached(forceRefresh: false)
        guard let match = all.first(where: { $0.id == id }) else {
            throw AppError.notFound("Request")
        }
        return match
    }

    func summary(forceRefresh: Bool) async throws -> MaintenanceSummary {
        let all = try await cached(forceRefresh: forceRefresh)
        let open = all.filter { $0.status != .done }
        return MaintenanceSummary(
            open: open.count,
            urgent: open.filter { $0.priority == .urgent }.count,
            unassigned: open.filter { $0.vendor == nil }.count,
            averageResolutionText: "1.8d"
        )
    }

    func vendors() async throws -> [Vendor] {
        await cache.fetch(key: "\(Self.namespace)|vendors") { Projections.vendors() }
    }

    func vendor(id: String) async throws -> Vendor? {
        try await vendors().first { $0.id == id }
    }

    func timeline(forTicketID id: String) async throws -> [TenantEvent] {
        try await SimulatedLatency.wait(.detail)
        return Projections.timeline(forTicketID: id)
    }

    // MARK: Writes

    func move(_ ticketID: String, to status: TicketStatus) async throws {
        try await mutate(ticketID) { $0.status = status }
    }

    func assign(_ vendorID: String, to ticketID: String) async throws {
        guard let vendor = try await vendor(id: vendorID) else {
            throw AppError.notFound("Vendor")
        }
        try await mutate(ticketID) { ticket in
            ticket.vendor = vendor
            if ticket.status == .new { ticket.status = .inProgress }
        }
    }

    func addComment(_ text: String, to ticketID: String) async throws {
        try await mutate(ticketID) { ticket in
            ticket.comments.append(
                TicketComment(author: "You", isManager: true, text: text, time: "Just now")
            )
        }
    }

    func markReplySent(_ ticketID: String) async throws {
        try await mutate(ticketID) { $0.replySent = true }
    }

    // MARK: Internals

    /// Applies a change, records it as an override, and invalidates the
    /// namespace so subsequent reads see it.
    private func mutate(
        _ ticketID: String,
        _ change: (inout MaintenanceTicket) -> Void
    ) async throws {
        try await SimulatedLatency.wait(.write)

        let all = try await cached(forceRefresh: false)
        guard var ticket = all.first(where: { $0.id == ticketID }) else {
            throw AppError.notFound("Request")
        }
        change(&ticket)
        overrides[ticketID] = ticket
        cache.invalidate(prefix: Self.namespace)
    }

    private func cached(forceRefresh: Bool) async throws -> [MaintenanceTicket] {
        let base = await cache.fetch(key: Self.namespace, forceRefresh: forceRefresh) {
            Projections.tickets()
        }
        guard !overrides.isEmpty else { return base }
        return base.map { overrides[$0.id] ?? $0 }
    }

    static func apply(_ query: MaintenanceQuery, to source: [MaintenanceTicket]) -> [MaintenanceTicket] {
        var result = source

        if let term = query.searchTerm {
            result = result.filter {
                $0.title.matches(term) || $0.propertyName.matches(term)
                    || $0.unitName.matches(term) || $0.tenantName.matches(term)
            }
        }

        if let priority = query.filter.priority {
            result = result.filter { $0.priority == priority }
        }
        if let status = query.filter.status {
            result = result.filter { $0.status == status }
        }

        let ascending = query.sort.direction.isAscending
        switch query.sort.field {
        case .priority:
            result.sort {
                $0.status.rawValue != $1.status.rawValue
                    ? $0.status.rawValue < $1.status.rawValue
                    : $0.priority < $1.priority
            }
        case .createdAt:
            // Source order is already newest-first.
            if !ascending { result.reverse() }
        case .property:
            result.sort { ascending ? $0.propertyName < $1.propertyName : $0.propertyName > $1.propertyName }
        }

        return result
    }
}

// MARK: - Messaging

@MainActor
@Observable
final class InMemoryMessageRepository: MessageRepositoryProtocol {

    private let cache: RepositoryCache
    private var threads: [String: [ChatMessage]] = [:]
    private var readConversationIDs: Set<String> = []
    private(set) var typingIn: Set<String> = []

    init(cache: RepositoryCache = .shared) {
        self.cache = cache
    }

    private static let namespace = "messages"

    func conversations(matching query: MessageQuery, forceRefresh: Bool) async throws -> Page<Conversation> {
        try await SimulatedLatency.wait(.list)
        try Task.checkCancellation()

        let all = try await cached(forceRefresh: forceRefresh)
        return Self.apply(query, to: all).page(query.page)
    }

    func conversation(id: String) async throws -> Conversation {
        let all = try await cached(forceRefresh: false)
        guard let match = all.first(where: { $0.id == id }) else {
            throw AppError.notFound("Conversation")
        }
        return match
    }

    func messages(forConversationID id: String, forceRefresh: Bool) async throws -> [ChatMessage] {
        if let existing = threads[id], !forceRefresh { return existing }
        try await SimulatedLatency.wait(.detail)
        let generated = Projections.messages(forConversationID: id)
        threads[id] = generated
        return generated
    }

    func totalUnread() async throws -> Int {
        try await cached(forceRefresh: false).reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: Writes

    func markRead(_ conversationID: String) async throws {
        guard !readConversationIDs.contains(conversationID) else { return }
        readConversationIDs.insert(conversationID)
        cache.invalidate(prefix: Self.namespace)
    }

    func send(_ text: String, attachment: ChatAttachment?, in conversationID: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty || attachment != nil else { return }

        let message = ChatMessage(
            text: trimmed, isMine: true, time: "Now",
            status: .sending, attachment: attachment
        )
        threads[conversationID, default: []].append(message)

        Task { await simulateDelivery(of: message.id, in: conversationID) }
    }

    // MARK: Realtime Simulation

    private func simulateDelivery(of messageID: UUID, in conversationID: String) async {
        try? await Task.sleep(for: .milliseconds(500))
        setStatus(.sent, for: messageID, in: conversationID)

        try? await Task.sleep(for: .milliseconds(700))
        setStatus(.read, for: messageID, in: conversationID)

        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(DS.Motion.smooth) { _ = typingIn.insert(conversationID) }

        try? await Task.sleep(for: .seconds(2.0))
        withAnimation(DS.Motion.smooth) { typingIn.remove(conversationID) }

        let reply = replyText(for: conversationID)
        withAnimation(DS.Motion.bouncy) {
            threads[conversationID, default: []].append(
                ChatMessage(text: reply, isMine: false, time: "Now")
            )
        }
    }

    private func setStatus(_ status: MessageStatus, for messageID: UUID, in conversationID: String) {
        guard var thread = threads[conversationID],
              let index = thread.firstIndex(where: { $0.id == messageID }) else { return }
        thread[index].status = status
        withAnimation(DS.Motion.gentle) { threads[conversationID] = thread }
    }

    private func replyText(for conversationID: String) -> String {
        let count = threads[conversationID]?.count ?? 0
        let tenantReplies = [
            "Thanks for the quick update! 🙌", "Perfect, that works for me.",
            "Got it — really appreciate it!", "Sounds good, thank you!"
        ]
        let vendorReplies = [
            "On it. I'll confirm the time slot shortly.", "Copy that — I'll bring the parts.",
            "Confirmed. Invoice will follow after the visit.", "Roger. ETA 45 minutes."
        ]
        let isVendor = conversationID.hashValue % 3 == 0
        let pool = isVendor ? vendorReplies : tenantReplies
        return pool[count % pool.count]
    }

    // MARK: Internals

    private func cached(forceRefresh: Bool) async throws -> [Conversation] {
        let base = await cache.fetch(key: Self.namespace, forceRefresh: forceRefresh) {
            Projections.conversations()
        }
        guard !readConversationIDs.isEmpty else { return base }
        return base.map { conversation in
            var copy = conversation
            if readConversationIDs.contains(conversation.id) { copy.unreadCount = 0 }
            return copy
        }
    }

    static func apply(_ query: MessageQuery, to source: [Conversation]) -> [Conversation] {
        var result = source

        if let term = query.searchTerm {
            result = result.filter { $0.name.matches(term) || $0.context.matches(term) }
        }
        if let role = query.filter.role {
            result = result.filter { $0.role == role }
        }
        if query.filter.unreadOnly {
            result = result.filter { $0.unreadCount > 0 }
        }

        return result.sorted { $0.isPinned && !$1.isPinned }
    }
}

// MARK: - Documents

@MainActor
@Observable
final class InMemoryDocumentRepository: DocumentRepositoryProtocol {

    private let cache: RepositoryCache
    private var favouriteOverrides: [UUID: Bool] = [:]
    private var uploaded: [DocFile] = []
    private(set) var uploads: [DocUpload] = []

    init(cache: RepositoryCache = .shared) {
        self.cache = cache
    }

    private static let namespace = "documents"

    private let folderList: [DocFolder] = [
        DocFolder(id: "leases", name: "Leases", icon: DS.Icons.lease, tint: DS.Colors.brandInk),
        DocFolder(id: "insurance", name: "Insurance", icon: "shield.fill", tint: DS.Colors.accentSkyInk),
        DocFolder(id: "financials", name: "Financials", icon: DS.Icons.payment, tint: DS.Colors.success),
        DocFolder(id: "inspections", name: "Inspections", icon: "checklist", tint: DS.Colors.accentSunnyInk),
        DocFolder(id: "photos", name: "Photos", icon: DS.Icons.camera, tint: DS.Colors.accentCoralInk)
    ]

    func files(matching query: DocumentQuery, forceRefresh: Bool) async throws -> Page<DocFile> {
        try await SimulatedLatency.wait(.list)
        try Task.checkCancellation()

        let all = try await cached(forceRefresh: forceRefresh)
        return Self.apply(query, to: all).page(query.page)
    }

    func folders() async throws -> [DocFolder] { folderList }

    func tags() async throws -> [String] {
        ["2026", "Signed", "Tax", "Urgent"]
    }

    func fileCount(inFolderID id: String) async throws -> Int {
        try await cached(forceRefresh: false).filter { $0.folderID == id }.count
    }

    // MARK: Writes

    func toggleFavorite(_ fileID: UUID) async throws {
        let all = try await cached(forceRefresh: false)
        guard let current = all.first(where: { $0.id == fileID }) else { return }
        favouriteOverrides[fileID] = !current.isFavorite
        cache.invalidate(prefix: Self.namespace)
    }

    func upload(named name: String, type: DocFileType, folderID: String) async throws {
        let upload = DocUpload(name: name, type: type)
        withAnimation(DS.Motion.bouncy) { uploads.append(upload) }

        var progress = 0.0
        while progress < 1.0 {
            try await Task.sleep(for: .milliseconds(180))
            progress = min(progress + Double.random(in: 0.08...0.2), 1.0)
            if let index = uploads.firstIndex(where: { $0.id == upload.id }) {
                withAnimation(DS.Motion.smooth) { uploads[index].progress = progress }
            }
        }

        try await Task.sleep(for: .milliseconds(350))

        withAnimation(DS.Motion.bouncy) {
            uploads.removeAll { $0.id == upload.id }
            uploaded.insert(
                DocFile(
                    name: name, type: type,
                    size: "\(Int.random(in: 120...2400)) KB",
                    date: "Just now", folderID: folderID,
                    tags: ["2026"], paletteIndex: Int.random(in: 0..<6)
                ),
                at: 0
            )
        }
        cache.invalidate(prefix: Self.namespace)
    }

    // MARK: Internals

    private func cached(forceRefresh: Bool) async throws -> [DocFile] {
        let base = await cache.fetch(key: Self.namespace, forceRefresh: forceRefresh) {
            Projections.files()
        }
        let combined = uploaded + base
        guard !favouriteOverrides.isEmpty else { return combined }
        return combined.map { file in
            var copy = file
            if let override = favouriteOverrides[file.id] { copy.isFavorite = override }
            return copy
        }
    }

    static func apply(_ query: DocumentQuery, to source: [DocFile]) -> [DocFile] {
        var result = source

        if let folderID = query.filter.folderID {
            result = result.filter { $0.folderID == folderID }
        }
        if let type = query.filter.type {
            result = result.filter { $0.type == type }
        }
        if !query.filter.tags.isEmpty {
            result = result.filter { !query.filter.tags.isDisjoint(with: $0.tags) }
        }
        if let term = query.searchTerm {
            result = result.filter {
                $0.name.matches(term) || $0.tags.contains { $0.matches(term) }
            }
        }

        if query.sort.field == .name {
            let ascending = query.sort.direction.isAscending
            result.sort { ascending ? $0.name < $1.name : $0.name > $1.name }
        }

        return result
    }
}

// MARK: - Notifications

@MainActor
@Observable
final class InMemoryNotificationRepository: NotificationRepositoryProtocol {

    private let cache: RepositoryCache
    private var readIDs: Set<UUID> = []
    private var dismissedIDs: Set<UUID> = []

    init(cache: RepositoryCache = .shared) {
        self.cache = cache
    }

    private static let namespace = "notifications"

    func notifications(forceRefresh: Bool) async throws -> [AppNotification] {
        try await SimulatedLatency.wait(.list)
        try Task.checkCancellation()
        return try await cached(forceRefresh: forceRefresh)
    }

    func unreadCount() async throws -> Int {
        try await cached(forceRefresh: false).filter(\.isUnread).count
    }

    func markRead(_ id: UUID) async throws {
        readIDs.insert(id)
        cache.invalidate(prefix: Self.namespace)
    }

    func markAllRead() async throws {
        let all = try await cached(forceRefresh: false)
        readIDs.formUnion(all.map(\.id))
        cache.invalidate(prefix: Self.namespace)
    }

    func dismiss(_ id: UUID) async throws {
        dismissedIDs.insert(id)
        cache.invalidate(prefix: Self.namespace)
    }

    // MARK: - Actions, mutes, preferences
    //
    // Held in memory so the mock graph exercises the same code paths the
    // server does — a mute set here really suppresses the row, so a bug in
    // the filtering logic shows up in previews rather than in production.

    private var mutes: [MuteTarget] = []
    private var storedPreferences: [NotificationPreference] = NotificationCategory.allCases.map {
        NotificationPreference(category: $0, inApp: true, push: true, email: false,
                               minPushPriority: .normal)
    }
    private var storedSettings: NotificationSettings = .default

    func perform(action actionID: String, on notificationID: UUID) async throws {
        try await SimulatedLatency.wait(.write)
        // Acting on a notification implies you have seen it.
        readIDs.insert(notificationID)
        cache.invalidate(prefix: Self.namespace)
    }

    func mute(_ target: MuteTarget, until: Date?) async throws {
        try await SimulatedLatency.wait(.write)
        guard !mutes.contains(target) else { return }
        mutes.append(target)
        cache.invalidate(prefix: Self.namespace)
    }

    func unmute(_ target: MuteTarget) async throws {
        try await SimulatedLatency.wait(.write)
        mutes.removeAll { $0 == target }
        cache.invalidate(prefix: Self.namespace)
    }

    func mutedTargets() async throws -> [MuteTarget] { mutes }

    func preferences() async throws -> [NotificationPreference] { storedPreferences }

    func updatePreference(_ preference: NotificationPreference) async throws {
        try await SimulatedLatency.wait(.write)
        if let index = storedPreferences.firstIndex(where: { $0.category == preference.category }) {
            storedPreferences[index] = preference
        }
    }

    func settings() async throws -> NotificationSettings { storedSettings }

    func updateSettings(_ settings: NotificationSettings) async throws {
        try await SimulatedLatency.wait(.write)
        storedSettings = settings
    }

    func registerDevice(token: String, platform: String, appVersion: String?) async throws {
        // Nothing to register against without a server.
    }

    /// Mirrors the server's suppression rule: a muted subject or category is
    /// recorded but hidden from the centre.
    private func isMuted(_ notification: AppNotification) -> Bool {
        mutes.contains { target in
            switch target {
            case .category(let category):
                return category == notification.category
            case .subject(let type, let id):
                return notification.subjectType == type && notification.subjectID == id
            }
        }
    }

    private func cached(forceRefresh: Bool) async throws -> [AppNotification] {
        let base = await cache.fetch(key: Self.namespace, forceRefresh: forceRefresh) {
            Projections.notifications()
        }
        return base
            .filter { !dismissedIDs.contains($0.id) && !isMuted($0) }
            .map { notification in
                var copy = notification
                if readIDs.contains(notification.id) { copy.isUnread = false }
                return copy
            }
    }
}
