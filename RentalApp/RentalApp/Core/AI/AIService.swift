//
//  AIService.swift
//  RentalApp (RentOS)
//
//  Core/AI — The one entry point features use.
//
//  Everything above this line is a contract; everything below is a
//  provider detail. A feature calls `run(task:input:)` and gets a typed
//  value or a typed proposal — it never sees the router, the audit log,
//  or a prompt.
//
//  The composition is deliberately in one place: task → request → router
//  → audit → decode → proposal. That order is the guarantee. There is no
//  path from a model's output to the database that skips the log or the
//  approval gate, because there is no other path at all.
//

import Foundation

// MARK: - Contract

@MainActor
protocol AIServiceProtocol: AnyObject {

    var isEnabled: Bool { get }
    var policy: AIAutonomyPolicy { get }

    /// Runs a read-only task and returns its typed output.
    func run<T: AITask>(_ task: T, input: T.Input) async throws -> T.Output

    /// Runs a task whose result would change data, returning a proposal
    /// that must be accepted before anything is written.
    func propose<T: AITask>(
        _ task: T,
        input: T.Input,
        confidence: @escaping @Sendable (T.Output) -> Double?,
        apply: @escaping @MainActor (T.Output) async throws -> UndoToken?
    ) async throws -> AIProposal<T.Output>

    func recentActivity(limit: Int) async throws -> [AIInvocationRecord]
    func usage(since: Date) async throws -> AIUsageSummary
    func providerStatus() async -> [AIProviderStatus]
}

// MARK: - Implementation

@MainActor
final class AIService: AIServiceProtocol {

    private let router: AIRouter
    private let audit: AIAuditLogging
    private(set) var policy: AIAutonomyPolicy

    init(
        router: AIRouter,
        audit: AIAuditLogging,
        policy: AIAutonomyPolicy = .manual
    ) {
        self.router = router
        self.audit = audit
        self.policy = policy
    }

    var isEnabled: Bool { true }

    func updatePolicy(_ newPolicy: AIAutonomyPolicy) {
        policy = newPolicy
    }

    // MARK: Read-only

    func run<T: AITask>(_ task: T, input: T.Input) async throws -> T.Output {
        let (output, _) = try await execute(task, input: input, confidence: { _ in nil })
        return output
    }

    // MARK: Proposals

    func propose<T: AITask>(
        _ task: T,
        input: T.Input,
        confidence: @escaping @Sendable (T.Output) -> Double?,
        apply: @escaping @MainActor (T.Output) async throws -> UndoToken?
    ) async throws -> AIProposal<T.Output> {

        let (output, provenance) = try await execute(task, input: input, confidence: confidence)

        let proposal = AIProposal(
            payload: output,
            provenance: provenance,
            audit: audit,
            apply: apply
        )

        // Policy may let this one through without review. It is still
        // logged, and still produces an undo token.
        if policy.mayAutoApply(T.kind, confidence: provenance.confidence) {
            _ = await proposal.autoApply()
        }

        return proposal
    }

    // MARK: Core

    /// The single funnel. Every AI call in the app passes through here.
    private func execute<T: AITask>(
        _ task: T,
        input: T.Input,
        confidence: @Sendable (T.Output) -> Double?
    ) async throws -> (T.Output, AIProvenance) {

        let invocationID = UUID()
        let started = Date()
        let messages = try task.messages(for: input)
        let digest = AIPromptDigest.make(from: messages)
        let subject = task.subject(for: input)

        var request = try task.makeRequest(for: input)
        request.messages = messages

        do {
            let response = try await router.complete(request)

            // Decode before logging success: a 200 that fails to parse is
            // a failure from the feature's point of view, and the log
            // should say so.
            let output: T.Output
            do {
                output = try task.decode(response)
            } catch {
                await logFailure(
                    id: invocationID, task: T.self, request: request,
                    response: response, digest: digest, subject: subject,
                    started: started, message: String(describing: error)
                )
                throw error
            }

            let modelConfidence = confidence(output)
            let provenance = AIProvenance(
                invocationID: invocationID,
                taskKind: T.kind,
                promptVersion: T.promptVersion,
                providerID: response.providerID,
                modelID: response.modelID,
                generatedAt: Date(),
                usage: response.usage,
                confidence: modelConfidence
            )

            await audit.record(AIInvocationRecord(
                id: invocationID,
                taskKind: T.kind,
                promptVersion: T.promptVersion,
                providerID: response.providerID,
                modelID: response.modelID,
                preference: request.preference,
                subjectType: subject?.type,
                subjectID: subject?.id,
                inputTokens: response.usage.inputTokens,
                outputTokens: response.usage.outputTokens,
                estimatedCostUSD: response.usage.estimatedCostUSD,
                latency: Date().timeIntervalSince(started),
                didDecodeSuccessfully: true,
                errorMessage: nil,
                confidence: modelConfidence,
                // Read-only tasks have nothing to approve, so they are
                // recorded as already applied rather than left pending
                // and later expiring for no reason.
                status: T.kind.proposesMutation ? .pending : .autoApplied,
                decidedBy: nil,
                decidedAt: nil,
                decisionNote: nil,
                createdAt: started,
                promptDigest: digest
            ))

            return (output, provenance)

        } catch let error as AIError {
            await logFailure(
                id: invocationID, task: T.self, request: request,
                response: nil, digest: digest, subject: subject,
                started: started, message: error.errorDescription ?? "\(error)"
            )
            throw error
        }
    }

    private func logFailure<T: AITask>(
        id: UUID,
        task: T.Type,
        request: AIRequest,
        response: AIResponse?,
        digest: String,
        subject: AISubject?,
        started: Date,
        message: String
    ) async {
        await audit.record(AIInvocationRecord(
            id: id,
            taskKind: T.kind,
            promptVersion: T.promptVersion,
            providerID: response?.providerID ?? "none",
            modelID: response?.modelID ?? "none",
            preference: request.preference,
            subjectType: subject?.type,
            subjectID: subject?.id,
            inputTokens: response?.usage.inputTokens ?? 0,
            outputTokens: response?.usage.outputTokens ?? 0,
            estimatedCostUSD: response?.usage.estimatedCostUSD ?? 0,
            latency: Date().timeIntervalSince(started),
            didDecodeSuccessfully: false,
            errorMessage: message,
            confidence: nil,
            status: .expired,
            decidedBy: nil,
            decidedAt: nil,
            decisionNote: nil,
            createdAt: started,
            promptDigest: digest
        ))
    }

    // MARK: Reporting

    func recentActivity(limit: Int) async throws -> [AIInvocationRecord] {
        try await audit.recentInvocations(limit: limit)
    }

    func usage(since: Date) async throws -> AIUsageSummary {
        try await audit.usageSummary(since: since)
    }

    func providerStatus() async -> [AIProviderStatus] {
        await router.status()
    }
}

// MARK: - Disabled Service

/// Used when the workspace has no AI entitlement, or the user turned the
/// copilot off in Settings.
///
/// A null object rather than an optional dependency: every AI call site
/// would otherwise need `if let ai =` around it, and the one that forgets
/// is the one that crashes.
@MainActor
final class DisabledAIService: AIServiceProtocol {

    var isEnabled: Bool { false }
    var policy: AIAutonomyPolicy { .manual }

    func run<T: AITask>(_ task: T, input: T.Input) async throws -> T.Output {
        throw AIError.notConfigured
    }

    func propose<T: AITask>(
        _ task: T,
        input: T.Input,
        confidence: @escaping @Sendable (T.Output) -> Double?,
        apply: @escaping @MainActor (T.Output) async throws -> UndoToken?
    ) async throws -> AIProposal<T.Output> {
        throw AIError.notConfigured
    }

    func recentActivity(limit: Int) async throws -> [AIInvocationRecord] { [] }
    func usage(since: Date) async throws -> AIUsageSummary { .empty }
    func providerStatus() async -> [AIProviderStatus] { [] }
}
