//
//  DashboardViewModel.swift
//  RentalApp (Purrperty)
//
//  Dashboard — Command-centre view model.
//
//  The whole screen loads from one snapshot call. Eight independent
//  requests would make the dashboard flash through eight separate
//  loading states on every appearance.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class DashboardViewModel {

    private let dashboard: DashboardRepositoryProtocol
    private let notifications: NotificationRepositoryProtocol

    private(set) var state: LoadState<DashboardSnapshot> = .idle
    private(set) var isRefreshing = false
    private(set) var unreadNotifications = 0
    private(set) var streak = RentStreak.none
    private(set) var weather: Weather?
    /// Outfits just earned, to announce once.
    private(set) var newOutfits: [PurrOutfit] = []
    let wardrobe: WardrobeStore
    private let payments: PaymentRepositoryProtocol
    private let weatherService: WeatherServiceProtocol
    private let preferences: PreferencesRepositoryProtocol

    init(
        dashboard: DashboardRepositoryProtocol,
        notifications: NotificationRepositoryProtocol,
        payments: PaymentRepositoryProtocol,
        weather: WeatherServiceProtocol,
        wardrobe: WardrobeStore,
        preferences: PreferencesRepositoryProtocol
    ) {
        self.payments = payments
        self.weatherService = weather
        self.wardrobe = wardrobe
        self.preferences = preferences
        self.dashboard = dashboard
        self.notifications = notifications
    }

    // MARK: Derived

    private var snapshot: DashboardSnapshot? { state.value }

    var isLoading: Bool { state.isLoading }
    var error: AppError? { state.error }

    var portfolioValue: String { snapshot?.portfolio.portfolioValue ?? "—" }
    var monthlyRevenue: Double { snapshot?.portfolio.monthlyRevenue ?? 0 }
    var revenueTrend: String { snapshot?.portfolio.revenueTrend ?? "" }
    var propertyCount: Int { snapshot?.portfolio.propertyCount ?? 0 }
    var unitCount: Int { snapshot?.portfolio.unitCount ?? 0 }
    var occupancyRate: Double { snapshot?.portfolio.occupancyRate ?? 0 }
    var occupiedUnits: Int { snapshot?.portfolio.occupiedUnits ?? 0 }
    var vacantUnits: Int { snapshot?.portfolio.vacantUnits ?? 0 }
    var turnoverUnits: Int { snapshot?.portfolio.turnoverUnits ?? 0 }

    var revenue: [RevenuePoint] { snapshot?.revenue ?? [] }
    var stats: [DashboardStat] { snapshot?.stats ?? [] }
    var insights: [AIInsight] { snapshot?.insights ?? [] }
    var maintenanceCounts: [MaintenanceStatusCount] { snapshot?.maintenanceCounts ?? [] }
    var activity: [ActivityItem] { snapshot?.activity ?? [] }
    var tasks: [UpcomingTask] { snapshot?.tasks ?? [] }

    var openRequestCount: Int {
        maintenanceCounts.filter { $0.kind != .success }.reduce(0) { $0 + $1.count }
    }

    /// Time-aware greeting shown in the header.
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = snapshot?.portfolio.greetingName ?? "there"
        switch hour {
        case 5..<12: return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        default: return "Good evening, \(name)"
        }
    }

    // MARK: Lifecycle

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        await fetch(forceRefresh: false)
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await fetch(forceRefresh: true)
    }

    func retry() async {
        state = .idle
        state = .loading
        await fetch(forceRefresh: true)
    }

    // MARK: Scene

    /// The sky, the streak and the wardrobe. After the numbers: none of it
    /// may hold them up.
    func loadExtras() async {
        weather = preferences.showsWeather ? await weatherService.current() : nil
    }

    private func updateMilestones() async {
        streak = await RentStreak.load(from: payments)
        let month = try? await payments.rentRoll(for: .now, forceRefresh: false)
        newOutfits = wardrobe.update(with: WardrobeFacts(
            properties: propertyCount,
            units: unitCount,
            rentedUnits: occupiedUnits,
            openRequests: openRequestCount,
            hasRequests: maintenanceCounts.contains { $0.count > 0 },
            isMonthCollected: month.map { $0.expected > 0 && $0.collected >= $0.expected } ?? false,
            streak: streak.count
        ))
    }

    func announcedOutfits() { newOutfits = [] }

    // MARK: Intents

    func toggleTask(_ task: UpcomingTask) async {
        try? await dashboard.toggleTask(task.id)
        await fetch(forceRefresh: false)
    }

    private func fetch(forceRefresh: Bool) async {
        do {
            state = .loaded(try await dashboard.snapshot(forceRefresh: forceRefresh))
            unreadNotifications = (try? await notifications.unreadCount()) ?? 0
            await updateMilestones()
        } catch is CancellationError {
            // The view went away mid-load (e.g. the app reopened onto a
            // screen pushed over Home). Without a value to show, go back
            // to idle so the next appearance loads again instead of
            // showing the skeleton forever.
            if case .loading = state { state = .idle }
        } catch {
            state = .failed(error as? AppError ?? .unknown)
        }
    }
}
