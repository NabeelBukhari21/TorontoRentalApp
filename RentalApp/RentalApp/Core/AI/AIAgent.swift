//
//  AIAgent.swift
//  RentalApp (Purrperty)
//
//  Core/AI — Agent scaffold.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY THIS EXISTS BEFORE THERE IS AN AGENT
//  ─────────────────────────────────────────────────────────────────
//  A single-shot task and an agent differ in one structural way: the
//  agent decides *what to do next*, repeatedly, and some of those choices
//  write to the database. Bolting that onto a request/response service
//  later means rewriting the service, because the loop needs things a
//  one-shot call never does — a step budget, a tool registry, a
//  transcript, and a place to stop and ask.
//
//  So the shape is here now, with the safety properties built in rather
//  than promised:
//
//  1. A step budget. Loops that cannot terminate are the default failure
//     mode of agent code, not an edge case.
//  2. A tool allowlist per agent. An agent can only call what it was
//     handed — capability, not instruction.
//  3. A hard gate on mutating tools. `AIToolbox.execute` refuses to run a
//     tool marked `isMutating` unless the caller passes an approval token
//     that only an accepted `AIProposal` can produce. The rule is enforced
//     by the type system, not by remembering to check.
//  4. Every step logged with its own invocation id, so a five-step run is
//     five auditable rows rather than one opaque "the agent did something".
//

import Foundation

// MARK: - Approval Token

/// Proof that a human approved a mutating action.
///
/// Cannot be constructed outside this file's `fileprivate` initialiser
/// path, so an agent cannot mint its own permission. The only public way
/// to obtain one is `AIProposal.approvalToken(...)` after acceptance.
struct AIApprovalToken: Sendable {
    let invocationID: UUID
    let approvedBy: String
    let approvedAt: Date

    fileprivate init(invocationID: UUID, approvedBy: String) {
        self.invocationID = invocationID
        self.approvedBy = approvedBy
        self.approvedAt = .now
    }
}

extension AIProposal {
    /// Available only once a human has accepted this proposal.
    var approvalToken: AIApprovalToken? {
        guard status == .accepted || status == .edited || status == .autoApplied,
              let decidedBy else { return nil }
        return AIApprovalToken(invocationID: provenance.invocationID, approvedBy: decidedBy)
    }
}

// MARK: - Tool Execution

/// A tool an agent can run.
protocol AIExecutableTool: Sendable {
    var descriptor: AITool { get }
    /// Receives the model's raw JSON arguments, returns a result string
    /// that goes back into the transcript.
    func execute(argumentsJSON: String) async throws -> String
}

/// The registry an agent is handed. It owns the mutating-tool rule.
struct AIToolbox: Sendable {

    private let tools: [String: any AIExecutableTool]

    init(_ tools: [any AIExecutableTool]) {
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.descriptor.name, $0) })
    }

    var descriptors: [AITool] { tools.values.map(\.descriptor) }

    /// Runs a tool call.
    ///
    /// - Parameter approval: required for any tool whose descriptor is
    ///   `isMutating`. Passing nil for such a tool is an error, not a
    ///   silent no-op — a swallowed refusal would leave the agent
    ///   believing it acted.
    func execute(_ call: AIToolCall, approval: AIApprovalToken?) async throws -> String {
        guard let tool = tools[call.name] else {
            throw AIError.malformedOutput("agent called unknown tool '\(call.name)'")
        }

        if tool.descriptor.isMutating && approval == nil {
            throw AIError.malformedOutput(
                "tool '\(call.name)' changes data and needs an approved proposal"
            )
        }

        return try await tool.execute(argumentsJSON: call.argumentsJSON)
    }

    func isMutating(_ name: String) -> Bool {
        tools[name]?.descriptor.isMutating ?? true   // unknown ⇒ treat as dangerous
    }
}

// MARK: - Run Result

enum AIAgentStopReason: String, Sendable {
    case completed
    case stepBudgetExhausted = "step_budget_exhausted"
    /// Paused because the next action needs human approval. The run can be
    /// resumed with a token.
    case awaitingApproval = "awaiting_approval"
    case failed
}

struct AIAgentRun: Sendable {
    let transcript: [AIMessage]
    let stopReason: AIAgentStopReason
    let steps: Int
    let totalUsage: AIUsage
    /// Set when `stopReason == .awaitingApproval`.
    let pendingCall: AIToolCall?
    let finalAnswer: String?
}

// MARK: - Agent

/// A goal-directed loop over a toolbox.
///
/// Not yet wired to a feature — deliberately. This is the substrate the
/// first real agent (a leasing assistant, or an overnight triage sweep)
/// will be built on, and having it typed now means that agent is a
/// configuration rather than an architecture change.
@MainActor
final class AIAgent {

    struct Configuration: Sendable {
        var name: String
        var systemPrompt: String
        var preference: AIModelPreference
        /// Hard ceiling on model round trips. Small on purpose: an agent
        /// that needs twenty steps usually needs a better prompt.
        var maxSteps: Int
        var maxOutputTokens: Int

        init(
            name: String,
            systemPrompt: String,
            preference: AIModelPreference = .reasoning,
            maxSteps: Int = 6,
            maxOutputTokens: Int = 1_200
        ) {
            self.name = name
            self.systemPrompt = systemPrompt
            self.preference = preference
            self.maxSteps = maxSteps
            self.maxOutputTokens = maxOutputTokens
        }
    }

    private let configuration: Configuration
    private let toolbox: AIToolbox
    private let router: AIRouter
    private let audit: AIAuditLogging

    init(
        configuration: Configuration,
        toolbox: AIToolbox,
        router: AIRouter,
        audit: AIAuditLogging
    ) {
        self.configuration = configuration
        self.toolbox = toolbox
        self.router = router
        self.audit = audit
    }

    /// Runs until the model answers, the budget runs out, or a mutating
    /// tool needs approval.
    ///
    /// - Parameter approvals: tokens already granted, keyed by tool name.
    ///   Resuming a paused run means calling again with one more entry.
    func run(
        goal: String,
        subject: AISubject? = nil,
        approvals: [String: AIApprovalToken] = [:]
    ) async -> AIAgentRun {

        var transcript: [AIMessage] = [
            .system(configuration.systemPrompt),
            .user(goal)
        ]
        var usage = AIUsage.zero
        var step = 0

        while step < configuration.maxSteps {
            step += 1

            let request = AIRequest(
                messages: transcript,
                preference: configuration.preference,
                tools: toolbox.descriptors,
                maxOutputTokens: configuration.maxOutputTokens,
                temperature: 0.2,
                subject: subject
            )

            let response: AIResponse
            do {
                response = try await router.complete(request)
            } catch {
                await logStep(step: step, subject: subject, usage: usage,
                              error: String(describing: error))
                return AIAgentRun(
                    transcript: transcript, stopReason: .failed, steps: step,
                    totalUsage: usage, pendingCall: nil, finalAnswer: nil
                )
            }

            usage = AIUsage(
                inputTokens: usage.inputTokens + response.usage.inputTokens,
                outputTokens: usage.outputTokens + response.usage.outputTokens,
                estimatedCostUSD: usage.estimatedCostUSD + response.usage.estimatedCostUSD,
                latency: usage.latency + response.usage.latency
            )

            await logStep(step: step, subject: subject, usage: response.usage, error: nil)

            // No tool calls means the model is answering.
            guard let call = response.toolCalls.first else {
                transcript.append(.assistant(response.text))
                return AIAgentRun(
                    transcript: transcript, stopReason: .completed, steps: step,
                    totalUsage: usage, pendingCall: nil, finalAnswer: response.text
                )
            }

            transcript.append(.assistant(response.text))

            // Pause rather than proceed when the next move writes data and
            // nobody has approved it.
            if toolbox.isMutating(call.name), approvals[call.name] == nil {
                return AIAgentRun(
                    transcript: transcript, stopReason: .awaitingApproval, steps: step,
                    totalUsage: usage, pendingCall: call, finalAnswer: nil
                )
            }

            do {
                let result = try await toolbox.execute(call, approval: approvals[call.name])
                transcript.append(AIMessage(
                    role: .tool, content: result,
                    toolCallID: call.id, toolName: call.name
                ))
            } catch {
                // Feed the failure back instead of aborting: a tool error
                // is often recoverable by the model choosing differently.
                transcript.append(AIMessage(
                    role: .tool,
                    content: "Error: \(error.localizedDescription)",
                    toolCallID: call.id, toolName: call.name
                ))
            }
        }

        return AIAgentRun(
            transcript: transcript, stopReason: .stepBudgetExhausted,
            steps: step, totalUsage: usage, pendingCall: nil, finalAnswer: nil
        )
    }

    private func logStep(
        step: Int,
        subject: AISubject?,
        usage: AIUsage,
        error: String?
    ) async {
        await audit.record(AIInvocationRecord(
            id: UUID(),
            taskKind: .portfolioCopilot,
            promptVersion: "agent:\(configuration.name)#\(step)",
            providerID: "router",
            modelID: "agent",
            preference: configuration.preference,
            subjectType: subject?.type,
            subjectID: subject?.id,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            estimatedCostUSD: usage.estimatedCostUSD,
            latency: usage.latency,
            didDecodeSuccessfully: error == nil,
            errorMessage: error,
            confidence: nil,
            status: .autoApplied,
            decidedBy: nil,
            decidedAt: nil,
            decisionNote: nil,
            createdAt: .now,
            promptDigest: "agent"
        ))
    }
}
