//
//  AIProviders.swift
//  RentalApp (RentOS)
//
//  Services/AI — The concrete providers.
//
//  ─────────────────────────────────────────────────────────────────
//  THE APP NEVER HOLDS A PROVIDER KEY
//  ─────────────────────────────────────────────────────────────────
//  `EdgeFunctionAIProvider` sends a normalised request to a Supabase Edge
//  Function, which holds the OpenAI / Anthropic / Gemini keys as secrets
//  and does the vendor-specific translation. The app's request body is
//  identical regardless of who answers.
//
//  This is not caution for its own sake:
//
//  • An iOS binary is readable. A shipped key is a public key, and
//    rotating it means an App Store release.
//  • The function enforces per-organization rate limits and budget caps.
//    A client-side limit is a suggestion.
//  • Adding Gemini becomes a server deploy, not an app update — which is
//    the practical meaning of "not coupled to one provider".
//
//  `OnDeviceAIProvider` is the exception: it has no key because there is
//  no server. It is a stub until a model is bundled, and reports
//  `isAvailable == false` so the router simply skips it.
//

import Foundation
import Supabase

// MARK: - Edge Function Provider

/// Talks to `supabase/functions/ai-complete`.
final class EdgeFunctionAIProvider: AIProviderProtocol, @unchecked Sendable {

    let id: String
    let supportedPreferences: Set<AIModelPreference>

    private let client: SupabaseClient
    private let functionName: String

    /// Which upstream vendor the function should use for this provider
    /// instance. Registering the same function twice with different values
    /// is how the router gets a real failover chain across vendors.
    private let vendor: String

    init(
        id: String,
        vendor: String,
        client: SupabaseClient,
        supportedPreferences: Set<AIModelPreference>,
        functionName: String = "ai-complete"
    ) {
        self.id = id
        self.vendor = vendor
        self.client = client
        self.supportedPreferences = supportedPreferences
        self.functionName = functionName
    }

    /// The app cannot know whether the key is configured server-side, and
    /// probing on every launch would cost a request. Assume available and
    /// let the router's cooldown handle a vendor that is not.
    var isAvailable: Bool { true }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        let started = Date()

        let body = EdgeRequest(
            vendor: vendor,
            preference: request.preference.rawValue,
            messages: request.messages.map {
                EdgeRequest.Message(
                    role: $0.role.rawValue,
                    content: $0.content,
                    toolCallID: $0.toolCallID,
                    toolName: $0.toolName
                )
            },
            responseSchema: request.responseSchema.map { AnyCodableJSON($0.jsonObject) },
            tools: request.tools.map {
                EdgeRequest.Tool(
                    name: $0.name,
                    description: $0.description,
                    parameters: AnyCodableJSON($0.parametersSchema.jsonObject)
                )
            },
            maxOutputTokens: request.maxOutputTokens,
            temperature: request.temperature,
            subjectType: request.subject?.type,
            subjectID: request.subject?.id
        )

        do {
            let response: EdgeResponse = try await client.functions.invoke(
                functionName,
                options: FunctionInvokeOptions(body: body)
            )

            if let failure = response.error {
                throw Self.mapEdgeError(code: failure.code, message: failure.message)
            }

            return AIResponse(
                text: response.text ?? "",
                structuredJSON: response.structured.flatMap {
                    try? JSONSerialization.data(withJSONObject: $0.value)
                },
                toolCalls: (response.toolCalls ?? []).map {
                    AIToolCall(id: $0.id, name: $0.name, argumentsJSON: $0.arguments)
                },
                finishReason: AIFinishReason(rawValue: response.finishReason ?? "stop") ?? .unknown,
                usage: AIUsage(
                    inputTokens: response.usage?.inputTokens ?? 0,
                    outputTokens: response.usage?.outputTokens ?? 0,
                    estimatedCostUSD: response.usage?.estimatedCostUSD ?? 0,
                    latency: Date().timeIntervalSince(started)
                ),
                providerID: id,
                modelID: response.model ?? "unknown"
            )
        } catch let error as AIError {
            throw error
        } catch is CancellationError {
            throw AIError.cancelled
        } catch {
            throw AIError.transport(error.localizedDescription)
        }
    }

    private static func mapEdgeError(code: String, message: String) -> AIError {
        switch code {
        case "not_configured":  .notConfigured
        case "rate_limited":    .rateLimited(retryAfter: nil)
        case "budget_exceeded": .transport("This workspace has reached its monthly AI budget.")
        case "content_filter":  .contentFiltered
        case "bad_output":      .malformedOutput(message)
        default:                .transport(message)
        }
    }
}

// MARK: - Wire Types

private struct EdgeRequest: Encodable {
    let vendor: String
    let preference: String
    let messages: [Message]
    let responseSchema: AnyCodableJSON?
    let tools: [Tool]
    let maxOutputTokens: Int
    let temperature: Double
    let subjectType: String?
    let subjectID: String?

    struct Message: Encodable {
        let role: String
        let content: String
        let toolCallID: String?
        let toolName: String?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCallID = "tool_call_id"
            case toolName = "tool_name"
        }
    }

    struct Tool: Encodable {
        let name: String
        let description: String
        let parameters: AnyCodableJSON
    }

    enum CodingKeys: String, CodingKey {
        case vendor, preference, messages, tools, temperature
        case responseSchema = "response_schema"
        case maxOutputTokens = "max_output_tokens"
        case subjectType = "subject_type"
        case subjectID = "subject_id"
    }
}

private struct EdgeResponse: Decodable {
    let text: String?
    let structured: AnyCodableJSON?
    let toolCalls: [ToolCall]?
    let finishReason: String?
    let model: String?
    let usage: Usage?
    let error: Failure?

    struct ToolCall: Decodable {
        let id: String
        let name: String
        let arguments: String
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        let estimatedCostUSD: Double

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case estimatedCostUSD = "estimated_cost_usd"
        }
    }

    struct Failure: Decodable {
        let code: String
        let message: String
    }

    enum CodingKeys: String, CodingKey {
        case text, structured, model, usage, error
        case toolCalls = "tool_calls"
        case finishReason = "finish_reason"
    }
}

/// Carries an already-built JSON Schema dictionary through Codable.
///
/// `AIJSONSchema.jsonObject` produces `[String: Any]`, which Codable
/// cannot encode directly. This is the smallest bridge that avoids
/// hand-writing an encoder for the schema enum.
struct AnyCodableJSON: Codable, @unchecked Sendable {

    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let object = try? container.decode([String: AnyCodableJSON].self) {
            value = object.mapValues(\.value)
        } else if let array = try? container.decode([AnyCodableJSON].self) {
            value = array.map(\.value)
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let number = try? container.decode(Double.self) {
            value = number
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues(AnyCodableJSON.init))
        case let array as [Any]:
            try container.encode(array.map(AnyCodableJSON.init))
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let array as [String]:
            try container.encode(array)
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - On-Device Provider

/// Placeholder for a bundled local model.
///
/// Reports unavailable, so the router skips it and nothing breaks. When a
/// model ships, only `complete` and `isAvailable` change — and because it
/// is the only provider that can serve `.onDevice`, tasks that must not
/// send tenant data off the device can already be written against it.
final class OnDeviceAIProvider: AIProviderProtocol, @unchecked Sendable {

    let id = "on-device"
    let supportedPreferences: Set<AIModelPreference> = [.onDevice, .fast]

    /// Flips to true once a model file is present in the bundle or
    /// downloaded into Application Support.
    var isAvailable: Bool { false }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        throw AIError.notConfigured
    }
}

// MARK: - Mock Provider

/// Deterministic offline provider for previews, tests, and development
/// without a backend.
///
/// Returns schema-shaped canned output rather than lorem ipsum, so the UI
/// renders realistically and decoding is genuinely exercised — a mock that
/// returns prose would let a schema bug reach production.
final class MockAIProvider: AIProviderProtocol, @unchecked Sendable {

    let id = "mock"
    let supportedPreferences: Set<AIModelPreference> = Set(AIModelPreference.allCases)
    var isAvailable: Bool { true }

    private let latency: Duration

    init(latency: Duration = .milliseconds(900)) {
        self.latency = latency
    }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        try? await Task.sleep(for: latency)
        try Task.checkCancellation()

        let text = Self.cannedResponse(for: request)
        return AIResponse(
            text: text,
            structuredJSON: request.responseSchema == nil ? nil : text.data(using: .utf8),
            finishReason: .stop,
            usage: AIUsage(
                inputTokens: request.messages.reduce(0) { $0 + $1.content.count / 4 },
                outputTokens: text.count / 4,
                estimatedCostUSD: 0,
                latency: Double(latency.components.seconds)
            ),
            providerID: id,
            modelID: "mock-1"
        )
    }

    /// Keyed off the schema's shape rather than the task type, because the
    /// provider layer deliberately does not know what tasks exist.
    private static func cannedResponse(for request: AIRequest) -> String {
        guard case .object(let properties, _, _)? = request.responseSchema else {
            return """
                Two units are vacant at Queen West Lofts, and rent collection is \
                at 96% for the month. The oldest open request is a 9-day plumbing \
                ticket at 88 Bathurst — it has no vendor assigned yet.
                """
        }

        // Build a value for each declared property so decoding succeeds
        // for any task without a per-task branch here.
        var fields: [String] = []
        for (key, schema) in properties.sorted(by: { $0.key < $1.key }) {
            fields.append("\"\(key)\": \(sample(for: schema, key: key))")
        }
        return "{\(fields.joined(separator: ", "))}"
    }

    private static func sample(for schema: AIJSONSchema, key: String) -> String {
        switch schema {
        case .string:
            "\"\(placeholder(for: key))\""
        case .number:
            key.contains("confidence") || key.contains("score") ? "0.82" : "1250"
        case .integer:
            key.contains("score") ? "78" : "3"
        case .boolean:
            "false"
        case .enumeration(let values, _):
            "\"\(values.first ?? "unknown")\""
        case .array(let element, _):
            "[\(sample(for: element, key: key))]"
        case .object(let properties, _, _):
            "{\(properties.sorted { $0.key < $1.key }.map { "\"\($0.key)\": \(sample(for: $0.value, key: $0.key))" }.joined(separator: ", "))}"
        }
    }

    private static func placeholder(for key: String) -> String {
        switch key {
        case "summary", "detail", "narrative", "overview", "rationale":
            "Sample analysis generated by the offline provider."
        case "headline", "title":
            "Two units vacant since May"
        case "draft":
            "Thanks for flagging this — I've booked a plumber for Thursday morning and will confirm the window once they reply."
        case "label", "field":
            "Monthly rent"
        case "value", "record_says", "document_says":
            "$2,400"
        case "date":
            "2026-09-01"
        case "grade":
            "good"
        case "impact_summary":
            "+$180/mo"
        default:
            "Sample"
        }
    }
}
