//
//  AIProposal.swift
//  RentalApp (Purrperty)
//
//  Core/AI — Human approval.
//
//  ─────────────────────────────────────────────────────────────────
//  THE AI PROPOSES; A PERSON DISPOSES
//  ─────────────────────────────────────────────────────────────────
//  "Supports human approval" is not a confirmation dialog bolted on at
//  the end. If the model's output can reach the database through any path
//  that does not carry an approval record, the guarantee is decorative.
//
//  So a mutating task cannot return a value a caller might apply — it
//  returns an `AIProposal`, and the only way to apply one is `accept(by:)`,
//  which records who approved it and routes through the existing
//  `MutationOutcome`/`UndoToken` spine. Accepting AI advice is therefore
//  an ordinary, auditable, undoable mutation.
//
//  Editing is a first-class outcome, not a rejection. A manager who fixes
//  one word in a drafted reply is telling you the model was 95% right,
//  and `.edited` preserves that signal where `.rejected` would destroy it.
//

import Foundation

// MARK: - Status

enum AIProposalStatus: String, Codable, Sendable {
    case pending
    case accepted
    /// Accepted, but the human changed the content first.
    case edited
    case rejected
    /// Applied without review because policy allowed it. Still logged.
    case autoApplied = "auto_applied"
    /// The window passed with no decision.
    case expired

    var isResolved: Bool { self != .pending }
}

// MARK: - Provenance

/// Everything needed to answer "where did this come from?" months later.
struct AIProvenance: Codable, Sendable, Equatable {
    let invocationID: UUID
    let taskKind: AITaskKind
    let promptVersion: String
    let providerID: String
    let modelID: String
    let generatedAt: Date
    let usage: AIUsage
    /// Model's own confidence where the task reports one. Nil is honest —
    /// it is not the same as 0.
    let confidence: Double?
}

// MARK: - Proposal

/// A typed AI output awaiting a human decision.
///
/// Generic over the payload so `AIProposal<MaintenanceClassificationTask.Output>`
/// keeps its fields all the way to the view — no stringly-typed handoff.
@MainActor
@Observable
final class AIProposal<Payload: Sendable> {

    let id = UUID()
    let provenance: AIProvenance

    /// What the model produced. `private(set)` because an edit must go
    /// through `accept(editedTo:)` so the status reflects it.
    private(set) var payload: Payload
    private(set) var status: AIProposalStatus = .pending
    private(set) var decidedBy: String?
    private(set) var decidedAt: Date?
    private(set) var rejectionNote: String?
    private(set) var isApplying = false

    /// Performs the real mutation. Supplied by whoever created the
    /// proposal, so this type never knows about repositories.
    private let apply: @MainActor (Payload) async throws -> UndoToken?

    /// Recorded so every decision reaches the audit trail.
    private let audit: AIAuditLogging

    init(
        payload: Payload,
        provenance: AIProvenance,
        audit: AIAuditLogging,
        apply: @escaping @MainActor (Payload) async throws -> UndoToken?
    ) {
        self.payload = payload
        self.provenance = provenance
        self.audit = audit
        self.apply = apply
    }

    // MARK: Decisions

    /// Applies the proposal as-is.
    func accept(by user: String) async -> MutationOutcome {
        await resolve(status: .accepted, by: user, payload: payload)
    }

    /// Applies a human-corrected version.
    func accept(editedTo edited: Payload, by user: String) async -> MutationOutcome {
        payload = edited
        return await resolve(status: .edited, by: user, payload: edited)
    }

    /// Declines. The note is worth asking for — rejection reasons are the
    /// only free feedback you get on prompt quality.
    func reject(by user: String, note: String? = nil) async {
        status = .rejected
        decidedBy = user
        decidedAt = .now
        rejectionNote = note
        await audit.recordDecision(
            invocationID: provenance.invocationID,
            status: .rejected,
            decidedBy: user,
            note: note
        )
    }

    /// Used by the policy layer when review is not required.
    func autoApply() async -> MutationOutcome {
        await resolve(status: .autoApplied, by: "system", payload: payload)
    }

    func expire() async {
        guard status == .pending else { return }
        status = .expired
        decidedAt = .now
        await audit.recordDecision(
            invocationID: provenance.invocationID,
            status: .expired,
            decidedBy: nil,
            note: nil
        )
    }

    // MARK: Internals

    private func resolve(
        status newStatus: AIProposalStatus,
        by user: String,
        payload appliedPayload: Payload
    ) async -> MutationOutcome {
        guard status == .pending, !isApplying else {
            return .failed(.validation("This suggestion was already handled."))
        }

        isApplying = true
        defer { isApplying = false }

        do {
            let undo = try await apply(appliedPayload)
            status = newStatus
            decidedBy = user
            decidedAt = .now
            await audit.recordDecision(
                invocationID: provenance.invocationID,
                status: newStatus,
                decidedBy: user,
                note: nil
            )
            return .succeeded(undo: undo)
        } catch {
            // The proposal stays pending: a failed write must not look
            // like a decision the user made.
            let appError = AppError.from(error)
            await audit.recordApplyFailure(
                invocationID: provenance.invocationID,
                message: appError.errorDescription ?? "apply failed"
            )
            return .failed(appError)
        }
    }
}

// MARK: - Autonomy Policy

/// Decides what may skip review.
///
/// Starts fully manual by design. Autonomy is earned per task once its
/// accept rate is known — turning it on before you have that number is
/// how an AI feature loses a user's trust in one bad afternoon.
struct AIAutonomyPolicy: Codable, Sendable, Equatable {

    /// Tasks allowed to apply without review, and the confidence floor.
    var autoApplyThresholds: [AITaskKind: Double]

    /// Below this, the proposal is shown with a caution styling rather
    /// than presented as a recommendation.
    var lowConfidenceFloor: Double

    /// How long a pending proposal stands before expiring. A stale
    /// suggestion applied a week later is reasoning about data that has
    /// since changed.
    var proposalLifetime: TimeInterval

    static let manual = AIAutonomyPolicy(
        autoApplyThresholds: [:],
        lowConfidenceFloor: 0.6,
        proposalLifetime: 60 * 60 * 24
    )

    /// A reasonable second step: let the model file obvious triage on its
    /// own, keep a human on anything the tenant will read.
    static let assisted = AIAutonomyPolicy(
        autoApplyThresholds: [.maintenanceClassification: 0.9],
        lowConfidenceFloor: 0.6,
        proposalLifetime: 60 * 60 * 24
    )

    func mayAutoApply(_ kind: AITaskKind, confidence: Double?) -> Bool {
        guard let threshold = autoApplyThresholds[kind] else { return false }
        guard let confidence else { return false }   // unknown ≠ confident
        return confidence >= threshold
    }

    func isLowConfidence(_ confidence: Double?) -> Bool {
        guard let confidence else { return true }
        return confidence < lowConfidenceFloor
    }
}

// MARK: - Codable support for the policy's dictionary key

extension AITaskKind: CodingKeyRepresentable {
    public var codingKey: any CodingKey {
        AITaskKindCodingKey(stringValue: rawValue)
    }

    public init?<T: CodingKey>(codingKey: T) {
        self.init(rawValue: codingKey.stringValue)
    }
}

private struct AITaskKindCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
