//
//  AppEnvironment.swift
//  RentalApp (RentOS)
//
//  Core/Environment — Which deployment this build talks to.
//
//  ─────────────────────────────────────────────────────────────────
//  THE ENVIRONMENT IS A BUILD FACT, NOT A RUNTIME CHOICE
//  ─────────────────────────────────────────────────────────────────
//  A common shape is a global `var environment` someone can flip, or a
//  scattering of `#if DEBUG` at the point of use. Both fail the same
//  way: the answer to "which backend did this build talk to" becomes
//  unanswerable from the outside, which is exactly the question you
//  need answered when a crash report arrives from TestFlight.
//
//  So the environment is resolved once, from the build, and is
//  read-only thereafter. Every environment-dependent decision in the
//  app routes through this type rather than re-deriving the answer.
//
//  `#if DEBUG` is still used, but only for things that are genuinely
//  about the *compiler* (assertions, debug menus). Anything about
//  *deployment* — which URL, whether to upload crashes, whether to
//  sample analytics — asks this instead, because a Release build
//  pointed at staging is a real and normal thing.
//

import Foundation

// MARK: - Environment

enum AppEnvironment: String, Sendable, CaseIterable {

    case development
    case staging
    case production

    // MARK: Resolution

    /// The environment this build was compiled for.
    ///
    /// Read from the `APP_ENVIRONMENT` Info.plist key, which xcconfig
    /// populates per build configuration. Never traps: a missing value
    /// means someone added a build configuration and forgot the key, and
    /// that should not be fatal.
    ///
    /// The fallback splits on the BUILD, not on a single global guess, and
    /// the reason is worth recording because the first version of this got
    /// it wrong. It returned `.production` unconditionally, on the
    /// reasoning that production exposes the least debug surface. True in
    /// isolation — but `.production` is also the one environment that
    /// *refuses to launch* on missing configuration. So a fresh clone with
    /// no xcconfig resolved to production and then trapped in
    /// `AppConfiguration`, taking the app and every SwiftUI preview down
    /// before a single screen rendered. The safe-sounding default was the
    /// unrunnable one.
    ///
    /// Splitting on `DEBUG` keeps both properties:
    ///
    /// • A Debug build with no key is a developer's machine. `.development`
    ///   there means the app runs, previews work, and diagnostics stay
    ///   local.
    /// • A Release build with no key could be headed for the App Store, so
    ///   it still assumes `.production` — debug tools stay off, and a
    ///   genuinely misconfigured release still fails loudly rather than
    ///   shipping pointed at nothing.
    ///
    /// This is one of the few places `#if DEBUG` is the right tool: the
    /// question really is "how was this compiled", not "which backend".
    static let current: AppEnvironment = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String,
           let resolved = AppEnvironment(rawValue: raw.trimmingCharacters(in: .whitespaces).lowercased()) {
            return resolved
        }

        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()

    // MARK: Behaviour

    /// Whether this build may expose developer affordances: the flag
    /// override screen, the environment badge, verbose logging.
    ///
    /// Deliberately excludes staging-as-release: a staging build handed to
    /// a beta tester should still show the debug menu, because that is the
    /// point of handing it to them.
    var allowsDebugTools: Bool {
        switch self {
        case .development, .staging: true
        case .production:            false
        }
    }

    /// Whether diagnostics should actually be transmitted.
    ///
    /// Development keeps them local — uploading crashes from a simulator
    /// running a debugger drowns the real signal from real users.
    var transmitsDiagnostics: Bool {
        switch self {
        case .development: false
        case .staging, .production: true
        }
    }

    /// Fraction of non-critical analytics events to keep.
    ///
    /// Production sampling is a cost and privacy decision, not a technical
    /// one: full-fidelity behavioural telemetry on every user is more data
    /// than this app has a reason to hold.
    var analyticsSampleRate: Double {
        switch self {
        case .development: 1.0
        case .staging:     1.0
        case .production:  0.25
        }
    }

    /// Shown in the debug badge. Not localized — it is a developer string.
    var badgeLabel: String {
        switch self {
        case .development: "DEV"
        case .staging:     "STAGING"
        case .production:  "PROD"
        }
    }

    var isProduction: Bool { self == .production }
}

// MARK: - Build Metadata

/// Facts about *this binary*, as opposed to the environment it targets.
///
/// Separated from `AppEnvironment` because they answer different
/// questions: the environment is "which backend", this is "which build".
/// Crash reports need both, and conflating them makes it impossible to
/// tell a stale TestFlight build from a misconfigured one.
struct BuildInfo: Sendable, Equatable {

    /// Marketing version, e.g. "1.2.0".
    let version: String
    /// Build number, e.g. "184".
    let build: String
    let bundleIdentifier: String
    /// True when a debugger may be attached and assertions are live.
    let isDebugBuild: Bool

    static let current: BuildInfo = {
        let info = Bundle.main.infoDictionary
        return BuildInfo(
            version: info?["CFBundleShortVersionString"] as? String ?? "0.0.0",
            build: info?["CFBundleVersion"] as? String ?? "0",
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
            isDebugBuild: {
                #if DEBUG
                true
                #else
                false
                #endif
            }()
        )
    }()

    /// "1.2.0 (184)" — the form used in crash reports and the settings
    /// footer, so a user reading it aloud gives support something usable.
    var displayVersion: String { "\(version) (\(build))" }

    /// Sortable identity for grouping crash reports.
    var releaseIdentifier: String { "\(bundleIdentifier)@\(version)+\(build)" }
}
