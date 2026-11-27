//
//  HomeModel.swift
//  RentalApp (Purrperty)
//
//  Dashboard — What Home shows, and the bar across its top.
//

import MapKit
import SwiftUI

@MainActor
@Observable
final class HomeModel {


    let dashboard: DashboardViewModel
    private(set) var properties: [Property] = []
    private(set) var roll = RentRoll.empty(.now)
    private(set) var places: [String: CLLocationCoordinate2D] = [:]

    private let propertyRepository: PropertyRepositoryProtocol
    private let payments: PaymentRepositoryProtocol
    private let reminders: RentReminderSender
    /// Settings ▸ Appearance ▸ Show amounts on Home.
    private let preferences: PreferencesRepositoryProtocol

    init(dashboard: DashboardViewModel, container: AppContainer) {
        self.dashboard = dashboard
        propertyRepository = container.properties
        payments = container.payments
        preferences = container.preferences
        reminders = RentReminderSender(messages: container.messages, payments: container.payments, analytics: container.analytics, sync: container.sync)
    }

    func load() async {
        await dashboard.load()
        properties = (try? await propertyRepository.properties(matching: PropertyQuery(filter: .all, sort: SortOrder(.name)), forceRefresh: false).items) ?? []
        roll = (try? await payments.rentRoll(for: .now, forceRefresh: false)) ?? .empty(.now)
        await dashboard.loadExtras()
        await locate()
    }

    func refresh() async {
        await dashboard.refresh()
        properties = (try? await propertyRepository.properties(matching: PropertyQuery(filter: .all, sort: SortOrder(.name)), forceRefresh: true).items) ?? properties
        roll = (try? await payments.rentRoll(for: .now, forceRefresh: true)) ?? roll
        await locate()
    }

    /// Where each property is, for the map: its own coordinates, or its
    /// address looked up for one that has none.
    func locate() async {
        for property in properties where places[property.id] == nil {
            if let latitude = property.latitude, let longitude = property.longitude {
                places[property.id] = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                continue
            }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "\(property.address), ON"
            request.region = MKCoordinateRegion(center: .init(latitude: 43.7, longitude: -79.4), latitudinalMeters: 60000, longitudinalMeters: 60000)
            if let found = try? await MKLocalSearch(request: request).start().mapItems.first?.location.coordinate {
                places[property.id] = found
            }
        }
    }

    // MARK: Numbers

    /// Who owes, in words.
    var rentLine: String {
        if roll.owingCount == 0 { return "Everyone has paid." }
        if roll.outstanding == 0 { return "This month is in. \(roll.owingCount) still owe \(dollars(roll.arrears)) from before." }
        return "\(roll.owingCount) still to pay, \(dollars(roll.outstanding + roll.arrears)) to come."
    }

    /// Who owes, most first.
    var owing: [RentRollRow] { roll.rows.filter(\.isOwing).sorted { $0.totalOwing > $1.totalOwing } }

    /// Homes with urgent repairs, most first.
    var urgentHomes: [Property] { properties.filter { $0.urgentRequests > 0 }.sorted { $0.urgentRequests > $1.urgentRequests } }

    /// Homes with empty units, most first.
    var emptyHomes: [Property] { properties.filter { $0.vacantCount > 0 }.sorted { $0.vacantCount > $1.vacantCount } }

    /// Sends the same reminder the Rent screen does. Nil when it went.
    func remind(_ row: RentRollRow) async -> String? {
        let text = RentReminderSender.message(firstName: row.firstName, owing: row.totalOwing,
                                              oldestDueOn: row.arrears.first?.dueOn ?? row.dueOn, unitName: row.unitName)
        do {
            try await reminders.send(text, toTenantID: row.tenantID, conversationID: row.conversationID, month: roll.month)
            roll = (try? await payments.rentRoll(for: .now, forceRefresh: true)) ?? roll
            return nil
        } catch {
            return (error as? AppError ?? .unknown).errorDescription
        }
    }

    /// When a task is due, read back from its label ("Today, 2:00 PM",
    /// "Thu, 10:00 AM", "Dec 3").
    static func date(of task: UpcomingTask, now: Date = .now) -> Date? {
        let calendar = Calendar.current
        // System times use narrow and no-break spaces ("2:00\u{202F}PM").
        let label = task.due.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
        let parts = label.components(separatedBy: ", ")
        let time = parts.count > 1 ? parts[1] : nil
        var day: Date?
        switch parts[0] {
        case "Today": day = calendar.startOfDay(for: now)
        case "Tomorrow": day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        default:
            let weekdays = calendar.shortWeekdaySymbols
            if let index = weekdays.firstIndex(of: parts[0]) {
                let today = calendar.component(.weekday, from: now) - 1
                let ahead = (index - today + 7) % 7
                day = calendar.date(byAdding: .day, value: ahead == 0 ? 7 : ahead, to: calendar.startOfDay(for: now))
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_CA")
                formatter.dateFormat = "MMM d"
                if let parsed = formatter.date(from: parts[0]) {
                    var c = calendar.dateComponents([.month, .day], from: parsed)
                    c.year = calendar.component(.year, from: now)
                    day = calendar.date(from: c)
                }
            }
        }
        guard let day else { return nil }
        guard let time else { return day }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        guard let clock = formatter.date(from: time.replacingOccurrences(of: "a.m.", with: "AM").replacingOccurrences(of: "p.m.", with: "PM")) else { return day }
        let c = calendar.dateComponents([.hour, .minute], from: clock)
        return calendar.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: day)
    }

    var openTasks: [UpcomingTask] { dashboard.tasks.filter { !$0.isDone } }
    var urgentTasks: Int { openTasks.count { $0.isUrgent } }
    var rentRate: Double { roll.collectionRate }
    var occupancy: Double { dashboard.occupancyRate > 1 ? dashboard.occupancyRate / 100 : dashboard.occupancyRate }
    var requests: Int { dashboard.openRequestCount }
    var resolvedRate: Double {
        let total = dashboard.maintenanceCounts.reduce(0) { $0 + $1.count }
        return total == 0 ? 1 : Double(total - requests) / Double(total)
    }
    var taskRate: Double {
        dashboard.tasks.isEmpty ? 1 : Double(dashboard.tasks.count { $0.isDone }) / Double(dashboard.tasks.count)
    }
    var brief: DashboardBrief {
        DashboardBrief(urgentTasks: urgentTasks, openRequests: requests, openTasks: openTasks.count,
                       occupancyRate: dashboard.occupancyRate, unitCount: dashboard.unitCount)
    }

    /// Money as Home shows it: hidden behind dots when amounts are off,
    /// for using the app in public.
    func dollars(_ amount: Int) -> String {
        guard preferences.showPortfolioValueOnHome else { return "$•••" }
        return amount.formatted(.currency(code: "CAD").precision(.fractionLength(0)).presentation(.narrow))
    }
}


// MARK: - Bar

/// The way to everything that isn't on the page.
struct HomeBar: View {
    let model: HomeModel
    var ink: Color = DS.Colors.textPrimary
    var showsGreeting = true
    /// Over a picture: the greeting gets its own glass.
    var onGlass = false
    var onWardrobe: () -> Void = {}
    @Environment(AppRouter.self) private var router
    @Environment(SessionViewModel.self) private var session

    var body: some View {
        HStack(spacing: 10) {
            if showsGreeting {
                VStack(alignment: .leading, spacing: 0) {
                    // The date, and Toronto's weather when it's on.
                    HStack(spacing: 4) {
                        Text(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        if let weather = model.dashboard.weather {
                            // Credited, as Open-Meteo asks.
                            Link("· \(weather.summary), Open-Meteo", destination: OpenMeteoWeather.attribution)
                                .accessibilityLabel("Toronto weather, \(weather.summary), from Open-Meteo")
                        }
                    }
                    .font(DS.Typography.brand(.footnote))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .opacity(0.8)
                    Text(model.dashboard.greeting(for: session.session?.fullName))
                        .font(DS.Typography.brand(.title2, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(ink)
                .padding(.horizontal, onGlass ? 14 : 0)
                .padding(.vertical, onGlass ? 6 : 0)
                .dsGlass(in: .rect(cornerRadius: 20), isEnabled: onGlass)
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Menu {
                    Button("New property", systemImage: AppSymbol.properties.rawValue) { router.present(.newProperty) }
                    Button("New request", systemImage: AppSymbol.maintenance.rawValue) { router.present(.newMaintenanceRequest) }
                    Button("Ask Copilot", systemImage: AppSymbol.assistant.rawValue) { router.push(.assistant) }
                    Button("Purr's wardrobe", systemImage: "tshirt.fill", action: onWardrobe)
                    Section("Go to") {
                        Button("Rent", systemImage: AppSymbol.rent.rawValue) { router.push(.rentCollection) }
                        Button("Tenants", systemImage: AppSymbol.tenants.rawValue) { router.push(.tenants) }
                        Button("Documents", systemImage: AppSymbol.documents.rawValue) { router.push(.documents) }
                    }
                } label: { icon("plus") }
                    .accessibilityLabel("New")
                Button { router.push(.notifications) } label: {
                    icon("bell.fill").overlay(alignment: .topTrailing) {
                        if model.dashboard.unreadNotifications > 0 {
                            Circle().fill(DS.Colors.brand).frame(width: 9, height: 9).offset(x: -9, y: 9)
                        }
                    }
                }
                .accessibilityLabel("Notifications, \(model.dashboard.unreadNotifications) unread")
                Button { router.push(.settings) } label: { icon("person.fill") }
                    .accessibilityLabel("Account and Settings")
            }
            .padding(.horizontal, 4)
            .dsGlass(.regular.interactive(), in: .capsule)
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(DS.Colors.textPrimary)
            .frame(width: 42, height: 44)
    }
}
