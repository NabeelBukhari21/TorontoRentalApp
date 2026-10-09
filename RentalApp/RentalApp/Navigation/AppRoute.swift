//
//  AppRoute.swift
//  RentalApp
//
//  Navigation — Single source of truth for every destination in the app.
//  Tabs, push routes, bottom sheets, and full-screen covers are all
//  modeled as values so navigation stays data-driven and testable.
//

import SwiftUI

// MARK: - Tabs

/// Top-level sections shown in the tab bar (iPhone) and sidebar (iPad).
enum AppTab: String, CaseIterable, Identifiable, Hashable, Codable {
    case dashboard
    case properties
    case maintenance
    case messages
    case aiAssistant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Home"
        case .properties: "Properties"
        case .maintenance: "Maintenance"
        case .messages: "Messages"
        case .aiAssistant: "AI"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: DS.Icons.dashboard
        case .properties: DS.Icons.properties
        case .maintenance: DS.Icons.maintenance
        case .messages: DS.Icons.messages
        case .aiAssistant: DS.Icons.ai
        }
    }
}

// MARK: - Push Routes

/// Destinations pushed onto a `NavigationStack`.
/// Associated values carry only identifiers — views resolve their own data later.
/// `Codable` so navigation state survives relaunch and deep links round-trip.
enum AppRoute: Hashable, Codable {
    case propertyDetail(propertyID: String)
    case units(propertyID: String)
    case unitDetail(unitID: String)
    case tenants
    case tenantDetail(tenantID: String)
    case maintenanceDetail(requestID: String)
    case conversation(conversationID: String)
    case documents
    case notifications
    case profile
    case settings
    case settingsSection(section: SettingsSection)

    var title: String {
        switch self {
        case .propertyDetail: "Property Details"
        case .units: "Units"
        case .unitDetail: "Unit"
        case .tenants: "Tenants"
        case .tenantDetail: "Tenant"
        case .maintenanceDetail: "Request"
        case .conversation: "Conversation"
        case .documents: "Documents"
        case .notifications: "Notifications"
        case .profile: "Profile"
        case .settings: "Settings"
        case .settingsSection(let section): section.title
        }
    }

    var icon: String {
        switch self {
        case .propertyDetail: DS.Icons.properties
        case .units, .unitDetail: DS.Icons.unit
        case .tenants: DS.Icons.tenants
        case .tenantDetail: DS.Icons.tenant
        case .maintenanceDetail: DS.Icons.maintenance
        case .conversation: DS.Icons.messages
        case .documents: DS.Icons.documents
        case .notifications: DS.Icons.notifications
        case .profile: DS.Icons.tenant
        case .settings: DS.Icons.settings
        case .settingsSection(let section): section.icon
        }
    }
}

// MARK: - Bottom Sheets

/// Modals presented as bottom sheets with detents.
enum DSSheetRoute: Identifiable, Hashable {
    case globalSearch
    case quickActions
    case newProperty
    case newMaintenanceRequest
    case newTenant
    case filters

    var id: String {
        switch self {
        case .globalSearch: "globalSearch"
        case .quickActions: "quickActions"
        case .newProperty: "newProperty"
        case .newMaintenanceRequest: "newMaintenanceRequest"
        case .newTenant: "newTenant"
        case .filters: "filters"
        }
    }

    var title: String {
        switch self {
        case .globalSearch: "Search"
        case .quickActions: "Quick Actions"
        case .newProperty: "New Property"
        case .newMaintenanceRequest: "New Request"
        case .newTenant: "New Tenant"
        case .filters: "Filters"
        }
    }

    /// Preferred sheet heights per modal.
    var detents: Set<PresentationDetent> {
        switch self {
        // Large only: a half-height search sheet shows three results and
        // hides the keyboard behind the fold.
        case .globalSearch: [.large]
        case .quickActions: [.height(340)]
        case .newProperty: [.medium, .large]
        case .newMaintenanceRequest: [.large]
        case .newTenant: [.large]
        case .filters: [.medium]
        }
    }
}

// MARK: - Full-Screen Covers

/// Immersive flows presented over the entire app.
enum DSFullScreenRoute: Identifiable, Hashable {
    case onboarding
    case authentication
    case photoViewer(photoID: String)

    var id: String {
        switch self {
        case .onboarding: "onboarding"
        case .authentication: "authentication"
        case .photoViewer(let photoID): "photoViewer-\(photoID)"
        }
    }

    var title: String {
        switch self {
        case .onboarding: "Onboarding"
        case .authentication: "Sign In"
        case .photoViewer: "Photo"
        }
    }
}
