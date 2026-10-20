//
//  RepairVisitTrackingRows.swift
//  RentalApp (Purrperty)
//
//  Shared — The two opt-ins for a booked visit: follow it on the Lock
//  Screen (Live Activity) and get a reminder an hour before. Used by the
//  staff request screen, the tenant portal and the vendor portal.
//
//  Shown only for a visit that's booked and still ahead.
//

import SwiftUI

struct RepairVisitTrackingRows: View {

    let ticket: MaintenanceTicket
    let tracker: RepairVisitTracker

    @State private var isWorking = false
    @State private var message: String?

    static func applies(to ticket: MaintenanceTicket) -> Bool {
        ticket.status == .scheduled && (ticket.scheduledVisit.map { $0 > .now } ?? false)
    }

    var body: some View {
        Toggle(isOn: lockScreenBinding) {
            Label("Show on Lock Screen", systemImage: "platter.filled.bottom.iphone")
        }
        .disabled(isWorking || !tracker.canShowLiveActivities)

        Toggle(isOn: reminderBinding) {
            Label("Remind Me 1 Hour Before", systemImage: "bell")
        }
        .disabled(isWorking || !canRemind)

        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var canRemind: Bool {
        guard let visit = ticket.scheduledVisit else { return false }
        return visit.addingTimeInterval(-RepairVisitTracker.reminderLead) > .now
    }

    // MARK: Bindings

    private var lockScreenBinding: Binding<Bool> {
        Binding(
            get: { tracker.trackedRequestIDs.contains(ticket.id) },
            set: { on in
                run {
                    if on {
                        if !(await tracker.track(ticket)) {
                            message = "Live Activities are off for Purrperty. Turn them on in Settings › Purrperty."
                        }
                    } else {
                        await tracker.stopTracking(ticket.id)
                    }
                }
            }
        )
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { tracker.remindedRequestIDs.contains(ticket.id) },
            set: { on in
                run {
                    if on {
                        if !(await tracker.remind(ticket)) {
                            message = "Notifications are off for Purrperty. Turn them on in Settings › Notifications."
                        }
                    } else {
                        await tracker.cancelReminder(ticket.id)
                    }
                }
            }
        )
    }

    private func run(_ work: @escaping () async -> Void) {
        isWorking = true
        message = nil
        Task {
            await work()
            isWorking = false
        }
    }
}
