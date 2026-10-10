//
//  FeatureFlag.swift
//  RentalApp (Purrperty)
//
//  Core/FeatureFlags — What is switched on, and who decides.
//
//  ─────────────────────────────────────────────────────────────────
//  THE COMPILED-IN DEFAULT IS THE CONTRACT
//  ─────────────────────────────────────────────────────────────────
//  Remote config drifts toward being an untyped RPC channel: someone
//  adds a key server-side, someone reads it by string in one screen,
//  and now the app's behaviour is defined in a database nobody
//  versions alongside the code.
//
//  The rule here is that flags are declared in Swift, with defaults, and
//  remote may only *override a flag that already exists*. An unknown
//  remote key is ignored and logged. So the set of things that can vary
//  is fixed at compile time, and the worst a bad remote payload can do
//  is toggle a switch that was already designed to be toggled.
//
//  ─────────────────────────────────────────────────────────────────
//  PRECEDENCE
//  ─────────────────────────────────────────────────────────────────
//      local override  (debug builds only)
//        ↓ falls back to
//      remote value    (if the flag is remotely controllable)
//        ↓ falls back to
//      compiled default
//
//  Local override sits on top so a developer can reproduce a bug
//  without touching shared config. It is unavailable in production —
//  not merely hidden, but not consulted — so a flag cannot be flipped
//  on a user's device by anything that manages to write to defaults.
//
//  ─────────────────────────────────────────────────────────────────
//  FLAGS ARE TEMPORARY
//  ─────────────────────────────────────────────────────────────────
//  Every flag carries an `introducedIn` version. A flag with no removal
//  plan is a permanent branch in the codebase, and permanent branches
//  are how a codebase becomes untestable: N flags mean 2^N behaviours,
//  of which you test one.
//

import Foundation

// MARK: - Flag

enum FeatureFlag: String, Sendable, CaseIterable, Codable {

    // Rollout — features shipping progressively.
    case aiCopilot              = "ai_copilot"
    case aiMaintenanceTriage    = "ai_maintenance_triage"
    case semanticSearch         = "semantic_search"
    case bulkPropertyActions    = "bulk_property_actions"

    // Kill switches — on by default, flipped off to stop the bleeding.
    // These are the flags that justify the whole system: shipping a fix
    // through review takes days, flipping one of these takes seconds.
    case realtimeSync           = "realtime_sync"
    case offlineWrites          = "offline_writes"
    case pushNotifications      = "push_notifications"

    // Commerce — off until StoreKit products exist.
    case subscriptionsEnabled   = "subscriptions_enabled"
    case paywallEnforced        = "paywall_enforced"

    // MARK: Metadata

    /// The value when nothing else says otherwise.
    ///
    /// Kill switches default ON because their normal state is working.
    /// Rollout flags default OFF because their normal state is not
    /// finished. Getting this backwards means an unfinished feature
    /// ships to everyone the first time remote config is unreachable.
    var defaultValue: Bool {
        switch self {
        case .realtimeSync, .offlineWrites, .pushNotifications:
            true
        case .aiCopilot, .aiMaintenanceTriage, .semanticSearch,
             .bulkPropertyActions, .subscriptionsEnabled, .paywallEnforced:
            false
        }
    }

    /// Whether the server may override this flag.
    ///
    /// `paywallEnforced` is deliberately excluded. A remotely flippable
    /// switch that grants or withholds paid functionality is both a
    /// revenue risk and an App Review problem — the reviewed build must
    /// behave the way it behaved when reviewed.
    var isRemotelyControllable: Bool {
        switch self {
        case .paywallEnforced: false
        default:               true
        }
    }

    var title: String {
        switch self {
        case .aiCopilot:            "AI Copilot"
        case .aiMaintenanceTriage:  "AI Maintenance Triage"
        case .semanticSearch:       "Semantic Search"
        case .bulkPropertyActions:  "Bulk Property Actions"
        case .realtimeSync:         "Realtime Sync"
        case .offlineWrites:        "Offline Writes"
        case .pushNotifications:    "Push Notifications"
        case .subscriptionsEnabled: "Subscriptions"
        case .paywallEnforced:      "Enforce Paywall"
        }
    }

    /// Version this flag appeared in, so stale flags are findable.
    /// Audit these at each release and delete the ones that have been
    /// fully on or fully off for two versions.
    var introducedIn: String { "1.0.0" }

    /// Turning this off must never lose user data or strand a queue.
    /// Consulted by the store, which refuses to disable them remotely
    /// while there is pending work.
    var isDataCritical: Bool {
        switch self {
        case .offlineWrites: true
        default:             false
        }
    }
}

// MARK: - Resolution Source

/// Where a flag's current value came from. Shown in the debug screen,
/// because "is this on?" is a much less useful question than "why?".
enum FlagSource: String, Sendable {
    case localOverride
    case remote
    case compiledDefault
}

struct FlagResolution: Sendable, Equatable {
    let value: Bool
    let source: FlagSource

    static func == (lhs: FlagResolution, rhs: FlagResolution) -> Bool {
        lhs.value == rhs.value && lhs.source == rhs.source
    }
}
