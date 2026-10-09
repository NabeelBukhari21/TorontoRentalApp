//
//  AIAssistantViewModel.swift
//  RentalApp (RentOS)
//
//  AI Assistant — Copilot screen view model.
//
//  Owns the phase machine and the typewriter; all intelligence comes
//  from the injected repository. The `analyzing` phase is the screen's
//  loading state, so it maps directly onto the async fetch rather
//  than being a decorative timer.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class AIAssistantViewModel {

    /// Equatable so the view can drive `.animation(_:value:)` and
    /// compare against a case — `AppError` is Equatable, so this is
    /// synthesized.
    enum Phase: Equatable {
        case analyzing
        case briefing
        case ready
        case failed(AppError)
    }

    private let copilot: CopilotRepositoryProtocol
    private let notifications: NotificationRepositoryProtocol

    private(set) var phase: Phase = .analyzing
    private(set) var typedBriefing = ""
    private(set) var isWorking = false
    private(set) var unreadNotifications = 0

    private(set) var actions: [AIRecommendedAction] = []
    private(set) var activity: [AIActivityEntry] = []
    private(set) var maintenanceInsights: [AIInsightRow] = []
    private(set) var leaseInsights: [AIInsightRow] = []
    private(set) var quickActions: [AIQuickAction] = []
    private(set) var healthScore = 0
    private(set) var healthFactors: [AIHealthFactor] = []

    private var fullBriefing = ""
    private var hasStarted = false

    init(
        copilot: CopilotRepositoryProtocol,
        notifications: NotificationRepositoryProtocol
    ) {
        self.copilot = copilot
        self.notifications = notifications
    }

    var error: AppError? {
        if case .failed(let error) = phase { return error }
        return nil
    }

    // MARK: Lifecycle

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await run(forceRefresh: false)
    }

    func retry() async {
        phase = .analyzing
        typedBriefing = ""
        await run(forceRefresh: true)
    }

    func refresh() async {
        await run(forceRefresh: true)
    }

    private func run(forceRefresh: Bool) async {
        do {
            let briefing = try await copilot.briefing(forceRefresh: forceRefresh)
            guard !Task.isCancelled else { return }

            fullBriefing = briefing.narrative
            actions = briefing.actions
            activity = briefing.activity
            maintenanceInsights = briefing.maintenanceInsights
            leaseInsights = briefing.leaseInsights
            quickActions = briefing.quickActions
            healthScore = briefing.healthScore
            healthFactors = briefing.healthFactors
            unreadNotifications = (try? await notifications.unreadCount()) ?? 0

            withAnimation(DS.Motion.smooth) { phase = .briefing }

            typedBriefing = ""
            for character in fullBriefing {
                guard !Task.isCancelled else { return }
                typedBriefing.append(character)
                try? await Task.sleep(for: .milliseconds(character == " " ? 8 : 14))
            }

            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(DS.Motion.entrance) { phase = .ready }
        } catch is CancellationError {
            return
        } catch {
            withAnimation(DS.Motion.smooth) {
                phase = .failed(error as? AppError ?? .unknown)
            }
        }
    }

    // MARK: Intents

    func accept(_ action: AIRecommendedAction) {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
        withAnimation(DS.Motion.bouncy) { actions[index].state = .accepted }
        log(icon: action.icon, text: action.acceptedLabel)
    }

    func dismiss(_ action: AIRecommendedAction) {
        withAnimation(DS.Motion.smooth) {
            actions.removeAll { $0.id == action.id }
        }
    }

    func run(_ quickAction: AIQuickAction) {
        guard !isWorking else { return }
        withAnimation(DS.Motion.gentle) { isWorking = true }

        Task {
            defer { withAnimation(DS.Motion.bouncy) { isWorking = false } }
            guard let entry = try? await copilot.run(quickAction) else { return }
            withAnimation(DS.Motion.bouncy) { activity.insert(entry, at: 0) }
        }
    }

    private func log(icon: String, text: String) {
        withAnimation(DS.Motion.bouncy) {
            activity.insert(AIActivityEntry(icon: icon, text: text, time: "Now"), at: 0)
        }
    }
}
