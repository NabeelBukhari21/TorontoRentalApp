//
//  NavigationModules.swift
//  RentalApp (RentOS)
//
//  Navigation — Domain navigation modules.
//  Each module owns its slice of the route space: which pushed routes
//  it renders, and how its deep-link paths resolve to a tab + stack.
//  `RouteDestinationView` dispatches to these; `AppRouter.open(_:)`
//  parses rentos:// URLs through them.
//
//  Adding a feature = add a case to AppRoute + one module. Nothing
//  else in the navigation layer changes.
//

import SwiftUI

// MARK: - Property Navigation

enum PropertyNavigation {

    static let deepLinkHost = "properties"

    @MainActor
    @ViewBuilder
    static func destination(for route: AppRoute) -> some View {
        switch route {
        case .propertyDetail(let propertyID):
            PropertyDetailView(propertyID: propertyID)
        case .units, .unitDetail:
            NavigationComingSoonView(route: route)
        default:
            EmptyView()
        }
    }

    /// properties → list · properties/<id> → detail
    static func resolve(_ path: [String]) -> (tab: AppTab, stack: [AppRoute])? {
        path.isEmpty
            ? (.properties, [])
            : (.properties, [.propertyDetail(propertyID: path[0])])
    }
}

// MARK: - Tenant Navigation

enum TenantNavigation {

    static let deepLinkHost = "tenants"

    @MainActor
    @ViewBuilder
    static func destination(for route: AppRoute) -> some View {
        switch route {
        case .tenants:
            TenantListView()
        case .tenantDetail(let tenantID):
            TenantDetailView(tenantID: tenantID)
        default:
            EmptyView()
        }
    }

    /// tenants → directory · tenants/<id> → profile
    static func resolve(_ path: [String]) -> (tab: AppTab, stack: [AppRoute])? {
        path.isEmpty
            ? (.properties, [.tenants])
            : (.properties, [.tenants, .tenantDetail(tenantID: path[0])])
    }
}

// MARK: - Maintenance Navigation

enum MaintenanceNavigation {

    static let deepLinkHost = "maintenance"

    @MainActor
    @ViewBuilder
    static func destination(for route: AppRoute) -> some View {
        switch route {
        case .maintenanceDetail(let requestID):
            MaintenanceDetailView(ticketID: requestID)
        default:
            EmptyView()
        }
    }

    /// maintenance → inbox · maintenance/<id> → ticket
    static func resolve(_ path: [String]) -> (tab: AppTab, stack: [AppRoute])? {
        path.isEmpty
            ? (.maintenance, [])
            : (.maintenance, [.maintenanceDetail(requestID: path[0])])
    }
}

// MARK: - Messages Navigation

enum MessagesNavigation {

    static let deepLinkHost = "messages"

    @MainActor
    @ViewBuilder
    static func destination(for route: AppRoute) -> some View {
        switch route {
        case .conversation(let conversationID):
            ChatView(conversationID: conversationID)
        default:
            EmptyView()
        }
    }

    /// messages → list · messages/<id> → thread
    static func resolve(_ path: [String]) -> (tab: AppTab, stack: [AppRoute])? {
        path.isEmpty
            ? (.messages, [])
            : (.messages, [.conversation(conversationID: path[0])])
    }
}

// MARK: - Document Navigation

enum DocumentNavigation {

    static let deepLinkHost = "documents"

    @MainActor
    @ViewBuilder
    static func destination(for route: AppRoute) -> some View {
        switch route {
        case .documents:
            DocumentCenterView()
        default:
            EmptyView()
        }
    }

    /// documents → document center (lives off the dashboard stack)
    static func resolve(_ path: [String]) -> (tab: AppTab, stack: [AppRoute])? {
        (.dashboard, [.documents])
    }
}

// MARK: - Settings Navigation

enum SettingsNavigation {

    static let deepLinkHost = "settings"

    @MainActor
    @ViewBuilder
    static func destination(for route: AppRoute) -> some View {
        switch route {
        case .settings:
            SettingsHubView()
        case .settingsSection(let section):
            SettingsSectionView(section: section)
        case .profile:
            SettingsSectionView(section: .profile)
        case .notifications:
            NotificationsView()
        default:
            EmptyView()
        }
    }

    /// settings → hub · settings/<section> → page
    static func resolve(_ path: [String]) -> (tab: AppTab, stack: [AppRoute])? {
        if let raw = path.first, let section = SettingsSection(rawValue: raw) {
            return (.dashboard, [.settings, .settingsSection(section: section)])
        }
        return (.dashboard, [.settings])
    }
}

// MARK: - Coming Soon

/// Refined landing for destinations shipping in the next release.
struct NavigationComingSoonView: View {

    let route: AppRoute

    var body: some View {
        ZStack {
            DSAmbientBackground()

            VStack {
                Spacer()

                DSEmptyState(
                    icon: route.icon,
                    title: route.title,
                    message: "Unit-level views arrive in the next release. Units are visible today inside each property's detail page."
                )

                Spacer()
            }
        }
        .dsHeader(title: route.title, showsBack: true)
    }
}
