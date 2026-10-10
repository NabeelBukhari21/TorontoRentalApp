//
//  LegalAcceptance.swift
//  RentalApp (Purrperty)
//
//  Core/Legal — Versioned terms, and proving they were accepted.
//
//  ─────────────────────────────────────────────────────────────────
//  ACCEPTANCE IS A RECORD, NOT A BOOLEAN
//  ─────────────────────────────────────────────────────────────────
//  `hasAcceptedTerms = true` in UserDefaults answers none of the
//  questions actually asked when it matters. Which version did they
//  accept? When? From which device? A dispute about a lease-management
//  agreement is exactly the situation where "the app has a flag set"
//  is not evidence.
//
//  So acceptance records the document version and timestamp, and is
//  written server-side. The local copy is a cache for the gate; the
//  server row is the record. If the two disagree, the server wins —
//  local state can be cleared by a reinstall and must not be able to
//  erase an acceptance that legally happened.
//
//  ─────────────────────────────────────────────────────────────────
//  RE-ACCEPTANCE IS SEMANTIC, NOT AUTOMATIC
//  ─────────────────────────────────────────────────────────────────
//  Not every edit to a policy requires re-consent. Fixing a typo does
//  not; changing what data is shared does. That judgement is a human
//  one, so it lives in an explicitly-bumped version number rather than
//  in a content hash — a hash would re-prompt every user over a
//  reworded sentence, and users who are re-prompted constantly stop
//  reading, which defeats the purpose.
//

import Foundation
import Observation
import OSLog

// MARK: - Document

enum LegalDocument: String, Sendable, CaseIterable, Codable {

    case termsOfService = "terms_of_service"
    case privacyPolicy  = "privacy_policy"

    var title: String {
        switch self {
        case .termsOfService: "Terms of Service"
        case .privacyPolicy:  "Privacy Policy"
        }
    }

    /// Bump ONLY for material changes — ones that alter what a user is
    /// agreeing to. See the note at the top of this file.
    var currentVersion: Int {
        switch self {
        case .termsOfService: 1
        case .privacyPolicy:  1
        }
    }

    func url(in configuration: AppConfiguration = .current) -> URL {
        switch self {
        case .termsOfService: configuration.termsURL
        case .privacyPolicy:  configuration.privacyPolicyURL
        }
    }
}

// MARK: - Acceptance

struct LegalAcceptance: Sendable, Codable, Equatable {
    let document: LegalDocument
    let version: Int
    let acceptedAt: Date
    /// Which build recorded it. Useful when a bug in a specific version
    /// turns out to have mis-recorded acceptances.
    let appVersion: String
}

// MARK: - Remote Record

/// Server-side persistence of acceptance.
///
/// Separate protocol rather than a method on some larger repository
/// because this has a different durability requirement from ordinary
/// app data: it must not be lost, and it must not be silently
/// overwritten.
protocol LegalAcceptanceRecording: Sendable {
    func fetchAcceptances() async throws -> [LegalAcceptance]
    func record(_ acceptance: LegalAcceptance) async throws
}

/// Local-only recorder, for the mock backend and previews.
final class InMemoryLegalRecorder: LegalAcceptanceRecording, @unchecked Sendable {
    private var stored: [LegalAcceptance] = []
    func fetchAcceptances() async throws -> [LegalAcceptance] { stored }
    func record(_ acceptance: LegalAcceptance) async throws { stored.append(acceptance) }
}

// MARK: - Gate

@MainActor
@Observable
final class LegalGate {

    private(set) var acceptances: [LegalDocument: LegalAcceptance] = [:]
    private(set) var isSubmitting = false
    private(set) var lastError: AppError?

    private let recorder: LegalAcceptanceRecording
    private let persistence: PersistenceServiceProtocol
    private let build: BuildInfo

    private static let storageKey = "legal.acceptance.v1"

    init(
        recorder: LegalAcceptanceRecording,
        persistence: PersistenceServiceProtocol,
        build: BuildInfo = .current
    ) {
        self.recorder = recorder
        self.persistence = persistence
        self.build = build
        self.acceptances = Self.loadCache(from: persistence)
    }

    // MARK: Query

    /// Documents the user still has to accept.
    var outstanding: [LegalDocument] {
        LegalDocument.allCases.filter { document in
            guard let accepted = acceptances[document] else { return true }
            return accepted.version < document.currentVersion
        }
    }

    var needsAcceptance: Bool { !outstanding.isEmpty }

    /// True when the user accepted an earlier version — the copy should
    /// say "we've updated our terms", not "please accept our terms".
    var isReacceptance: Bool {
        outstanding.contains { acceptances[$0] != nil }
    }

    // MARK: Sync

    /// Reconciles with the server after sign-in.
    ///
    /// The server is authoritative *upward* only: a remote acceptance is
    /// adopted, but a missing remote acceptance does not clear a local
    /// one. That asymmetry is deliberate — a failed fetch must not
    /// re-prompt someone who has already agreed.
    func synchronize() async {
        do {
            let remote = try await recorder.fetchAcceptances()
            for acceptance in remote {
                let existing = acceptances[acceptance.document]
                if existing == nil || existing!.version < acceptance.version {
                    acceptances[acceptance.document] = acceptance
                }
            }
            cache()
        } catch {
            AppLog.app.failure("Could not fetch legal acceptances", error: error)
        }
    }

    // MARK: Accept

    /// Records acceptance of everything outstanding.
    ///
    /// The gate only opens once the server has the record. Letting the
    /// user through on a local write alone would mean an acceptance that
    /// exists on exactly one device and vanishes on reinstall.
    @discardableResult
    func acceptOutstanding() async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        lastError = nil
        defer { isSubmitting = false }

        let pending = outstanding
        var recorded: [LegalAcceptance] = []

        do {
            for document in pending {
                let acceptance = LegalAcceptance(
                    document: document,
                    version: document.currentVersion,
                    acceptedAt: Date(),
                    appVersion: build.displayVersion
                )
                try await recorder.record(acceptance)
                recorded.append(acceptance)
            }
        } catch {
            lastError = AppError.from(error)
            // Keep whatever did succeed. Re-running accept for a
            // partially-recorded set is safe and idempotent server-side.
            for acceptance in recorded { acceptances[acceptance.document] = acceptance }
            cache()
            return false
        }

        for acceptance in recorded { acceptances[acceptance.document] = acceptance }
        cache()

        AppLog.app.notice(
            "Accepted \(recorded.count, privacy: .public) legal document(s)"
        )
        return true
    }

    // MARK: Cache

    private func cache() {
        guard let data = try? JSONEncoder().encode(Array(acceptances.values)) else { return }
        persistence.set(data, forKey: Self.storageKey)
    }

    private static func loadCache(
        from persistence: PersistenceServiceProtocol
    ) -> [LegalDocument: LegalAcceptance] {
        guard
            let data = persistence.data(forKey: storageKey),
            let list = try? JSONDecoder().decode([LegalAcceptance].self, from: data)
        else { return [:] }

        return list.reduce(into: [:]) { result, acceptance in
            result[acceptance.document] = acceptance
        }
    }
}
