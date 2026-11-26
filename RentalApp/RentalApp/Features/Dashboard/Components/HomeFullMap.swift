//
//  HomeFullMap.swift
//  RentalApp (Purrperty)
//
//  Dashboard — The layouts where Toronto fills the whole screen and the
//  map itself is the report: lenses that turn every pin into a number,
//  today's route through the homes that need you, and a command bar with
//  the paw's toes as a rail of gauges.
//

import CoreLocation
import SwiftUI

// MARK: - Lenses

/// What the pins report.
enum HomeLens: String, CaseIterable, Identifiable {
    case owing, repairs, empty, income
    var id: String { rawValue }

    var title: String {
        switch self {
        case .owing: "Owing"
        case .repairs: "Repairs"
        case .empty: "Empty units"
        case .income: "Income"
        }
    }

    var symbol: String {
        switch self {
        case .owing: "dollarsign.circle.fill"
        case .repairs: "wrench.and.screwdriver.fill"
        case .empty: "door.left.hand.open"
        case .income: "chart.bar.fill"
        }
    }

    var accent: DSAccent {
        switch self {
        case .owing: .gold
        case .repairs: .cherry
        case .empty: .sky
        case .income: .mint
        }
    }
}

extension HomeModel {

    /// Who owes at a home, most first.
    func owing(at property: Property) -> [RentRollRow] {
        owing.filter { $0.propertyName == property.name }
    }

    /// What a lens says about a home; nil when it has nothing to report.
    func badge(_ lens: HomeLens, for property: Property) -> HomePinBadge? {
        switch lens {
        case .owing:
            let total = owing(at: property).reduce(0) { $0 + $1.totalOwing }
            return total > 0 ? HomePinBadge(text: dollars(total), symbol: "exclamationmark", accent: .gold) : nil
        case .repairs:
            guard property.openRequests > 0 else { return nil }
            return property.urgentRequests > 0
                ? HomePinBadge(text: "\(property.urgentRequests) urgent", symbol: "flame.fill", accent: .cherry)
                : HomePinBadge(text: "\(property.openRequests) open", symbol: "wrench.fill", accent: .sky)
        case .empty:
            return property.vacantCount > 0 ? HomePinBadge(text: "\(property.vacantCount) empty", symbol: "door.left.hand.open", accent: .sky) : nil
        case .income:
            return property.monthlyRevenue > 0
                ? HomePinBadge(text: "$\(property.monthlyRevenue.formatted(.number.precision(.fractionLength(1))))K", symbol: "arrow.up", accent: .mint)
                : nil
        }
    }

    /// The homes a lens has something on, most first.
    func ranked(_ lens: HomeLens) -> [Property] {
        homes(lens).sorted { weight(lens, $0) > weight(lens, $1) }
    }

    private func weight(_ lens: HomeLens, _ property: Property) -> Double {
        switch lens {
        case .owing: Double(owing(at: property).reduce(0) { $0 + $1.totalOwing })
        case .repairs: Double(property.urgentRequests * 100 + property.openRequests)
        case .empty: Double(property.vacantCount)
        case .income: property.monthlyRevenue
        }
    }

    /// The homes a lens has something on.
    func homes(_ lens: HomeLens) -> [Property] {
        properties.filter { badge(lens, for: $0) != nil }
    }
}

/// The lens chips under the bar.
struct HomeLensBar: View {
    let model: HomeModel
    @Binding var lens: HomeLens
    @Environment(\.feedback) private var feedback

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(HomeLens.allCases) { option in
                    let isOn = lens == option
                    Button {
                        feedback?.play(.tap)
                        withAnimation(DS.Motion.bouncy) { lens = option }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.symbol).foregroundStyle(isOn ? DS.Colors.textOnBrand : option.accent.ink)
                            Text(option.title)
                            Text(model.homes(option).count, format: .number)
                                .font(DS.Typography.brandFixed(12))
                                .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20)
                                .background(Capsule().fill(isOn ? .white.opacity(0.25) : option.accent.tint))
                        }
                        .font(DS.Typography.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(isOn ? DS.Colors.textOnBrand : DS.Colors.textPrimary)
                        .padding(.horizontal, 12).frame(minHeight: 40)
                        .background {
                            if isOn { Capsule().fill(DS.Colors.brand) } else { Capsule().fill(.clear).homeGlass(radius: 20) }
                        }
                    }
                    .buttonStyle(SquishStyle(scale: 0.93))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

/// The lens's total, in a card under the map, with the one thing to do.
struct HomeLensCard: View {
    let model: HomeModel
    let lens: HomeLens
    @Binding var selection: String?
    @Environment(AppRouter.self) private var router

    var body: some View {
        let homes = model.homes(lens)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                PurrMascot(mood: mood(isClear: homes.isEmpty), size: 64, isInteractive: false).padding(-6)
                VStack(alignment: .leading, spacing: 0) {
                    Text(headline).font(DS.Typography.brandFixed(26)).foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
                    Text(line(count: homes.count)).font(DS.Typography.brand(.subheadline)).foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if !homes.isEmpty {
                // The homes it found, biggest first: each one flies the map there.
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(homes) { home in
                            Button { selection = home.id } label: {
                                HStack(spacing: 6) {
                                    Text(home.name).lineLimit(1)
                                    if let badge = model.badge(lens, for: home) {
                                        Text(badge.text).foregroundStyle(badge.accent.ink)
                                    }
                                }
                                .font(DS.Typography.brand(.footnote, weight: .semibold))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .padding(.horizontal, 12).frame(minHeight: 36)
                                .background(Capsule().fill(DS.Colors.surfaceRaised.opacity(0.85)))
                            }
                            .buttonStyle(SquishStyle(scale: 0.94))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
            Button(action: go) {
                HStack {
                    Text(action)
                    Spacer()
                    Image(systemName: "arrow.forward")
                }
                .font(DS.Typography.brand(.headline, weight: .semibold))
                .foregroundStyle(DS.Colors.textOnBrand)
                .padding(.horizontal, 18).frame(height: 50)
                .background(Capsule().fill(DS.Colors.brand))
            }
            .buttonStyle(SquishStyle(scale: 0.97))
        }
        .padding(16)
        .homeGlass()
        .animation(DS.Motion.smooth, value: lens)
    }

    private var headline: String {
        switch lens {
        case .owing: model.dollars(model.owing.reduce(0) { $0 + $1.totalOwing }) + " owing"
        case .repairs: "\(model.requests) repairs open"
        case .empty: "\(model.dashboard.vacantUnits) empty units"
        case .income: model.dollars(Int(model.properties.reduce(0) { $0 + $1.monthlyRevenue } * 1000)) + " a month"
        }
    }

    private func line(count: Int) -> String {
        let homes = count == 1 ? "1 home" : "\(count) homes"
        switch lens {
        case .owing: return count == 0 ? "Everyone has paid." : "\(model.owing.count) tenants at \(homes)."
        case .repairs: return count == 0 ? "Nothing to fix." : "\(model.urgentHomes.reduce(0) { $0 + $1.urgentRequests }) urgent, across \(homes)."
        case .empty: return count == 0 ? "Every unit is rented." : "Across \(homes)."
        case .income: return "Rent roll across \(homes)."
        }
    }

    private func mood(isClear: Bool) -> PurrMood {
        switch lens {
        case .owing: isClear ? .moneyDance : .rentOverdue
        case .repairs: isClear ? .noRequests : .urgentIssue
        case .empty: isClear ? .allCaughtUp : .vacancy
        case .income: .analytics
        }
    }

    private var action: String {
        switch lens {
        case .owing: "Open rent"
        case .repairs: "Open repairs"
        case .empty: "Open properties"
        case .income: "Open rent"
        }
    }

    private func go() {
        switch lens {
        case .owing, .income: router.push(.rentCollection)
        case .repairs: router.select(.maintenance)
        case .empty: router.select(.properties)
        }
    }
}

// MARK: - Today's route

/// A home that needs you, and why.
struct HomeStop: Identifiable {
    let property: Property
    let owing: [RentRollRow]
    var id: String { property.id }
}

extension HomeModel {

    /// The homes that need someone there: urgent repairs, rent owing,
    /// empty units, open repairs. The most pressing first, then always the
    /// nearest next, so the order is one you could drive.
    var route: [HomeStop] {
        let needing: [(stop: HomeStop, score: Int)] = properties.compactMap { property in
            let owing = owing(at: property)
            let score = property.urgentRequests * 3 + (owing.isEmpty ? 0 : 2) + (property.vacantCount > 0 ? 1 : 0) + (property.openRequests > 0 ? 1 : 0)
            guard score > 0, places[property.id] != nil else { return nil }
            return (HomeStop(property: property, owing: owing), score)
        }
        guard var current = needing.max(by: { $0.score < $1.score })?.stop else { return [] }
        var left = needing.map(\.stop).filter { $0.id != current.id }
        var ordered = [current]
        while !left.isEmpty, ordered.count < 6 {
            let here = location(current.id)
            let next = left.indices.min { here.distance(from: location(left[$0].id)) < here.distance(from: location(left[$1].id)) }!
            current = left.remove(at: next)
            ordered.append(current)
        }
        return ordered
    }

    /// Straight-line kilometres from the first stop to the last.
    func kilometres(_ stops: [HomeStop]) -> Double {
        zip(stops, stops.dropFirst()).reduce(0) { $0 + location($1.0.id).distance(from: location($1.1.id)) } / 1000
    }

    private func location(_ id: String) -> CLLocation {
        let place = places[id] ?? .init(latitude: 43.67, longitude: -79.39)
        return CLLocation(latitude: place.latitude, longitude: place.longitude)
    }
}

/// The route as stops: an overview first, then one stop at a time.
struct HomeRouteCard: View {
    let model: HomeModel
    let stops: [HomeStop]
    @Binding var current: Int?
    @Environment(AppRouter.self) private var router
    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(current.map { "Stop \($0 + 1) of \(stops.count)" } ?? "Today's route")
                        .font(DS.Typography.brand(.title3, weight: .bold))
                        .contentTransition(.numericText())
                    Text("\(stops.count) homes need you · \(model.kilometres(stops).formatted(.number.precision(.fractionLength(1)))) km end to end")
                        .font(DS.Typography.brand(.footnote)).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                PurrMascot(mood: current == nil ? .scheduledVisit : .inProgress, size: 58, isInteractive: false).padding(-8)
            }
            stepper
            if let current, stops.indices.contains(current) {
                stopDetail(stops[current])
                    .id(stops[current].id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
            } else {
                Text("The homes with rent owing, urgent repairs or empty units, most pressing first, then always the nearest next.")
                    .font(DS.Typography.brand(.subheadline)).foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            controls
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(16)
        .homeGlass()
        .clipShape(.rect(cornerRadius: 28, style: .continuous))
        .animation(DS.Motion.smooth, value: current)
    }

    /// One dot per stop on a line, filled up to where you are.
    private var stepper: some View {
        HStack(spacing: 0) {
            ForEach(stops.indices, id: \.self) { i in
                if i > 0 {
                    Capsule().fill(i <= (current ?? -1) ? DS.Colors.brand : DS.Colors.textSecondary.opacity(0.25)).frame(height: 4)
                }
                Button { go(to: i) } label: {
                    Text(i + 1, format: .number)
                        .font(DS.Typography.brandFixed(15))
                        .foregroundStyle(i <= (current ?? -1) ? DS.Colors.textOnBrand : DS.Colors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(i <= (current ?? -1) ? DS.Colors.brand : DS.Colors.surfaceRaised))
                        .overlay(Circle().strokeBorder(DS.Colors.brand, lineWidth: i == current ? 3 : 0).padding(-4))
                }
                .buttonStyle(SquishStyle(scale: 0.88))
                .accessibilityLabel("Stop \(i + 1), \(stops[i].property.name)")
            }
        }
    }

    private func stopDetail(_ stop: HomeStop) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(stop.property.name).font(DS.Typography.brand(.headline, weight: .bold)).lineLimit(1)
                Text("\(stop.property.address) · \(stop.property.neighborhood)").font(DS.Typography.brand(.caption)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
            }
            ForEach(stop.owing.prefix(2)) { row in
                reason("dollarsign", .gold, "\(row.tenantName) owes \(model.dollars(row.totalOwing))", row.unitName) {
                    HomeRemindButton(model: model, row: row)
                }
            }
            if stop.property.openRequests > 0 {
                reason("wrench.fill", stop.property.urgentRequests > 0 ? .cherry : .sky,
                       stop.property.urgentRequests > 0 ? "\(stop.property.urgentRequests) urgent repairs" : "\(stop.property.openRequests) repairs open",
                       "\(stop.property.openRequests) open in all") {
                    small("Repairs") { router.select(.maintenance) }
                }
            }
            if stop.property.vacantCount > 0 {
                reason("door.left.hand.open", .sky, "\(stop.property.vacantCount) empty units", "\(stop.property.occupiedCount) of \(stop.property.unitCount) rented") {
                    small("Units") { router.push(.units(propertyID: stop.property.id)) }
                }
            }
        }
    }

    private func reason<Trailing: View>(_ symbol: String, _ accent: DSAccent, _ title: String, _ detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 10) {
            ClayToken(symbol: symbol, accent: accent, size: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(DS.Typography.brand(.subheadline, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(detail).font(DS.Typography.brand(.caption)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            trailing()
        }
    }

    private func small(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(DS.Typography.brand(.subheadline, weight: .semibold))
            .foregroundStyle(DS.Colors.brandInk)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(Capsule().fill(DS.Colors.brand.opacity(0.12)))
            .buttonStyle(SquishStyle(scale: 0.92))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if let current {
                Button("Back", systemImage: "chevron.backward") { go(to: current == 0 ? nil : current - 1) }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(DS.Colors.surfaceRaised))
                    .buttonStyle(SquishStyle(scale: 0.9))
                Button { router.push(.propertyDetail(propertyID: stops[current].id)) } label: {
                    Text("Open home").frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(DS.Colors.surfaceRaised))
                }
                .buttonStyle(SquishStyle(scale: 0.96))
            }
            Button {
                let next = (current ?? -1) + 1
                go(to: next < stops.count ? next : nil)
            } label: {
                let isLast = current == stops.count - 1
                HStack(spacing: 6) {
                    Text(current == nil ? "Start the route" : isLast ? "Finish" : "Next stop")
                    Image(systemName: isLast ? "flag.checkered" : "arrow.forward")
                }
                .foregroundStyle(DS.Colors.textOnBrand)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Capsule().fill(DS.Colors.brand))
            }
            .buttonStyle(SquishStyle(scale: 0.96))
        }
        .font(DS.Typography.brand(.headline, weight: .semibold))
        .foregroundStyle(DS.Colors.textPrimary)
    }

    private func go(to stop: Int?) {
        feedback?.play(stop == nil && current != nil ? .celebrate : .tap)
        current = stop
    }
}

/// Sends a tenant the Rent screen's reminder, once.
struct HomeRemindButton: View {
    let model: HomeModel
    let row: RentRollRow
    @State private var isSending = false
    @State private var isSent = false
    @Environment(\.toasts) private var toasts
    @Environment(\.feedback) private var feedback

    var body: some View {
        let isDone = isSent || row.remindedAt != nil
        Button(action: send) {
            Group {
                if isSending { ProgressView() } else { Text(isDone ? "Reminded" : "Remind") }
            }
            .font(DS.Typography.brand(.subheadline, weight: .semibold))
            .foregroundStyle(isDone ? DSAccent.mint.ink : DS.Colors.textOnBrand)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(Capsule().fill(isDone ? DSAccent.mint.tint : DS.Colors.brand))
        }
        .buttonStyle(SquishStyle(scale: 0.92))
        .disabled(isDone || isSending)
    }

    private func send() {
        isSending = true
        Task {
            let failure = await model.remind(row)
            isSending = false
            if let failure {
                feedback?.play(.error)
                toasts.failure(.validation(failure))
            } else {
                isSent = true
                feedback?.play(.stamp)
                toasts.success("Reminder sent to \(row.firstName)", mood: .messageSent)
            }
        }
    }
}

// MARK: - Command

/// Find a home or a tenant from the top of the map.
struct HomeSearchField: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .bold)).foregroundStyle(DS.Colors.textSecondary)
            TextField("Find a home, tenant or unit", text: $query)
                .font(DS.Typography.brand(.body))
                .foregroundStyle(DS.Colors.textPrimary)
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { query = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.leading, 16).padding(.trailing, 4)
        .frame(height: 50)
        .homeGlass(radius: 25, tint: 0.8)
    }
}

/// What the search found: homes fly the map there, tenants open.
struct HomeSearchResults: View {
    let model: HomeModel
    let query: String
    let onHome: (Property) -> Void
    @Environment(AppRouter.self) private var router

    var body: some View {
        let homes = model.properties.filter { [$0.name, $0.neighborhood, $0.address].contains { $0.localizedCaseInsensitiveContains(query) } }.prefix(4)
        let tenants = model.roll.rows.filter { [$0.tenantName, $0.unitName, $0.propertyName].contains { $0.localizedCaseInsensitiveContains(query) } }.prefix(4)
        VStack(alignment: .leading, spacing: 4) {
            if homes.isEmpty, tenants.isEmpty {
                HStack(spacing: 10) {
                    PurrMascot(mood: .noResults, size: 52, isInteractive: false).padding(-6)
                    Text("Nothing here called “\(query)”.").font(DS.Typography.brand(.subheadline, weight: .semibold))
                }
                .padding(.vertical, 6)
            }
            if !homes.isEmpty { heading("Homes") }
            ForEach(homes) { home in
                row(symbol: home.kind.icon, accent: .gold, title: home.name, detail: "\(home.neighborhood) · \(home.occupiedCount)/\(home.unitCount) rented", trailing: "mappin") { onHome(home) }
            }
            if !tenants.isEmpty { heading("Tenants") }
            ForEach(tenants) { tenant in
                row(symbol: "person.fill", accent: .sky, title: tenant.tenantName,
                    detail: "\(tenant.unitName) · \(tenant.propertyName)" + (tenant.isOwing ? " · owes \(model.dollars(tenant.totalOwing))" : ""),
                    trailing: "chevron.forward") { router.push(.tenantDetail(tenantID: tenant.tenantID)) }
            }
            Divider().padding(.vertical, 4)
            row(symbol: "sparkles", accent: .cherry, title: "Ask Copilot", detail: "Open Copilot to ask anything", trailing: "chevron.forward") {
                router.push(.assistant)
            }
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(12)
        .homeGlass(radius: 24, tint: 0.85)
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(DS.Typography.brand(.caption, weight: .bold)).foregroundStyle(DS.Colors.textSecondary)
            .textCase(.uppercase).padding(.top, 4).padding(.leading, 4)
    }

    private func row(symbol: String, accent: DSAccent, title: String, detail: String, trailing: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ClayToken(symbol: symbol, accent: accent, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(DS.Typography.brand(.subheadline, weight: .semibold)).lineLimit(1)
                    Text(detail).font(DS.Typography.brand(.caption)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: trailing).font(.footnote.weight(.bold)).foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(minHeight: 48)
            .contentShape(.rect)
        }
        .buttonStyle(SquishStyle(scale: 0.98))
    }
}

/// The paw's five toes as gauges down the side of the map.
struct HomeToeRail: View {
    let model: HomeModel
    @Binding var toe: PawToe?
    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(spacing: 6) {
            ForEach([PawToe.rent, .homes, .repairs, .tasks, .streak]) { option in
                let isOn = toe == option
                Button {
                    feedback?.play(.select(option.rawValue))
                    withAnimation(DS.Motion.bouncy) { toe = isOn ? nil : option }
                } label: {
                    VStack(spacing: 1) {
                        ZStack {
                            Circle().stroke(option.accent.fill.opacity(0.22), lineWidth: 4)
                            Circle().trim(from: 0, to: model.level(option))
                                .stroke(option.accent.fill, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: option.symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(option.accent.ink)
                        }
                        .frame(width: 38, height: 38)
                        Text(model.value(option)).font(DS.Typography.brandFixed(12)).foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(width: 52, height: 60)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isOn ? option.accent.tint : .clear))
                    .scaleEffect(isOn ? 1.06 : 1)
                }
                .buttonStyle(SquishStyle(scale: 0.9))
                .accessibilityLabel("\(option.name), \(model.value(option))")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(5)
        .homeGlass(radius: 26)
    }
}

extension PawToe {
    /// The lens that shows this toe's homes on the map, where there is one.
    var lens: HomeLens? {
        switch self {
        case .rent: .owing
        case .homes: .empty
        case .repairs: .repairs
        case .tasks, .streak: nil
        }
    }
}

/// Purr on the toe you picked, with the way to it.
struct HomeToeCard: View {
    let model: HomeModel
    let toe: PawToe
    let onClose: () -> Void
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PurrMascot(mood: model.mood(toe), size: 78, isInteractive: false).padding(-6)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(toe.name) · \(model.value(toe))").font(DS.Typography.brand(.caption, weight: .bold)).foregroundStyle(toe.accent.ink).textCase(.uppercase)
                Text(model.detail(toe)).font(DS.Typography.brand(.headline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open \(toe.name.lowercased())", systemImage: "chevron.forward") { toe.open(with: router) }
                    .labelStyle(.titleOnly)
                    .font(DS.Typography.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(DS.Colors.brandInk)
            }
            Spacer(minLength: 30)
        }
        .padding(16)
        .homeGlass()
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly).font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.Colors.textSecondary).frame(width: 44, height: 44)
        }
        .id(toe)
        .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
    }
}
