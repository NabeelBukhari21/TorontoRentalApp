//
//  HomeStudio.swift
//  RentalApp (Purrperty)
//
//  Dashboard — Five directions for Home, side by side, on real data. DEBUG
//  builds only, until one is chosen. All three are the map with glass
//  cards over it, and the paw as one feature:
//
//      -PurrpertyStartAt home -PurrpertyHome 1|2|3
//

#if DEBUG
import MapKit
import SwiftUI

enum HomeDesign: String, CaseIterable {
    /// A glass sheet over the map, as in Maps.
    case sheet = "1"
    /// Glass cards floating at the map's edges.
    case float = "2"
    /// The map up top, the glass dashboard scrolling over it.
    case hero = "3"

    static let key = "PurrpertyHome"

    /// Test builds open on the studio; "Now" is today's Home.
    static var requested: HomeDesign? {
        let value = UserDefaults.standard.string(forKey: key) ?? HomeDesign.sheet.rawValue
        return HomeDesign(rawValue: value)
    }
}

/// What every direction draws from.
@MainActor
@Observable
final class HomeStudioModel {

    let dashboard: DashboardViewModel
    private(set) var properties: [Property] = []
    private(set) var roll = RentRoll.empty(.now)
    private(set) var places: [String: CLLocationCoordinate2D] = [:]

    private let propertyRepository: PropertyRepositoryProtocol
    private let payments: PaymentRepositoryProtocol

    init(dashboard: DashboardViewModel, container: AppContainer) {
        self.dashboard = dashboard
        propertyRepository = container.properties
        payments = container.payments
    }

    func load() async {
        await dashboard.load()
        properties = (try? await propertyRepository.properties(matching: PropertyQuery(filter: .all, sort: SortOrder(.name)), forceRefresh: false).items) ?? []
        roll = (try? await payments.rentRoll(for: .now, forceRefresh: false)) ?? .empty(.now)
        await dashboard.loadExtras()
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

    func dollars(_ amount: Int) -> String { amount.formatted(.currency(code: "CAD").precision(.fractionLength(0)).presentation(.narrow)) }
}

struct HomeStudio: View {
    let design: HomeDesign
    @State private var model: HomeStudioModel

    init(design: HomeDesign, dashboard: DashboardViewModel, container: AppContainer) {
        self.design = design
        _model = State(initialValue: HomeStudioModel(dashboard: dashboard, container: container))
    }

    var body: some View {
        Group {
            switch design {
            case .sheet: SheetHome(model: model)
            case .float: FloatHome(model: model)
            case .hero: HeroHome(model: model)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        .overlay(alignment: .trailing) { HomeDesignSwitcher(current: design.rawValue).padding(.trailing, 4).offset(y: 40) }
    }
}

// MARK: - Switcher

/// Test builds: flip between the directions, and today's Home.
struct HomeDesignSwitcher: View {
    let current: String
    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(spacing: 2) {
            ForEach(HomeDesign.allCases.map(\.rawValue) + ["Now"], id: \.self) { option in
                Button {
                    feedback?.play(.tap)
                    UserDefaults.standard.set(option, forKey: HomeDesign.key)
                    NotificationCenter.default.post(name: HomeDesignSwitcher.changed, object: nil)
                } label: {
                    Text(option)
                        .font(DS.Typography.brand(.caption, weight: .bold))
                        .foregroundStyle(current == option ? DS.Colors.textOnBrand : DS.Colors.textPrimary)
                        .frame(minWidth: 30, minHeight: 26)
                        .background(Capsule().fill(current == option ? DS.Colors.brand : .clear))
                }
                .buttonStyle(SquishStyle(scale: 0.9))
            }
        }
        .padding(3)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    static let changed = Notification.Name("HomeDesignChanged")
}

// MARK: - Shared

/// The way to everything that isn't on the page.
struct HomeBar: View {
    let model: HomeStudioModel
    var ink: Color = DS.Colors.textPrimary
    var showsGreeting = true
    /// Over a picture: the greeting gets its own glass.
    var onGlass = false
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: 10) {
            if showsGreeting {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(DS.Typography.brand(.footnote))
                        .opacity(0.8)
                    Text(model.dashboard.greeting)
                        .font(DS.Typography.brand(.title2, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(ink)
                .padding(.horizontal, onGlass ? 14 : 0)
                .padding(.vertical, onGlass ? 6 : 0)
                .glassEffect(onGlass ? .regular : .identity, in: .rect(cornerRadius: 20))
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Menu {
                    Button("New property", systemImage: AppSymbol.properties.rawValue) { router.present(.newProperty) }
                    Button("New request", systemImage: AppSymbol.maintenance.rawValue) { router.present(.newMaintenanceRequest) }
                    Button("Ask Copilot", systemImage: AppSymbol.assistant.rawValue) { router.push(.assistant) }
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
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(DS.Colors.textPrimary)
            .frame(width: 42, height: 44)
    }
}
#endif
