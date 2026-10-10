//
//  NotificationsViewModel.swift
//  RentalApp (Purrperty)
//
//  Notifications — Grouped feed view model.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class NotificationsViewModel {

    private let repository: NotificationRepositoryProtocol

    private(set) var state: LoadState<[AppNotification]> = .idle

    init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    var notifications: [AppNotification] { state.value ?? [] }
    var unreadCount: Int { notifications.filter(\.isUnread).count }
    var isLoading: Bool { state.isLoading }
    var error: AppError? { state.error }
    var isEmpty: Bool { state.isLoaded && notifications.isEmpty }

    func notifications(in group: NotificationGroup) -> [AppNotification] {
        notifications.filter { $0.group == group }
    }

    func unreadCount(in group: NotificationGroup) -> Int {
        notifications(in: group).filter(\.isUnread).count
    }

    // MARK: Lifecycle

    func load() async {
        guard case .idle = state else { return }
        await fetch(forceRefresh: false, showsSpinner: true)
    }

    func refresh() async { await fetch(forceRefresh: true, showsSpinner: false) }

    func retry() async {
        state = .idle
        await fetch(forceRefresh: true, showsSpinner: true)
    }

    // MARK: Intents

    func markRead(_ id: UUID) async {
        try? await repository.markRead(id)
        await fetch(forceRefresh: false, showsSpinner: false)
    }

    func markAllRead() async {
        try? await repository.markAllRead()
        await fetch(forceRefresh: false, showsSpinner: false)
    }

    // MARK: - Actions & muting

    /// Runs a server-side action, then refreshes so the row reflects it.
    ///
    /// The server validates that the action was actually offered on this
    /// notification — a client cannot invoke one by guessing an identifier.
    func perform(_ actionID: String, on notification: AppNotification) async {
        do {
            try await repository.perform(action: actionID, on: notification.id)
            await fetch(forceRefresh: true, showsSpinner: false)
        } catch {
            lastError = AppError.from(error)
        }
    }

    /// Silences one thing — this ticket, this conversation.
    func muteSubject(of notification: AppNotification) async {
        guard let type = notification.subjectType, let id = notification.subjectID else { return }
        await mute(.subject(type: type, id: id), label: "thread")
    }

    /// Silences a whole class of notification.
    func muteCategory(of notification: AppNotification) async {
        await mute(.category(notification.category), label: notification.category.label.lowercased())
    }

    private func mute(_ target: MuteTarget, label: String) async {
        do {
            try await repository.mute(target, until: nil)
            // Muted rows disappear from the centre, so refresh rather than
            // leaving a row the user just silenced sitting on screen.
            await fetch(forceRefresh: true, showsSpinner: false)
            mutedLabel = label
        } catch {
            lastError = AppError.from(error)
        }
    }

    /// Set briefly after a mute so the view can offer an undo.
    private(set) var mutedLabel: String?
    private(set) var lastError: AppError?

    func clearMuteNotice() { mutedLabel = nil }

    func dismiss(_ id: UUID) async {
        try? await repository.dismiss(id)
        await fetch(forceRefresh: false, showsSpinner: false)
    }

    private func fetch(forceRefresh: Bool, showsSpinner: Bool) async {
        if showsSpinner { state = .loading }
        do {
            state = .loaded(try await repository.notifications(forceRefresh: forceRefresh))
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error as? AppError ?? .unknown)
        }
    }
}
