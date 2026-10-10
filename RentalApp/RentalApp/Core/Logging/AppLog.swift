//
//  AppLog.swift
//  RentalApp (Purrperty)
//
//  Core/Logging — Structured logging with redaction by default.
//
//  ─────────────────────────────────────────────────────────────────
//  THE DEFAULT MUST BE PRIVATE
//  ─────────────────────────────────────────────────────────────────
//  `os.Logger` already redacts interpolated values unless you opt out
//  with `privacy: .public`. That default is correct and this app was
//  overriding it: `ConsoleAnalyticsService` logged every analytics
//  property as `.public`, which meant any property anyone ever added —
//  a tenant name, an email, an address — was written in clear text to
//  the unified log, readable by anyone with the device and Console.app,
//  and captured in sysdiagnose bundles.
//
//  The rule here: `.public` is allowed only for values from a closed
//  set the code itself defines — an enum case, a state name, a count.
//  Anything derived from user data or server data stays private, which
//  is the default, which means the rule is mostly "don't write
//  `.public`".
//
//  Logging is also not analytics. Logs are for a developer reading a
//  device; analytics is a product measurement pipeline with consent
//  attached. Conflating them is how user data ends up somewhere nobody
//  audited. They are separate types here for that reason.
//

import Foundation
import OSLog

// MARK: - Categories

/// The log categories, fixed at compile time.
///
/// A closed set rather than free-form strings so `log show --category`
/// has a documented vocabulary, and so a typo cannot silently create a
/// category nobody ever filters on.
enum LogCategory: String, Sendable, CaseIterable {
    case app          = "app"
    case auth         = "auth"
    case network      = "network"
    case database     = "database"
    case sync         = "sync"
    case offline      = "offline"
    case notifications = "notifications"
    case ai           = "ai"
    case ui           = "ui"
    case commerce     = "commerce"
    case diagnostics  = "diagnostics"
    case privacy      = "privacy"
}

// MARK: - Log

/// Namespace for the app's loggers.
///
/// `Logger` instances are cheap but not free, and creating one per call
/// site loses the ability to filter. One per category, created once.
enum AppLog {

    /// Reverse-DNS subsystem, matching the bundle identifier so Console
    /// groups this app's output with its process.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "ca.rentos.app"

    private static let loggers: [LogCategory: Logger] = {
        var result: [LogCategory: Logger] = [:]
        for category in LogCategory.allCases {
            result[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
        return result
    }()

    static func logger(_ category: LogCategory) -> Logger {
        // The dictionary is exhaustively populated above; the fallback
        // exists only to keep this non-optional at the call site.
        loggers[category] ?? Logger(subsystem: subsystem, category: category.rawValue)
    }

    // MARK: Convenience

    static var app: Logger          { logger(.app) }
    static var auth: Logger         { logger(.auth) }
    static var network: Logger      { logger(.network) }
    static var database: Logger     { logger(.database) }
    static var sync: Logger         { logger(.sync) }
    static var offline: Logger      { logger(.offline) }
    static var notifications: Logger { logger(.notifications) }
    static var ai: Logger           { logger(.ai) }
    static var ui: Logger           { logger(.ui) }
    static var commerce: Logger     { logger(.commerce) }
    static var diagnostics: Logger  { logger(.diagnostics) }
    static var privacy: Logger      { logger(.privacy) }
}

// MARK: - Error Logging

extension Logger {

    /// Logs an error with its type but *not* its description.
    ///
    /// `error.localizedDescription` routinely interpolates the thing that
    /// failed — a URL with a query string, a row that failed validation,
    /// an email that was already registered. Logging the type is enough
    /// to find the code path; the description is left private so it is
    /// redacted in the unified log rather than trusted case by case.
    func failure(
        _ message: String,
        error: Error,
        function: StaticString = #function
    ) {
        self.error(
            "\(message, privacy: .public) [\(String(describing: type(of: error)), privacy: .public)] in \(function, privacy: .public): \(error.localizedDescription, privacy: .private)"
        )
    }

    /// Logs a state transition. Both sides are expected to come from a
    /// closed set, so both are public — this is the main case where
    /// `.public` is correct.
    func transition(from: String, to: String, function: StaticString = #function) {
        debug("\(from, privacy: .public) → \(to, privacy: .public) (\(function, privacy: .public))")
    }
}

// MARK: - Signposts

/// Performance intervals for Instruments.
///
/// Deliberately thin: signposts are for measuring in Instruments, and a
/// heavyweight wrapper defeats the point by adding its own cost to the
/// thing being measured. `OSSignposter` is already cheap and no-ops when
/// nothing is recording.
enum AppSignpost {

    static let sync = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "ca.rentos.app",
        category: "sync"
    )

    static let ui = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "ca.rentos.app",
        category: "ui"
    )
}
