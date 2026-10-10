//
//  AnalyticsService.swift
//  RentalApp (Purrperty)
//
//  Core/Analytics — Delivery, consent enforcement, sampling.
//
//  ─────────────────────────────────────────────────────────────────
//  THE GATE IS AT THE SINK, NOT THE CALL SITE
//  ─────────────────────────────────────────────────────────────────
//  Consent checks written at call sites are checks that will be
//  forgotten at the thirty-first call site. There is exactly one place
//  an event can reach a sink from, so that is where consent is
//  enforced. A feature author cannot bypass it without deleting code
//  that is obviously load-bearing.
//
//  ─────────────────────────────────────────────────────────────────
//  MULTIPLE SINKS, ONE FAN-OUT
//  ─────────────────────────────────────────────────────────────────
//  Sinks are the seam where a vendor SDK would eventually attach.
//  Adding Amplitude later means writing one `AnalyticsSink` conformance
//  and registering it, with no change to any call site and no change to
//  the consent logic — which is the point of the abstraction, and also
//  the point at which a privacy review has one file to read.
//

import Foundation
import OSLog

// MARK: - Sink

/// A destination for events.
///
/// `Sendable` and non-isolated: sinks are called from a detached task so
/// analytics never contends with the main actor. A sink that needs the
/// main actor should hop internally rather than forcing every caller to.
protocol AnalyticsSink: Sendable {

    var identifier: String { get }

    func record(_ envelope: AnalyticsEnvelope) async

    /// Attaches (or clears, when nil) the account this session belongs
    /// to. Only ever called when `.personalization` consent is granted.
    func identify(userID: String?) async

    /// Drops anything buffered. Called on consent revocation, where the
    /// obligation is to stop data that has been collected but not yet
    /// sent from being sent.
    func purge() async
}

// MARK: - Envelope

/// An event plus the context every sink needs.
///
/// Assembled once rather than by each sink, so all destinations agree on
/// what "session" and "environment" mean for a given event.
struct AnalyticsEnvelope: Sendable, Equatable {

    let name: String
    let parameters: [String: String]
    let timestamp: Date
    /// Rotates per app run. Enough to stitch a session together, not
    /// enough to follow someone between them — deliberately not a
    /// device identifier.
    let sessionID: String
    let environment: String
    let appVersion: String
    /// Present only with `.personalization` consent.
    let userID: String?
}

// MARK: - Service

/// The app-facing analytics API.
///
/// An actor because it owns mutable state (sinks, session, consent
/// snapshot) touched from arbitrary contexts, and because serializing
/// event submission is free here — nothing is waiting on it.
actor AnalyticsService {

    private var sinks: [AnalyticsSink]
    private let environment: AppEnvironment
    private let build: BuildInfo
    private let sessionID: String

    /// A snapshot rather than a live reference to `ConsentStore`.
    ///
    /// `ConsentStore` is `@MainActor` and this is an actor; awaiting the
    /// main actor on every event would make analytics able to stall on
    /// a busy UI. The store pushes changes in via `updateConsent` instead,
    /// so the hot path stays local.
    private var consent: [ConsentCategory: Bool] = [:]
    private var userID: String?

    init(
        sinks: [AnalyticsSink],
        environment: AppEnvironment = .current,
        build: BuildInfo = .current
    ) {
        self.sinks = sinks
        self.environment = environment
        self.build = build
        self.sessionID = UUID().uuidString
    }

    // MARK: Consent

    /// Pushed from `ConsentStore` at launch and on every change.
    func updateConsent(_ snapshot: [ConsentCategory: Bool]) async {
        let hadPersonalization = consent[.personalization] ?? false
        consent = snapshot

        let hasPersonalization = snapshot[.personalization] ?? false
        if hadPersonalization && !hasPersonalization {
            // Revoked: detach identity from future events *and* drop
            // anything buffered that still carries it.
            userID = nil
            for sink in sinks { await sink.identify(userID: nil) }
            for sink in sinks { await sink.purge() }
        }

        let analyticsAllowed = snapshot[.analytics] ?? false
        let diagnosticsAllowed = snapshot[.diagnostics] ?? false
        if !analyticsAllowed && !diagnosticsAllowed {
            for sink in sinks { await sink.purge() }
        }
    }

    /// Associates events with an account. A no-op without personalization
    /// consent — the caller does not have to remember to check.
    func identify(userID: String?) async {
        guard consent[.personalization] == true else {
            self.userID = nil
            return
        }
        self.userID = userID
        for sink in sinks { await sink.identify(userID: userID) }
    }

    // MARK: Track

    func track(_ event: AnalyticsEvent) async {
        guard consent[.analytics] == true else { return }
        guard shouldSample(event) else { return }

        let envelope = AnalyticsEnvelope(
            name: event.name,
            parameters: event.parameters.mapValues(\.stringValue),
            timestamp: Date(),
            sessionID: sessionID,
            environment: environment.rawValue,
            appVersion: build.displayVersion,
            userID: userID
        )

        for sink in sinks {
            await sink.record(envelope)
        }
    }

    /// Sampling decided per event, not per session.
    ///
    /// Per-session sampling would systematically exclude a quarter of
    /// users from every metric, which biases anything correlated with
    /// who they are. Per-event just reduces volume.
    private func shouldSample(_ event: AnalyticsEvent) -> Bool {
        if event.isCritical { return true }
        let rate = environment.analyticsSampleRate
        guard rate < 1.0 else { return true }
        return Double.random(in: 0..<1) < rate
    }

    // MARK: Composition

    func addSink(_ sink: AnalyticsSink) {
        guard !sinks.contains(where: { $0.identifier == sink.identifier }) else { return }
        sinks.append(sink)
    }

    func purgeAll() async {
        for sink in sinks { await sink.purge() }
    }
}

// MARK: - OSLog Sink

/// Writes events to the unified log. Development and staging only.
///
/// Values are logged `.public` here, which is safe *only* because
/// `AnalyticsValue` structurally cannot carry user text. That guarantee
/// is the reason this line is acceptable, so it is stated here — if
/// someone adds a free-form case to `AnalyticsValue`, this becomes a
/// leak and this comment is where they should notice.
struct OSLogAnalyticsSink: AnalyticsSink {

    let identifier = "oslog"

    func record(_ envelope: AnalyticsEnvelope) async {
        let rendered = envelope.parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        AppLog.logger(.app).debug(
            "analytics \(envelope.name, privacy: .public) \(rendered, privacy: .public)"
        )
    }

    func identify(userID: String?) async {
        // The identifier itself stays private: it is an account ID, and
        // an account ID in a sysdiagnose is a person.
        AppLog.logger(.app).debug("analytics identify \(userID ?? "nil", privacy: .private)")
    }

    func purge() async {}
}

// MARK: - No-op Sink

/// For previews, tests, and any build with diagnostics disabled.
struct NoOpAnalyticsSink: AnalyticsSink {
    let identifier = "noop"
    func record(_ envelope: AnalyticsEnvelope) async {}
    func identify(userID: String?) async {}
    func purge() async {}
}
