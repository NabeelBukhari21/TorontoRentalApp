//
//  AppContainer.swift
//  RentalApp (Purrperty)
//
//  Core — Dependency injection container.
//
//  Every dependency is declared as a protocol and injected through the
//  initializer, so production, previews, and tests each build their own
//  graph. Views reach it via `@Environment(\.container)`; ViewModels
//  receive exactly the dependencies they need — never the container
//  itself (that would just be a service locator in disguise).
//
//  Swapping mock data for a live backend is a one-line change here.
//

import SwiftUI
import OSLog

@MainActor
final class AppContainer {

    // MARK: Repositories

    let properties: PropertyRepositoryProtocol
    let tenants: TenantRepositoryProtocol
    let maintenance: MaintenanceRepositoryProtocol
    let messages: MessageRepositoryProtocol
    let documents: DocumentRepositoryProtocol
    let notifications: NotificationRepositoryProtocol
    let dashboard: DashboardRepositoryProtocol
    let profile: ProfileRepositoryProtocol
    let preferences: PreferencesRepositoryProtocol
    let billing: BillingRepositoryProtocol
    let integrations: IntegrationsRepositoryProtocol
    let copilot: CopilotRepositoryProtocol

    // MARK: Services

    let auth: AuthServiceProtocol
    let organization: OrganizationServiceProtocol
    let persistence: PersistenceServiceProtocol

    /// Typed-event analytics. An actor, so every call site awaits — see
    /// Core/Analytics/AnalyticsEvent.swift for why events are not strings.
    let analytics: AnalyticsService

    // MARK: Release Infrastructure

    /// Build-time facts: which environment, which version. Read once.
    let configuration: AppConfiguration

    /// What the user has agreed to be collected. Every diagnostics and
    /// analytics path consults this; nothing collects without it.
    let consent: ConsentStore

    /// Crash handlers and the breadcrumb trail that gives them context.
    let crashReporter: CrashReporter
    let breadcrumbs: BreadcrumbTrail

    /// Feature flags: compiled defaults, remote overrides, debug overrides.
    let featureFlags: FeatureFlagStore

    /// Versioned terms/privacy acceptance, gating entry to the app.
    let legal: LegalGate

    /// Subscription entitlements. Inert until `paywallEnforced` is on.
    let entitlements: EntitlementStore

    /// Quiz answers from onboarding, kept on the device until — and
    /// after — there is an account to attach them to.
    let onboardingProfile: OnboardingProfileStore

    /// Transient feedback. ONE instance for the whole app.
    ///
    /// Audit finding: six were being constructed — one owned by
    /// `RootNavigation` as `@State`, one here for the notification
    /// coordinator, and more for each `ConflictCenter`. Anything posted by a
    /// coordinator went to an object no view observed, so those toasts were
    /// silently invisible. Identity matters for observable singletons; two
    /// instances of a "centre" is a contradiction in terms.
    let toasts: ToastCenter

    /// Offline: persistent cache, the read/write gate, and the conflict queue.
    let offlineCache: OfflineCache
    let offline: OfflineGate
    let conflicts: ConflictCenter

    /// Push + the notification centre coordinator.
    let push: PushServiceProtocol
    let notificationCoordinator: NotificationCoordinator

    /// Global search across all eight entity types.
    let search: SearchRepositoryProtocol
    let recentSearches: RecentSearchStore

    /// Realtime. The engine owns the socket lifecycle; the outbox holds
    /// writes made while offline.
    let sync: SyncEngine
    let outbox: MutationOutbox
    let connectivity: ConnectivityMonitor

    /// The AI layer. A protocol, so a workspace without an entitlement
    /// gets `DisabledAIService` and no call site needs an optional.
    let ai: AIServiceProtocol

    /// Where the session is persisted. Exposed so the session
    /// coordinator can read the onboarding flag without going through
    /// the auth service — onboarding isn't an authentication concern.
    let sessionStore: SessionStoring

    // MARK: Init

    init(
        properties: PropertyRepositoryProtocol,
        tenants: TenantRepositoryProtocol,
        maintenance: MaintenanceRepositoryProtocol,
        messages: MessageRepositoryProtocol,
        documents: DocumentRepositoryProtocol,
        notifications: NotificationRepositoryProtocol,
        dashboard: DashboardRepositoryProtocol,
        profile: ProfileRepositoryProtocol,
        preferences: PreferencesRepositoryProtocol,
        billing: BillingRepositoryProtocol,
        integrations: IntegrationsRepositoryProtocol,
        copilot: CopilotRepositoryProtocol,
        auth: AuthServiceProtocol,
        organization: OrganizationServiceProtocol,
        persistence: PersistenceServiceProtocol,
        analytics: AnalyticsService,
        sessionStore: SessionStoring,
        ai: AIServiceProtocol,
        sync: SyncEngine,
        outbox: MutationOutbox,
        connectivity: ConnectivityMonitor,
        search: SearchRepositoryProtocol,
        recentSearches: RecentSearchStore,
        push: PushServiceProtocol,
        notificationCoordinator: NotificationCoordinator,
        offlineCache: OfflineCache,
        offline: OfflineGate,
        conflicts: ConflictCenter,
        toasts: ToastCenter,
        // Release infrastructure. Only the pieces that genuinely differ
        // between backends are parameters; the rest are derived below
        // from `persistence`, because a second `ConsentStore` or a second
        // `BreadcrumbTrail` is the same identity bug the toast centre had.
        flagSource: FeatureFlagRemoteSource = NoRemoteFlagSource(),
        legalRecorder: LegalAcceptanceRecording = InMemoryLegalRecorder(),
        subscriptions: SubscriptionProviding = MockSubscriptionProvider()
    ) {
        self.properties = properties
        self.tenants = tenants
        self.maintenance = maintenance
        self.messages = messages
        self.documents = documents
        self.notifications = notifications
        self.dashboard = dashboard
        self.profile = profile
        self.preferences = preferences
        self.billing = billing
        self.integrations = integrations
        self.copilot = copilot
        self.auth = auth
        self.organization = organization
        self.persistence = persistence
        self.analytics = analytics
        self.sessionStore = sessionStore
        self.ai = ai
        self.sync = sync
        self.outbox = outbox
        self.connectivity = connectivity
        self.search = search
        self.recentSearches = recentSearches
        self.push = push
        self.notificationCoordinator = notificationCoordinator
        self.offlineCache = offlineCache
        self.offline = offline
        self.conflicts = conflicts
        self.toasts = toasts

        // MARK: Release infrastructure
        //
        // Derived here rather than passed in. Each of these is a singleton
        // by nature — one consent record, one breadcrumb trail, one flag
        // snapshot — and constructing them at the one place that owns the
        // graph is what stops a second instance appearing later.

        let configuration = AppConfiguration.current
        self.configuration = configuration

        let consent = ConsentStore(persistence: persistence)
        self.consent = consent

        let breadcrumbs = BreadcrumbTrail(persistence: persistence)
        self.breadcrumbs = breadcrumbs

        self.crashReporter = CrashReporter(
            consent: consent,
            breadcrumbs: breadcrumbs,
            configuration: configuration
        )

        let featureFlags = FeatureFlagStore(
            remote: flagSource,
            persistence: persistence
        )
        self.featureFlags = featureFlags

        self.legal = LegalGate(
            recorder: legalRecorder,
            persistence: persistence
        )

        self.entitlements = EntitlementStore(
            provider: subscriptions,
            flags: featureFlags
        )

        self.onboardingProfile = OnboardingProfileStore(persistence: persistence)

        // The flag store refuses to remotely disable a data-critical flag
        // while work is still queued. It needs a way to ask, and the outbox
        // is the thing that knows — wired here because this is the only
        // place both objects exist.
        featureFlags.pendingWorkCheck = { [weak outbox] in
            outbox?.hasPending ?? false
        }
    }

    // MARK: Graphs

    /// Which backend the running app talks to.
    ///
    /// Kept as an explicit switch rather than a build flag so a migrating
    /// repository can be moved over one at a time: the Supabase graph
    /// below still falls back to the in-memory implementation for every
    /// domain that has not been ported yet. Nothing above this file — no
    /// ViewModel, no view — can tell the difference.
    enum Backend {
        case inMemory
        case supabase
    }

    /// The production graph.
    static func live(backend: Backend = .supabase) -> AppContainer {
        switch resolve(backend) {
        case .inMemory: inMemoryGraph()
        case .supabase: supabaseGraph()
        }
    }

    /// Downgrades to the in-memory graph when Supabase has no credentials.
    ///
    /// Without this the app is unrunnable on a fresh clone: `.supabase` is
    /// the default, `SupabaseConfig.fromBundle()` traps on a missing key,
    /// and so the app dies at launch and every SwiftUI preview dies with
    /// it — before a line of UI has been seen.
    ///
    /// The trap itself is still correct where it is. What was missing is
    /// the choice *not to go down that path*. An unconfigured checkout now
    /// runs on mock data, which is the useful behaviour: the UI works, and
    /// adding `Supabase.xcconfig` is what switches it to the real backend.
    ///
    /// Note this never silently downgrades a configured build — a wrong or
    /// unreachable URL still fails loudly at the request. It only covers
    /// "no credentials supplied at all".
    private static func resolve(_ backend: Backend) -> Backend {
        guard backend == .supabase else { return backend }
        guard !SupabaseConfig.isConfigured() else { return .supabase }

        AppLog.app.notice(
            """
            Supabase is not configured — running on the in-memory backend. \
            Add RentalApp/Supabase.xcconfig with SUPABASE_URL and \
            SUPABASE_ANON_KEY to use the real backend.
            """
        )
        return .inMemory
    }

    // MARK: Supabase graph

    private static func supabaseGraph() -> AppContainer {
        let persistence = UserDefaultsPersistenceService()

        // Keychain, NOT `SessionStore`. This graph issues real Supabase
        // access and refresh tokens; `SessionStore` writes through
        // `PersistenceServiceProtocol`, which is an unencrypted plist.
        // See KeychainSessionStore.swift — it also migrates any session a
        // previous build already left in UserDefaults.
        let sessionStore = KeychainSessionStore(persistence: persistence)

        let provider = SupabaseClientProvider.live()
        let client = provider.client

        // Ordered failover across vendors. All three route through the same
        // Edge Function, which holds the keys — no provider key is compiled
        // into this app. Reordering this array changes which vendor answers
        // first; adding a fourth is one line here plus a server secret.
        let aiRouter = AIRouter(providers: [
            EdgeFunctionAIProvider(
                id: "anthropic", vendor: "anthropic", client: client,
                supportedPreferences: [.fast, .reasoning, .longContext]
            ),
            EdgeFunctionAIProvider(
                id: "openai", vendor: "openai", client: client,
                supportedPreferences: [.fast, .reasoning, .longContext]
            ),
            EdgeFunctionAIProvider(
                id: "gemini", vendor: "gemini", client: client,
                supportedPreferences: [.fast, .reasoning, .longContext]
            ),
            // Unavailable until a model ships; the router skips it.
            OnDeviceAIProvider()
        ])

        let aiService = AIService(
            router: aiRouter,
            audit: SupabaseAIAuditLog(client: client),
            policy: .manual
        )

        // Realtime. Built here rather than lazily because the engine's
        // reachability hook must be installed before the first screen
        // appears, or the initial connect races the first render.
        let connectivity = ConnectivityMonitor()
        let outbox = MutationOutbox(
            persistence: persistence,
            executor: SupabaseOutboxExecutor(client: client)
        )
        // Offline stack. Built before the repositories so the property
        // repository can take the gate — reads fall back to disk and writes
        // queue instead of failing.
        let offlineCache = OfflineCache()
        let offlineGate = OfflineGate(
            connectivity: connectivity, cache: offlineCache, outbox: outbox
        )

        let resyncSource = SupabaseResyncSource(client: client)
        let syncEngine = SyncEngine(
            client: SupabaseRealtimeClient(client: client),
            connectivity: connectivity,
            outbox: outbox,
            persistence: persistence,
            resync: { topic, since in
                await resyncSource.changes(for: topic, since: since)
            }
        )

        // Notifications: the coordinator is the push service's sink, and the
        // push service is the coordinator's transport. Built in two steps
        // because neither can be constructed with the other already finished.
        let notificationRepo = SupabaseNotificationRepository(client: client)
        let toastCenter = ToastCenter()
        let pushBox = PushServiceBox()
        let coordinator = NotificationCoordinator(
            repository: notificationRepo,
            push: pushBox,
            toasts: toastCenter
        )
        pushBox.attach(PushService(sink: coordinator))

        return AppContainer(
            // ── Ported to Supabase ──────────────────────────────────
            properties: SupabasePropertyRepository(client: client, offline: offlineGate),

            // ── Still in-memory; each is one file away ──────────────
            tenants: InMemoryTenantRepository(),
            maintenance: InMemoryMaintenanceRepository(),
            messages: InMemoryMessageRepository(),
            documents: InMemoryDocumentRepository(),
            notifications: notificationRepo,
            dashboard: InMemoryDashboardRepository(),
            profile: InMemoryProfileRepository(),
            preferences: InMemoryPreferencesRepository(),
            billing: InMemoryBillingRepository(),
            integrations: InMemoryIntegrationsRepository(),
            copilot: InMemoryCopilotRepository(),

            auth: SupabaseAuthService(client: client, store: sessionStore),
            organization: SupabaseOrganizationService(client: client),
            persistence: persistence,
            analytics: Self.makeAnalytics(),
            sessionStore: sessionStore,
            ai: aiService,
            sync: syncEngine,
            outbox: outbox,
            connectivity: connectivity,
            search: SupabaseSearchRepository(client: client),
            recentSearches: RecentSearchStore(persistence: persistence),
            push: pushBox,
            notificationCoordinator: coordinator,
            offlineCache: offlineCache,
            offline: offlineGate,
            conflicts: ConflictCenter(toasts: toastCenter),
            toasts: toastCenter
        )
    }

    // MARK: In-memory graph

    /// The mock graph. Still the source for previews, and the fallback
    /// while the backend is unreachable during development.
    private static func inMemoryGraph() -> AppContainer {
        // Built ahead of the graph because auth and the container both
        // need the same store instance — two stores would mean two
        // disagreeing sources of truth for the session.
        let persistence = UserDefaultsPersistenceService()
        let sessionStore = SessionStore(persistence: persistence)
        let inertSync = Self.inertRealtime(persistence: persistence)
        let notificationsRepo = InMemoryNotificationRepository()

        // Declared before its first use. The toast centre is shared by the
        // notification coordinator and the conflict centre, so it has to
        // exist before either is built.
        let sharedToasts = ToastCenter()

        let mockNotifications = Self.mockNotifications(
            repository: notificationsRepo, toasts: sharedToasts
        )
        let mockOffline = Self.offlineStack(
            connectivity: inertSync.connectivity, outbox: inertSync.outbox
        )

        return AppContainer(
            properties: InMemoryPropertyRepository(),
            tenants: InMemoryTenantRepository(),
            maintenance: InMemoryMaintenanceRepository(),
            messages: InMemoryMessageRepository(),
            documents: InMemoryDocumentRepository(),
            notifications: notificationsRepo,
            dashboard: InMemoryDashboardRepository(),
            profile: InMemoryProfileRepository(),
            preferences: InMemoryPreferencesRepository(),
            billing: InMemoryBillingRepository(),
            integrations: InMemoryIntegrationsRepository(),
            copilot: InMemoryCopilotRepository(),
            auth: MockAuthService(store: sessionStore),
            organization: MockOrganizationService(),
            persistence: persistence,
            analytics: Self.makeAnalytics(),
            sessionStore: sessionStore,
            ai: Self.mockAI(),
            sync: inertSync.engine,
            outbox: inertSync.outbox,
            connectivity: inertSync.connectivity,
            search: InMemorySearchRepository(),
            recentSearches: RecentSearchStore(persistence: persistence),
            push: mockNotifications.push,
            notificationCoordinator: mockNotifications.coordinator,
            offlineCache: mockOffline.cache,
            offline: mockOffline.gate,
            conflicts: ConflictCenter(toasts: sharedToasts),
            toasts: sharedToasts
        )
    }

    /// Realtime stand-in for the mock graph: a socket that connects and
    /// never delivers anything, so previews look healthy without a server.
    private static func inertRealtime(
        persistence: PersistenceServiceProtocol
    ) -> (engine: SyncEngine, outbox: MutationOutbox, connectivity: ConnectivityMonitor) {
        let connectivity = ConnectivityMonitor()
        let outbox = MutationOutbox(persistence: persistence, executor: NoOutboxExecutor())
        let source = EmptyResyncSource()
        let engine = SyncEngine(
            client: InertRealtimeClient(),
            connectivity: connectivity,
            outbox: outbox,
            persistence: persistence,
            resync: { topic, since in await source.changes(for: topic, since: since) }
        )
        return (engine, outbox, connectivity)
    }

    /// Offline stack for the mock graph and previews.
    ///
    /// A real `OfflineCache` in a separate directory, not a stub — previews
    /// then exercise the encode/decode path, so a model that stops being
    /// Codable fails in a preview rather than on a plane.
    private static func offlineStack(
        connectivity: ConnectivityMonitor,
        outbox: MutationOutbox
    ) -> (cache: OfflineCache, gate: OfflineGate) {
        let cache = OfflineCache(directoryName: "OfflineCache-Preview")
        return (cache, OfflineGate(connectivity: connectivity, cache: cache, outbox: outbox))
    }

    /// Notification stack for the mock graph and previews.
    ///
    /// `NoPushService` rather than the real one: previews and the simulator
    /// have no APNs entitlement, and registering there logs a scary error
    /// for no benefit.
    private static func mockNotifications(
        repository: NotificationRepositoryProtocol,
        toasts: ToastCenter
    ) -> (push: PushServiceProtocol, coordinator: NotificationCoordinator) {
        let push = NoPushService()
        let coordinator = NotificationCoordinator(
            repository: repository,
            push: push,
            toasts: toasts
        )
        return (push, coordinator)
    }

    /// Deterministic AI for the mock graph and previews. Exercises real
    /// decoding — a mock that returned prose would let a schema bug reach
    /// production.
    private static func mockAI() -> AIServiceProtocol {
        AIService(
            router: AIRouter(providers: [MockAIProvider()]),
            audit: InMemoryAIAuditLog(),
            policy: .manual
        )
    }

    /// Builds the analytics service with the sinks this environment wants.
    ///
    /// No network sink is registered yet — there is no events endpoint
    /// deployed. That is deliberate rather than an omission: the consent
    /// gate, the typed events and the buffering all work now, and adding
    /// delivery later is `addSink` plus an `AnalyticsTransport`, with no
    /// call site touched.
    ///
    /// Note nothing is emitted regardless until the user grants
    /// `.analytics` consent — see `AnalyticsService.track`.
    private static func makeAnalytics() -> AnalyticsService {
        var sinks: [AnalyticsSink] = []
        if AppEnvironment.current.allowsDebugTools {
            sinks.append(OSLogAnalyticsSink())
        }
        return AnalyticsService(sinks: sinks)
    }

    /// Shared graph for the running app.
    static let shared = AppContainer.live()

    /// Fresh graph for previews and tests — never touches shared state.
    /// Uses ephemeral persistence so a preview can't sign the
    /// simulator in or out of the real app.
    static var preview: AppContainer {
        let persistence = EphemeralPersistenceService()
        let sessionStore = SessionStore(persistence: persistence)
        let inertSync = Self.inertRealtime(persistence: persistence)
        let notificationsRepo = InMemoryNotificationRepository()

        // Declared before first use — see the note in `inMemoryGraph()`.
        let sharedToasts = ToastCenter()

        let mockNotifications = Self.mockNotifications(
            repository: notificationsRepo, toasts: sharedToasts
        )
        let mockOffline = Self.offlineStack(
            connectivity: inertSync.connectivity, outbox: inertSync.outbox
        )

        return AppContainer(
            properties: InMemoryPropertyRepository(),
            tenants: InMemoryTenantRepository(),
            maintenance: InMemoryMaintenanceRepository(),
            messages: InMemoryMessageRepository(),
            documents: InMemoryDocumentRepository(),
            notifications: notificationsRepo,
            dashboard: InMemoryDashboardRepository(),
            profile: InMemoryProfileRepository(),
            preferences: InMemoryPreferencesRepository(),
            billing: InMemoryBillingRepository(),
            integrations: InMemoryIntegrationsRepository(),
            copilot: InMemoryCopilotRepository(),
            auth: MockAuthService(store: sessionStore, latency: .milliseconds(200)),
            organization: MockOrganizationService(),
            persistence: persistence,
            analytics: Self.makeAnalytics(),
            sessionStore: sessionStore,
            ai: Self.mockAI(),
            sync: inertSync.engine,
            outbox: inertSync.outbox,
            connectivity: inertSync.connectivity,
            search: InMemorySearchRepository(),
            recentSearches: RecentSearchStore(persistence: persistence),
            push: mockNotifications.push,
            notificationCoordinator: mockNotifications.coordinator,
            offlineCache: mockOffline.cache,
            offline: mockOffline.gate,
            conflicts: ConflictCenter(toasts: sharedToasts),
            toasts: sharedToasts
        )
    }
}

// MARK: - Environment

private struct AppContainerKey: @preconcurrency EnvironmentKey {

    /// `.preview` under the preview canvas, `.shared` when running.
    ///
    /// This used to be `.shared` unconditionally, which meant any preview
    /// that did not explicitly inject a container got the *live* graph —
    /// real Supabase client, real network, real session. Two consequences,
    /// the first visible and the second not:
    ///
    /// 1. On an unconfigured checkout the canvas died outright with
    ///    "Fatal Error in SupabaseClientProvider.swift", because building
    ///    the live graph traps on missing credentials.
    /// 2. On a configured one it was worse but quieter: previews would
    ///    hit the real backend, meaning a preview of a destructive view
    ///    could issue real writes against real data.
    ///
    /// A preview is a design-time artefact and has no business holding a
    /// production client. `XCODE_RUNNING_FOR_PREVIEWS` is the supported
    /// way to detect the canvas.
    @MainActor
    static var defaultValue: AppContainer {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            ? .preview
            : .shared
    }
}

extension EnvironmentValues {
    var container: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
