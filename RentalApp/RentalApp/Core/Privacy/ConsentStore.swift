//
//  ConsentStore.swift
//  RentalApp (RentOS)
//
//  Core/Privacy — What the user has agreed to be collected.
//
//  ─────────────────────────────────────────────────────────────────
//  CONSENT IS DENIED UNTIL GRANTED
//  ─────────────────────────────────────────────────────────────────
//  The failure mode to design against is a default of `true`. It makes
//  every bug — a store that fails to load, a fresh install, a decode
//  error, a new category added in a later release — fail in the
//  direction of collecting data the user never agreed to. So the
//  default is `.notAsked`, which is not consent, and every sink treats
//  anything other than an explicit `.granted` as refusal.
//
//  ─────────────────────────────────────────────────────────────────
//  CATEGORIES, NOT A SINGLE SWITCH
//  ─────────────────────────────────────────────────────────────────
//  "Share diagnostics" and "share usage analytics" are different
//  bargains. A user who will send a crash report to get a bug fixed
//  has not thereby agreed to behavioural product analytics. Bundling
//  them into one toggle is the pattern regulators object to, and it is
//  also just a worse product.
//
//  ─────────────────────────────────────────────────────────────────
//  WHAT THIS IS NOT
//  ─────────────────────────────────────────────────────────────────
//  This is not App Tracking Transparency. RentOS does not track users
//  across apps or websites owned by other companies, so it does not
//  need ATT, and asking for it anyway is both a rejected-binary risk
//  and a prompt the user has no reason to accept. Should the app ever
//  add an advertising SDK, ATT belongs here alongside these — but the
//  correct posture until then is not to ask.
//

import Foundation
import Observation
import OSLog

// MARK: - Categories

/// The kinds of collection a user can decide about, independently.
enum ConsentCategory: String, Sendable, CaseIterable, Codable {

    /// Crash reports and non-fatal error diagnostics.
    case diagnostics

    /// Product usage analytics: which screens, which features.
    case analytics

    /// Whether an *authenticated* user's identifier may be attached to
    /// the above. Separate because pseudonymous aggregates and
    /// person-linked records are different privacy propositions, and
    /// this is the one most users would decline if asked plainly.
    case personalization

    var title: String {
        switch self {
        case .diagnostics:     "Crash reports"
        case .analytics:       "Usage analytics"
        case .personalization: "Link data to my account"
        }
    }

    /// Written to be true. Vague consent copy is not consent.
    var explanation: String {
        switch self {
        case .diagnostics:
            "Send a report when RentOS crashes, so the cause can be fixed. Includes the app version, the device model, and where in the code it stopped."
        case .analytics:
            "Share which features are used, so the app can be improved. Includes screen names and counts. Never includes property addresses, tenant details, or message contents."
        case .personalization:
            "Attach your account ID to the above. Without this, reports arrive unlinked to any person."
        }
    }

    /// Defaulting anything to on would make the toggle theatre. All
    /// three start off, and the app is fully functional with all three
    /// off — which is the test of whether consent is real.
    static let defaultState: ConsentState = .notAsked
}

// MARK: - State

enum ConsentState: String, Sendable, Codable {
    case notAsked
    case granted
    case denied

    /// The only property any collection code should ever consult.
    ///
    /// Written as an explicit equality against `.granted` rather than
    /// `!= .denied`, so that adding a fourth case later fails closed.
    var allowsCollection: Bool { self == .granted }
}

// MARK: - Record

/// A consent decision, with enough context to honour it later.
struct ConsentRecord: Sendable, Codable, Equatable {

    let state: ConsentState
    let decidedAt: Date?
    /// The privacy policy version in force when they decided. A material
    /// policy change invalidates consent gathered under the old one, and
    /// without recording this there is no way to know which users need
    /// re-asking.
    let policyVersion: Int

    static let unasked = ConsentRecord(state: .notAsked, decidedAt: nil, policyVersion: 0)
}

// MARK: - Store

@MainActor
@Observable
final class ConsentStore {

    /// Bump when the privacy policy changes materially. Consent recorded
    /// against a lower version stops counting and the user is asked again.
    static let currentPolicyVersion = 1

    private(set) var records: [ConsentCategory: ConsentRecord]

    private let persistence: PersistenceServiceProtocol
    private static let storageKey = "privacy.consent.v1"

    init(persistence: PersistenceServiceProtocol) {
        self.persistence = persistence
        self.records = Self.load(from: persistence)
    }

    // MARK: Query

    /// The single question every sink asks.
    ///
    /// Returns false for `.notAsked`, for `.denied`, and for consent
    /// granted against a superseded policy version. Three different
    /// reasons, one safe answer.
    func allows(_ category: ConsentCategory) -> Bool {
        guard let record = records[category] else { return false }
        guard record.policyVersion >= Self.currentPolicyVersion else { return false }
        return record.state.allowsCollection
    }

    func state(of category: ConsentCategory) -> ConsentState {
        records[category]?.state ?? .notAsked
    }

    /// True when the user has never been asked, or was asked under an
    /// older policy. Drives whether to present the consent screen.
    var needsDecision: Bool {
        ConsentCategory.allCases.contains { category in
            guard let record = records[category] else { return true }
            return record.state == .notAsked || record.policyVersion < Self.currentPolicyVersion
        }
    }

    // MARK: Mutate

    func set(_ category: ConsentCategory, to state: ConsentState) {
        records[category] = ConsentRecord(
            state: state,
            decidedAt: Date(),
            policyVersion: Self.currentPolicyVersion
        )
        persist()

        // Category and state are both closed sets, so both are safe as
        // public — and an audit trail of consent changes is exactly what
        // you want to be able to read back off a device.
        AppLog.privacy.notice(
            "consent \(category.rawValue, privacy: .public) → \(state.rawValue, privacy: .public)"
        )
    }

    /// Records an explicit decision for every category at once, from the
    /// consent screen's "accept all" / "reject all".
    func setAll(to state: ConsentState) {
        for category in ConsentCategory.allCases {
            set(category, to: state)
        }
    }

    /// Revokes everything and returns the categories that had been on.
    ///
    /// The caller uses the return value to purge already-collected data
    /// for those categories — revocation that only stops *future*
    /// collection is not revocation.
    @discardableResult
    func revokeAll() -> [ConsentCategory] {
        let previouslyGranted = ConsentCategory.allCases.filter { allows($0) }
        setAll(to: .denied)
        return previouslyGranted
    }

    // MARK: Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(records)
            persistence.set(data, forKey: Self.storageKey)
        } catch {
            // Failing to persist means the user gets asked again next
            // launch, which is the safe direction. Worth logging, not
            // worth interrupting them over.
            AppLog.privacy.failure("Could not persist consent", error: error)
        }
    }

    private static func load(from persistence: PersistenceServiceProtocol) -> [ConsentCategory: ConsentRecord] {
        guard let data = persistence.data(forKey: storageKey) else { return [:] }
        do {
            return try JSONDecoder().decode([ConsentCategory: ConsentRecord].self, from: data)
        } catch {
            // A corrupt store must not be read as consent. Empty means
            // "ask again", which is the only safe interpretation.
            AppLog.privacy.failure("Consent store unreadable; treating as not asked", error: error)
            return [:]
        }
    }
}
