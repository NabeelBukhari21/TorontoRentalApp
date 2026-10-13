//
//  Entitlements.swift
//  RentalApp (Purrperty)
//
//  Core/Commerce — What the user is allowed to do.
//
//  ─────────────────────────────────────────────────────────────────
//  THE APP ASKS ABOUT CAPABILITIES, NOT PRODUCTS
//  ─────────────────────────────────────────────────────────────────
//  The mistake to avoid is `if subscription.productID == "pro_monthly"`
//  scattered through feature code. It hardcodes the price list into the
//  UI, so introducing an annual plan, a trial, a grandfathered tier or
//  a regional SKU means finding every one of those checks.
//
//  Features ask "may I do this?" (`entitlements.allows(.unlimitedProperties)`)
//  and one place maps products to capabilities. Adding a SKU becomes a
//  change in that one map.
//
//  ─────────────────────────────────────────────────────────────────
//  THE CLIENT IS NOT THE AUTHORITY
//  ─────────────────────────────────────────────────────────────────
//  StoreKit 2's `Transaction.currentEntitlements` is cryptographically
//  verified by the OS, which is genuinely strong — far better than the
//  old receipt-parsing world. But it establishes what *Apple* thinks
//  this Apple ID owns; it is still client-side state on a device the
//  user controls, and RLS on the server cannot see it.
//
//  So this drives *UI*: which buttons appear, what the paywall says.
//  Any server-side limit — how many properties a plan may store — has
//  to be enforced in Postgres, exactly like every other rule in this
//  app. The same principle as everywhere else here: never trust the
//  client. That server-side enforcement is NOT yet written; see the
//  note at the bottom.
//

import Foundation
import Observation
import OSLog

// MARK: - Capability

/// A thing the app can do that a plan might gate.
///
/// Named for the user-visible capability, not the plan. `.aiAssistant`
/// survives a repackaging; `.proTierFeature` does not.
enum Entitlement: String, Sendable, CaseIterable {

    case unlimitedProperties
    case aiAssistant
    case advancedAnalytics
    case teamMembers
    case documentStorage
    case prioritySupport
    case dataExport

    var title: String {
        switch self {
        case .unlimitedProperties: "Unlimited properties"
        case .aiAssistant:         "AI assistant"
        case .advancedAnalytics:   "Advanced analytics"
        case .teamMembers:         "Team members"
        case .documentStorage:     "Expanded document storage"
        case .prioritySupport:     "Priority support"
        case .dataExport:          "Data export"
        }
    }
}

// MARK: - Tier

enum SubscriptionTier: String, Sendable, CaseIterable, Comparable {

    case free
    case starter
    case professional
    case enterprise

    /// Everything the tier grants. The single source of truth for what
    /// a plan means.
    var entitlements: Set<Entitlement> {
        switch self {
        case .free:
            // Data export is free deliberately. Charging to get your own
            // data out is hostile, and in several jurisdictions the right
            // to portability is not something a paywall may gate.
            [.dataExport]
        case .starter:
            [.dataExport, .documentStorage]
        case .professional:
            [.dataExport, .documentStorage, .unlimitedProperties,
             .aiAssistant, .advancedAnalytics]
        case .enterprise:
            Set(Entitlement.allCases)
        }
    }

    /// Limits for the free tier. Enforced server-side too — this copy
    /// exists so the UI can warn *before* a write fails.
    var propertyLimit: Int? {
        switch self {
        case .free:         3
        case .starter:      15
        case .professional: nil
        case .enterprise:   nil
        }
    }

    var displayName: String {
        switch self {
        case .free:         "Free"
        case .starter:      "Starter"
        case .professional: "Professional"
        case .enterprise:   "Enterprise"
        }
    }

    private var rank: Int {
        switch self {
        case .free: 0
        case .starter: 1
        case .professional: 2
        case .enterprise: 3
        }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rank < rhs.rank
    }
}

// MARK: - Status

enum SubscriptionStatus: Sendable, Equatable {

    case unknown
    case none
    case active(tier: SubscriptionTier, expiresAt: Date?)
    /// Renewal failed; Apple is retrying. Access continues during this
    /// window — revoking immediately on a card that will succeed on
    /// retry punishes the user for their bank's timing.
    case gracePeriod(tier: SubscriptionTier, until: Date)
    case expired(tier: SubscriptionTier)
    case revoked

    var tier: SubscriptionTier {
        switch self {
        case .active(let tier, _):     tier
        case .gracePeriod(let tier, _): tier
        case .unknown, .none, .expired, .revoked: .free
        }
    }

    /// `.unknown` deliberately resolves to free rather than to the last
    /// known tier. Before StoreKit answers, granting paid access would
    /// make "quit before the check completes" a bypass.
    var isEntitled: Bool {
        switch self {
        case .active, .gracePeriod: true
        case .unknown, .none, .expired, .revoked: false
        }
    }
}

// MARK: - Provider

/// The StoreKit seam.
///
/// Protocol so the app can be built, previewed and tested with no
/// StoreKit configuration at all — which matters, because StoreKit
/// testing requires a configured product list and App Store Connect
/// entries that do not exist yet.
protocol SubscriptionProviding: Sendable {
    func currentStatus() async -> SubscriptionStatus
    func availableProducts() async throws -> [SubscriptionProduct]
    func purchase(_ product: SubscriptionProduct) async throws -> SubscriptionStatus
    func restorePurchases() async throws -> SubscriptionStatus
    /// Emits when a transaction arrives from outside the app — a renewal,
    /// a family-sharing grant, an Ask-to-Buy approval, a refund.
    func statusUpdates() -> AsyncStream<SubscriptionStatus>
}

struct SubscriptionProduct: Sendable, Identifiable, Equatable {

    enum BillingPeriod: String, Sendable {
        case month
        case year

        var months: Int { self == .year ? 12 : 1 }
    }

    let id: String
    let tier: SubscriptionTier
    let displayName: String
    /// Already localized by StoreKit. Never format currency yourself —
    /// StoreKit knows the storefront, the locale and the tax treatment.
    let displayPrice: String
    /// The raw price, for comparisons only (savings, per-week breakdowns).
    /// Display it through `formatted(_:)`, which uses the storefront's
    /// currency.
    let price: Decimal
    let currencyCode: String
    let billingPeriod: BillingPeriod
    /// Free-trial length, when the product has an introductory offer.
    let trialDays: Int?

    var period: String { billingPeriod.rawValue }

    var introductoryOffer: String? {
        trialDays.map { "\($0) days free" }
    }

    /// The price spread over a week, e.g. for "≈ $6.92 a week".
    var pricePerWeek: Decimal {
        let weeks: Decimal = billingPeriod == .year ? 52 : Decimal(52) / 12
        return price / weeks
    }

    /// The price spread over a month.
    var pricePerMonth: Decimal {
        price / Decimal(billingPeriod.months)
    }

    func formatted(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode))
    }
}

// MARK: - Store

@MainActor
@Observable
final class EntitlementStore {

    private(set) var status: SubscriptionStatus = .unknown
    private(set) var products: [SubscriptionProduct] = []
    private(set) var isLoading = false
    private(set) var lastError: AppError?

    private let provider: SubscriptionProviding
    private let flags: FeatureFlagStore
    private var updateTask: Task<Void, Never>?

    init(provider: SubscriptionProviding, flags: FeatureFlagStore) {
        self.provider = provider
        self.flags = flags
    }

    // No `deinit`. `updateTask` is main-actor-isolated stored state, and a
    // `deinit` on a @MainActor class may not touch it — the same error that
    // forced the AsyncListModel deinit out during the architecture pass.
    //
    // Nothing is leaked: the task captures `self` weakly and its loop exits
    // when the stream finishes, and this store lives as long as the
    // container anyway.

    // MARK: Query

    /// The question feature code asks.
    ///
    /// Returns true for everything while the paywall is not enforced, so
    /// the app is fully usable before any products exist. That is the
    /// correct default for an unreleased commerce layer — and it is a
    /// flag, so turning it on is a deliberate act rather than a
    /// consequence of shipping this file.
    func allows(_ entitlement: Entitlement) -> Bool {
        guard flags.isEnabled(.paywallEnforced) else { return true }
        return status.tier.entitlements.contains(entitlement)
    }

    /// Whether a limited resource has room left. Nil means unlimited.
    func remainingProperties(current: Int) -> Int? {
        guard flags.isEnabled(.paywallEnforced) else { return nil }
        guard let limit = status.tier.propertyLimit else { return nil }
        return max(0, limit - current)
    }

    var tier: SubscriptionTier { status.tier }

    // MARK: Lifecycle

    func start() async {
        await refresh()
        observeUpdates()
    }

    func refresh() async {
        guard flags.isEnabled(.subscriptionsEnabled) else {
            status = .none
            return
        }

        isLoading = true
        defer { isLoading = false }

        status = await provider.currentStatus()

        do {
            products = try await provider.availableProducts()
        } catch {
            // Products failing to load is not an entitlement failure.
            // Someone who has already paid keeps their access; they just
            // cannot see the upgrade options right now.
            lastError = AppError.from(error)
            AppLog.commerce.failure("Could not load products", error: error)
        }
    }

    /// Listens for transactions arriving outside a purchase flow.
    ///
    /// Required by StoreKit 2, not optional: renewals, Ask-to-Buy
    /// approvals and refunds all arrive here. An app that only updates
    /// entitlements inside `purchase()` will show a lapsed subscriber as
    /// active until they relaunch.
    private func observeUpdates() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            guard let self else { return }
            for await update in self.provider.statusUpdates() {
                guard !Task.isCancelled else { return }
                self.status = update
                AppLog.commerce.notice(
                    "Subscription status → \(update.tier.rawValue, privacy: .public)"
                )
            }
        }
    }

    // MARK: Purchase

    func purchase(_ product: SubscriptionProduct) async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            status = try await provider.purchase(product)
            return status.isEntitled
        } catch {
            lastError = AppError.from(error)
            return false
        }
    }

    /// Restore. App Review rejects apps offering non-consumable or
    /// subscription purchases without a restore path, so this is a
    /// submission requirement, not a nicety.
    func restore() async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            status = try await provider.restorePurchases()
            return status.isEntitled
        } catch {
            lastError = AppError.from(error)
            return false
        }
    }
}

// MARK: - Mock Provider

/// Used until StoreKit products exist.
///
/// Reports `.none` rather than a generous fake tier: a mock that grants
/// everything hides every paywall bug until the day real products are
/// switched on.
struct MockSubscriptionProvider: SubscriptionProviding {

    var simulatedStatus: SubscriptionStatus = .none

    func currentStatus() async -> SubscriptionStatus { simulatedStatus }

    func availableProducts() async throws -> [SubscriptionProduct] {
        // Placeholder prices until App Store Connect products exist.
        // Product IDs keep the stable `ca.rentos.*` prefix.
        [
            Self.product("ca.rentos.professional.yearly", .professional, "Premium", 359.99, .year, trial: 14),
            Self.product("ca.rentos.professional.monthly", .professional, "Premium", 49.99, .month, trial: 14),
            Self.product("ca.rentos.starter.yearly", .starter, "Starter", 143.99, .year, trial: 14),
            Self.product("ca.rentos.starter.monthly", .starter, "Starter", 19.99, .month, trial: 14)
        ]
    }

    func purchase(_ product: SubscriptionProduct) async throws -> SubscriptionStatus {
        .active(tier: product.tier, expiresAt: Date().addingTimeInterval(30 * 86_400))
    }

    private static func product(
        _ id: String,
        _ tier: SubscriptionTier,
        _ name: String,
        _ price: Decimal,
        _ period: SubscriptionProduct.BillingPeriod,
        trial: Int?
    ) -> SubscriptionProduct {
        SubscriptionProduct(
            id: id,
            tier: tier,
            displayName: name,
            displayPrice: price.formatted(.currency(code: "CAD")),
            price: price,
            currencyCode: "CAD",
            billingPeriod: period,
            trialDays: trial
        )
    }

    func restorePurchases() async throws -> SubscriptionStatus { simulatedStatus }

    func statusUpdates() -> AsyncStream<SubscriptionStatus> {
        AsyncStream { $0.finish() }
    }
}

// MARK: - Before Enabling Commerce
//
// This layer is deliberately inert. Before flipping `subscriptionsEnabled`:
//
// 1. WRITE THE SERVER-SIDE ENFORCEMENT FIRST. Nothing in this file is a
//    security boundary. The property limit needs to be a Postgres check
//    against the org's plan, or a determined user simply edits their
//    entitlement locally and keeps writing rows.
//
// 2. IMPLEMENT StoreKitSubscriptionProvider. Use StoreKit 2's
//    `Transaction.currentEntitlements` and `Transaction.updates` — never
//    parse a receipt by hand, and never send the receipt to your own
//    server to validate with the deprecated verifyReceipt endpoint.
//
// 3. HANDLE THE UNFINISHED TRANSACTION CASE. A transaction not marked
//    `finish()` is redelivered forever, which presents as a purchase
//    loop the user cannot escape.
//
// 4. USE App Store Server Notifications V2 for the authoritative
//    lifecycle. Client polling misses refunds, which is how a refunded
//    user keeps paid access indefinitely.
//
// 5. CHECK REVIEW REQUIREMENTS: a visible restore control, terms and
//    privacy links on the paywall, and the auto-renew disclosure. Each
//    is an individually sufficient reason for rejection.
