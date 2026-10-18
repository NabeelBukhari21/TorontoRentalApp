//
//  DashboardView.swift
//  RentalApp
//
//  Dashboard — The AI-powered command center. Composes the hero chart,
//  stat grid, quick actions, AI insights, occupancy & maintenance
//  overviews, tasks, and live activity — all entering with a cascade.
//

import SwiftUI

struct DashboardView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.container) private var container
    @State private var viewModel: DashboardViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: DashboardViewModel(
            dashboard: container.dashboard,
            notifications: container.notifications
        ))
    }

    private let statColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {

                    // The mascot's brief: the one thing that matters most
                    // right now, in a sentence.
                    if !viewModel.isLoading {
                        DashboardMascotBrief(
                            urgentTasks: viewModel.tasks.filter { $0.isUrgent && !$0.isDone }.count,
                            openRequests: viewModel.openRequestCount,
                            openTasks: viewModel.tasks.filter { !$0.isDone }.count,
                            occupancyRate: viewModel.occupancyRate
                        )
                        .dsEntrance(index: 0)
                    }

                    // Hero analytics.
                    DashboardHeroCard(
                        portfolioValue: viewModel.portfolioValue,
                        monthlyRevenue: viewModel.monthlyRevenue,
                        revenueTrend: viewModel.revenueTrend,
                        propertyCount: viewModel.propertyCount,
                        unitCount: viewModel.unitCount,
                        revenue: viewModel.revenue
                    )
                    .dsEntrance(index: 0)

                    // Stats grid.
                    LazyVGrid(columns: statColumns, spacing: DS.Spacing.md) {
                        ForEach(Array(viewModel.stats.enumerated()), id: \.element.id) { index, stat in
                            DSStatCard(
                                title: stat.title,
                                value: stat.value,
                                icon: stat.icon,
                                iconGradient: stat.gradient,
                                trend: stat.trend,
                                trendKind: stat.trendKind
                            )
                            .dsEntrance(index: 1 + index)
                        }
                    }

                    // Quick actions.
                    DashboardQuickActionsRow(actions: quickActions)
                        .padding(.vertical, DS.Spacing.sm)
                        .dsEntrance(index: 5)

                    // AI insights.
                    DashboardAIInsightsCard(insights: viewModel.insights) { _ in
                        router.push(.assistant)
                    }
                    .dsEntrance(index: 6)

                    // Occupancy.
                    DashboardOccupancyCard(
                        rate: viewModel.occupancyRate,
                        occupied: viewModel.occupiedUnits,
                        vacant: viewModel.vacantUnits,
                        turnover: viewModel.turnoverUnits
                    )
                    .dsEntrance(index: 7)

                    // Maintenance.
                    DashboardMaintenanceCard(counts: viewModel.maintenanceCounts) {
                        router.select(.maintenance)
                    }
                    .dsEntrance(index: 8)

                    // Upcoming tasks.
                    DashboardTasksCard(tasks: viewModel.tasks) { task in
                        Task { await viewModel.toggleTask(task) }
                    }
                    .dsEntrance(index: 9)

                    // Live activity.
                    DashboardActivityCard(items: viewModel.activity) {
                        router.push(.notifications)
                    }
                    .dsEntrance(index: 10)

                    if let error = viewModel.error {
                        DSErrorView(error: error) { await viewModel.retry() }
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .refreshable { await viewModel.refresh() }

            if viewModel.isLoading {
                VStack(spacing: DS.Spacing.lg) {
                    // The cat at its laptop while the portfolio loads.
                    MascotGuide(
                        mood: .working,
                        message: "Fetching your portfolio…",
                        mascotSize: 100
                    )
                    DSCardSkeleton(cards: 3)
                }
                .padding(DS.Spacing.lg)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(DSAmbientBackground())
            }
        }
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .properties) {
                await viewModel.refresh()
            }
        }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .maintenanceRequests) {
                await viewModel.refresh()
            }
        }
        .navigationTitle("Home")
        .navigationSubtitle(viewModel.greeting)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Copilot", systemImage: AppSymbol.assistant.rawValue) {
                    router.push(.assistant)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Notifications", systemImage: AppSymbol.notifications.rawValue) {
                    router.push(.notifications)
                }
                .badge(viewModel.unreadNotifications)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Profile", systemImage: AppSymbol.person.rawValue) {
                    router.push(.profile)
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu("New", systemImage: AppSymbol.add.rawValue) {
                    Button("New property", systemImage: AppSymbol.properties.rawValue) {
                        router.present(.newProperty)
                    }
                    Button("New maintenance request", systemImage: AppSymbol.maintenance.rawValue) {
                        router.present(.newMaintenanceRequest)
                    }
                    Button("New message", systemImage: AppSymbol.messages.rawValue) {
                        router.select(.messages)
                    }
                }
            }
        }
    }

    // MARK: Quick Actions

    private var quickActions: [DashboardQuickAction] {
        [
            DashboardQuickAction(
                icon: DS.Icons.add,
                title: "Property",
                gradient: DS.Gradients.brand
            ) { router.present(.newProperty) },

            DashboardQuickAction(
                icon: DS.Icons.maintenance,
                title: "Request",
                gradient: DS.Gradients.warm,
                iconForeground: DS.Colors.textOnAccent
            ) { router.present(.newMaintenanceRequest) },

            DashboardQuickAction(
                icon: DS.Icons.messages,
                title: "Message",
                gradient: DS.Gradients.ai
            ) { router.select(.messages) },

            DashboardQuickAction(
                icon: DS.Icons.payment,
                title: "Collect",
                gradient: DS.Gradients.success,
                iconForeground: DS.Colors.textOnAccent
            ) { router.present(.quickActions) }
        ]
    }
}

// MARK: - Previews

#Preview("Dashboard") {
    RootNavigationView()
}
