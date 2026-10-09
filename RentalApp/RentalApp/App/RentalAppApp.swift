//
//  RentalAppApp.swift
//  RentalApp (RentOS)
//
//  App — Composition root. Builds the dependency graph once and
//  injects it into the view hierarchy.
//

import SwiftUI
import UIKit
import OSLog

@main
struct RentalAppApp: App {

    /// The production dependency graph.
    private let container = AppContainer.shared

    /// Background refresh. Registered in `init` because `BGTaskScheduler`
    /// ignores registrations made after launch finishes — doing this in
    /// `.task` or `onAppear` silently never runs.
    private let backgroundRefresh: BackgroundRefreshCoordinator

    /// APNs hands the device token to the app delegate, and there is no
    /// SwiftUI equivalent — `UIApplicationDelegateAdaptor` is the supported
    /// bridge, not a legacy workaround.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let container = AppContainer.shared
        let coordinator = BackgroundRefreshCoordinator(persistence: container.persistence)

        // The outbox has to be passed here. Without it the coordinator's
        // reference stays nil, `scheduleDrainIfNeeded()` guards itself off,
        // and the registered BGProcessingTask drains nothing — a background
        // task that runs, does no work, and reports success.
        coordinator.register(engine: container.sync, outbox: container.outbox)
        self.backgroundRefresh = coordinator

        // Crash handlers go in as early as possible — a crash during the
        // rest of launch is exactly the one worth catching, and handlers
        // installed in `.task` or `onAppear` miss it.
        container.crashReporter.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.container, container)
                .environment(\.featureFlags, container.featureFlags)
                .task { await startUp() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .background else { return }
                    // Submit while there is still a runloop to submit on.
                    backgroundRefresh.schedule()
                    // And ask for a drain if writes are still queued — this
                    // was previously never called anywhere, so a queue built
                    // up offline sat until the user happened to reopen the
                    // app, which is the one moment it did not need to.
                    backgroundRefresh.scheduleDrainIfNeeded()
                }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    // MARK: Start-up

    /// Everything that has to happen once per launch, off the first frame.
    ///
    /// Ordered deliberately: consent is pushed to analytics *before* any
    /// event can be emitted, so there is no window in which something is
    /// recorded under a consent state nobody has read yet.
    @MainActor
    private func startUp() async {
        let consentSnapshot = ConsentCategory.allCases.reduce(into: [ConsentCategory: Bool]()) {
            $0[$1] = container.consent.allows($1)
        }
        await container.analytics.updateConsent(consentSnapshot)

        await container.analytics.track(.appLaunched(coldStart: true))

        // A report left by a previous run. Collected regardless of consent
        // — transmitting it is what consent governs.
        if let report = container.crashReporter.collectPendingReport() {
            AppLog.diagnostics.notice(
                "Previous run ended in \(report.reason, privacy: .public)"
            )
        }

        await container.featureFlags.refresh()
        await container.entitlements.start()
    }
}

// MARK: - App Delegate

/// Exists for exactly one reason: `application(_:didRegisterForRemote…)`.
///
/// Everything else notification-related lives in `PushService` and
/// `NotificationCoordinator`; this is the thinnest possible bridge from
/// UIKit's callback to them.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await AppContainer.shared.push.register(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Expected on the simulator and whenever the push entitlement is
        // missing. Not worth surfacing — the app works without push, and the
        // notification centre is unaffected.
    }
}
