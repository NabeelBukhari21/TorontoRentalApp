//
//  PushService.swift
//  RentalApp (Purrperty)
//
//  Core/Notifications — APNs registration, delivery, and routing.
//
//  ─────────────────────────────────────────────────────────────────
//  THE PAYLOAD IS A CONTRACT, NOT A MESSAGE
//  ─────────────────────────────────────────────────────────────────
//  A push notification is the only part of the app a user sees while the
//  app is not running, which makes it the one place where a mistake is
//  both highly visible and impossible to correct. Three decisions follow:
//
//  1. The payload carries the notification's **row id**, not its content.
//     The banner text is for the lock screen; when the app opens it fetches
//     the real row. Otherwise a notification tapped three days later shows
//     a status that changed two days ago.
//  2. Actions are registered as `UNNotificationCategory` at launch, keyed by
//     the same identifiers the server sends in `actions`. The two cannot
//     drift because they come from one enum.
//  3. Permission is requested **contextually**, not at launch. Asking on
//     first run gets refused by most people, and iOS only asks once.
//

import Foundation
import UserNotifications
import Observation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Payload

/// The APNs `aps` payload plus Purrperty keys.
///
/// Mirrored exactly by the `send-push` Edge Function. Changing a key here
/// without changing it there breaks tapping, silently, in production.
struct PushPayload: Codable, Sendable {

    /// The `notifications` row id. Everything else is display-only.
    let notificationID: String
    let category: String
    let priority: String
    let deepLink: String?
    let groupKey: String?

    enum CodingKeys: String, CodingKey {
        case notificationID = "notification_id"
        case category
        case priority
        case deepLink = "deep_link"
        case groupKey = "group_key"
    }

    /// Parses the Purrperty keys out of a `userInfo` dictionary.
    init?(userInfo: [AnyHashable: Any]) {
        guard let id = userInfo["notification_id"] as? String else { return nil }
        self.notificationID = id
        self.category = userInfo["category"] as? String ?? "system"
        self.priority = userInfo["priority"] as? String ?? "normal"
        self.deepLink = userInfo["deep_link"] as? String
        self.groupKey = userInfo["group_key"] as? String
    }
}

// MARK: - Authorization

enum PushAuthorizationState: String, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    /// Registered but the device has no APNs token yet.
    case pending

    var canPrompt: Bool { self == .notDetermined }
    var isUsable: Bool { self == .authorized || self == .provisional }
}

// MARK: - Contract

@MainActor
protocol PushServiceProtocol: AnyObject {

    var authorization: PushAuthorizationState { get }
    var deviceToken: String? { get }

    /// Registers notification categories with the system. Called once at
    /// launch, before any notification can arrive.
    func configure()

    /// Asks for permission. Call at a moment where the value is obvious —
    /// after creating the first property, not on the splash screen.
    @discardableResult
    func requestAuthorization() async -> Bool

    func refreshAuthorization() async

    /// Called from the app delegate when APNs hands over a token.
    func register(deviceToken: Data) async

    /// Sets the app icon badge, respecting the user's preference.
    func setBadge(_ count: Int) async
}

// MARK: - Implementation

@MainActor
@Observable
final class PushService: NSObject, PushServiceProtocol {

    private(set) var authorization: PushAuthorizationState = .notDetermined
    private(set) var deviceToken: String?

    /// Uploads the token and records action taps. Injected so this class
    /// stays free of networking.
    private let sink: PushSink

    /// Opens whatever a tapped notification points at.
    private let router: AppRouter

    init(sink: PushSink, router: AppRouter = .shared) {
        self.sink = sink
        self.router = router
        super.init()
    }

    // MARK: Configuration

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories(Self.categories())

        Task { await refreshAuthorization() }
    }

    /// Builds a `UNNotificationCategory` per notification category, carrying
    /// the actions that category can offer.
    ///
    /// Registered up front because iOS matches an incoming push's
    /// `category` against this set — a category registered after the push
    /// arrives shows no buttons at all.
    private static func categories() -> Set<UNNotificationCategory> {
        var result: Set<UNNotificationCategory> = []

        for category in NotificationCategory.allCases {
            let actions = PushActionCatalog.actions(for: category).map { action in
                UNNotificationAction(
                    identifier: action.id,
                    title: action.title,
                    options: action.isDestructive ? [.destructive, .authenticationRequired] : []
                )
            }
            result.insert(UNNotificationCategory(
                identifier: category.rawValue,
                actions: actions,
                intentIdentifiers: [],
                options: []
            ))
        }
        return result
    }

    // MARK: Authorization

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            // `.provisional` alongside the rest: on a first ask this delivers
            // quietly to the notification centre without a prompt, letting
            // the user upgrade once they see the value. Refusing a prompt is
            // permanent; ignoring a quiet notification is not.
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            await refreshAuthorization()
            if granted { registerForRemoteNotifications() }
            return granted
        } catch {
            await refreshAuthorization()
            return false
        }
    }

    func refreshAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorization = switch settings.authorizationStatus {
        case .authorized:    .authorized
        case .provisional:   .provisional
        case .denied:        .denied
        case .notDetermined: .notDetermined
        default:             .notDetermined
        }

        if authorization.isUsable, deviceToken == nil {
            authorization = .pending
            registerForRemoteNotifications()
        }
    }

    private func registerForRemoteNotifications() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    // MARK: Token

    func register(deviceToken data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        guard token != deviceToken else { return }

        deviceToken = token
        authorization = .authorized
        await sink.upload(token: token)
    }

    // MARK: Badge

    func setBadge(_ count: Int) async {
        try? await UNUserNotificationCenter.current().setBadgeCount(max(0, count))
    }
}

// MARK: - Delegate

extension PushService: UNUserNotificationCenterDelegate {

    /// A push that arrives while the app is open.
    ///
    /// Suppressed as a banner for everything but critical: the user is
    /// already looking at the app, and the in-app toast plus the badge
    /// carry the news without covering what they are reading. A flooded
    /// basement still interrupts.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {

        let userInfo = notification.request.content.userInfo
        let priority = userInfo["priority"] as? String ?? "normal"

        await MainActor.run {
            if let payload = PushPayload(userInfo: userInfo) {
                sink.didReceiveForeground(payload)
            }
        }

        return priority == "critical" ? [.banner, .sound, .list] : [.list]
    }

    /// A tap, or an action button.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {

        let userInfo = response.notification.request.content.userInfo
        guard let payload = PushPayload(userInfo: userInfo) else { return }

        await MainActor.run {
            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                open(payload)
            case UNNotificationDismissActionIdentifier:
                sink.didDismiss(payload)
            default:
                // An action button. Performed server-side so it works
                // identically whether the app was running or not.
                sink.didTriggerAction(response.actionIdentifier, payload: payload)
                // Actions that need a screen still navigate afterwards.
                if PushActionCatalog.opensApp(response.actionIdentifier) {
                    open(payload)
                }
            }
        }
    }

    private func open(_ payload: PushPayload) {
        sink.didOpen(payload)

        // Deep links go through the router, which owns tab selection and
        // stack construction. Reimplementing that here is how a push ends
        // up on the right screen in the wrong tab.
        if let link = payload.deepLink, let url = URL(string: link) {
            router.open(url)
        }
    }
}

// MARK: - Sink

/// Everything the push service needs from the rest of the app.
///
/// A protocol so `PushService` has no dependency on repositories, the toast
/// centre, or the sync engine — which keeps it testable without a backend.
@MainActor
protocol PushSink: AnyObject {
    func upload(token: String) async
    func didReceiveForeground(_ payload: PushPayload)
    func didOpen(_ payload: PushPayload)
    func didDismiss(_ payload: PushPayload)
    func didTriggerAction(_ actionID: String, payload: PushPayload)
}

// MARK: - Action Catalog

/// The single source of truth for action identifiers.
///
/// The server sends `{"id":"assign"}`; iOS registers an action with
/// identifier `assign`; the sink dispatches on `assign`. One table means
/// those three can never disagree.
enum PushActionCatalog {

    static func actions(for category: NotificationCategory) -> [NotificationAction] {
        switch category {
        case .maintenance:
            [
                .init(id: "assign", title: "Assign vendor"),
                .init(id: "view", title: "View")
            ]
        case .message:
            [.init(id: "reply", title: "Reply")]
        case .payment:
            [.init(id: "contact", title: "Contact tenant")]
        case .lease:
            [.init(id: "renew", title: "Start renewal")]
        case .inspection, .aiInsight, .system, .unknown:
            []
        }
    }

    /// Actions that need the app in the foreground to finish.
    static func opensApp(_ actionID: String) -> Bool {
        ["assign", "view", "reply", "contact", "renew"].contains(actionID)
    }
}

// MARK: - Disabled Service

/// Used in previews, the simulator, and the in-memory graph.
///
/// A null object rather than an optional: every call site would otherwise
/// need `if let push =`, and the one that forgets is the one that crashes
/// on a device where notifications are denied.
@MainActor
final class NoPushService: PushServiceProtocol {
    private(set) var authorization: PushAuthorizationState = .denied
    private(set) var deviceToken: String?

    func configure() {}
    @discardableResult func requestAuthorization() async -> Bool { false }
    func refreshAuthorization() async {}
    func register(deviceToken: Data) async {}
    func setBadge(_ count: Int) async {}
}
