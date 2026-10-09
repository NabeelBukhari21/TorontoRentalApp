//
//  RouteDestinationView.swift
//  RentalApp (RentOS)
//
//  Navigation — Thin dispatchers. Tabs map to feature roots;
//  pushed routes delegate to their domain navigation module.
//

import SwiftUI

// MARK: - Tab Roots

struct TabRootView: View {

    let tab: AppTab

    var body: some View {
        switch tab {
        case .dashboard:
            DashboardView()
        case .properties:
            PropertyListView()
        case .maintenance:
            MaintenanceInboxView()
        case .messages:
            ConversationListView()
        case .aiAssistant:
            AIAssistantView()
        }
    }
}

// MARK: - Pushed Destinations

struct RouteDestinationView: View {

    let route: AppRoute

    var body: some View {
        switch route {
        case .propertyDetail, .units, .unitDetail:
            PropertyNavigation.destination(for: route)
        case .tenants, .tenantDetail:
            TenantNavigation.destination(for: route)
        case .maintenanceDetail:
            MaintenanceNavigation.destination(for: route)
        case .conversation:
            MessagesNavigation.destination(for: route)
        case .documents:
            DocumentNavigation.destination(for: route)
        case .notifications, .profile, .settings, .settingsSection:
            SettingsNavigation.destination(for: route)
        }
    }
}
