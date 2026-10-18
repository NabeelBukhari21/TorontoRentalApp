//
//  PresentationViews.swift
//  RentalApp (Purrperty)
//
//  Navigation — What each sheet and full-screen route shows.
//
//  Native presentations only: system sheet material, detents and grabber,
//  a `NavigationStack` so every sheet gets a real navigation bar, and
//  Cancel/Done in the standard placements. Feature forms that already
//  bring their own stack (the property form) are shown as they are.
//

import SwiftUI

// MARK: - Sheets

struct SheetRouteView: View {

    let route: DSSheetRoute

    @Environment(\.container) private var container

    var body: some View {
        content
            .presentationDetents(route.detents)
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .globalSearch:
            // Normally unreachable — the router turns this into the Search
            // tab — but a sheet still has to show something sensible.
            NavigationStack {
                GlobalSearchView(container: container)
            }
        case .newProperty:
            PropertyFormView(mode: .create, container: container)
        case .newTenant:
            CreateTenantView(container: container)
        case .quickActions, .newMaintenanceRequest, .filters:
            ComingSoonSheet(route: route)
        }
    }
}

/// A destination that's reserved but not built yet. Says so plainly and
/// offers the one action that makes sense: closing it.
private struct ComingSoonSheet: View {

    let route: DSSheetRoute

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(route.title, symbol: symbol)
            } description: {
                Text("This is coming in a future update.")
            }
            .navigationTitle(route.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: AppSymbol.done.rawValue) { dismiss() }
                }
            }
        }
    }

    private var symbol: AppSymbol {
        switch route {
        case .globalSearch: .search
        case .quickActions: .rent
        case .newProperty: .properties
        case .newMaintenanceRequest: .maintenance
        case .newTenant: .invite
        case .filters: .filter
        }
    }
}

// MARK: - Full-Screen Covers

struct FullScreenRouteView: View {

    let route: DSFullScreenRoute

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(route.title, systemImage: symbol)
            } description: {
                Text("This is coming in a future update.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: AppSymbol.close.rawValue) { dismiss() }
                }
            }
        }
    }

    private var symbol: String {
        switch route {
        case .onboarding: AppSymbol.assistant.rawValue
        case .authentication: "lock.shield"
        case .photoViewer: AppSymbol.photo.rawValue
        }
    }
}
