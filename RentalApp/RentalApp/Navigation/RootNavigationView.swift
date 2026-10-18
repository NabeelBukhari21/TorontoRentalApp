//
//  RootNavigationView.swift
//  RentalApp (Purrperty)
//
//  Navigation — The main app shell, built entirely from system containers:
//
//  • `TabView` with the `Tab` API. On iPhone it's the Liquid Glass tab
//    bar, which minimises as you scroll down; with `.sidebarAdaptable`
//    the same tabs become a sidebar on iPad, so there's no custom
//    sidebar or split layout to maintain.
//  • Search is a dedicated tab (`role: .search`) that the system sets
//    apart at the trailing end of the tab bar.
//  • Each tab owns a `NavigationStack` driven by the shared router, so
//    deep links and restored state land in the right stack.
//  • Sheets and full-screen covers are native presentations.
//

import SwiftUI

struct RootNavigationView: View {

    /// The app-wide router — carries restored state and deep-link targets.
    @State private var router = AppRouter.shared

    /// Injected by `RootNavigation` at runtime. Read optionally so that
    /// previews of this shell — and of any screen inside it — work
    /// standalone instead of trapping on a missing environment value.
    @Environment(SessionViewModel.self) private var providedSession: SessionViewModel?

    var body: some View {
        TabView(selection: tabSelection) {
            Tab(AppTab.dashboard.title, systemImage: AppTab.dashboard.icon, value: AppTab.dashboard) {
                stack(for: .dashboard)
            }
            Tab(AppTab.properties.title, systemImage: AppTab.properties.icon, value: AppTab.properties) {
                stack(for: .properties)
            }
            Tab(AppTab.maintenance.title, systemImage: AppTab.maintenance.icon, value: AppTab.maintenance) {
                stack(for: .maintenance)
            }
            Tab(AppTab.messages.title, systemImage: AppTab.messages.icon, value: AppTab.messages) {
                stack(for: .messages)
            }
            Tab(value: AppTab.search, role: .search) {
                stack(for: .search)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: $router.activeSheet) { route in
            SheetRouteView(route: route)
        }
        .fullScreenCover(item: $router.activeFullScreen) { route in
            FullScreenRouteView(route: route)
        }
        .environment(router)
        .environment(providedSession ?? PreviewSession.shared)
        // The colour scheme is applied once, at `RootNavigation`, so that
        // onboarding and auth follow the Appearance setting too.
    }

    /// Re-selecting the current tab pops it to its root, as in every
    /// system app. Routed through `AppRouter.select(_:)` so that rule
    /// lives in one place.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { router.select($0) }
        )
    }

    private func stack(for tab: AppTab) -> some View {
        NavigationStack(path: router.pathBinding(for: tab)) {
            TabRootView(tab: tab)
                .navigationDestination(for: AppRoute.self) { route in
                    RouteDestinationView(route: route)
                }
        }
    }
}

// MARK: - Preview Session

/// Stand-in session for previews. `static let` so it is only built when
/// something actually asks for it — the real app always injects its own
/// and never touches this.
@MainActor
private enum PreviewSession {
    static let shared: SessionViewModel = {
        let container = AppContainer.preview
        return SessionViewModel(
            auth: container.auth,
            store: container.sessionStore,
            analytics: container.analytics,
            onboarding: container.onboardingProfile
        )
    }()
}

// MARK: - Previews

#Preview("Root Navigation") {
    RootNavigationView()
}
