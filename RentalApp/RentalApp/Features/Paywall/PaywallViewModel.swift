//
//  PaywallViewModel.swift
//  RentalApp (Purrperty)
//
//  Paywall — The 3-step trial flow from docs/ONBOARDING_PLAYBOOK.md §6:
//
//      1. "Try Purrperty Premium free for 14 days", led by the outcomes
//         the user picked in the quiz.
//      2. "How your free trial works": today / reminder / trial ends.
//      3. Plan choice: Yearly (pre-selected) and Monthly side by side.
//
//  Soft by default — the close button is always there unless
//  `paywallEnforced` is on, and that flag can't be flipped remotely.
//  Every price, saving and per-week figure is computed from the
//  products StoreKit (or the mock) returns; nothing is hard-coded.
//

import SwiftUI
import Observation
import UserNotifications

enum PaywallStep: Int, CaseIterable {
    case intro
    case timeline
    case plans
}

@MainActor
@Observable
final class PaywallViewModel {

    // MARK: State

    private(set) var step: PaywallStep = .intro
    private(set) var movesForward = true
    var selectedPeriod: SubscriptionProduct.BillingPeriod = .year
    var remindsBeforeTrialEnds = true
    var showsAllPlans = false
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    // MARK: Dependencies

    let entitlements: EntitlementStore
    private let analytics: AnalyticsService
    private let profile: OnboardingProfile
    private let source: String
    let isDismissible: Bool

    init(
        entitlements: EntitlementStore,
        featureFlags: FeatureFlagStore,
        analytics: AnalyticsService,
        profile: OnboardingProfile,
        source: String
    ) {
        self.entitlements = entitlements
        self.analytics = analytics
        self.profile = profile
        self.source = source
        self.isDismissible = !featureFlags.isEnabled(.paywallEnforced)
    }

    // MARK: Products

    /// The tier the paywall leads with. Its yearly and monthly products
    /// are the only two on the base screen; "View all plans" can switch it.
    var featuredTier: SubscriptionTier = .professional

    /// The store's name for a tier ("Premium" for professional), falling
    /// back to the tier's own name before products load.
    func name(of tier: SubscriptionTier) -> String {
        entitlements.products.first { $0.tier == tier }?.displayName ?? tier.displayName
    }

    func product(_ tier: SubscriptionTier, _ period: SubscriptionProduct.BillingPeriod) -> SubscriptionProduct? {
        entitlements.products.first { $0.tier == tier && $0.billingPeriod == period }
    }

    var yearly: SubscriptionProduct? { product(featuredTier, .year) }
    var monthly: SubscriptionProduct? { product(featuredTier, .month) }

    var selectedProduct: SubscriptionProduct? {
        product(featuredTier, selectedPeriod) ?? yearly ?? monthly
    }

    var trialDays: Int { selectedProduct?.trialDays ?? yearly?.trialDays ?? 14 }

    /// Day the reminder goes out: two days before the trial ends.
    var reminderDay: Int { max(trialDays - 2, 1) }

    /// The real saving of yearly over twelve monthly payments, rounded
    /// down so the badge never overstates it.
    func savingsPercent(for tier: SubscriptionTier) -> Int? {
        guard let year = product(tier, .year), let month = product(tier, .month), month.price > 0 else { return nil }
        let fullYear = month.price * 12
        let saving = (fullYear - year.price) / fullYear * 100
        let floored = Int(NSDecimalNumber(decimal: saving).doubleValue.rounded(.down))
        return floored > 0 ? floored : nil
    }

    var isLoadingProducts: Bool { entitlements.products.isEmpty && entitlements.isLoading }

    // MARK: Outcomes

    /// What step 1 promises: the goal they chose first, then what their
    /// answers switched on. Falls back to the tier's benefits.
    var outcomes: [String] {
        var result: [String] = []
        if let goal = profile.goal { result.append(goal.outcome) }
        result += profile.unlocks.prefix(3).map(\.title)
        if result.isEmpty {
            result = featuredTier.entitlements.sorted { $0.title < $1.title }.prefix(4).map(\.title)
        }
        return result
    }

    // MARK: Navigation

    func onAppear() {
        Task { await analytics.track(.paywallPresented(source: source)) }
        if entitlements.products.isEmpty {
            Task { await entitlements.refresh() }
        }
    }

    func advance() {
        guard let next = PaywallStep(rawValue: step.rawValue + 1) else { return }
        movesForward = true
        withAnimation(DS.Motion.smooth) { step = next }
    }

    func goBack() {
        guard let previous = PaywallStep(rawValue: step.rawValue - 1) else { return }
        movesForward = false
        withAnimation(DS.Motion.smooth) { step = previous }
    }

    func dismissed() {
        Task { await analytics.track(.paywallDismissed(source: source)) }
    }

    // MARK: Purchase

    /// Returns true when the user ends up entitled.
    func startTrial() async -> Bool {
        guard let product = selectedProduct else { return false }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        let succeeded = await entitlements.purchase(product)
        if succeeded {
            Task { await analytics.track(.purchaseCompleted(productTier: product.tier.rawValue)) }
            if remindsBeforeTrialEnds, let days = product.trialDays {
                await TrialReminder.schedule(trialDays: days, reminderDay: reminderDay)
            }
        } else {
            // A closed vocabulary: an error's description can carry text
            // the analytics layer must never see.
            let reason = entitlements.lastError == nil ? "cancelled" : "error"
            Task { await analytics.track(.purchaseFailed(reason: reason)) }
            errorMessage = entitlements.lastError?.errorDescription
        }
        return succeeded
    }

    func restore() async -> Bool {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        let restored = await entitlements.restore()
        if !restored {
            errorMessage = entitlements.lastError?.errorDescription ?? "No previous purchase was found for this Apple ID."
        }
        return restored
    }
}

// MARK: - Trial Reminder

/// The "Day 12: we remind you" promise, kept with a local notification.
enum TrialReminder {

    static let identifier = "trial.reminder"

    /// Asks for permission if it hasn't been asked yet — the user just
    /// requested the reminder, which is the right moment (playbook §7).
    static func schedule(trialDays: Int, reminderDay: Int) async {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends in \(trialDays - reminderDay) days"
        content.body = "Keep Premium, or cancel in Settings before it renews. Purr won't mind."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(reminderDay) * 86_400,
            repeats: false
        )
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
