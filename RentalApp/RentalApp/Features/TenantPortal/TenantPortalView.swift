//
//  TenantPortalView.swift
//  RentalApp (Purrperty)
//
//  Tenant Portal — The app a tenant signs in to: their home, their
//  requests, their rent account and their landlord. Nothing from the
//  management app is reachable from here.
//

import SwiftUI

struct TenantPortalView: View {

    enum PortalTab: Hashable {
        case home, requests, payments, messages
    }

    @State private var viewModel: TenantPortalViewModel
    @State private var selectedTab: PortalTab = .home
    @State private var isReportingProblem = false

    @Environment(SessionViewModel.self) private var sessionModel
    @Environment(\.container) private var container

    init(session: AuthSession, container: AppContainer) {
        _viewModel = State(initialValue: TenantPortalViewModel(
            session: session,
            portal: container.tenantPortal,
            tenants: container.tenants,
            payments: container.payments,
            maintenance: container.maintenance
        ))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.groupedBackground)
            case .notLinked:
                NavigationStack { notLinked }
            case .failed(let message):
                NavigationStack {
                    ContentUnavailableView {
                        Label("Couldn't Load Your Home", symbol: .caution)
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { Task { await viewModel.load() } }
                    }
                    .toolbar { accountMenu }
                }
            case .ready:
                tabs
            }
        }
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .maintenanceRequests) { await viewModel.load() }
        }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .leases) { await viewModel.load() }
        }
        .sheet(isPresented: $isReportingProblem) {
            if let location = viewModel.requestLocation {
                NewMaintenanceRequestView(container: container, fixedLocation: location)
            }
        }
    }

    // MARK: Tabs

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: AppSymbol.home.rawValue, value: .home) {
                NavigationStack {
                    TenantHomeView(viewModel: viewModel, selectedTab: $selectedTab, onReportProblem: reportProblem)
                        .toolbar { accountMenu }
                }
            }
            Tab("Requests", systemImage: AppSymbol.maintenance.rawValue, value: .requests) {
                NavigationStack {
                    TenantRequestsView(viewModel: viewModel, onReportProblem: reportProblem)
                }
            }
            Tab("Payments", systemImage: AppSymbol.rent.rawValue, value: .payments) {
                NavigationStack {
                    TenantPaymentsView(viewModel: viewModel)
                }
            }
            Tab("Messages", systemImage: AppSymbol.messages.rawValue, value: .messages) {
                NavigationStack {
                    TenantMessagesView(viewModel: viewModel)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private func reportProblem() {
        isReportingProblem = true
    }

    // MARK: Not Linked

    private var notLinked: some View {
        ContentUnavailableView {
            Label("Waiting for Your Landlord", systemImage: "house.lodge")
        } description: {
            Text("Your account isn't linked to a rental yet. Ask your landlord or property manager to invite \(viewModel.session.email) from Purrperty, and your lease, rent and requests will appear here.")
        }
        .navigationTitle("Purrperty")
        .toolbar { accountMenu }
    }

    // MARK: Account

    @ToolbarContentBuilder
    private var accountMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Account", systemImage: AppSymbol.person.rawValue) {
                Section(viewModel.session.email) {
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await sessionModel.signOut() }
                    }
                }
            }
        }
    }
}
