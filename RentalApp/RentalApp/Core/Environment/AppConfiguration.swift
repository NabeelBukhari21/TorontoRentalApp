//
//  AppConfiguration.swift
//  RentalApp (Purrperty)
//
//  Core/Environment — Every configured value, read once, typed.
//
//  ─────────────────────────────────────────────────────────────────
//  ONE PLACE THAT TOUCHES Info.plist
//  ─────────────────────────────────────────────────────────────────
//  `Bundle.main.object(forInfoDictionaryKey:)` returns `Any?`. Every
//  call site that does its own lookup invents its own answer to "what
//  if it's missing", and they disagree — one traps, one defaults, one
//  silently uses "". The result is a build that half-works.
//
//  This type performs every lookup, at launch, with one policy per
//  value: required values trap immediately, optional values state
//  their default. If the app launches, its configuration is valid;
//  there is no third state where it runs but is misconfigured.
//
//  Reading configuration is also the one place a "fail fast" trap is
//  genuinely correct. A missing API URL cannot be recovered from at
//  runtime, and the alternative — a nil that propagates until some
//  unrelated screen shows "Something went wrong" — costs far more to
//  diagnose than a crash on the developer's machine.
//

import Foundation
import OSLog

// MARK: - Configuration

struct AppConfiguration: Sendable {

    let environment: AppEnvironment
    let build: BuildInfo

    /// Base URL for the backend. Supabase-derived today, but expressed
    /// separately so a future non-Supabase service does not require
    /// rewriting every caller.
    let apiBaseURL: URL

    /// Where diagnostics (crash reports, breadcrumbs) are POSTed.
    /// Nil disables upload entirely — the development default.
    let diagnosticsEndpoint: URL?

    /// Public legal documents. Versioned separately from the app so a
    /// policy change does not require a release.
    let termsURL: URL
    let privacyPolicyURL: URL
    let supportEmail: String

    /// The custom scheme registered for deep links and OAuth callbacks.
    let urlScheme: String

    // MARK: Resolution

    static let current = AppConfiguration()

    private init() {
        let environment = AppEnvironment.current
        self.environment = environment
        self.build = .current

        let bundle = Bundle.main

        // Derived from the Supabase URL rather than configured twice.
        // Two independently-configured URLs that must agree is a
        // misconfiguration waiting to happen.
        //
        // Not fatal outside production. `AppConfiguration` is built by the
        // container for EVERY graph, including the in-memory one that
        // talks to no backend at all — trapping here would make the mock
        // graph unlaunchable without Supabase credentials, which defeats
        // the point of having a mock graph. Production still refuses to
        // launch misconfigured, and `SupabaseClientProvider` still traps
        // at the point where the URL is actually needed.
        self.apiBaseURL = Self.resolvedAPIBaseURL(bundle: bundle, environment: environment)

        // Optional by design: a build with no endpoint keeps crash
        // reports on disk, which is exactly what development wants.
        self.diagnosticsEndpoint = Self.optionalURL("DIAGNOSTICS_URL", bundle: bundle)

        self.termsURL = Self.optionalURL("TERMS_URL", bundle: bundle)
            ?? URL(string: "https://rentos.ca/terms")!
        self.privacyPolicyURL = Self.optionalURL("PRIVACY_URL", bundle: bundle)
            ?? URL(string: "https://rentos.ca/privacy")!

        self.supportEmail = Self.optionalString("SUPPORT_EMAIL", bundle: bundle)
            ?? "support@rentos.ca"

        self.urlScheme = Self.optionalString("APP_URL_SCHEME", bundle: bundle) ?? "rentos"
    }

    // MARK: Lookup

    /// Present, non-empty, and not an unexpanded `$(VAR)` placeholder.
    ///
    /// That last check matters more than it looks: an xcconfig variable
    /// that was never defined expands to the literal text `$(NAME)`, so
    /// a naive non-empty check passes and the app then tries to reach a
    /// host literally called `$(SUPABASE_URL)`.
    private static func optionalString(_ key: String, bundle: Bundle) -> String? {
        guard
            let raw = bundle.object(forInfoDictionaryKey: key) as? String
        else { return nil }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }

    private static func optionalURL(_ key: String, bundle: Bundle) -> URL? {
        guard let raw = optionalString(key, bundle: bundle) else { return nil }
        guard let url = URL(string: raw), url.scheme?.hasPrefix("http") == true else {
            return nil
        }
        return url
    }

    /// Resolves the backend URL, trapping only where a wrong answer would
    /// actually ship.
    private static func resolvedAPIBaseURL(
        bundle: Bundle,
        environment: AppEnvironment
    ) -> URL {
        if let url = optionalURL("SUPABASE_URL", bundle: bundle) {
            guard url.scheme == "https" || environment != .production else {
                fatalError("SUPABASE_URL must use https in production. Got: \(url.scheme ?? "nil")")
            }
            return url
        }

        guard environment != .production else {
            fatalError(
                """
                Missing or malformed SUPABASE_URL.

                Expected an https URL in Info.plist, populated from
                RentalApp/Supabase.xcconfig. See supabase/README.md and
                RELEASE_CHECKLIST.md for the full list of required keys.
                """
            )
        }

        // Development and staging carry on with an unreachable placeholder.
        // Anything that genuinely needs the backend fails at the request,
        // with a clear error, instead of taking the whole app down at launch.
        AppLog.app.error(
            "SUPABASE_URL not configured — using a placeholder. Backend calls will fail."
        )
        return URL(string: "https://unconfigured.invalid")!
    }
}

// MARK: - Diagnostics Description

extension AppConfiguration {

    /// A redacted summary safe to attach to a crash report or show in a
    /// support screen.
    ///
    /// Note what is *absent*: no anon key, no endpoint credentials, no
    /// user identity. A configuration dump is a classic accidental
    /// secret-disclosure path — someone screenshots it into a support
    /// ticket — so the safe subset is defined here rather than left to
    /// whoever writes the support screen.
    var redactedSummary: [String: String] {
        [
            "environment": environment.rawValue,
            "version": build.displayVersion,
            "bundle": build.bundleIdentifier,
            "api_host": apiBaseURL.host ?? "unknown",
            "diagnostics": diagnosticsEndpoint == nil ? "disabled" : "enabled"
        ]
    }
}
