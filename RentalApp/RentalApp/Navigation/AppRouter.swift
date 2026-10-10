//
//  AppRouter.swift
//  RentalApp (Purrperty)
//
//  Navigation — Observable router owning all navigation state:
//  selected tab, one navigation path per tab, and presentation state
//  for bottom sheets and full-screen covers.
//
//  Production duties:
//  • State restoration — tab + stacks persist across relaunches.
//  • Deep linking — `open(_:)` resolves rentos:// URLs via the
//    domain navigation modules.
//
//  Inject once at the root with `.environment(router)` and read anywhere
//  with `@Environment(AppRouter.self)`.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class AppRouter {

    /// The app-wide router. Views receive it via the environment;
    /// deep links and scene events reach it here.
    static let shared = AppRouter(restoresState: true)

    // MARK: State

    /// Currently selected top-level section.
    var selectedTab: AppTab = .dashboard {
        didSet { persist() }
    }

    /// Independent navigation path per tab, so each tab keeps its own stack.
    var paths: [AppTab: [AppRoute]] = [:] {
        didSet { persist() }
    }

    /// Currently presented bottom sheet, if any. (Not persisted — modals
    /// should never reappear on relaunch.)
    var activeSheet: DSSheetRoute?

    /// Currently presented full-screen cover, if any.
    var activeFullScreen: DSFullScreenRoute?

    // MARK: Init

    /// - Parameter restoresState: pass `true` only for the app-wide instance;
    ///   previews and tests get a clean router.
    init(restoresState: Bool = false) {
        if restoresState {
            restore()
        }
    }

    // MARK: Tab Selection

    /// Switches tabs. Selecting the already-active tab pops it to root —
    /// the standard iOS tab bar behavior.
    func select(_ tab: AppTab) {
        if selectedTab == tab {
            popToRoot(in: tab)
        } else {
            selectedTab = tab
        }
    }

    // MARK: Stack Navigation

    /// Pushes a route onto a tab's stack (defaults to the current tab).
    func push(_ route: AppRoute, in tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        paths[target, default: []].append(route)
        if target != selectedTab {
            selectedTab = target
        }
    }

    /// Pops the top route off the current tab's stack.
    func pop() {
        guard var path = paths[selectedTab], !path.isEmpty else { return }
        path.removeLast()
        paths[selectedTab] = path
    }

    /// Clears a tab's stack back to its root.
    func popToRoot(in tab: AppTab? = nil) {
        paths[tab ?? selectedTab] = []
    }

    /// Binding for a tab's navigation path — feed to `NavigationStack(path:)`.
    func pathBinding(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: { self.paths[tab, default: []] },
            set: { self.paths[tab] = $0 }
        )
    }

    // MARK: Presentation

    /// Presents a bottom sheet.
    func present(_ sheet: DSSheetRoute) {
        activeSheet = sheet
    }

    /// Presents a full-screen cover.
    func presentFullScreen(_ route: DSFullScreenRoute) {
        activeFullScreen = route
    }

    /// Dismisses whichever modal presentation is active.
    func dismissPresentation() {
        activeSheet = nil
        activeFullScreen = nil
    }

    // MARK: - State Restoration

    private struct PersistedState: Codable {
        var selectedTab: AppTab
        var paths: [AppTab: [AppRoute]]
    }

    private static let persistenceKey = "rentos.navigation.state.v1"
    private var isRestoring = false

    private func persist() {
        guard !isRestoring else { return }
        let state = PersistedState(selectedTab: selectedTab, paths: paths)
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.persistenceKey)
    }

    private func restore() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
            let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return }

        isRestoring = true
        selectedTab = state.selectedTab
        paths = state.paths
        isRestoring = false
    }

    /// Clears saved navigation state (e.g. on sign-out).
    func resetPersistedState() {
        UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
        isRestoring = true
        selectedTab = .dashboard
        paths = [:]
        isRestoring = false
    }

    // MARK: - Deep Linking

    /// Resolves a `rentos://` URL and navigates. Returns `true` if handled.
    ///
    /// Grammar (host = domain, path = identifiers):
    ///   rentos://dashboard | properties | maintenance | messages | copilot
    ///   rentos://properties/<propertyID>
    ///   rentos://tenants[/<tenantID>]
    ///   rentos://maintenance/<ticketID>
    ///   rentos://messages/<conversationID>
    ///   rentos://documents · rentos://notifications
    ///   rentos://settings[/<section>]
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "rentos", let host = url.host?.lowercased() else {
            return false
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard let resolution = Self.resolveDeepLink(host: host, path: pathComponents) else {
            return false
        }

        // Land cleanly: dismiss modals, set the tab, replace its stack.
        dismissPresentation()
        withAnimation(DS.Motion.smooth) {
            selectedTab = resolution.tab
            paths[resolution.tab] = resolution.stack
        }
        return true
    }

    /// Pure resolution — host/path in, destination out. Unit-testable.
    static func resolveDeepLink(host: String, path: [String]) -> (tab: AppTab, stack: [AppRoute])? {
        switch host {
        case "dashboard", "home":
            return (.dashboard, [])
        case "copilot", "ai":
            return (.aiAssistant, [])
        case PropertyNavigation.deepLinkHost:
            return PropertyNavigation.resolve(path)
        case TenantNavigation.deepLinkHost:
            return TenantNavigation.resolve(path)
        case MaintenanceNavigation.deepLinkHost:
            return MaintenanceNavigation.resolve(path)
        case MessagesNavigation.deepLinkHost:
            return MessagesNavigation.resolve(path)
        case DocumentNavigation.deepLinkHost:
            return DocumentNavigation.resolve(path)
        case SettingsNavigation.deepLinkHost:
            return SettingsNavigation.resolve(path)
        case "notifications":
            return (.dashboard, [.notifications])
        default:
            return nil
        }
    }
}
