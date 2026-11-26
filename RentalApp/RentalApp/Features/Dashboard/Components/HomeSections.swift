//
//  HomeSections.swift
//  RentalApp (Purrperty)
//
//  Dashboard — The parts Home is built from beyond the map and the paw:
//  quick actions, the week and today's plan, Purr's brief, money over
//  time, decisions with their buttons, what just happened, and asking Purr.
//

import Charts
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

// MARK: - Money

/// Rent over the last six months, and this month against what's due.
struct HomeCashFlow: View {
    let model: HomeModel
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button { router.push(.rentCollection) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Rent in this month").font(DS.Typography.brand(.caption, weight: .semibold)).foregroundStyle(DS.Colors.textSecondary)
                        Text(model.dollars(model.roll.collected)).font(DS.Typography.brand(32, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                    }
                    Spacer()
                    Text(model.dashboard.revenueTrend).font(DS.Typography.brand(.subheadline, weight: .semibold)).foregroundStyle(DSAccent.mint.ink)
                }
                Chart(model.dashboard.revenue) { point in
                    BarMark(x: .value("Month", point.month), y: .value("Rent", point.amount))
                        .foregroundStyle(point.id == model.dashboard.revenue.last?.id ? DS.Colors.brand : DSAccent.gold.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .annotation(position: .top) {
                            Text("$\(point.amount.formatted(.number.precision(.fractionLength(0))))K").font(DS.Typography.brand(.caption2, weight: .semibold)).foregroundStyle(DS.Colors.textSecondary)
                        }
                }
                .chartYAxis(.hidden)
                .chartXAxis { AxisMarks { _ in AxisValueLabel().font(DS.Typography.brand(.caption2)) } }
                .frame(height: 130)
                OnboardingProgressTube(progress: max(0.03, model.rentRate), label: "", fill: DSAccent.mint.fill, track: DS.Colors.track)
                Text("\(model.dollars(model.roll.collected)) of \(model.dollars(model.roll.expected)) expected. \(model.rentLine)")
                    .font(DS.Typography.brand(.footnote)).foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(16)
            .homeGlass()
        }
        .buttonStyle(SquishStyle(scale: 0.98))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Decisions

/// Things waiting on you, each with the button that settles it.
struct HomeDecisions: View {
    let model: HomeModel
    @State private var sent: Set<String> = []
    @State private var sending: String?
    @Environment(AppRouter.self) private var router
    @Environment(\.toasts) private var toasts
    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionTitle(title: "Needs a decision")
            ForEach(model.owing.prefix(2)) { row in
                decision(
                    symbol: "dollarsign", accent: .gold,
                    title: "\(row.tenantName) owes \(model.dollars(row.totalOwing))",
                    detail: "\(row.unitName) · \(row.propertyName)",
                    button: sent.contains(row.id) || row.remindedAt != nil ? "Reminded" : "Remind",
                    isDone: sent.contains(row.id) || row.remindedAt != nil, isBusy: sending == row.id
                ) { remind(row) }
            }
            ForEach(model.urgentHomes.prefix(2)) { home in
                decision(symbol: "wrench.fill", accent: .cherry, title: "\(home.urgentRequests) urgent at \(home.name)",
                         detail: "\(home.openRequests) open in all", button: "Assign") { router.select(.maintenance) }
            }
            if let home = model.emptyHomes.first {
                decision(symbol: "door.left.hand.open", accent: .sky, title: "\(home.vacantCount) empty at \(home.name)",
                         detail: home.neighborhood, button: "View") { router.push(.propertyDetail(propertyID: home.id)) }
            }
        }
        .padding(16)
        .homeGlass()
    }

    private func decision(symbol: String, accent: DSAccent, title: String, detail: String, button: String,
                          isDone: Bool = false, isBusy: Bool = false, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ClayToken(symbol: symbol, accent: accent, size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(DS.Typography.brand(.subheadline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary).lineLimit(2)
                Text(detail).font(DS.Typography.brand(.caption)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(action: action) {
                Group {
                    if isBusy { ProgressView() } else { Text(button) }
                }
                .font(DS.Typography.brand(.subheadline, weight: .semibold))
                .foregroundStyle(isDone ? DSAccent.mint.ink : DS.Colors.textOnBrand)
                .padding(.horizontal, 14).frame(minHeight: 38)
                .background(Capsule().fill(isDone ? DSAccent.mint.tint : DS.Colors.brand))
            }
            .buttonStyle(SquishStyle(scale: 0.92))
            .disabled(isDone || isBusy)
        }
    }

    private func remind(_ row: RentRollRow) {
        sending = row.id
        Task {
            let failure = await model.remind(row)
            sending = nil
            if let failure {
                feedback?.play(.error)
                toasts.failure(.validation(failure))
            } else {
                sent.insert(row.id)
                feedback?.play(.stamp)
                toasts.success("Reminder sent to \(row.firstName)", mood: .messageSent)
            }
        }
    }
}

// MARK: - Activity

/// What just happened, newest first.
struct HomeActivity: View {
    let model: HomeModel
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HomeSectionTitle(title: "Just now", action: "All") { router.push(.notifications) }
            ForEach(model.dashboard.activity.prefix(4)) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon).font(.system(size: 14, weight: .bold)).foregroundStyle(DS.Colors.textOnBrand)
                        .frame(width: 32, height: 32).background(Circle().fill(color(item.kind)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.title).font(DS.Typography.brand(.subheadline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary).lineLimit(1)
                        Text(item.subtitle).font(DS.Typography.brand(.caption)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(item.time).font(DS.Typography.brand(.caption, weight: .semibold)).foregroundStyle(DS.Colors.textTertiary)
                    if item.isNew { Circle().fill(DS.Colors.brand).frame(width: 8, height: 8) }
                }
                .frame(minHeight: 50)
            }
        }
        .padding(16)
        .homeGlass()
    }

    private func color(_ kind: DSStatusKind) -> Color {
        switch kind {
        case .success: DSAccent.mint.ink
        case .danger: DS.Colors.brand
        case .warning: DSAccent.gold.ink
        default: DSAccent.sky.ink
        }
    }
}

// MARK: - Ask Purr

/// A question Purr can answer from what's already here.
enum PurrQuestion: String, CaseIterable, Identifiable {
    case owing = "Who hasn't paid?"
    case urgent = "What's urgent?"
    case empty = "Which units are empty?"
    case today = "What's on today?"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .owing: "dollarsign"
        case .urgent: "flame.fill"
        case .empty: "door.left.hand.open"
        case .today: "calendar"
        }
    }

    var accent: DSAccent {
        switch self {
        case .owing: .gold
        case .urgent: .cherry
        case .empty: .sky
        case .today: .mint
        }
    }
}

/// Round buttons, one per question, ringed like stories.
struct PurrQuestionRings: View {
    @Binding var asked: PurrQuestion?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(PurrQuestion.allCases) { question in
                    Button { withAnimation(DS.Motion.bouncy) { asked = asked == question ? nil : question } } label: {
                        VStack(spacing: 6) {
                            ClayToken(symbol: question.symbol, accent: question.accent, size: 54)
                                .padding(4)
                                .overlay(Circle().strokeBorder(AngularGradient(colors: [DS.Colors.brand, DSAccent.gold.fill, DS.Colors.brand], center: .center), lineWidth: asked == question ? 4 : 2.5))
                            Text(question.rawValue)
                                .font(DS.Typography.brand(.caption2, weight: .semibold))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .multilineTextAlignment(.center).lineLimit(2)
                                .frame(width: 76)
                        }
                    }
                    .buttonStyle(SquishStyle(scale: 0.9))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .homeGlass(radius: 28)
    }
}

/// Purr's answer, worked out from the data on this screen.
struct PurrAnswer: View {
    let model: HomeModel
    let question: PurrQuestion
    let onClose: () -> Void
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                PurrMascot(mood: mood, size: 70, isInteractive: false).padding(-8)
                VStack(alignment: .leading, spacing: 0) {
                    Text(question.rawValue).font(DS.Typography.brand(.caption, weight: .semibold)).foregroundStyle(DS.Colors.brandInk)
                    Text(headline).font(DS.Typography.brand(.headline, weight: .bold)).foregroundStyle(DS.Colors.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("Close", systemImage: "xmark", action: onClose).labelStyle(.iconOnly).font(.footnote.weight(.bold))
                    .foregroundStyle(DS.Colors.textSecondary).frame(width: 44, height: 44).padding(-10)
            }
            ForEach(Array(rows.prefix(4).enumerated()), id: \.offset) { _, row in
                Button(action: row.go) {
                    HStack {
                        Text(row.title).font(DS.Typography.brand(.subheadline, weight: .semibold)).lineLimit(1)
                        Spacer()
                        Text(row.value).font(DS.Typography.brand(.subheadline, weight: .bold)).foregroundStyle(question.accent.ink)
                        Image(systemName: "chevron.forward").font(.caption.weight(.bold)).foregroundStyle(DS.Colors.textTertiary)
                    }
                    .foregroundStyle(DS.Colors.textPrimary)
                    .frame(minHeight: 40)
                    .contentShape(.rect)
                }
                .buttonStyle(SquishStyle(scale: 0.98))
            }
        }
        .padding(16)
        .homeGlass(tint: 0.65)
        .accessibilityElement(children: .contain)
    }

    private var mood: PurrMood {
        switch question {
        case .owing: model.owing.isEmpty ? .moneyDance : .rentOverdue
        case .urgent: model.urgentHomes.isEmpty ? .allCaughtUp : .urgentIssue
        case .empty: model.emptyHomes.isEmpty ? .fullyOccupied : .vacancy
        case .today: .tasksWaiting
        }
    }

    private var headline: String {
        switch question {
        case .owing: model.owing.isEmpty ? "Everyone's paid. Lovely." : "\(model.owing.count) owe \(model.dollars(model.owing.reduce(0) { $0 + $1.totalOwing })) in all."
        case .urgent: model.urgentHomes.isEmpty ? "Nothing urgent right now." : "\(model.urgentHomes.reduce(0) { $0 + $1.urgentRequests }) urgent repairs at \(model.urgentHomes.count) homes."
        case .empty: model.emptyHomes.isEmpty ? "Every unit is rented!" : "\(model.dashboard.vacantUnits) empty units at \(model.emptyHomes.count) homes."
        case .today: todays.isEmpty ? "Nothing booked today." : "\(todays.count) things today."
        }
    }

    private var todays: [UpcomingTask] {
        model.dashboard.tasks.filter { HomeModel.date(of: $0).map(Calendar.current.isDateInToday) ?? false }
    }

    private var rows: [(title: String, value: String, go: () -> Void)] {
        switch question {
        case .owing: model.owing.map { row in (row.tenantName, model.dollars(row.totalOwing), { router.push(.tenantLedger(tenantID: row.tenantID)) }) }
        case .urgent: model.urgentHomes.map { home in (home.name, "\(home.urgentRequests) urgent", { router.push(.propertyDetail(propertyID: home.id)) }) }
        case .empty: model.emptyHomes.map { home in (home.name, "\(home.vacantCount) empty", { router.push(.propertyDetail(propertyID: home.id)) }) }
        case .today: todays.map { task in (task.title, task.due.components(separatedBy: ", ").last ?? "", { router.push(.notifications) }) }
        }
    }
}

/// "Ask Purr" at the bottom: the questions he can answer here, and the
/// Copilot for the rest.
struct PurrAskBar: View {
    @Binding var asked: PurrQuestion?
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(PurrQuestion.allCases) { question in
                        Button { withAnimation(DS.Motion.bouncy) { asked = question } } label: {
                            Text(question.rawValue)
                                .font(DS.Typography.brand(.footnote, weight: .semibold))
                                .foregroundStyle(asked == question ? DS.Colors.textOnBrand : DS.Colors.textPrimary)
                                .padding(.horizontal, 12).frame(minHeight: 34)
                                .background(Capsule().fill(asked == question ? DS.Colors.brand : DS.Colors.surfaceRaised.opacity(0.8)))
                        }
                        .buttonStyle(SquishStyle(scale: 0.93))
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            Button { router.push(.assistant) } label: {
                HStack(spacing: 10) {
                    PurrMascot(mood: .assistantIdle, size: 38, isInteractive: false).padding(-4)
                    Text("Ask Purr anything…").font(DS.Typography.brand(.body)).foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(DS.Colors.textOnBrand)
                        .frame(width: 34, height: 34).background(Circle().fill(DS.Colors.brand))
                }
                .padding(.leading, 10).padding(.trailing, 7).frame(height: 50)
                .homeGlass(radius: 25, tint: 0.75)
            }
            .buttonStyle(SquishStyle(scale: 0.98))
            .accessibilityLabel("Ask Purr, opens Copilot")
        }
    }
}
