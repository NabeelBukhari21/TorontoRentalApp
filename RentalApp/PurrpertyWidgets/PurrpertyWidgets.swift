//
//  PurrpertyWidgets.swift
//  PurrpertyWidgets
//
//  Home Screen and Lock Screen widgets: this month's rent and open
//  repairs. They read the `PortfolioSnapshot` the app writes to the
//  shared App Group, so they never show a number the app doesn't.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct PortfolioEntry: TimelineEntry {
    let date: Date
    /// Nil when signed out, or signed in as a tenant or vendor.
    let snapshot: PortfolioSnapshot?
}

struct PortfolioProvider: TimelineProvider {

    func placeholder(in context: Context) -> PortfolioEntry {
        PortfolioEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        completion(PortfolioEntry(date: .now, snapshot: context.isPreview ? .sample : PortfolioSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        let entry = PortfolioEntry(date: .now, snapshot: PortfolioSnapshot.load())
        // The app reloads the widgets whenever the numbers change; this is
        // only a fallback so they never sit stale for long.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Rent Widget

struct RentWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrpertyRent", provider: PortfolioProvider()) { entry in
            RentWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "rentos://rent"))
        }
        .configurationDisplayName("Rent")
        .description("How much of this month's rent is in, and how many tenants owe.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct RentWidgetView: View {

    let entry: PortfolioEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryCircular: circular(snapshot)
            case .accessoryRectangular: rectangular(snapshot)
            case .accessoryInline: Text("Rent \(percent(snapshot)) · \(owingText(snapshot))")
            case .systemMedium: medium(snapshot)
            default: small(snapshot)
            }
        } else {
            SignedOutView(title: "Rent", symbol: "dollarsign.circle")
        }
    }

    private func small(_ snapshot: PortfolioSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(title: "Rent", symbol: "dollarsign.circle", detail: snapshot.month.formatted(.dateTime.month(.abbreviated)))
            Spacer(minLength: 0)
            Text(percent(snapshot))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
            Text("\(snapshot.rentCollected.formatted(.dollars)) of \(snapshot.rentExpected.formatted(.dollars))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            OwingLabel(count: snapshot.tenantsOwing, text: owingText(snapshot))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medium(_ snapshot: PortfolioSnapshot) -> some View {
        HStack(spacing: 16) {
            small(snapshot)
            VStack(alignment: .leading, spacing: 8) {
                Gauge(value: snapshot.collectionRate) {
                    Text("Collected this month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(.green)
                LabeledValue(label: "Owing", value: snapshot.amountOwing.formatted(.dollars), isAlert: snapshot.amountOwing > 0)
                LabeledValue(label: "Tenants owing", value: "\(snapshot.tenantsOwing)", isAlert: snapshot.tenantsOwing > 0)
                Spacer(minLength: 0)
                UpdatedLabel(date: snapshot.updatedAt)
            }
        }
    }

    private func circular(_ snapshot: PortfolioSnapshot) -> some View {
        Gauge(value: snapshot.collectionRate) {
            Image(systemName: "dollarsign")
        } currentValueLabel: {
            Text(snapshot.collectionRate, format: .percent.precision(.fractionLength(0)))
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private func rectangular(_ snapshot: PortfolioSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Rent \(percent(snapshot))", systemImage: "dollarsign.circle")
                .font(.headline)
                .widgetAccentable()
            Text("\(snapshot.rentCollected.formatted(.dollars)) of \(snapshot.rentExpected.formatted(.dollars))")
            Text(owingText(snapshot))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The percentage is this month's rent; what's owed can include
    /// earlier months, so say so when this month is already fully in.
    private func owingText(_ snapshot: PortfolioSnapshot) -> String {
        if snapshot.tenantsOwing == 0 { return "All paid" }
        if snapshot.rentCollected >= snapshot.rentExpected { return "\(snapshot.tenantsOwing) in arrears" }
        return "\(snapshot.tenantsOwing) owing"
    }

    private func percent(_ snapshot: PortfolioSnapshot) -> String {
        snapshot.collectionRate.formatted(.percent.precision(.fractionLength(0)))
    }
}

// MARK: - Repairs Widget

struct RepairsWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrpertyRepairs", provider: PortfolioProvider()) { entry in
            RepairsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "rentos://maintenance"))
        }
        .configurationDisplayName("Repairs")
        .description("Open repair requests, the urgent ones, and the next booked visits.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct RepairsWidgetView: View {

    let entry: PortfolioEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryCircular: circular(snapshot)
            case .accessoryRectangular: rectangular(snapshot)
            case .accessoryInline: Text("\(snapshot.openRequests) repairs · \(snapshot.urgentRequests) urgent")
            case .systemMedium: medium(snapshot)
            default: small(snapshot)
            }
        } else {
            SignedOutView(title: "Repairs", symbol: "wrench.and.screwdriver")
        }
    }

    private func small(_ snapshot: PortfolioSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(title: "Repairs", symbol: "wrench.and.screwdriver", detail: nil)
            Spacer(minLength: 0)
            Text("\(snapshot.openRequests)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
            Text("open")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if snapshot.urgentRequests > 0 {
                    Label("\(snapshot.urgentRequests) urgent", systemImage: "exclamationmark.octagon.fill")
                        .foregroundStyle(.red)
                } else {
                    Label("None urgent", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medium(_ snapshot: PortfolioSnapshot) -> some View {
        HStack(alignment: .top, spacing: 16) {
            small(snapshot)
                .frame(maxWidth: 110, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text("Next visits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if snapshot.upcomingVisits.isEmpty {
                    Text("No visits booked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.upcomingVisits.prefix(2)) { visit in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(visit.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(visit.place)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(visit.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                Spacer(minLength: 0)
                if snapshot.unassignedRequests > 0 {
                    Text("\(snapshot.unassignedRequests) without a vendor")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func circular(_ snapshot: PortfolioSnapshot) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.caption)
                Text("\(snapshot.openRequests)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
        }
        .accessibilityLabel("\(snapshot.openRequests) open repairs")
    }

    private func rectangular(_ snapshot: PortfolioSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("\(snapshot.openRequests) open repairs", systemImage: "wrench.and.screwdriver")
                .font(.headline)
                .widgetAccentable()
            Text("\(snapshot.urgentRequests) urgent")
            if let next = snapshot.upcomingVisits.first {
                Text("Next visit \(next.date, format: .dateTime.weekday(.abbreviated).hour().minute())")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pieces

private struct WidgetHeader: View {
    let title: String
    let symbol: String
    let detail: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
            Text(title)
                .fontWeight(.semibold)
            Spacer(minLength: 0)
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .widgetAccentable()
    }
}

private struct OwingLabel: View {
    let count: Int
    let text: String

    var body: some View {
        Group {
            if count == 0 {
                Label("All paid", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label(text, systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String
    let isAlert: Bool

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(isAlert ? .red : .primary)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

private struct UpdatedLabel: View {
    let date: Date

    var body: some View {
        Text("Updated \(date, style: .time)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }
}

/// Shown when no staff account is signed in on this phone.
private struct SignedOutView: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            Spacer(minLength: 0)
            Text("Open Purrperty and sign in as an owner or manager.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Formatting

extension FormatStyle where Self == IntegerFormatStyle<Int>.Currency {
    /// Whole Canadian dollars: "$2,340".
    static var dollars: IntegerFormatStyle<Int>.Currency {
        .currency(code: "CAD").precision(.fractionLength(0))
    }
}

// MARK: - Previews

#Preview("Rent", as: .systemSmall) {
    RentWidget()
} timeline: {
    PortfolioEntry(date: .now, snapshot: .sample)
    PortfolioEntry(date: .now, snapshot: nil)
}

#Preview("Repairs", as: .systemMedium) {
    RepairsWidget()
} timeline: {
    PortfolioEntry(date: .now, snapshot: .sample)
}
