//
//  OnboardingFlowViewModel.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Hook → Personalise → Sign up.
//
//  Follows docs/ONBOARDING_PLAYBOOK.md §1: a welcome and a short fly-over
//  of what the app does, then a short
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
    /// The cover: the name, drifting feature cards, the paw button.
    case welcome
    /// The fly-over video of the app at work.
    case intro
    case persona
    case units
    case headaches
    case goal
    case personalize
    case building
    case unlocked
    case signUp

    /// Steps where going back makes sense. The building step is a moment,
    /// not a form, and the welcome and fly-over are the start.
    var allowsBack: Bool {
        switch self {
        case .welcome, .intro, .building: false
        default: true
        }
    }

    /// The welcome and fly-over are the cover; the questions show progress.
    var showsProgress: Bool { !isFullScreen }

    /// Drawn edge to edge, without the navigation bar or bottom bar.
    var isFullScreen: Bool { self == .welcome || self == .intro }
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

    private(set) var step: OnboardingStep = .welcome
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
            return [.welcome, .intro, .persona, .personalize, .signUp]
        }
        return OnboardingStep.allCases
    }

    private var index: Int { steps.firstIndex(of: step) ?? 0 }

    /// The steps that count toward progress: everything after the cover.
    private var questionSteps: [OnboardingStep] { steps.filter(\.showsProgress) }
    private var questionIndex: Int { questionSteps.firstIndex(of: step) ?? 0 }

    /// Starts at ~10% on the first question so the bar already feels
    /// under way (playbook §5, endowed progress).
    var progress: Double {
        let questions = Double(max(questionSteps.count - 1, 1))
        return 0.1 + 0.9 * Double(questionIndex) / questions
    }

    /// "Step 3 of 7" — the welcome and fly-over aren't counted.
    var stepLabel: String {
        "Step \(questionIndex + 1) of \(questionSteps.count)"
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
        // Tenants have nothing to build; for them this leads to sign-up.
        case .personalize: steps.contains(.building) ? "Build my Purrperty" : "Continue"
        case .unlocked:    "Save my setup"
        default:           "Continue"
        }
    }

    // MARK: Purr

    /// Purr acts out each step, and then the answer itself.
    var mascotMood: PurrMood {
        switch step {
        case .welcome: .welcome
        case .intro: .dashboard
        case .persona:
            switch profile.persona {
            case nil: .assistantThinking
            case .landlord: .keysReady
            case .propertyManager: .superhero
            case .tenant: .moveInDay
            }
        case .units:
            switch profile.unitRange {
            case nil: .properties
            case .one: .favourited
            case .twoToFive: .keysReady
            case .sixToTwenty: .fullyOccupied
            case .twentyPlus: .royalWave
            }
        case .headaches: headacheMood
        case .goal:
            switch profile.goal {
            case nil: .assistantIdea
            case .saveTime: .meditate
            case .getPaidOnTime: .moneyDance
            case .fewerVacancies: .victoryLap
            }
        case .personalize:
            switch preferences.theme {
            case .system: .appearance
            case .light: .goodMorning
            case .dark: .stargazing
            }
        case .building: .builder
        case .unlocked: .partyTime
        case .signUp: .signUp
        }
    }

    /// Every combination of headaches gets its own act (31 of them), so
    /// each tap changes Purr. All stay on his feet and in the frame.
    private var headacheMood: PurrMood {
        let picked = OnboardingHeadache.allCases.filter(profile.headaches.contains)
        return switch picked {
        case []: .begging
        // One
        case [.lateRent]: .rentOverdue
        case [.repairs]: .builder
        case [.tenantMessages]: .askQuestion
        case [.paperwork]: .analytics
        case [.findingTenants]: .vacancy
        // Two
        case [.lateRent, .repairs]: .paymentFailed
        case [.lateRent, .tenantMessages]: .loginFailed
        case [.lateRent, .paperwork]: .freezing
        case [.lateRent, .findingTenants]: .revenueDown
        case [.repairs, .tenantMessages]: .hiccups
        case [.repairs, .paperwork]: .assistantConfused
        case [.repairs, .findingTenants]: .rainyDay
        case [.tenantMessages, .paperwork]: .typing
        case [.tenantMessages, .findingTenants]: .notFound
        case [.paperwork, .findingTenants]: .sneeze
        // Three
        case [.lateRent, .repairs, .tenantMessages]: .inProgress
        case [.lateRent, .repairs, .paperwork]: .yogaStretch
        case [.lateRent, .repairs, .findingTenants]: .peekaboo
        case [.lateRent, .tenantMessages, .paperwork]: .blankStare
        case [.lateRent, .tenantMessages, .findingTenants]: .favouriteTaken
        case [.lateRent, .paperwork, .findingTenants]: .permissionDenied
        case [.repairs, .tenantMessages, .paperwork]: .drumRoll
        case [.repairs, .tenantMessages, .findingTenants]: .shakeDry
        case [.repairs, .paperwork, .findingTenants]: .karateChop
        case [.tenantMessages, .paperwork, .findingTenants]: .laughCrying
        // Four
        case [.lateRent, .repairs, .tenantMessages, .paperwork]: .boxing
        case [.lateRent, .repairs, .tenantMessages, .findingTenants]: .shocked
        case [.lateRent, .repairs, .paperwork, .findingTenants]: .error
        case [.lateRent, .tenantMessages, .paperwork, .findingTenants]: .workout
        case [.repairs, .tenantMessages, .paperwork, .findingTenants]: .sleepwalk
        // All five
        default: .tantrum
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
                : headacheLine
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

    private var headacheLine: String {
        switch profile.headaches.count {
        case 1: "Ugh, I know. I'll take that off your plate."
        case 2: "Two at once? I've got four paws."
        case 3: "Three! No wonder you need a cat."
        case 4: "Four headaches… hand them over."
        default: "All of it? Deep breath. I'm on it."
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
        // Back from the first question is the welcome, not a replay of
        // the fly-over.
        if previous == .intro { previous = .welcome }
        move(to: previous, forward: false)
    }

    /// The fly-over ended, watched through or skipped.
    func finishIntro(skipped: Bool) {
        guard step == .intro else { return }
        Task { await analytics.track(.onboardingIntroFinished(skipped: skipped)) }
        advance()
    }

    private func move(to next: OnboardingStep, forward: Bool) {
        movesForward = forward
        if next == .building { buildTasks = [] }
        withAnimation(DS.Motion.scene) { step = next }
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

        // Long enough for the liquid to reach the top.
        try? await Task.sleep(for: .milliseconds(800))
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
