//
//  NotificationCoordinator.swift
//  RentalApp (Purrperty)
//
//  Core/Notifications — Where push meets the rest of the app.
//
//  `PushService` knows about APNs and nothing else. This is the piece that
//  turns a delivered payload into app behaviour: refresh the centre, update
//  the badge, raise an in-app toast, record an action.
//
//  Splitting them matters because the push half is untestable without a
//  device and an entitlement, while this half is pure logic over protocols.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class NotificationCoordinator: PushSink {

    /// The badge value, mirrored so the UI can show it without asking the
    /// system.
    private(set) var unreadCount = 0
    private(set) var lastPayload: PushPayload?

    private let repository: NotificationRepositoryProtocol
    private let push: PushServiceProtocol
    private let toasts: ToastCenter
    private let router: AppRouter

    /// Honours the user's badge preference. Cached because the badge is set
    /// far more often than the setting changes.
    private var badgeEnabled = true

    init(
        repository: NotificationRepositoryProtocol,
        push: PushServiceProtocol,
        toasts: ToastCenter,
        router: AppRouter = .shared
    ) {
        self.repository = repository
        self.push = push
        self.toasts = toasts
        self.router = router
    }

    // MARK: Lifecycle

    /// Called once the user is signed in — not at launch. A device token
    /// uploaded before sign-in has no user to attach to.
    func start() async {
        push.configure()
        badgeEnabled = (try? await repository.settings().badgeEnabled) ?? true
        await refreshBadge()
    }

    /// Called on sign-out. The token stays on the device but is detached
    /// from the account, so the next person to sign in on this phone does
    /// not receive the previous user's notifications.
    func stop() async {
        await push.setBadge(0)
        unreadCount = 0
    }

    func refreshBadge() async {
        unreadCount = (try? await repository.unreadCount()) ?? unreadCount
        if badgeEnabled {
            await push.setBadge(unreadCount)
        } else {
            await push.setBadge(0)
        }
    }

    func setBadgeEnabled(_ enabled: Bool) async {
        badgeEnabled = enabled
        await refreshBadge()
    }

    // MARK: Permission

    /// Asks for permission at a moment where the value is obvious.
    ///
    /// Deliberately not called at launch: iOS asks once, and a prompt
    /// shown before the user understands what the app does is usually
    /// declined permanently.
    @discardableResult
    func requestPermissionIfNeeded() async -> Bool {
        guard push.authorization.canPrompt else {
            return push.authorization.isUsable
        }
        return await push.requestAuthorization()
    }

    // MARK: PushSink

    func upload(token: String) async {
        try? await repository.registerDevice(
            token: token,
            platform: Self.platform,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
    }

    /// A push that arrived while the app was open.
    ///
    /// The banner is suppressed by `PushService` for non-critical items, so
    /// this is what tells the user something happened — a toast they can
    /// tap, which is less disruptive than a system banner over the screen
    /// they are already reading.
    func didReceiveForeground(_ payload: PushPayload) {
        lastPayload = payload
        Task { await refreshBadge() }

        guard let category = NotificationCategory(rawValue: payload.category) else { return }
        toasts.show(Toast(
            message: "New \(category.label.lowercased())",
            style: .info,
            duration: .seconds(4)
        ))
    }

    func didOpen(_ payload: PushPayload) {
        lastPayload = payload
        // Opening from a notification marks it read: the user has seen it,
        // and leaving it bold in the centre is just noise.
        if let id = UUID(uuidString: payload.notificationID) {
            Task {
                try? await repository.markRead(id)
                await refreshBadge()
            }
        }
    }

    func didDismiss(_ payload: PushPayload) {
        guard let id = UUID(uuidString: payload.notificationID) else { return }
        Task {
            // Swiping away a push is not the same as dismissing the record —
            // it only clears the lock screen. Marking it read is the honest
            // interpretation.
            try? await repository.markRead(id)
            await refreshBadge()
        }
    }

    func didTriggerAction(_ actionID: String, payload: PushPayload) {
        guard let id = UUID(uuidString: payload.notificationID) else { return }
        Task {
            do {
                try await repository.perform(action: actionID, on: id)
                await refreshBadge()
            } catch {
                // The action failed after the app was already opened by it,
                // so the user is looking at the screen and deserves to know.
                toasts.failure(AppError.from(error))
            }
        }
    }

    // MARK: Platform

    private static var platform: String {
        #if targetEnvironment(simulator)
        "ios_sandbox"
        #elseif DEBUG
        "ios_sandbox"
        #else
        "ios"
        #endif
    }
}
