//
//  GettingStartedViewModel.swift
//  RentalApp (Purrperty)
//
//  Getting started — Aha → Habit (playbook §1, steps 11–14).
//
//  Runs once, right after a new account has its workspace:
//
//      first property (one field per step) → saving → celebration
//      → notification priming → trial paywall → Home
//
//  The property is created for real through the repository, so Home
//  shows it the moment the flow ends. Every later step is skippable.
//

import SwiftUI
import Observation
import UserNotifications

enum GettingStartedStep: String, CaseIterable {
    case kind
    case address
    case name
    case units
    case saving
    case celebration
    case notifications
    case paywall

    /// The four property questions, for "Step x of 4".
    static let propertySteps: [GettingStartedStep] = [.kind, .address, .name, .units]

    var isPropertyStep: Bool { Self.propertySteps.contains(self) }
}

@MainActor
@Observable
final class GettingStartedViewModel {

    // MARK: State

    private(set) var step: GettingStartedStep = .kind
    private(set) var movesForward = true
    var draft = PropertyDraft()
    var unitCount = 1
    private(set) var saveTasks: [OnboardingBuildTask] = []
    private(set) var saveError: String?
    private(set) var createdProperty: Property?

    let profile: OnboardingProfile
    let firstName: String

    // MARK: Dependencies

    private let properties: PropertyRepositoryProtocol
    private let dashboard: DashboardRepositoryProtocol
    private let push: PushServiceProtocol
    private let featureFlags: FeatureFlagStore
    private let entitlements: EntitlementStore
    private let analytics: AnalyticsService
    private let onFinished: (_ addedProperty: Bool) -> Void

    /// Upper bound on units created here. Bigger buildings are added from
    /// the property screen, where units can be named one by one.
    static let maxUnits = 50

    init(
        session: AuthSession,
        container: AppContainer,
        onFinished: @escaping (_ addedProperty: Bool) -> Void
    ) {
        self.profile = container.onboardingProfile.profile
        self.firstName = session.fullName.split(separator: " ").first.map(String.init) ?? session.fullName
        self.properties = container.properties
        self.dashboard = container.dashboard
        self.push = container.push
        self.featureFlags = container.featureFlags
        self.entitlements = container.entitlements
        self.analytics = container.analytics
        self.onFinished = onFinished
        self.unitCount = profile.unitRange?.suggestedUnitsPerProperty ?? 1
    }

    // MARK: Derived

    var progress: Double {
        guard let index = GettingStartedStep.propertySteps.firstIndex(of: step) else { return 1 }
        return 0.1 + 0.9 * Double(index) / Double(GettingStartedStep.propertySteps.count)
    }

    var stepLabel: String {
        let index = (GettingStartedStep.propertySteps.firstIndex(of: step) ?? 0) + 1
        return "Step \(index) of \(GettingStartedStep.propertySteps.count)"
    }

    var canContinue: Bool {
        switch step {
        case .address: !trimmed(draft.addressLine1).isEmpty && postalCodeIsValid
        case .name:    trimmed(draft.name).count >= 2
        case .units:   (1...Self.maxUnits).contains(unitCount)
        default:       true
        }
    }

    /// Optional, but if it's there it has to look Canadian.
    var postalCodeIsValid: Bool {
        let code = trimmed(draft.postalCode)
        return code.isEmpty || code.range(of: #"^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$"#, options: .regularExpression) != nil
    }

    var question: String {
        switch step {
        case .kind:    "What kind of place is it?"
        case .address: "Where is it?"
        case .name:    "What do you call it?"
        case .units:   "How many units?"
        default:       ""
        }
    }

    var mascotLine: String {
        switch step {
        case .kind:    "Let's add your first property. It takes about a minute."
        case .address: "Just the street is fine. I'll file everything under it."
        case .name:    "A nickname helps once you have a few. The address works too."
        case .units:   unitCount == 1 ? "One unit, nice and simple." : "\(unitCount) units. I'll set each one up."
        default:       ""
        }
    }

    var mascotMood: MascotMood {
        switch step {
        case .kind:    .happy
        case .address: .thinking
        case .name:    .happy
        case .units:   unitCount > 1 ? .excited : .happy
        default:       .happy
        }
    }

    /// Soft paywall at the end of onboarding, after the aha moment
    /// (playbook §6) — only when there's something to sell and the
    /// user doesn't already have it.
    private var showsPaywall: Bool {
        featureFlags.isEnabled(.subscriptionsEnabled) && !entitlements.status.isEntitled
    }

    // MARK: Navigation

    func choose(_ kind: PropertyKind) {
        withAnimation(DS.Motion.bouncy) {
            draft.kind = kind
            switch kind {
            case .house, .condo: unitCount = 1
            case .multiUnit:     unitCount = max(2, profile.unitRange?.suggestedUnitsPerProperty ?? 2)
            case .commercial:    unitCount = profile.unitRange?.suggestedUnitsPerProperty ?? 1
            }
        }
        advance()
    }

    func advance() {
        switch step {
        case .kind:
            move(to: .address)
        case .address:
            // Suggest the street as the name; most landlords call a
            // place by its address anyway.
            if trimmed(draft.name).isEmpty { draft.name = trimmed(draft.addressLine1) }
            move(to: .name)
        case .name:
            move(to: .units)
        case .units:
            move(to: .saving)
            Task { await save() }
        case .saving:
            break
        case .celebration:
            Task { await moveToNotificationsOrLater() }
        case .notifications:
            moveToPaywallOrFinish()
        case .paywall:
            finish()
        }
    }

    func goBack() {
        guard let index = GettingStartedStep.propertySteps.firstIndex(of: step), index > 0 else { return }
        move(to: GettingStartedStep.propertySteps[index - 1], forward: false)
    }

    /// "I'll add it later": no property, no celebration.
    func skipProperty() {
        Task { await moveToNotificationsOrLater() }
    }

    private func move(to next: GettingStartedStep, forward: Bool = true) {
        movesForward = forward
        withAnimation(DS.Motion.smooth) { step = next }
    }

    /// Priming only makes sense while the system prompt can still be
    /// shown. Asked of the OS directly: permission belongs to the device,
    /// while the push service only handles remote registration (and the
    /// in-memory graph's `NoPushService` always reports `.denied`).
    private func moveToNotificationsOrLater() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .notDetermined {
            move(to: .notifications)
        } else {
            moveToPaywallOrFinish()
        }
    }

    private func moveToPaywallOrFinish() {
        if showsPaywall {
            move(to: .paywall)
        } else {
            finish()
        }
    }

    func finish() {
        onFinished(createdProperty != nil)
    }

    // MARK: Units

    func changeUnits(by delta: Int) {
        let next = min(max(unitCount + delta, 1), Self.maxUnits)
        guard next != unitCount else { return }
        withAnimation(DS.Motion.snappy) { unitCount = next }
    }

    // MARK: Saving

    /// Real work, revealed one line at a time (playbook §4): create the
    /// property, create its units, refresh the dashboard Home will show.
    private func save() async {
        saveError = nil
        let name = trimmed(draft.name)
        saveTasks = [
            OnboardingBuildTask(id: "property", title: "Adding \(name)"),
            OnboardingBuildTask(id: "units", title: unitCount == 1 ? "Setting up the unit" : "Setting up \(unitCount) units"),
            OnboardingBuildTask(id: "dashboard", title: "Updating your dashboard")
        ]

        do {
            try await run("property") {
                var clean = self.draft
                clean.name = name
                clean.addressLine1 = self.trimmed(clean.addressLine1)
                clean.postalCode = self.trimmed(clean.postalCode).uppercased()
                self.createdProperty = try await self.properties.createProperty(clean)
            }
            try await run("units") {
                guard let property = self.createdProperty else { return }
                try await self.createUnits(for: property.id)
            }
            try await run("dashboard") {
                _ = try? await self.dashboard.snapshot(forceRefresh: true)
            }
        } catch {
            saveError = (error as? AppError)?.errorDescription ?? AppError.unknown.errorDescription
            // A property without its units is still a property; only go
            // back to the form if nothing was created.
            if createdProperty == nil {
                move(to: .units, forward: false)
                return
            }
        }

        Task { await analytics.track(.propertyCreated) }
        try? await Task.sleep(for: .milliseconds(350))
        move(to: .celebration)
    }

    private func createUnits(for propertyID: String) async throws {
        let isSingle = unitCount == 1
        // Concurrent: the mock (and the network) take ~300ms a write, and
        // fifty in sequence would turn a moment into a wait.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for number in 1...unitCount {
                let draft = UnitDraft(label: isSingle ? "Main" : "Unit \(number)")
                group.addTask { @MainActor in
                    _ = try await self.properties.createUnit(draft, propertyID: propertyID)
                }
            }
            try await group.waitForAll()
        }
    }

    /// Runs one save line with a short floor so each tick is readable.
    private func run(_ id: String, _ work: @escaping () async throws -> Void) async throws {
        setState(.running, for: id)
        let started = ContinuousClock.now
        try await work()
        let floor = Duration.milliseconds(500)
        let elapsed = ContinuousClock.now - started
        if elapsed < floor { try? await Task.sleep(for: floor - elapsed) }
        withAnimation(DS.Motion.bouncy) { setState(.done, for: id) }
    }

    private func setState(_ state: OnboardingBuildTask.State, for id: String) {
        guard let i = saveTasks.firstIndex(where: { $0.id == id }) else { return }
        saveTasks[i].state = state
    }

    // MARK: Notifications

    /// The user tapped "Turn on" after the preview, so this is the
    /// explicit system prompt — not the push service's quiet provisional
    /// request. The push service then picks up the result and registers
    /// for remote notifications if it can.
    func enableNotifications() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        await push.refreshAuthorization()
        Task { await analytics.track(.notificationPermissionResponded(granted: granted)) }
        advance()
    }

    func declineNotifications() {
        advance()
    }

    // MARK: Helpers

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
