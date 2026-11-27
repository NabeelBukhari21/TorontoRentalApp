//
//  HomeSections.swift
//  RentalApp (Purrperty)
//
//  Dashboard — The day under the map: quick actions, the week and the
//  day's plan, and Purr's brief.
//

import SwiftUI

// MARK: - Section title

struct HomeSectionTitle: View {
    let title: String
    var action: String? = nil
    var onAction: () -> Void = {}

    var body: some View {
        HStack {
            Text(title).font(DS.Typography.brand(.title3, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
            Spacer()
            if let action {
                Button(action, action: onAction)
                    .font(DS.Typography.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(DS.Colors.brandInk)
                    .frame(minHeight: 44)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Quick actions

/// The four things a landlord starts most, one tap each.
struct HomeQuickActions: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: 8) {
            action("Record rent", "dollarsign", .mint) { router.push(.rentCollection) }
            action("New repair", "wrench.fill", .cherry) { router.present(.newMaintenanceRequest) }
            action("Message", "bubble.left.fill", .sky) { router.select(.messages) }
            action("Add home", "plus", .gold) { router.present(.newProperty) }
        }
    }

    private func action(_ title: String, _ symbol: String, _ accent: DSAccent, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: 6) {
                ClayToken(symbol: symbol, accent: accent, size: 50)
                Text(title)
                    .font(DS.Typography.brand(.caption, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .homeGlass(radius: 22)
        }
        .buttonStyle(SquishStyle(scale: 0.92))
    }
}

// MARK: - Week

/// This week, today picked out, a dot under each day with something on.
struct HomeWeekStrip: View {
    let model: HomeModel
    @Binding var day: Date

    private var days: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func count(on date: Date) -> Int {
        model.dashboard.tasks.count { HomeModel.date(of: $0).map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { date in
                let isPicked = Calendar.current.isDate(date, inSameDayAs: day)
                let isToday = Calendar.current.isDateInToday(date)
                Button { withAnimation(DS.Motion.bouncy) { day = date } } label: {
                    VStack(spacing: 3) {
                        Text(date, format: .dateTime.weekday(.narrow)).font(DS.Typography.brand(.caption, weight: .semibold))
                        Text(date, format: .dateTime.day()).font(DS.Typography.brandFixed(20))
                        Circle().fill(count(on: date) > 0 ? (isPicked ? DS.Colors.textOnBrand : DS.Colors.brand) : .clear).frame(width: 6, height: 6)
                    }
                    .foregroundStyle(isPicked ? DS.Colors.textOnBrand : isToday ? DS.Colors.brandInk : DS.Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isPicked ? DS.Colors.brand : .clear))
                }
                .buttonStyle(SquishStyle(scale: 0.9))
                .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month()) + ", \(count(on: date)) things")
            }
        }
        .padding(6)
        .homeGlass(radius: 24)
    }
}

/// One day's tasks on a line, with "now" marked on today.
struct HomeDayPlan: View {
    let model: HomeModel
    let day: Date

    private var items: [(task: UpcomingTask, at: Date)] {
        model.dashboard.tasks.compactMap { task in
            HomeModel.date(of: task).flatMap { Calendar.current.isDate($0, inSameDayAs: day) ? (task, $0) : nil }
        }
        .sorted { $0.at < $1.at }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeSectionTitle(title: Calendar.current.isDateInToday(day) ? "Today" : day.formatted(.dateTime.weekday(.wide)))
                .padding(.bottom, 6)
            if items.isEmpty {
                HStack(spacing: 10) {
                    PurrMascot(mood: .meditate, size: 64, isInteractive: false).padding(-6)
                    Text("Nothing booked. A quiet one.").font(DS.Typography.brand(.subheadline)).foregroundStyle(DS.Colors.textSecondary)
                }
            }
            ForEach(Array(items.enumerated()), id: \.element.task.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.at, format: .dateTime.hour().minute())
                        .font(DS.Typography.brand(.caption, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 58, alignment: .trailing)
                        .padding(.top, 14)
                    VStack(spacing: 0) {
                        Circle().fill(item.task.isUrgent ? DS.Colors.brand : DSAccent.mint.fill).frame(width: 12, height: 12).padding(.top, 17)
                        if index < items.count - 1 { Rectangle().fill(DS.Colors.track).frame(width: 2).frame(maxHeight: .infinity) }
                    }
                    Button { Task { await model.dashboard.toggleTask(item.task) } } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.task.icon).foregroundStyle(item.task.isUrgent ? DS.Colors.brandInk : DSAccent.mint.ink)
                            Text(item.task.title).font(DS.Typography.brand(.subheadline, weight: .semibold)).strikethrough(item.task.isDone).lineLimit(2)
                            Spacer(minLength: 0)
                            SakugaCheckMark(isOn: item.task.isDone)
                        }
                        .foregroundStyle(DS.Colors.textPrimary)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DS.Colors.surface.opacity(0.8)))
                    }
                    .buttonStyle(SquishStyle(scale: 0.98))
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .homeGlass()
    }
}

// MARK: - Brief

/// Purr's morning brief: the few things that need you, in a sentence each.
struct HomeBrief: View {
    let model: HomeModel
    @Environment(AppRouter.self) private var router

    private var lines: [(symbol: String, text: String, accent: DSAccent, go: () -> Void)] {
        var result: [(String, String, DSAccent, () -> Void)] = []
        if model.urgentTasks > 0 { result.append(("flame.fill", "\(model.urgentTasks) urgent \(model.urgentTasks == 1 ? "task" : "tasks") today", .cherry, { router.push(.notifications) })) }
        if !model.owing.isEmpty { result.append(("dollarsign", "\(model.owing.count) still owe \(model.dollars(model.owing.reduce(0) { $0 + $1.totalOwing }))", .gold, { router.push(.rentCollection) })) }
        if let home = model.urgentHomes.first { result.append(("wrench.fill", "\(home.name) has \(home.urgentRequests) urgent repairs", .sky, { router.push(.propertyDetail(propertyID: home.id)) })) }
        if result.isEmpty { result.append(("checkmark", "Nothing needs you. Enjoy the day.", .mint, {})) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Purr's brief").font(DS.Typography.brand(.caption, weight: .semibold)).foregroundStyle(DS.Colors.brandInk)
                    Text(lines.count == 1 && lines[0].accent == .mint ? "All clear" : "\(lines.count) things need you")
                        .font(DS.Typography.brand(26, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                }
                Spacer(minLength: 0)
                PurrMascot(mood: model.urgentTasks > 0 ? .urgentIssue : .tasksWaiting, size: 92, isInteractive: false)
                    .padding(.vertical, -20).padding(.trailing, -10)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Button(action: line.go) {
                    HStack(spacing: 10) {
                        Image(systemName: line.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(line.accent.onFill)
                            .frame(width: 28, height: 28).background(Circle().fill(line.accent.fill))
                        Text(line.text).font(DS.Typography.brand(.subheadline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward").font(.caption.weight(.bold)).foregroundStyle(DS.Colors.textTertiary)
                    }
                    .frame(minHeight: 40)
                    .contentShape(.rect)
                }
                .buttonStyle(SquishStyle(scale: 0.98))
            }
        }
        .padding(16)
        .homeGlass()
    }
}
