//
//  AIProvider.swift
//  RentalApp (Purrperty)
//
//  Core — The provider boundary.
//
//  ─────────────────────────────────────────────────────────────────
//  WHAT "NOT COUPLED TO ONE PROVIDER" ACTUALLY REQUIRES
//  ─────────────────────────────────────────────────────────────────
//  Swapping providers is easy to *claim* and easy to get wrong. Three
//  things leak vendor identity if you let them:
//
//  1. Model names. `"gpt-4o"` in a feature file is a hard dependency on
//     OpenAI. So callers state a *capability* — fast, reasoning,
//     long-context — and each provider maps that to whatever it has.
//  2. Response shapes. Providers differ on how they return structured
//     output (JSON mode, tool calls, XML tags). `AIResponse` carries a
//     decoded payload; making that happen is the provider's problem.
//  3. Token accounting. Every provider names usage differently, so it is
//     normalised on the way out — otherwise cost reporting silently
//     depends on which vendor answered.
//
//  ─────────────────────────────────────────────────────────────────
//  WHERE THE API KEY LIVES: NOT HERE
//  ─────────────────────────────────────────────────────────────────
//  No provider key is ever compiled into this app. An iOS binary is
//  readable by anyone who owns the device, so a shipped OpenAI key is a
//  shared key — someone else's bill, and no way to rotate it without an
//  App Store release. The production provider therefore talks to a
//  Supabase Edge Function that holds the secret server-side.
//
//  That constraint turns out to be a feature: switching from Anthropic
//  to Gemini becomes a server-side config change, not an app update.
//

import Foundation

// MARK: - Capability

/// What a caller needs from a model, rather than which model it wants.
///
/// This is the single most important indirection in the file: as long as
/// features ask for `.reasoning`, the mapping to `claude-opus-4`,
/// `gpt-4o`, `gemini-2.5-pro` or a local GGUF is a provider detail.
enum AIModelPreference: String, Codable, Sendable, CaseIterable {
    /// Cheap and quick. Classification, tagging, short rewrites.
    case fast
    /// Deliberate. Multi-step analysis, risk detection, planning.
    case reasoning
    /// Large input. Whole leases, long document sets.
    case longContext
    /// Runs on device. No network, no data egress — for tenant PII.
    case onDevice
}

// MARK: - Messages

enum AIRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    /// The result of a tool call, fed back for the next turn.
    case tool
}

struct AIMessage: Codable, Sendable, Equatable {
    let role: AIRole
    let content: String
    /// Set on `.tool` messages so the provider can correlate the result
    /// with the call that produced it.
    var toolCallID: String?
    var toolName: String?

    init(role: AIRole, content: String, toolCallID: String? = nil, toolName: String? = nil) {
        self.role = role
        self.content = content
        self.toolCallID = toolCallID
        self.toolName = toolName
    }

    static func system(_ text: String) -> AIMessage { .init(role: .system, content: text) }
    static func user(_ text: String) -> AIMessage { .init(role: .user, content: text) }
    static func assistant(_ text: String) -> AIMessage { .init(role: .assistant, content: text) }
}

// MARK: - Tools
//
// Present now because retrofitting tool-calling is a rewrite, not an
// addition: it changes the response type from "text" to "text or a
// request to act", and every call site has to handle the second case.

/// A capability an agent may invoke.
struct AITool: Codable, Sendable, Equatable {

    let name: String
    let description: String
    /// JSON Schema for the arguments. Sent verbatim to whichever
    /// provider is answering.
    let parametersSchema: AIJSONSchema

    /// Whether running this tool changes data.
    ///
    /// The agent loop refuses to execute a mutating tool without an
    /// approved proposal. This flag is what makes that enforceable rather
    /// than a convention someone forgets.
    let isMutating: Bool

    init(name: String, description: String, parametersSchema: AIJSONSchema, isMutating: Bool) {
        self.name = name
        self.description = description
        self.parametersSchema = parametersSchema
        self.isMutating = isMutating
    }
}

/// A tool the model wants to run.
struct AIToolCall: Codable, Sendable, Equatable {
    let id: String
    let name: String
    /// Raw JSON arguments, decoded by the tool that owns them.
    let argumentsJSON: String
}

// MARK: - Schema

/// A minimal JSON Schema representation.
///
/// Deliberately not a full implementation — it covers what structured
/// extraction needs (objects, arrays, enums, primitives) and nothing
/// more, so it stays readable and provider-portable.
indirect enum AIJSONSchema: Codable, Sendable, Equatable {
    case string(description: String? = nil)
    case number(description: String? = nil)
    case integer(description: String? = nil)
    case boolean(description: String? = nil)
    case enumeration(values: [String], description: String? = nil)
    case array(of: AIJSONSchema, description: String? = nil)
    case object(properties: [String: AIJSONSchema], required: [String], description: String? = nil)

    /// Encodes to real JSON Schema so it can be handed to any provider's
    /// structured-output mode unchanged.
    var jsonObject: [String: Any] {
        switch self {
        case .string(let d):
            return base("string", d)
        case .number(let d):
            return base("number", d)
        case .integer(let d):
            return base("integer", d)
        case .boolean(let d):
            return base("boolean", d)
        case .enumeration(let values, let d):
            var o = base("string", d)
            o["enum"] = values
            return o
        case .array(let element, let d):
            var o = base("array", d)
            o["items"] = element.jsonObject
            return o
        case .object(let properties, let required, let d):
            var o = base("object", d)
            o["properties"] = properties.mapValues(\.jsonObject)
            o["required"] = required
            // Providers vary in how strictly they honour this, but asking
            // for it is what keeps a model from inventing extra keys.
            o["additionalProperties"] = false
            return o
        }
    }

    private func base(_ type: String, _ description: String?) -> [String: Any] {
        var o: [String: Any] = ["type": type]
        if let description { o["description"] = description }
        return o
    }
}

// MARK: - Request

struct AIRequest: Sendable {

    var messages: [AIMessage]
    var preference: AIModelPreference
    /// When set, the provider must return JSON matching this shape.
    var responseSchema: AIJSONSchema?
    var tools: [AITool]
    var maxOutputTokens: Int
    /// 0 for extraction and classification, higher for drafting prose.
    /// Defaulted per task rather than globally, because "creative" is
    /// wrong for a rent calculation and "deterministic" is wrong for a
    /// tenant reply.
    var temperature: Double

    /// Ties the call to the record it is reasoning about, so the audit
    /// log can answer "what did the AI say about unit 402?".
    var subject: AISubject?

    init(
        messages: [AIMessage],
        preference: AIModelPreference = .fast,
        responseSchema: AIJSONSchema? = nil,
        tools: [AITool] = [],
        maxOutputTokens: Int = 1_024,
        temperature: Double = 0,
        subject: AISubject? = nil
    ) {
        self.messages = messages
        self.preference = preference
        self.responseSchema = responseSchema
        self.tools = tools
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.subject = subject
    }
}

/// What a call is about. Mirrors `Domain.EntityReference` so an audit row
/// can be joined back to the record.
struct AISubject: Codable, Sendable, Equatable {
    let type: String
    let id: String

    init(type: String, id: String) {
        self.type = type
        self.id = id
    }

    static func maintenanceRequest(_ id: String) -> AISubject { .init(type: "maintenance_request", id: id) }
    static func lease(_ id: String) -> AISubject { .init(type: "lease", id: id) }
    static func property(_ id: String) -> AISubject { .init(type: "property", id: id) }
    static func document(_ id: String) -> AISubject { .init(type: "document", id: id) }
    static func conversation(_ id: String) -> AISubject { .init(type: "conversation", id: id) }
    static func organization(_ id: String) -> AISubject { .init(type: "organization", id: id) }
}

// MARK: - Response

struct AIUsage: Codable, Sendable, Equatable {
    var inputTokens: Int
    var outputTokens: Int
    /// Normalised so cost reporting doesn't depend on who answered.
    var estimatedCostUSD: Double
    var latency: TimeInterval

    static let zero = AIUsage(inputTokens: 0, outputTokens: 0, estimatedCostUSD: 0, latency: 0)
}

enum AIFinishReason: String, Codable, Sendable {
    case stop
    case length
    case toolCalls = "tool_calls"
    case contentFilter = "content_filter"
    case unknown
}

struct AIResponse: Sendable {

    let text: String
    /// Present when the request carried a `responseSchema`. Raw bytes so
    /// each task decodes its own type.
    let structuredJSON: Data?
    let toolCalls: [AIToolCall]
    let finishReason: AIFinishReason
    let usage: AIUsage

    /// Which provider and model actually answered. Recorded in the audit
    /// log, and the reason a fallback is visible rather than silent.
    let providerID: String
    let modelID: String

    init(
        text: String,
        structuredJSON: Data? = nil,
        toolCalls: [AIToolCall] = [],
        finishReason: AIFinishReason = .stop,
        usage: AIUsage = .zero,
        providerID: String,
        modelID: String
    ) {
        self.text = text
        self.structuredJSON = structuredJSON
        self.toolCalls = toolCalls
        self.finishReason = finishReason
        self.usage = usage
        self.providerID = providerID
        self.modelID = modelID
    }
}

// MARK: - Errors

enum AIError: LocalizedError, Equatable {
    case notConfigured
    case unsupportedPreference(AIModelPreference)
    case rateLimited(retryAfter: TimeInterval?)
    case contentFiltered
    case malformedOutput(String)
    case allProvidersFailed
    case cancelled
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "AI features aren't set up for this workspace yet."
        case .unsupportedPreference:
            "No available model can handle this request."
        case .rateLimited:
            "The assistant is busy. Try again in a moment."
        case .contentFiltered:
            "The assistant declined to answer that."
        case .malformedOutput:
            // Deliberately vague to the user, specific in the log: the
            // detail is a developer problem, not theirs.
            "The assistant returned something unexpected. Nothing was changed."
        case .allProvidersFailed:
            "The assistant is unavailable right now."
        case .cancelled:
            "Cancelled."
        case .transport(let detail):
            detail
        }
    }

    /// Whether trying a different provider could plausibly succeed.
    /// A content filter or a malformed schema will fail identically
    /// everywhere, so the router must not burn budget retrying those.
    var isWorthFailingOver: Bool {
        switch self {
        case .rateLimited, .transport, .notConfigured, .unsupportedPreference: true
        case .contentFiltered, .malformedOutput, .allProvidersFailed, .cancelled: false
        }
    }
}

// MARK: - Provider

/// One AI backend. Implemented by the Edge Function proxy, the offline
/// mock, and — later — an on-device model.
///
/// Intentionally a single method. Everything richer (task typing,
/// approval, auditing, agents) is layered above rather than pushed into
/// each provider, so adding a fourth vendor stays a small job.
protocol AIProviderProtocol: AnyObject, Sendable {

    /// Stable identifier recorded in the audit log, e.g. `"anthropic"`.
    var id: String { get }

    /// Which capabilities this provider can serve. The router uses this
    /// to skip providers that cannot help rather than discovering it
    /// through a failed call.
    var supportedPreferences: Set<AIModelPreference> { get }

    /// False when unconfigured (no key server-side, model not downloaded).
    var isAvailable: Bool { get }

    func complete(_ request: AIRequest) async throws -> AIResponse
}
