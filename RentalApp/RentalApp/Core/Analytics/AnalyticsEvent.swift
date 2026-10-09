//
//  AnalyticsEvent.swift
//  RentalApp (RentOS)
//
//  Core/Analytics — The closed set of things this app measures.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY EVENTS ARE TYPES
//  ─────────────────────────────────────────────────────────────────
//  The previous API was `track(_ event: String, properties: [String: String])`.
//  Three problems, all of which show up eventually in every codebase
//  that ships that signature:
//
//  1. Adding an event is invisible in review. `track("x", ["email": e])`
//     is one line in an unrelated diff and there is no type to notice.
//  2. Event names drift. "signed_in", "sign_in", "user_signed_in" all
//     coexist and the funnel silently splits.
//  3. `[String: String]` accepts anything a `String` can hold, which is
//     to say a tenant's name, a full address, or a message body.
//
//  Making events an enum fixes all three: the vocabulary is finite and
//  greppable, names are generated from cases so they cannot drift, and
//  the parameters each case can carry are declared here where a reviewer
//  is looking at privacy rather than at the feature they came to review.
//
//  ─────────────────────────────────────────────────────────────────
//  THE PARAMETER TYPE IS THE PRIVACY CONTROL
//  ─────────────────────────────────────────────────────────────────
//  `AnalyticsValue` cannot hold free-form user text. Not "should not" —
//  cannot: there is no case that takes an arbitrary `String`. Anything
//  user-authored has to be reduced to a count, a bucket, a boolean, or
//  an enum before it can be attached to an event, and doing that
//  reduction is what makes it safe.
//

import Foundation

// MARK: - Values

/// A value that may be attached to an analytics event.
///
/// The deliberate absence of a `case text(String)` is the whole design.
/// Adding one would defeat every guarantee in this file, so if a future
/// event seems to need it, the answer is a new `enumerated` case with a
/// closed set of options, not an escape hatch.
enum AnalyticsValue: Sendable, Equatable {

    case count(Int)
    case flag(Bool)
    case duration(TimeInterval)

    /// A value drawn from a fixed set the app itself defines — a role, a
    /// status, a screen name. Safe because the set is enumerable in
    /// source; unsafe if anyone passes a server string through it, which
    /// is why the initialiser takes a `RawRepresentable` rather than a
    /// `String`.
    case enumerated(String)

    /// A magnitude reduced to a bucket. `12 properties` becomes "11-50",
    /// which answers "do power users behave differently" without
    /// tending toward identifying a specific portfolio.
    case bucket(String)

    init<T: RawRepresentable>(_ value: T) where T.RawValue == String {
        self = .enumerated(value.rawValue)
    }

    /// Buckets a magnitude on a coarse log-ish scale.
    ///
    /// Coarse on purpose. In a market the size of Toronto, "owns 47
    /// properties" is close to a name; "owns 11-50" is not.
    static func bucketed(_ value: Int) -> AnalyticsValue {
        switch value {
        case ..<0:      .bucket("invalid")
        case 0:         .bucket("0")
        case 1:         .bucket("1")
        case 2...5:     .bucket("2-5")
        case 6...10:    .bucket("6-10")
        case 11...50:   .bucket("11-50")
        case 51...200:  .bucket("51-200")
        default:        .bucket("200+")
        }
    }

    var stringValue: String {
        switch self {
        case .count(let value):      String(value)
        case .flag(let value):       value ? "true" : "false"
        case .duration(let value):   String(format: "%.3f", value)
        case .enumerated(let value): value
        case .bucket(let value):     value
        }
    }
}

// MARK: - Events

/// Every event RentOS emits.
///
/// Grouped by area. Adding a case is the *only* way to add an event,
/// which makes "what do we collect?" answerable by reading one file —
/// the question a privacy review, an App Store privacy label, and a
/// customer's DSAR all start from.
enum AnalyticsEvent: Sendable, Equatable {

    // Lifecycle
    case appLaunched(coldStart: Bool)
    case sessionRestored(role: AppRole)

    // Authentication
    case signedIn(role: AppRole, method: SignInMethod)
    case signedOut
    case signUpCompleted(role: AppRole)
    case mfaChallenged
    case mfaVerified(succeeded: Bool)
    case onboardingCompleted

    // Organization
    case organizationCreated(portfolioSize: Int)
    case memberInvited(count: Int)

    // Portfolio
    case propertyCreated
    case propertyUpdated
    case propertyArchived
    case unitCreated
    case tenantCreated
    case leaseCreated

    // Operations
    case maintenanceTicketCreated(priority: String)
    case maintenanceStatusChanged(to: String)
    case documentUploaded(sizeBucket: String)
    case messageSent

    // Search
    case searchPerformed(resultBucket: String, hadResults: Bool)

    // AI
    case aiTaskRequested(capability: String)
    case aiProposalReviewed(approved: Bool)

    // Sync and reliability
    case syncConflictResolved(choice: String)
    case offlineWriteQueued
    case outboxDrained(count: Int)

    // Commerce
    case paywallPresented(source: String)
    case purchaseCompleted(productTier: String)
    case purchaseFailed(reason: String)

    // Screens
    case screenViewed(name: ScreenName)

    // MARK: Identity

    /// snake_case, derived mechanically so two cases cannot collide and
    /// a rename shows up as a compile error at every call site.
    var name: String {
        switch self {
        case .appLaunched:              "app_launched"
        case .sessionRestored:          "session_restored"
        case .signedIn:                 "signed_in"
        case .signedOut:                "signed_out"
        case .signUpCompleted:          "sign_up_completed"
        case .mfaChallenged:            "mfa_challenged"
        case .mfaVerified:              "mfa_verified"
        case .onboardingCompleted:      "onboarding_completed"
        case .organizationCreated:      "organization_created"
        case .memberInvited:            "member_invited"
        case .propertyCreated:          "property_created"
        case .propertyUpdated:          "property_updated"
        case .propertyArchived:         "property_archived"
        case .unitCreated:              "unit_created"
        case .tenantCreated:            "tenant_created"
        case .leaseCreated:             "lease_created"
        case .maintenanceTicketCreated: "maintenance_ticket_created"
        case .maintenanceStatusChanged: "maintenance_status_changed"
        case .documentUploaded:         "document_uploaded"
        case .messageSent:              "message_sent"
        case .searchPerformed:          "search_performed"
        case .aiTaskRequested:          "ai_task_requested"
        case .aiProposalReviewed:       "ai_proposal_reviewed"
        case .syncConflictResolved:     "sync_conflict_resolved"
        case .offlineWriteQueued:       "offline_write_queued"
        case .outboxDrained:            "outbox_drained"
        case .paywallPresented:         "paywall_presented"
        case .purchaseCompleted:        "purchase_completed"
        case .purchaseFailed:           "purchase_failed"
        case .screenViewed:             "screen_viewed"
        }
    }

    var parameters: [String: AnalyticsValue] {
        switch self {
        case .appLaunched(let coldStart):
            ["cold_start": .flag(coldStart)]
        case .sessionRestored(let role):
            ["role": AnalyticsValue(role)]
        case .signedIn(let role, let method):
            ["role": AnalyticsValue(role), "method": AnalyticsValue(method)]
        case .signUpCompleted(let role):
            ["role": AnalyticsValue(role)]
        case .mfaVerified(let succeeded):
            ["succeeded": .flag(succeeded)]
        case .organizationCreated(let portfolioSize):
            ["portfolio_size": .bucketed(portfolioSize)]
        case .memberInvited(let count):
            ["count": .bucketed(count)]
        case .maintenanceTicketCreated(let priority):
            ["priority": .enumerated(priority)]
        case .maintenanceStatusChanged(let status):
            ["to": .enumerated(status)]
        case .documentUploaded(let sizeBucket):
            ["size": .bucket(sizeBucket)]
        case .searchPerformed(let resultBucket, let hadResults):
            // Note what is absent: the query itself. A search box is the
            // single most reliable place to accidentally collect a
            // tenant's name or an address.
            ["results": .bucket(resultBucket), "had_results": .flag(hadResults)]
        case .aiTaskRequested(let capability):
            ["capability": .enumerated(capability)]
        case .aiProposalReviewed(let approved):
            ["approved": .flag(approved)]
        case .syncConflictResolved(let choice):
            ["choice": .enumerated(choice)]
        case .outboxDrained(let count):
            ["count": .bucketed(count)]
        case .paywallPresented(let source):
            ["source": .enumerated(source)]
        case .purchaseCompleted(let tier):
            ["tier": .enumerated(tier)]
        case .purchaseFailed(let reason):
            ["reason": .enumerated(reason)]
        case .screenViewed(let name):
            ["screen": AnalyticsValue(name)]
        case .signedOut, .mfaChallenged, .onboardingCompleted,
             .propertyCreated, .propertyUpdated, .propertyArchived,
             .unitCreated, .tenantCreated, .leaseCreated,
             .messageSent, .offlineWriteQueued:
            [:]
        }
    }

    // MARK: Priority

    /// Events exempt from sampling.
    ///
    /// Sampling a funnel step makes the funnel wrong, and sampling a
    /// purchase makes revenue reporting wrong. Everything else is
    /// volume, and volume is what sampling is for.
    var isCritical: Bool {
        switch self {
        case .signedIn, .signUpCompleted, .signedOut, .onboardingCompleted,
             .organizationCreated, .purchaseCompleted, .purchaseFailed,
             .paywallPresented:
            true
        default:
            false
        }
    }
}

// MARK: - Supporting Enumerations

enum SignInMethod: String, Sendable {
    case password
    case biometric
    case restoredSession
    case magicLink
}

/// Screen names as a closed set.
///
/// The alternative — passing `String(describing: type(of: self))` — ties
/// the analytics vocabulary to Swift type names, so renaming a view
/// silently breaks a dashboard nobody will connect to the rename.
enum ScreenName: String, Sendable, CaseIterable {
    case dashboard
    case properties
    case propertyDetail
    case tenants
    case tenantDetail
    case maintenance
    case maintenanceDetail
    case messages
    case chat
    case documents
    case aiAssistant
    case notifications
    case search
    case settings
    case paywall
}
