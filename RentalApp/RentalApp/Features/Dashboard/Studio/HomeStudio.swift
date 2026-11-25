//
//  HomeStudio.swift
//  RentalApp (Purrperty)
//
//  Dashboard — Five directions for Home, side by side, on real data. DEBUG
//  builds only, until one is chosen:
//
//      -PurrpertyStartAt home -PurrpertyHome A|B|C|D|E
//

#if DEBUG
import MapKit
import SwiftUI

enum HomeDesign: String, CaseIterable {
    case place = "A", tower = "B", city = "C", deck = "D", paw = "E"

    static var requested: HomeDesign? {
        UserDefaults.standard.string(forKey: "PurrpertyHome").flatMap(HomeDesign.init(rawValue:))
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
    }

    /// Where each property is, for the map.
    func locate() async {
        for property in properties where places[property.id] == nil {
            // The street, or failing that the neighbourhood.
            for query in ["\(property.address), Toronto, ON", "\(property.neighborhood), Toronto, ON"] {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.region = MKCoordinateRegion(center: .init(latitude: 43.66, longitude: -79.39), latitudinalMeters: 40000, longitudinalMeters: 40000)
                do {
                    let found = try await MKLocalSearch(request: request).start().mapItems.first?.location.coordinate
                    if let found, abs(found.latitude - 43.7) < 0.3, abs(found.longitude + 79.4) < 0.4 {
                        withAnimation(DS.Motion.bouncy) { places[property.id] = found }
                        break
                    }
                } catch { continue }
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
            case .place: PlaceHome(model: model)
            case .tower: TowerHome(model: model)
            case .city: CityHome(model: model)
            case .deck: DeckHome(model: model)
            case .paw: PawHome(model: model)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
    }
}

// MARK: - Shared

/// The way to everything that isn't on the page.
struct HomeBar: View {
    let model: HomeStudioModel
    var ink: Color = DS.Colors.textPrimary
    var showsGreeting = true
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
