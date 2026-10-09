//
//  AIAuditLog.swift
//  RentalApp (RentOS)
//
//  Core/AI — Every AI action, recorded.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY THE LOG IS SERVER-SIDE AND NOT OPTIONAL
//  ─────────────────────────────────────────────────────────────────
//  Three separate needs converge on one table:
//
//  1. Accountability. When a tenant asks why their request was marked
//     low priority, "the AI decided" is not an answer. The log holds the
//     prompt version, the model, the confidence, and who approved it.
//  2. Cost. Per-task token spend is the only way to know which feature
//     is worth its bill.
//  3. Quality. Accept / edit / reject rates per prompt version are the
//     feedback loop. Without them, improving a prompt is guesswork.
//
//  It is also why logging is *not* fire-and-forget on the client: a log
//  that lives only on one device disappears with the device, and a
//  landlord's audit trail is exactly the thing that must not.
//
//  Failure to log never blocks the feature, though. Losing an audit row
//  is bad; refusing to triage a flooded basement because the log was
//  unreachable is worse.
//

import Foundation

// MARK: - Record

/// One AI call, from request to human decision.
struct AIInvocationRecord: Codable, Sendable, Identifiable {

    let id: UUID
    let taskKind: AITaskKind
    let promptVersion: String
    let providerID: String
    let modelID: String
    let preference: AIModelPreference

    let subjectType: String?
    let subjectID: String?

    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostUSD: Double
    let latency: TimeInterval

    /// Whether the model's structured output parsed. A rising failure rate
    /// is usually a provider silently changing behaviour.
    let didDecodeSuccessfully: Bool
    let errorMessage: String?

    let confidence: Double?
    var status: AIProposalStatus
    var decidedBy: String?
    var decidedAt: Date?
    var decisionNote: String?

    let createdAt: Date

    /// Prompts and completions are deliberately NOT stored by default.
    /// They contain tenant names, addresses, and message contents, and a
    /// full transcript table becomes the single most sensitive object in
    /// the system. `promptVersion` plus the subject id is enough to
    /// reproduce a call when investigating.
    let promptDigest: String
}

// MARK: - Contract

protocol AIAuditLogging: Sendable {

    /// Called once per completed call, successful or not.
    func record(_ invocation: AIInvocationRecord) async

    /// Called when a human resolves a proposal.
    func recordDecision(
        invocationID: UUID,
        status: AIProposalStatus,
        decidedBy: String?,
        note: String?
    ) async

    func recordApplyFailure(invocationID: UUID, message: String) async

    /// Backs the AI Activity Feed.
    func recentInvocations(limit: Int) async throws -> [AIInvocationRecord]

    /// Backs the Settings → AI usage panel.
    func usageSummary(since: Date) async throws -> AIUsageSummary
}

struct AIUsageSummary: Sendable {
    let totalCalls: Int
    let totalCostUSD: Double
    let byTask: [AITaskKind: TaskUsage]

    struct TaskUsage: Sendable {
        let calls: Int
        let costUSD: Double
        let accepted: Int
        let edited: Int
        let rejected: Int

        /// The number that tells you whether a prompt is working.
        var approvalRate: Double {
            let decided = accepted + edited + rejected
            return decided == 0 ? 0 : Double(accepted + edited) / Double(decided)
        }
    }

    static let empty = AIUsageSummary(totalCalls: 0, totalCostUSD: 0, byTask: [:])
}

// MARK: - Prompt Digest

enum AIPromptDigest {

    /// A stable, non-reversible fingerprint of the prompt.
    ///
    /// Lets you group "all calls that sent this exact context" without
    /// storing the context. Cheap hash, not a cryptographic commitment —
    /// it identifies, it does not protect.
    static func make(from messages: [AIMessage]) -> String {
        var hasher = Hasher()
        for message in messages {
            hasher.combine(message.role)
            hasher.combine(message.content)
        }
        return String(format: "%016llx", UInt64(bitPattern: Int64(hasher.finalize())))
    }
}

// MARK: - In-memory implementation

/// Used in previews, tests, and whenever the backend is unreachable.
///
/// An actor because invocations arrive from whatever context the task ran
/// in, and this is shared mutable state.
actor InMemoryAIAuditLog: AIAuditLogging {

    private var records: [UUID: AIInvocationRecord] = [:]
    private var order: [UUID] = []
    private let limit: Int

    init(limit: Int = 500) {
        self.limit = limit
    }

    func record(_ invocation: AIInvocationRecord) async {
        records[invocation.id] = invocation
        order.append(invocation.id)
        if order.count > limit, let oldest = order.first {
            order.removeFirst()
            records.removeValue(forKey: oldest)
        }
    }

    func recordDecision(
        invocationID: UUID,
        status: AIProposalStatus,
        decidedBy: String?,
        note: String?
    ) async {
        guard var existing = records[invocationID] else { return }
        existing.status = status
        existing.decidedBy = decidedBy
        existing.decidedAt = .now
        existing.decisionNote = note
        records[invocationID] = existing
    }

    func recordApplyFailure(invocationID: UUID, message: String) async {
        guard var existing = records[invocationID] else { return }
        existing.decisionNote = "apply failed: \(message)"
        records[invocationID] = existing
    }

    func recentInvocations(limit: Int) async throws -> [AIInvocationRecord] {
        order.reversed().prefix(limit).compactMap { records[$0] }
    }

    func usageSummary(since: Date) async throws -> AIUsageSummary {
        let relevant = records.values.filter { $0.createdAt >= since }
        var byTask: [AITaskKind: AIUsageSummary.TaskUsage] = [:]

        for kind in AITaskKind.allCases {
            let calls = relevant.filter { $0.taskKind == kind }
            guard !calls.isEmpty else { continue }
            byTask[kind] = AIUsageSummary.TaskUsage(
                calls: calls.count,
                costUSD: calls.reduce(0) { $0 + $1.estimatedCostUSD },
                accepted: calls.filter { $0.status == .accepted || $0.status == .autoApplied }.count,
                edited: calls.filter { $0.status == .edited }.count,
                rejected: calls.filter { $0.status == .rejected }.count
            )
        }

        return AIUsageSummary(
            totalCalls: relevant.count,
            totalCostUSD: relevant.reduce(0) { $0 + $1.estimatedCostUSD },
            byTask: byTask
        )
    }
}
