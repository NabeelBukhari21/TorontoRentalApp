//
//  RepairVisitTracker.swift
//  RentalApp (Purrperty)
//
//  System Surfaces — A booked repair visit on the Lock Screen and in the
//  Dynamic Island (Live Activity), and a reminder notification an hour
//  before it.
//
//  Both are opt-in from the visit itself ("Show on Lock Screen",
//  "Remind Me"): a person asks for them in context, which is when
//  notification permission is requested (playbook §7).
//
//  Reminders are scheduled on this device, so they work without push. A
//  reminder for someone else's device needs server push, which needs the
//  paid Apple Developer Program.
//

import ActivityKit
import Foundation
import Observation
import OSLog
import UserNotifications

@MainActor
@Observable
final class RepairVisitTracker {

    static let shared = RepairVisitTracker()

    /// Request ids with a running Live Activity.
    private(set) var trackedRequestIDs: Set<String> = []
    /// Request ids with a pending reminder.
    private(set) var remindedRequestIDs: Set<String> = []

    private init() {}

    // MARK: Availability

    var canShowLiveActivities: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: Refresh

    /// Reads what's actually running and pending, so the toggles match.
    func refresh() async {
        trackedRequestIDs = Set(Activity<RepairVisitAttributes>.activities
            .filter { $0.activityState == .active || $0.activityState == .stale }
            .map(\.attributes.requestID))
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        remindedRequestIDs = Set(pending.compactMap { Self.requestID(fromReminder: $0.identifier) })
    }

    // MARK: Live Activity

    /// Starts (or updates) the Live Activity for a booked visit.
    func track(_ ticket: MaintenanceTicket) async -> Bool {
        guard let visit = ticket.scheduledVisit, canShowLiveActivities else { return false }
        let state = RepairVisitAttributes.ContentState(stage: .booked, visitTime: visit)
        // Stale a few hours after the visit, in case nobody marks it done.
        let content = ActivityContent(state: state, staleDate: visit.addingTimeInterval(4 * 3600))

        if let existing = activity(for: ticket.id) {
            await existing.update(content)
            trackedRequestIDs.insert(ticket.id)
            return true
        }
        do {
            _ = try Activity.request(
                attributes: RepairVisitAttributes(
                    requestID: ticket.id,
                    title: ticket.title,
                    place: "\(ticket.unitName) · \(ticket.propertyName)",
                    vendor: ticket.vendor?.company
                ),
                content: content
            )
            trackedRequestIDs.insert(ticket.id)
            return true
        } catch {
            AppLog.app.failure("Couldn't start the repair Live Activity", error: error)
            return false
        }
    }

    func stopTracking(_ requestID: String) async {
        await activity(for: requestID)?.end(nil, dismissalPolicy: .immediate)
        trackedRequestIDs.remove(requestID)
    }

    /// Keeps a running activity in step with the job: a rebooked time, or
    /// "Fixed" for a few minutes once it's done.
    func jobChanged(_ ticket: MaintenanceTicket) async {
        guard let activity = activity(for: ticket.id) else { return }
        if ticket.status == .done {
            let done = RepairVisitAttributes.ContentState(stage: .done, visitTime: ticket.scheduledVisit ?? .now)
            await activity.end(ActivityContent(state: done, staleDate: nil),
                               dismissalPolicy: .after(.now.addingTimeInterval(15 * 60)))
            trackedRequestIDs.remove(ticket.id)
            await cancelReminder(ticket.id)
        } else if let visit = ticket.scheduledVisit {
            let state = RepairVisitAttributes.ContentState(stage: .booked, visitTime: visit)
            await activity.update(ActivityContent(state: state, staleDate: visit.addingTimeInterval(4 * 3600)))
            if remindedRequestIDs.contains(ticket.id) {
                _ = await remind(ticket)
            }
        }
    }

    private func activity(for requestID: String) -> Activity<RepairVisitAttributes>? {
        Activity<RepairVisitAttributes>.activities.first { $0.attributes.requestID == requestID }
    }

    // MARK: Reminder

    /// How long before the visit the reminder fires.
    static let reminderLead: TimeInterval = 60 * 60

    /// Schedules (or reschedules) a reminder an hour before the visit.
    /// Returns false when notifications aren't allowed or it's too late.
    func remind(_ ticket: MaintenanceTicket) async -> Bool {
        guard let visit = ticket.scheduledVisit else { return false }
        let fireDate = visit.addingTimeInterval(-Self.reminderLead)
        guard fireDate > .now, await requestNotificationPermission() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Repair visit in 1 hour"
        content.body = "\(ticket.title) · \(ticket.unitName), \(ticket.propertyName) at \(visit.formatted(date: .omitted, time: .shortened))."
        content.sound = .default
        content.threadIdentifier = "repair-visits"
        content.userInfo = ["deep_link": "rentos://maintenance/\(ticket.id)"]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier(ticket.id),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            remindedRequestIDs.insert(ticket.id)
            return true
        } catch {
            AppLog.app.failure("Couldn't schedule the visit reminder", error: error)
            return false
        }
    }

    func cancelReminder(_ requestID: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier(requestID)])
        remindedRequestIDs.remove(requestID)
    }

    private func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private static let reminderPrefix = "repair-visit-"

    private static func reminderIdentifier(_ requestID: String) -> String {
        reminderPrefix + requestID
    }

    private static func requestID(fromReminder identifier: String) -> String? {
        identifier.hasPrefix(reminderPrefix) ? String(identifier.dropFirst(reminderPrefix.count)) : nil
    }
}
