//
//  NotificationsModels.swift
//  RentalApp (RentOS)
//
//  Notifications — Model, store, and mock feed.
//

import SwiftUI
import Observation

// MARK: - Model

enum NotificationGroup: String, Codable, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case earlier = "Earlier"
}

// MARK: - Category & Priority
//
// Mirrors `Domain.Notification.Category` / `.Priority` and the Postgres
// enums. Present on the presentation model because the notification centre
// filters, groups, and mutes by them — a view cannot do that from an icon.

enum NotificationCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case maintenance
    case payment
    case message
    case lease
    case inspection
    case aiInsight = "ai_insight"
    case system
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .maintenance: "Maintenance"
        case .payment:     "Payments"
        case .message:     "Messages"
        case .lease:       "Leases"
        case .inspection:  "Inspections"
        case .aiInsight:   "AI insights"
        case .system:      "System"
        case .unknown:     "Other"
        }
    }

    var icon: String {
        switch self {
        case .maintenance: DS.Icons.maintenance
        case .payment:     DS.Icons.payment
        case .message:     DS.Icons.messages
        case .lease:       DS.Icons.lease
        case .inspection:  "checklist"
        case .aiInsight:   DS.Icons.ai
        case .system,
             .unknown:     DS.Icons.notifications
        }
    }
}

enum NotificationPriority: String, Codable, Sendable, CaseIterable, Comparable {
    case low
    case normal
    case high
    case critical

    private var rank: Int {
        switch self {
        case .low: 0
        case .normal: 1
        case .high: 2
        case .critical: 3
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }

    var statusKind: DSStatusKind {
        switch self {
        case .critical: .danger
        case .high:     .warning
        case .normal:   .info
        case .low:      .neutral
        }
    }

    /// Critical alerts pierce quiet hours and use a time-sensitive interrupt
    /// level. Everything else waits its turn.
    var isInterruptive: Bool { self == .critical }
}

// MARK: - Action

/// An inline action on a notification.
///
/// The same value drives the in-app buttons and the lock-screen actions, so
/// the two can never drift — a `UNNotificationAction` is registered from
/// this list at launch.
struct NotificationAction: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let title: String
    var isDestructive: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, title
        case isDestructive = "is_destructive"
    }
}

// MARK: - Notification

struct AppNotification: Identifiable, Sendable, Equatable, Codable {

    /// The server row id.
    ///
    /// Was `let id = UUID()` — locally generated, which meant `markRead(id)`
    /// could never address the row it came from. Everything downstream
    /// (read state, dismissal, deep links, push correlation) depends on this
    /// being the real identifier.
    let id: UUID

    let category: NotificationCategory
    let priority: NotificationPriority
    let title: String
    let message: String
    let time: String
    let group: NotificationGroup
    var isUnread: Bool

    /// What it is about, for muting and for opening the right screen.
    let subjectType: String?
    let subjectID: String?
    let deepLink: String?

    /// Collapses siblings — three comments on one ticket share a key.
    let groupKey: String?
    let actions: [NotificationAction]

    let createdAt: Date

    var icon: String { category.icon }
    var kind: DSStatusKind { priority.statusKind }

    /// A `rentos://` URL, when the server supplied one.
    ///
    /// Handed to `AppRouter.open(_:)` rather than parsed here — the router
    /// already owns deep-link resolution, including choosing the tab and
    /// building the whole stack. Re-implementing a subset of that on the
    /// model would drift the moment a route changes.
    var deepLinkURL: URL? {
        deepLink.flatMap(URL.init(string:))
    }

    /// Fallback destination when there is no deep link.
    var route: AppRoute? {
        guard let subjectID else { return nil }
        switch subjectType {
        case "maintenance_request": return .maintenanceDetail(requestID: subjectID)
        case "conversation":        return .conversation(conversationID: subjectID)
        case "property":            return .propertyDetail(propertyID: subjectID)
        case "tenant":              return .tenantDetail(tenantID: subjectID)
        case "document":            return .documents
        default:                    return nil
        }
    }

    init(
        id: UUID = UUID(),
        category: NotificationCategory,
        priority: NotificationPriority = .normal,
        title: String,
        message: String,
        time: String,
        group: NotificationGroup,
        isUnread: Bool,
        subjectType: String? = nil,
        subjectID: String? = nil,
        deepLink: String? = nil,
        groupKey: String? = nil,
        actions: [NotificationAction] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.category = category
        self.priority = priority
        self.title = title
        self.message = message
        self.time = time
        self.group = group
        self.isUnread = isUnread
        self.subjectType = subjectType
        self.subjectID = subjectID
        self.deepLink = deepLink
        self.groupKey = groupKey
        self.actions = actions
        self.createdAt = createdAt
    }
}

// MARK: - Mock Data

enum NotificationsMockData {

    static let feed: [AppNotification] = [
        // Today
        AppNotification(
            category: .maintenance, priority: .critical,
            title: "Urgent: water leak reported",
            message: "Sarah Chen · Unit 304 · AI classified urgent, plumber suggested",
            time: "26m", group: .today, isUnread: true
        ),
        AppNotification(
            category: .payment, priority: .normal,
            title: "Rent payment received",
            message: "$2,180 from Unit 12 · Queen West Lofts",
            time: "2h", group: .today, isUnread: true
        ),
        AppNotification(
            category: .aiInsight, priority: .normal,
            title: "Copilot briefing ready",
            message: "3 items need your attention today",
            time: "6h", group: .today, isUnread: true
        ),
        // Yesterday
        AppNotification(
            category: .message, priority: .normal,
            title: "New message from Marcus Johnson",
            message: "\u{201C}Thursday works, I'll be home all morning.\u{201D}",
            time: "Yesterday", group: .yesterday, isUnread: false
        ),
        AppNotification(
            category: .lease, priority: .normal,
            title: "Lease signed",
            message: "Unit 7 · Danforth Triplex · 12-month term",
            time: "Yesterday", group: .yesterday, isUnread: false
        ),
        AppNotification(
            category: .system, priority: .low,
            title: "Vendor assigned",
            message: "Lena Kowalski → dishwasher repair · Unit 102",
            time: "Yesterday", group: .yesterday, isUnread: false
        ),
        // Earlier
        AppNotification(
            category: .system, priority: .high,
            title: "Pricing opportunity flagged",
            message: "Queen West rents 6% under market — 2 vacancies upcoming",
            time: "Mon", group: .earlier, isUnread: false
        ),
        AppNotification(
            category: .system, priority: .normal,
            title: "Viewing scheduled",
            message: "Unit 2 · Queen West Lofts · Saturday 11 AM",
            time: "Mon", group: .earlier, isUnread: false
        ),
        AppNotification(
            category: .system, priority: .low,
            title: "Document uploaded",
            message: "Annual inspection report · Danforth Triplex",
            time: "Sun", group: .earlier, isUnread: false
        )
    ]
}
