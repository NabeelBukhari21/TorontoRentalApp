//
//  SupabaseAIAuditLog.swift
//  RentalApp (Purrperty)
//
//  Services/AI — The audit trail, persisted.
//
//  Writes to `public.ai_invocations`, which RLS scopes to the caller's
//  organization and which has no DELETE policy. An audit trail you can
//  erase from the client is not an audit trail.
//
//  Every method here swallows its errors. That is unusual and deliberate:
//  losing a log row is bad, but refusing to triage a flooded basement
//  because the logging insert timed out is worse. The failure is visible
//  in the gap between client-side and server-side counts rather than in a
//  broken feature.
//

import Foundation
import Supabase

actor SupabaseAIAuditLog: AIAuditLogging {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: Writes

    func record(_ invocation: AIInvocationRecord) async {
        let row = InvocationInsert(
            id: invocation.id,
            taskKind: invocation.taskKind.rawValue,
            promptVersion: invocation.promptVersion,
            providerID: invocation.providerID,
            modelID: invocation.modelID,
            preference: invocation.preference.rawValue,
            subjectType: invocation.subjectType,
            subjectID: invocation.subjectID,
            inputTokens: invocation.inputTokens,
            outputTokens: invocation.outputTokens,
            estimatedCostUSD: invocation.estimatedCostUSD,
            latencyMS: Int(invocation.latency * 1000),
            decodedOK: invocation.didDecodeSuccessfully,
            errorMessage: invocation.errorMessage,
            confidence: invocation.confidence,
            status: invocation.status.rawValue,
            promptDigest: invocation.promptDigest
        )

        // No organization_id: the `force_org_id` trigger stamps it from
        // auth.uid(), so this row cannot be attributed to another tenant.
        _ = try? await client.from("ai_invocations").insert(row).execute()
    }

    func recordDecision(
        invocationID: UUID,
        status: AIProposalStatus,
        decidedBy: String?,
        note: String?
    ) async {
        _ = try? await client
            .from("ai_invocations")
            .update(DecisionUpdate(
                status: status.rawValue,
                decidedBy: decidedBy,
                decidedAt: Date(),
                decisionNote: note
            ))
            .eq("id", value: invocationID.uuidString)
            .execute()
    }

    func recordApplyFailure(invocationID: UUID, message: String) async {
        _ = try? await client
            .from("ai_invocations")
            .update(["decision_note": "apply failed: \(message)"])
            .eq("id", value: invocationID.uuidString)
            .execute()
    }

    // MARK: Reads

    func recentInvocations(limit: Int) async throws -> [AIInvocationRecord] {
        do {
            let rows: [InvocationRow] = try await client
                .from("ai_invocations")
                .select()
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.compactMap(\.asRecord)
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }

    func usageSummary(since: Date) async throws -> AIUsageSummary {
        do {
            // The view does the aggregation; shipping raw rows to sum them on
            // device would defeat the point of having it.
            let rows: [UsageRow] = try await client
                .from("ai_usage_by_task")
                .select()
                .gte("month", value: SupabaseCoding.dateOnlyString(since))
                .execute()
                .value

            var byTask: [AITaskKind: AIUsageSummary.TaskUsage] = [:]
            for row in rows {
                guard let kind = AITaskKind(rawValue: row.taskKind) else { continue }
                // A task can appear once per prompt_version, so merge rather
                // than assign — otherwise only the last version is counted.
                let existing = byTask[kind]
                byTask[kind] = AIUsageSummary.TaskUsage(
                    calls: (existing?.calls ?? 0) + row.calls,
                    costUSD: (existing?.costUSD ?? 0) + row.costUSD,
                    accepted: (existing?.accepted ?? 0) + row.accepted,
                    edited: (existing?.edited ?? 0) + row.edited,
                    rejected: (existing?.rejected ?? 0) + row.rejected
                )
            }

            return AIUsageSummary(
                totalCalls: rows.reduce(0) { $0 + $1.calls },
                totalCostUSD: rows.reduce(0) { $0 + $1.costUSD },
                byTask: byTask
            )
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

// MARK: - Wire Types

private struct InvocationInsert: Encodable, Sendable {
    let id: UUID
    let taskKind: String
    let promptVersion: String
    let providerID: String
    let modelID: String
    let preference: String
    let subjectType: String?
    let subjectID: String?
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostUSD: Double
    let latencyMS: Int
    let decodedOK: Bool
    let errorMessage: String?
    let confidence: Double?
    let status: String
    let promptDigest: String

    enum CodingKeys: String, CodingKey {
        case id, preference, confidence, status
        case taskKind          = "task_kind"
        case promptVersion     = "prompt_version"
        case providerID        = "provider_id"
        case modelID           = "model_id"
        case subjectType       = "subject_type"
        case subjectID         = "subject_id"
        case inputTokens       = "input_tokens"
        case outputTokens      = "output_tokens"
        case estimatedCostUSD  = "estimated_cost_usd"
        case latencyMS         = "latency_ms"
        case decodedOK         = "decoded_ok"
        case errorMessage      = "error_message"
        case promptDigest      = "prompt_digest"
    }
}

private struct DecisionUpdate: Encodable, Sendable {
    let status: String
    let decidedBy: String?
    let decidedAt: Date
    let decisionNote: String?

    enum CodingKeys: String, CodingKey {
        case status
        case decidedBy    = "decided_by"
        case decidedAt    = "decided_at"
        case decisionNote = "decision_note"
    }
}

private struct InvocationRow: Decodable, Sendable {
    let id: UUID
    let taskKind: String
    let promptVersion: String
    let providerID: String
    let modelID: String
    let preference: String?
    let subjectType: String?
    let subjectID: String?
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostUSD: Double
    let latencyMS: Int
    let decodedOK: Bool
    let errorMessage: String?
    let confidence: Double?
    let status: String
    let decidedBy: String?
    let decidedAt: Date?
    let decisionNote: String?
    let promptDigest: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, preference, confidence, status
        case taskKind          = "task_kind"
        case promptVersion     = "prompt_version"
        case providerID        = "provider_id"
        case modelID           = "model_id"
        case subjectType       = "subject_type"
        case subjectID         = "subject_id"
        case inputTokens       = "input_tokens"
        case outputTokens      = "output_tokens"
        case estimatedCostUSD  = "estimated_cost_usd"
        case latencyMS         = "latency_ms"
        case decodedOK         = "decoded_ok"
        case errorMessage      = "error_message"
        case decidedBy         = "decided_by"
        case decidedAt         = "decided_at"
        case decisionNote      = "decision_note"
        case promptDigest      = "prompt_digest"
        case createdAt         = "created_at"
    }

    /// Nil when the row's task kind is one this build doesn't know — a
    /// newer server enum shouldn't crash an older client.
    var asRecord: AIInvocationRecord? {
        guard let kind = AITaskKind(rawValue: taskKind) else { return nil }
        return AIInvocationRecord(
            id: id,
            taskKind: kind,
            promptVersion: promptVersion,
            providerID: providerID,
            modelID: modelID,
            preference: preference.flatMap(AIModelPreference.init(rawValue:)) ?? .fast,
            subjectType: subjectType,
            subjectID: subjectID,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            estimatedCostUSD: estimatedCostUSD,
            latency: Double(latencyMS) / 1000,
            didDecodeSuccessfully: decodedOK,
            errorMessage: errorMessage,
            confidence: confidence,
            status: AIProposalStatus(rawValue: status) ?? .expired,
            decidedBy: decidedBy,
            decidedAt: decidedAt,
            decisionNote: decisionNote,
            createdAt: createdAt,
            promptDigest: promptDigest
        )
    }
}

private struct UsageRow: Decodable, Sendable {
    let taskKind: String
    let calls: Int
    let costUSD: Double
    let accepted: Int
    let edited: Int
    let rejected: Int

    enum CodingKeys: String, CodingKey {
        case taskKind = "task_kind"
        case calls
        case costUSD  = "cost_usd"
        case accepted, edited, rejected
    }
}
