//
//  OperationsRepositories.swift
//  RentalApp (Purrperty)
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
    @ObservationIgnored @WorkspaceLocal private var overrides: [String: MaintenanceTicket] = [:]
    /// Requests created this session, newest first, with when they were made.
    @ObservationIgnored @WorkspaceLocal private var created: [(ticket: MaintenanceTicket, at: Date)] = []

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
        if let entry = created.first(where: { $0.ticket.id == id }) {
            return [
                TenantEvent(
                    icon: TicketStatus.new.icon, kind: .info,
                    title: "Request received",
                    detail: "\(entry.ticket.unitName) · \(entry.ticket.propertyName)",
                    date: FakeDateFormat.relative(entry.at)
                )
            ]
        }
        return Projections.timeline(forTicketID: id)
    }

    // MARK: Writes

    func create(_ draft: MaintenanceRequestDraft) async throws -> MaintenanceTicket {
        try Self.validate(draft)
        try await SimulatedLatency.wait(.write)

        let ticket = MaintenanceTicket(
            id: "req-\(UUID().uuidString.lowercased())",
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: draft.details.trimmingCharacters(in: .whitespacesAndNewlines),
            propertyName: draft.propertyName,
            unitName: draft.unitID == nil ? "Common area" : draft.unitName,
            tenantName: draft.tenantName ?? "Staff report",
            priority: draft.priority,
            status: .new,
            category: draft.category,
            createdAgo: "Just now",
            photoCount: draft.photos.count,
            paletteIndex: created.count % 6,
            ai: nil,
            vendor: nil,
            comments: [],
            access: draft.access,
            photoData: draft.photos,
            unitID: draft.unitID,
            createdAt: .now
        )
        created.insert((ticket, .now), at: 0)
        cache.invalidate(prefix: Self.namespace)
        return ticket
    }

    /// The same rules the `maintenance_requests` CHECK constraints enforce.
    private static func validate(_ draft: MaintenanceRequestDraft) throws {
        guard draft.propertyID != nil else {
            throw AppError.validation("Choose the property.")
        }
        guard draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else {
            throw AppError.validation("Describe the problem in a few words.")
        }
        guard draft.photos.count <= MaintenanceRequestDraft.maxPhotos else {
            throw AppError.validation("Attach up to \(MaintenanceRequestDraft.maxPhotos) photos.")
        }
    }

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

    func bookVisit(_ ticketID: String, at date: Date, note: String) async throws {
        try await setVisit(ticketID, at: date, note: note) { text in
            TicketComment(author: "You", isManager: true, text: text, time: "Just now")
        }
    }

    // MARK: Vendor Actions

    func accept(_ ticketID: String, by vendorName: String) async throws {
        try await mutate(ticketID) { ticket in
            guard ticket.status == .new else { return }
            ticket.status = .inProgress
            ticket.comments.append(Self.vendorComment(vendorName, "Accepted the job."))
        }
    }

    func decline(_ ticketID: String, by vendorName: String, reason: String) async throws {
        let reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        try await mutate(ticketID) { ticket in
            ticket.vendor = nil
            ticket.scheduledVisit = nil
            ticket.status = .new
            ticket.comments.append(Self.vendorComment(
                vendorName, reason.isEmpty ? "Declined the job." : "Declined the job: \(reason)"
            ))
        }
    }

    func scheduleVisit(_ ticketID: String, at date: Date, by vendorName: String, note: String) async throws {
        try await setVisit(ticketID, at: date, note: note) { Self.vendorComment(vendorName, $0) }
    }

    /// Sets the visit, moves the job to scheduled and leaves an update in
    /// the author's name. Shared by the vendor and the organization.
    private func setVisit(
        _ ticketID: String,
        at date: Date,
        note: String,
        comment: @escaping (String) -> TicketComment
    ) async throws {
        guard date > .now else {
            throw AppError.validation("Choose a time in the future.")
        }
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try await mutate(ticketID) { ticket in
            let rebooked = ticket.scheduledVisit != nil
            ticket.scheduledVisit = date
            ticket.status = .scheduled
            let when = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
            ticket.comments.append(comment(
                "\(rebooked ? "Rebooked" : "Booked") a visit for \(when)." + (note.isEmpty ? "" : " \(note)")
            ))
        }
    }

    func complete(_ ticketID: String, by vendorName: String, notes: String) async throws {
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty else {
            throw AppError.validation("Say what was done, so the landlord and tenant know.")
        }
        try await mutate(ticketID) { ticket in
            ticket.status = .done
            ticket.comments.append(Self.vendorComment(vendorName, "Marked done: \(notes)"))
        }
    }

    func addVendorNote(_ text: String, to ticketID: String, by vendorName: String) async throws {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        try await mutate(ticketID) { $0.comments.append(Self.vendorComment(vendorName, text)) }
    }

    private static func vendorComment(_ vendorName: String, _ text: String) -> TicketComment {
        TicketComment(author: vendorName, isManager: false, text: text, time: "Just now")
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
        let all = created.map(\.ticket) + base
        guard !overrides.isEmpty else { return all }
        return all.map { overrides[$0.id] ?? $0 }
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
        if let unitID = query.filter.unitID {
            result = result.filter { $0.unitID == unitID }
        }
        if let vendorID = query.filter.vendorID {
            result = result.filter { $0.vendor?.id == vendorID }
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
            // Source order is already newest-first, so only ascending
            // (oldest first) needs reversing.
            if ascending { result.reverse() }
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
    @ObservationIgnored @WorkspaceLocal private var threads: [String: [ChatMessage]] = [:]
    @ObservationIgnored @WorkspaceLocal private var readConversationIDs: Set<String> = []
    /// Conversations with a message sent or received this session, most
    /// recent last, so the list shows them first with their new preview.
    @ObservationIgnored @WorkspaceLocal private var activeConversationIDs: [String] = []
    /// Conversations started in the app with tenants who had none.
    @ObservationIgnored @WorkspaceLocal private var started: [Conversation] = []
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
        guard let match = all.first(where: { $0.id == id }) ?? started.first(where: { $0.id == id }) else {
            throw AppError.notFound("Conversation")
        }
        return match
    }

    func conversationID(forTenantID id: String) async throws -> String {
        if let seeded = Projections.conversationID(forTenantID: id) { return seeded }
        let conversationID = "conv-tenant-\(id)"
        if !started.contains(where: { $0.id == conversationID }) {
            guard let contact = Projections.chatContact(forTenantID: id) else {
                throw AppError.notFound("Tenant")
            }
            started.append(Conversation(
                id: conversationID, name: contact.name, role: .tenant, context: contact.context,
                lastMessage: "", lastTime: "", unreadCount: 0, isOnline: false, isPinned: false
            ))
            threads[conversationID] = []
        }
        return conversationID
    }

    func messages(forConversationID id: String, forceRefresh: Bool) async throws -> [ChatMessage] {
        if let existing = threads[id], !forceRefresh || started.contains(where: { $0.id == id }) {
            return existing
        }
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

    func send(_ text: String, attachment: ChatAttachment?, in conversationID: String, from sender: MessageSender) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty || attachment != nil else { return }

        let message = ChatMessage(
            text: trimmed, isMine: sender == .staff, time: "Now",
            status: .sending, attachment: attachment
        )
        // Sending into a thread nobody has opened yet (a rent reminder
        // from the rent roll) must keep its history, not replace it.
        if threads[conversationID] == nil {
            threads[conversationID] = Projections.messages(forConversationID: conversationID)
        }
        threads[conversationID, default: []].append(message)
        markActive(conversationID)

        Task { await simulateDelivery(of: message.id, in: conversationID, from: sender) }
    }

    // MARK: Realtime Simulation

    private func simulateDelivery(of messageID: UUID, in conversationID: String, from sender: MessageSender) async {
        try? await Task.sleep(for: .milliseconds(500))
        setStatus(.sent, for: messageID, in: conversationID)

        // Only the tenant/vendor side is simulated. A message from a tenant
        // waits for a real person at the organization to answer it.
        guard sender == .staff else { return }

        try? await Task.sleep(for: .milliseconds(700))
        setStatus(.read, for: messageID, in: conversationID)

        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(DS.Motion.smooth) { _ = typingIn.insert(conversationID) }

        try? await Task.sleep(for: .seconds(2.0))
        withAnimation(DS.Motion.smooth) { _ = typingIn.remove(conversationID) }

        let reply = replyText(for: conversationID)
        withAnimation(DS.Motion.bouncy) {
            threads[conversationID, default: []].append(
                ChatMessage(text: reply, isMine: false, time: "Now")
            )
        }
        markActive(conversationID)
    }

    private func markActive(_ conversationID: String) {
        activeConversationIDs.removeAll { $0 == conversationID }
        activeConversationIDs.append(conversationID)
        cache.invalidate(prefix: Self.namespace)
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
        let seeded = await cache.fetch(key: Self.namespace, forceRefresh: forceRefresh) {
            Projections.conversations()
        }
        // A started conversation joins the inbox with its first message.
        let base = seeded + started.filter { activeConversationIDs.contains($0.id) }
        guard !readConversationIDs.isEmpty || !activeConversationIDs.isEmpty else { return base }
        let updated = base.map { conversation in
            var copy = conversation
            if readConversationIDs.contains(conversation.id) { copy.unreadCount = 0 }
            // The preview follows the thread once it has a message from
            // this session.
            if activeConversationIDs.contains(conversation.id),
               let last = threads[conversation.id]?.last {
                copy.lastMessage = last.isMine ? "You: \(Self.preview(of: last))" : Self.preview(of: last)
                copy.lastTime = last.time
            }
            return copy
        }
        // Most recently active first, then the seeded order.
        return updated.sorted { lhs, rhs in
            let l = activeConversationIDs.lastIndex(of: lhs.id) ?? -1
            let r = activeConversationIDs.lastIndex(of: rhs.id) ?? -1
            return l > r
        }
    }

    private static func preview(of message: ChatMessage) -> String {
        if !message.text.isEmpty { return message.text }
        switch message.attachment {
        case .photo: return "Photo"
        case .document(let name, _): return name
        case nil: return ""
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

        // Pinned first; otherwise keep the incoming (most recent) order.
        return result.filter(\.isPinned) + result.filter { !$0.isPinned }
    }
}

// MARK: - Documents

@MainActor
@Observable
final class InMemoryDocumentRepository: DocumentRepositoryProtocol {

    private let cache: RepositoryCache
    @ObservationIgnored @WorkspaceLocal private var favouriteOverrides: [UUID: Bool] = [:]
    @ObservationIgnored @WorkspaceLocal private var uploaded: [DocFile] = []
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
    @ObservationIgnored @WorkspaceLocal private var readIDs: Set<UUID> = []
    @ObservationIgnored @WorkspaceLocal private var dismissedIDs: Set<UUID> = []

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

    @ObservationIgnored @WorkspaceLocal private var mutes: [MuteTarget] = []
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
