//
//  DeepLink.swift
//  RentalApp (RentOS)
//
//  Navigation — Deep link builders and the URL scheme contract.
//
//  ONE-TIME XCODE SETUP (required for links to reach the app):
//  Target → Info → URL Types → + → URL Schemes: `rentos`
//  Identifier: your bundle id. Nothing else is needed —
//  `RootNavigation.onOpenURL` already forwards to `AppRouter.open(_:)`.
//
//  Test from Terminal with the simulator running:
//      xcrun simctl openurl booted "rentos://maintenance/t-leak-304"
//

import Foundation

enum DeepLink {

    static let scheme = "rentos"

    // MARK: Builders

    /// rentos://properties/<id>
    static func property(_ id: String) -> URL? {
        url(host: PropertyNavigation.deepLinkHost, path: [id])
    }

    /// rentos://tenants/<id>
    static func tenant(_ id: String) -> URL? {
        url(host: TenantNavigation.deepLinkHost, path: [id])
    }

    /// rentos://maintenance/<id>
    static func maintenanceTicket(_ id: String) -> URL? {
        url(host: MaintenanceNavigation.deepLinkHost, path: [id])
    }

    /// rentos://messages/<id>
    static func conversation(_ id: String) -> URL? {
        url(host: MessagesNavigation.deepLinkHost, path: [id])
    }

    /// rentos://documents
    static var documents: URL? {
        url(host: DocumentNavigation.deepLinkHost)
    }

    /// rentos://notifications
    static var notifications: URL? {
        url(host: "notifications")
    }

    /// rentos://settings/<section>
    static func settings(_ section: SettingsSection? = nil) -> URL? {
        url(
            host: SettingsNavigation.deepLinkHost,
            path: section.map { [$0.rawValue] } ?? []
        )
    }

    /// rentos://<tab>
    static func tab(_ tab: AppTab) -> URL? {
        switch tab {
        case .dashboard: url(host: "dashboard")
        case .properties: url(host: PropertyNavigation.deepLinkHost)
        case .maintenance: url(host: MaintenanceNavigation.deepLinkHost)
        case .messages: url(host: MessagesNavigation.deepLinkHost)
        case .aiAssistant: url(host: "copilot")
        }
    }

    // MARK: Helper

    private static func url(host: String, path: [String] = []) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if !path.isEmpty {
            components.path = "/" + path.joined(separator: "/")
        }
        return components.url
    }
}
