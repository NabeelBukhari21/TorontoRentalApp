//
//  OnboardingFlowViewModel.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Hook → Personalise → Sign up.
//
//  Follows docs/ONBOARDING_PLAYBOOK.md §1: an outcome-led hello, a short
//  conversational quiz with Purr, "make it yours", an honest building
//  step, a summary of what the answers switched on, then sign-up — by
//  which point the user is invested and the form reads as a pitch.
//
//  The view model owns the step machine and the answers. It reports a
//  finished sign-up upward as a `SignInOutcome`; what that means for
//  the session is `SessionViewModel`'s decision, as everywhere else.
//

import SwiftUI
import Observation

// MARK: - Steps

enum OnboardingStep: String, CaseIterable, Sendable {
    case hello
    case persona
    case units
    case headaches
    case goal
    case personalize
    case building
    case unlocked
    case signUp

    /// Steps where going back makes sense. The building step is a moment,
    /// not a form, and hello is the start.
    var allowsBack: Bool {
        switch self {
        case .hello, .building: false
        default: true
        }
    }

    /// Hello is the cover; everything after it shows progress.
    var showsProgress: Bool { self != .hello }
}

// MARK: - Building Checklist

/// One line of the "Building your Purrperty…" checklist. Each is real
/// work; the checklist only paces how it's revealed (playbook §4).
struct OnboardingBuildTask: Identifiable, Equatable {
    enum State: Equatable { case pending, running, done }

    let id: String
    let title: String
    var state: State = .pending
}

// MARK: - View Model

@MainActor
@Observable
final class OnboardingFlowViewModel {

    // MARK: State

    private(set) var step: OnboardingStep = .hello
    private(set) var movesForward = true
    var profile: OnboardingProfile
    private(set) var buildTasks: [OnboardingBuildTask] = []

    /// The sign-up form. Created up front so the role chosen in the quiz
    /// is already on it.
    let auth: AuthViewModel

    // MARK: Dependencies

    private let store: OnboardingProfileStore
    private let preferences: PreferencesRepositoryProtocol
    private let dashboard: DashboardRepositoryProtocol
    private let analytics: AnalyticsService

    init(
        store: OnboardingProfileStore,
        preferences: PreferencesRepositoryProtocol,
        dashboard: DashboardRepositoryProtocol,
        authService: AuthServiceProtocol,
        analytics: AnalyticsService
    ) {
        self.store = store
        self.preferences = preferences
        self.dashboard = dashboard
        self.analytics = analytics
        self.profile = store.profile
        self.auth = AuthViewModel(auth: authService)
        auth.requiresPasswordConfirmation = false
    }

    // MARK: Derived

    /// The path through the flow. Tenants skip the portfolio questions,
    /// and with nothing to build or unlock, those two steps as well.
    var steps: [OnboardingStep] {
        guard profile.persona?.asksPortfolioQuestions ?? true else {
            return [.hello, .persona, .personalize, .signUp]
        }
        return OnboardingStep.allCases
    }

    private var index: Int { steps.firstIndex(of: step) ?? 0 }

    /// Starts at ~10% on the first question so the bar already feels
    /// under way (playbook §5, endowed progress).
    var progress: Double {
        let questions = Double(max(steps.count - 1, 1))
        return 0.1 + 0.9 * Double(index) / questions
    }

    /// "Step 3 of 7" — hello isn't counted, it's the cover.
    var stepLabel: String {
        "Step \(max(index, 1)) of \(steps.count - 1)"
    }

    var canContinue: Bool {
        switch step {
        case .persona:   profile.persona != nil
        case .units:     profile.unitRange != nil
        case .headaches: !profile.headaches.isEmpty
        case .goal:      profile.goal != nil
        case .building:  buildTasks.allSatisfy { $0.state == .done } && !buildTasks.isEmpty
        default:         true
        }
    }

    var continueTitle: String {
        switch step {
        case .hello:       "Let's go"
        // Tenants have nothing to build; for them this leads to sign-up.
        case .personalize: steps.contains(.building) ? "Build my Purrperty" : "Continue"
        case .unlocked:    "Save my setup"
        default:           "Continue"
        }
    }

    // MARK: Purr

    var mascotMood: MascotMood {
        switch step {
        case .hello:       .cheer
        case .persona:     .thinking
        case .units:       profile.unitRange == nil ? .thinking : .happy
        case .headaches:   profile.headaches.isEmpty ? .concerned : .happy
        case .goal:        .excited
        case .personalize: .cool
        case .building:    .working
        case .unlocked:    .cheer
        case .signUp:      .happy
        }
    }

    /// The question Purr asks on a quiz step.
    var question: String {
        switch step {
        case .persona:     "Who are you?"
        case .units:       "How many units?"
        case .headaches:   "What's the biggest headache?"
        case .goal:        "What's your #1 goal?"
        case .personalize: "Make it yours"
        default:           ""
        }
    }

    /// Purr's line under the question. Reacts to the answer where it can.
    var mascotLine: String {
        switch step {
        case .persona:
            "Tell me a little about you, and I'll set things up to match."
        case .units:
            profile.unitRange?.reaction ?? "Roughly is fine. I'll size your dashboard to fit."
        case .headaches:
            profile.headaches.isEmpty
                ? "Pick as many as you like. I've heard it all."
                : "Ugh, I know. I'll take those off your plate."
        case .goal:
            "If Purrperty does one thing brilliantly for you, what is it?"
        case .personalize:
            profile.persona == .tenant
                ? "Light, dark or match your iPhone. Your landlord can invite you in after you sign up."
                : "Light, dark or match your iPhone. You can change it anytime in Settings."
        default:
            ""
        }
    }

    // MARK: Navigation

    func advance() {
        recordAnswer(for: step)

        guard let next = steps.dropFirst(index + 1).first else { return }
        move(to: next, forward: true)
    }

    func goBack() {
        guard step.allowsBack, index > 0 else { return }
        var previous = steps[index - 1]
        // The building step is a one-way moment; stepping back over it
        // lands on the choice it was building from.
        if previous == .building, index > 1 { previous = steps[index - 2] }
        move(to: previous, forward: false)
    }

    private func move(to next: OnboardingStep, forward: Bool) {
        movesForward = forward
        withAnimation(DS.Motion.smooth) { step = next }
        Task { await analytics.track(.onboardingStepViewed(step: next.rawValue)) }

        if next == .building {
            Task { await build() }
        }
        if next == .signUp, let persona = profile.persona {
            auth.selectedRole = persona.role
        }
    }

    // MARK: Answers

    func select(_ persona: OnboardingPersona) {
        withAnimation(DS.Motion.bouncy) { profile.persona = persona }
    }

    func select(_ range: OnboardingUnitRange) {
        withAnimation(DS.Motion.bouncy) { profile.unitRange = range }
    }

    func toggle(_ headache: OnboardingHeadache) {
        withAnimation(DS.Motion.bouncy) {
            if profile.headaches.contains(headache) {
                profile.headaches.remove(headache)
            } else {
                profile.headaches.insert(headache)
            }
        }
    }

    func select(_ goal: OnboardingGoal) {
        withAnimation(DS.Motion.bouncy) { profile.goal = goal }
    }

    var theme: AppTheme {
        get { preferences.theme }
        set { withAnimation(DS.Motion.smooth) { preferences.theme = newValue } }
    }

    private func recordAnswer(for step: OnboardingStep) {
        let answers: [String]
        switch step {
        case .persona:     answers = [profile.persona?.rawValue].compactMap { $0 }
        case .units:       answers = [profile.unitRange?.rawValue].compactMap { $0 }
        case .headaches:   answers = profile.headaches.map(\.rawValue).sorted()
        case .goal:        answers = [profile.goal?.rawValue].compactMap { $0 }
        case .personalize: answers = [preferences.theme.rawValue.lowercased()]
        default:           return
        }
        Task {
            for answer in answers {
                await analytics.track(.onboardingAnswered(question: step.rawValue, answer: answer))
            }
        }
    }

    // MARK: Building

    /// The labour-illusion step, done honestly: every line is work that
    /// really happens. A short floor per line keeps it readable (~2s in
    /// total, inside the playbook's 1.5–3s), and it runs once per visit.
    private func build() async {
        let tasks = [
            OnboardingBuildTask(id: "answers", title: "Saving your answers"),
            OnboardingBuildTask(id: "alerts", title: "Choosing your alert settings"),
            OnboardingBuildTask(id: "dashboard", title: "Preparing your dashboard")
        ]
        buildTasks = tasks

        for task in tasks {
            setState(.running, for: task.id)
            let started = ContinuousClock.now
            await perform(task.id)
            let floor = Duration.milliseconds(520)
            let elapsed = ContinuousClock.now - started
            if elapsed < floor { try? await Task.sleep(for: floor - elapsed) }
            withAnimation(DS.Motion.bouncy) { setState(.done, for: task.id) }
        }

        try? await Task.sleep(for: .milliseconds(450))
        if step == .building { advance() }
    }

    private func perform(_ taskID: String) async {
        switch taskID {
        case "answers":
            store.profile = profile
        case "alerts":
            applyAlertPreferences()
        case "dashboard":
            // Warms the cache Home reads first, so the first screen after
            // sign-up arrives filled in rather than loading.
            _ = try? await dashboard.snapshot(forceRefresh: false)
        default:
            break
        }
    }

    /// Each headache turns on the alert that answers it.
    private func applyAlertPreferences() {
        if profile.headaches.contains(.lateRent) { preferences.notifyPayments = true }
        if profile.headaches.contains(.repairs) { preferences.notifyUrgentMaintenance = true }
        if profile.headaches.contains(.tenantMessages) { preferences.notifyMessages = true }
        if profile.headaches.contains(.findingTenants) { preferences.notifyLeaseEvents = true }
    }

    private func setState(_ state: OnboardingBuildTask.State, for id: String) {
        guard let i = buildTasks.firstIndex(where: { $0.id == id }) else { return }
        buildTasks[i].state = state
    }

    // MARK: Sign-Up

    func signUp() async -> SignInOutcome? {
        store.profile = profile
        return await auth.signUp()
    }

    func signIn(with provider: SocialProvider) async -> SignInOutcome? {
        store.profile = profile
        return await auth.signIn(with: provider)
    }
}
