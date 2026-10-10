//
//  SupabaseNotificationRepository.swift
//  RentalApp (Purrperty)
//
//  Supabase — The notification centre, backed by Postgres.
//
//  Reads are plain PostgREST; the interesting part is what is *absent*.
//  There is no insert path here at all, because `notifications` has no
//  INSERT policy — rows are created only by the triggers in migration 10.
//  A client that could write its own notifications could also write them to
//  a colleague's feed.
//

import Foundation
import Supabase

@MainActor
final class SupabaseNotificationRepository: NotificationRepositoryProtocol {

    private let client: SupabaseClient
    private let cache: RepositoryCache

    init(client: SupabaseClient, cache: RepositoryCache = .shared) {
        self.client = client
        self.cache = cache
    }

    private static let namespace = "supabase.notifications"

    // MARK: Reads

    func notifications(forceRefresh: Bool) async throws -> [AppNotification] {
        try await cache.fetch(key: Self.namespace, forceRefresh: forceRefresh) {
            do {
                let rows: [NotificationRow] = try await client
                    .from("notifications")
                    .select()
                    // RLS already restricts to the caller, so no recipient
                    // filter is needed — or trusted.
                    .filter("dismissed_at", operator: "is", value: "null")
                    .order("created_at", ascending: false)
                    .limit(100)
                    .execute()
                    .value

                let now = Date()
                return rows
                    .filter { ($0.expiresAt ?? .distantFuture) > now }
                    .map { $0.asNotification(now: now) }
            } catch {
                throw SupabaseErrorMapper.map(error)
            }
        }
    }

    func unreadCount() async throws -> Int {
        do {
            // A function rather than fetching and counting: the badge is
            // refreshed constantly and does not need the rows.
            return try await client
                .rpc("unread_notification_count")
                .execute()
                .value
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: State

    func markRead(_ id: UUID) async throws {
        try await update(id: id, patch: ["read_at": Date()])
    }

    func markAllRead() async throws {
        do {
            _ = try await client.rpc("mark_all_notifications_read").execute()
            cache.invalidate(prefix: Self.namespace)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func dismiss(_ id: UUID) async throws {
        try await update(id: id, patch: ["dismissed_at": Date()])
    }

    private func update(id: UUID, patch: [String: Date]) async throws {
        do {
            _ = try await client
                .from("notifications")
                .update(patch)
                .eq("id", value: id.uuidString)
                .execute()
            cache.invalidate(prefix: Self.namespace)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: Actions

    func perform(action actionID: String, on notificationID: UUID) async throws {
        do {
            // Server-side so an action taken from the lock screen behaves
            // identically to one taken in the app, and so the set of valid
            // actions is not whatever the client decides to send.
            _ = try await client
                .rpc("perform_notification_action", params: ActionParams(
                    notificationID: notificationID.uuidString,
                    actionID: actionID
                ))
                .execute()
            cache.invalidate(prefix: Self.namespace)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: Mutes

    func mute(_ target: MuteTarget, until: Date?) async throws {
        do {
            switch target {
            case .subject(let type, let id):
                _ = try await client.from("notification_mutes")
                    .upsert(SubjectMuteRow(subjectType: type, subjectID: id, expiresAt: until),
                            onConflict: "user_id,subject_type,subject_id")
                    .execute()
            case .category(let category):
                _ = try await client.from("notification_mutes")
                    .upsert(CategoryMuteRow(category: category.rawValue, expiresAt: until),
                            onConflict: "user_id,category")
                    .execute()
            }
            cache.invalidate(prefix: Self.namespace)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func unmute(_ target: MuteTarget) async throws {
        do {
            var query = client.from("notification_mutes").delete()
            switch target {
            case .subject(let type, let id):
                query = query.eq("subject_type", value: type).eq("subject_id", value: id)
            case .category(let category):
                query = query.eq("category", value: category.rawValue).filter("subject_id", operator: "is", value: "null")
            }
            _ = try await query.execute()
            cache.invalidate(prefix: Self.namespace)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func mutedTargets() async throws -> [MuteTarget] {
        do {
            let rows: [MuteRow] = try await client
                .from("notification_mutes")
                .select("subject_type, subject_id, category, expires_at")
                .execute()
                .value

            let now = Date()
            return rows.compactMap { row in
                guard (row.expiresAt ?? .distantFuture) > now else { return nil }
                if let type = row.subjectType, let id = row.subjectID {
                    return .subject(type: type, id: id)
                }
                if let raw = row.category, let category = NotificationCategory(rawValue: raw) {
                    return .category(category)
                }
                return nil
            }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: Preferences

    func preferences() async throws -> [NotificationPreference] {
        do {
            let rows: [PreferenceRow] = try await client
                .from("notification_preferences")
                .select()
                .execute()
                .value

            let existing = rows.compactMap(\.asPreference)
            // A user created before this migration has no rows yet. Fill the
            // gaps with defaults rather than showing an empty settings screen.
            let covered = Set(existing.map(\.category))
            let missing = NotificationCategory.allCases
                .filter { !covered.contains($0) }
                .map {
                    NotificationPreference(category: $0, inApp: true, push: true,
                                           email: false, minPushPriority: .normal)
                }
            return (existing + missing).sorted { $0.category.rawValue < $1.category.rawValue }
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func updatePreference(_ preference: NotificationPreference) async throws {
        do {
            _ = try await client.from("notification_preferences")
                .upsert(PreferenceUpsert(preference), onConflict: "user_id,category")
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func settings() async throws -> NotificationSettings {
        do {
            let rows: [SettingsRow] = try await client
                .from("notification_settings")
                .select()
                .limit(1)
                .execute()
                .value
            return rows.first?.asSettings ?? .default
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func updateSettings(_ settings: NotificationSettings) async throws {
        do {
            _ = try await client.from("notification_settings")
                .upsert(SettingsUpsert(settings), onConflict: "user_id")
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    // MARK: Push

    func registerDevice(token: String, platform: String, appVersion: String?) async throws {
        do {
            // Upsert on the token: the same device relaunching must refresh
            // `last_seen_at`, not accumulate a row per launch.
            _ = try await client.from("device_tokens")
                .upsert(DeviceTokenUpsert(
                    token: token, platform: platform, appVersion: appVersion
                ), onConflict: "token")
                .execute()
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

// MARK: - Wire Types

private struct NotificationRow: Decodable {
    let id: UUID
    let category: String
    let title: String
    let body: String
    let priority: String
    let subjectType: String?
    let subjectID: String?
    let deepLink: String?
    let groupKey: String?
    let actions: [NotificationAction]?
    let readAt: Date?
    let expiresAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, category, title, body, priority, actions
        case subjectType = "subject_type"
        case subjectID   = "subject_id"
        case deepLink    = "deep_link"
        case groupKey    = "group_key"
        case readAt      = "read_at"
        case expiresAt   = "expires_at"
        case createdAt   = "created_at"
    }

    func asNotification(now: Date) -> AppNotification {
        let calendar = Calendar.current
        let group: NotificationGroup =
            calendar.isDateInToday(createdAt) ? .today
            : calendar.isDateInYesterday(createdAt) ? .yesterday
            : .earlier

        return AppNotification(
            id: id,
            category: NotificationCategory(rawValue: category) ?? .system,
            priority: NotificationPriority(rawValue: priority) ?? .normal,
            title: title,
            message: body,
            time: createdAt.formatted(.relative(presentation: .numeric)),
            group: group,
            isUnread: readAt == nil,
            subjectType: subjectType,
            subjectID: subjectID,
            deepLink: deepLink,
            groupKey: groupKey,
            actions: actions ?? [],
            createdAt: createdAt
        )
    }
}

private struct MuteRow: Decodable {
    let subjectType: String?
    let subjectID: String?
    let category: String?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case category
        case subjectType = "subject_type"
        case subjectID   = "subject_id"
        case expiresAt   = "expires_at"
    }
}

private struct PreferenceRow: Decodable {
    let category: String
    let inApp: Bool
    let push: Bool
    let email: Bool
    let minPushPriority: String

    enum CodingKeys: String, CodingKey {
        case category, push, email
        case inApp           = "in_app"
        case minPushPriority = "min_push_priority"
    }

    var asPreference: NotificationPreference? {
        guard let kind = NotificationCategory(rawValue: category) else { return nil }
        return NotificationPreference(
            category: kind, inApp: inApp, push: push, email: email,
            minPushPriority: NotificationPriority(rawValue: minPushPriority) ?? .normal
        )
    }
}

private struct SettingsRow: Decodable {
    let quietHoursEnabled: Bool
    let quietStart: String
    let quietEnd: String
    let allowCriticalInQuiet: Bool
    let digestEnabled: Bool
    let badgeEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case quietHoursEnabled     = "quiet_hours_enabled"
        case quietStart            = "quiet_start"
        case quietEnd              = "quiet_end"
        case allowCriticalInQuiet  = "allow_critical_in_quiet"
        case digestEnabled         = "digest_enabled"
        case badgeEnabled          = "badge_enabled"
    }

    var asSettings: NotificationSettings {
        NotificationSettings(
            quietHoursEnabled: quietHoursEnabled,
            quietStart: Self.minutes(from: quietStart) ?? 22 * 60,
            quietEnd: Self.minutes(from: quietEnd) ?? 7 * 60,
            allowCriticalInQuiet: allowCriticalInQuiet,
            digestEnabled: digestEnabled,
            badgeEnabled: badgeEnabled
        )
    }

    /// Postgres `time` arrives as `HH:MM:SS`.
    private static func minutes(from raw: String) -> Int? {
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }
}

// MARK: - Upserts
//
// `user_id` is deliberately absent from every one of these: the column
// defaults to `auth.uid()` server-side, so a client cannot write a
// preference — or a mute, or a device token — onto somebody else's account.

private struct SubjectMuteRow: Encodable {
    let subjectType: String
    let subjectID: String
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case subjectType = "subject_type"
        case subjectID   = "subject_id"
        case expiresAt   = "expires_at"
    }
}

private struct CategoryMuteRow: Encodable {
    let category: String
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case category
        case expiresAt = "expires_at"
    }
}

private struct PreferenceUpsert: Encodable {
    let category: String
    let inApp: Bool
    let push: Bool
    let email: Bool
    let minPushPriority: String

    init(_ preference: NotificationPreference) {
        self.category = preference.category.rawValue
        self.inApp = preference.inApp
        self.push = preference.push
        self.email = preference.email
        self.minPushPriority = preference.minPushPriority.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case category, push, email
        case inApp           = "in_app"
        case minPushPriority = "min_push_priority"
    }
}

private struct SettingsUpsert: Encodable {
    let quietHoursEnabled: Bool
    let quietStart: String
    let quietEnd: String
    let allowCriticalInQuiet: Bool
    let digestEnabled: Bool
    let badgeEnabled: Bool

    init(_ settings: NotificationSettings) {
        self.quietHoursEnabled = settings.quietHoursEnabled
        self.quietStart = Self.time(settings.quietStart)
        self.quietEnd = Self.time(settings.quietEnd)
        self.allowCriticalInQuiet = settings.allowCriticalInQuiet
        self.digestEnabled = settings.digestEnabled
        self.badgeEnabled = settings.badgeEnabled
    }

    private static func time(_ minutes: Int) -> String {
        String(format: "%02d:%02d:00", minutes / 60, minutes % 60)
    }

    enum CodingKeys: String, CodingKey {
        case quietHoursEnabled    = "quiet_hours_enabled"
        case quietStart           = "quiet_start"
        case quietEnd             = "quiet_end"
        case allowCriticalInQuiet = "allow_critical_in_quiet"
        case digestEnabled        = "digest_enabled"
        case badgeEnabled         = "badge_enabled"
    }
}

private struct DeviceTokenUpsert: Encodable {
    let token: String
    let platform: String
    let appVersion: String?
    let lastSeenAt: Date

    init(token: String, platform: String, appVersion: String?) {
        self.token = token
        self.platform = platform
        self.appVersion = appVersion
        self.lastSeenAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case token, platform
        case appVersion = "app_version"
        case lastSeenAt = "last_seen_at"
    }
}

private struct ActionParams: Encodable {
    let notificationID: String
    let actionID: String

    enum CodingKeys: String, CodingKey {
        case notificationID = "p_notification_id"
        case actionID       = "p_action_id"
    }
}
