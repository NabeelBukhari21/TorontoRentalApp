//
//  PurrpertyWidgetsLiveActivity.swift
//  PurrpertyWidgets
//
//  The repair-visit Live Activity: what's being fixed, where, who's
//  coming and how long until they arrive, on the Lock Screen and in the
//  Dynamic Island. The app starts it from a booked visit and ends it when
//  the job is marked done.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RepairVisitLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RepairVisitAttributes.self) { context in
            LockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(nil)
                .widgetURL(URL(string: "rentos://maintenance/\(context.attributes.requestID)"))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Repair", systemImage: "wrench.and.screwdriver.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusText(state: context.state)
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(subtitle(context.attributes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                CompactStatus(state: context.state)
            } minimal: {
                Image(systemName: context.state.stage == .done ? "checkmark" : "wrench.and.screwdriver.fill")
                    .foregroundStyle(.tint)
            }
            .widgetURL(URL(string: "rentos://maintenance/\(context.attributes.requestID)"))
        }
    }

    private func subtitle(_ attributes: RepairVisitAttributes) -> String {
        [attributes.place, attributes.vendor].compactMap { $0 }.joined(separator: " · ")
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {

    let context: ActivityViewContext<RepairVisitAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: context.state.stage == .done ? "checkmark.circle.fill" : "wrench.and.screwdriver.fill")
                .font(.title2)
                .foregroundStyle(context.state.stage == .done ? AnyShapeStyle(.green) : AnyShapeStyle(.tint))
                .frame(width: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(context.attributes.place)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let vendor = context.attributes.vendor {
                    Text(vendor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            StatusText(state: context.state)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                // A relative date wants all the width it can get; cap it so
                // the title keeps its room.
                .frame(width: 116, alignment: .trailing)
        }
    }
}

// MARK: - Status

/// "In 2 hr, 14 min", "Due now" or "Fixed".
private struct StatusText: View {
    let state: RepairVisitAttributes.ContentState

    var body: some View {
        switch state.stage {
        case .done:
            Text("Fixed")
                .foregroundStyle(.green)
        case .booked:
            if state.visitTime > .now {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(state.visitTime, style: .relative)
                        .monospacedDigit()
                    Text(state.visitTime, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Due now")
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct CompactStatus: View {
    let state: RepairVisitAttributes.ContentState

    var body: some View {
        switch state.stage {
        case .done:
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
        case .booked:
            // A bare time reads as today; on another day, name the day.
            Text(state.visitTime, format: Calendar.current.isDateInToday(state.visitTime)
                 ? .dateTime.hour().minute()
                 : .dateTime.weekday(.abbreviated))
                .monospacedDigit()
                .foregroundStyle(.tint)
        }
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content, using: RepairVisitAttributes(
    requestID: "r1", title: "Kitchen sink leaking", place: "Unit 204 · Glenholme Row", vendor: "Beacon Plumbing"
)) {
    RepairVisitLiveActivity()
} contentStates: {
    RepairVisitAttributes.ContentState(stage: .booked, visitTime: .now.addingTimeInterval(2 * 3600))
    RepairVisitAttributes.ContentState(stage: .done, visitTime: .now)
}
