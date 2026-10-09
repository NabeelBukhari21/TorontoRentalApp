//
//  RootNavigationView.swift
//  RentalApp (RentOS)
//
//  Navigation — MainTabNavigation: the main app shell. Adapts to the
//  environment:
//  • Compact width (iPhone): floating glass tab bar + per-tab NavigationStacks.
//  • Regular width (iPad): NavigationSplitView with sidebar.
//  Also hosts the global bottom-sheet and full-screen presentation layers.
//
//  Uses the shared router so deep links and restored state land here.
//

import SwiftUI

struct RootNavigationView: View {

    /// The app-wide router — carries restored state and deep-link targets.
    @State private var router = AppRouter.shared
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.container) private var container

    /// Injected by `RootNavigation` at runtime. Read optionally so that
    /// previews of this shell — and of any screen inside it — work
    /// standalone instead of trapping on a missing environment value.
    @Environment(SessionViewModel.self) private var providedSession: SessionViewModel?

    var body: some View {
        Group {
            if sizeClass == .regular {
                SidebarSplitLayout(router: router)
            } else {
                CompactTabLayout(router: router)
            }
        }
        .sheet(item: $router.activeSheet) { route in
            DSSheetContainer(route: route)
        }
        .fullScreenCover(item: $router.activeFullScreen) { route in
            DSFullScreenContainer(route: route)
        }
        .environment(router)
        .environment(providedSession ?? PreviewSession.shared)
        // The colour scheme is applied once, at `RootNavigation`, so that
        // splash, onboarding and auth follow the Appearance setting too.
        // Applying it here as well would give the window two competing
        // preferences.
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
            analytics: container.analytics
        )
    }()
}

// MARK: - Compact Layout (iPhone)

private struct CompactTabLayout: View {

    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.pathBinding(for: tab)) {
                    TabRootView(tab: tab)
                        .navigationDestination(for: AppRoute.self) { route in
                            RouteDestinationView(route: route)
                        }
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(tab)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            DSTabBar(
                selectedTab: $router.selectedTab,
                onReselect: { router.popToRoot(in: $0) }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Split Layout (iPad)

private struct SidebarSplitLayout: View {

    @Bindable var router: AppRouter

    var body: some View {
        NavigationSplitView {
            DSSidebar(router: router)
        } detail: {
            NavigationStack(path: router.pathBinding(for: router.selectedTab)) {
                TabRootView(tab: router.selectedTab)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteDestinationView(route: route)
                    }
            }
            // New identity per tab so each section keeps an independent stack.
            .id(router.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Previews

#Preview("Root Navigation") {
    RootNavigationView()
}
