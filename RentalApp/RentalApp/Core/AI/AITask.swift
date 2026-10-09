//
//  AITask.swift
//  RentalApp (RentOS)
//
//  Core — The capability boundary.
//
//  ─────────────────────────────────────────────────────────────────
//  ONE FEATURE, ONE FILE, ONE TYPE
//  ─────────────────────────────────────────────────────────────────
//  Every AI feature in the app is an `AITask`: a typed input, a typed
//  output, the prompt that connects them, and the schema the model must
//  satisfy. Nothing else in the codebase writes a prompt.
//
//  That is what "modular" buys here:
//
//  • A feature can be tuned, versioned, or A/B tested without touching
//    any other feature or the transport.
//  • Its output is a Swift type, so a view binds to `LeaseSummary.risks`
//    rather than parsing a blob of markdown at render time.
//  • `promptVersion` is recorded with every invocation, so when quality
//    changes you can tell whether the prompt moved or the model did.
//    Without it, "the AI got worse" is unfalsifiable.
//

import Foundation

// MARK: - Task Kind

/// The catalogue. Also the audit log's category column, which is why it
/// is a stable string enum rather than a type name.
enum AITaskKind: String, Codable, Sendable, CaseIterable {
    case maintenanceClassification = "maintenance_classification"
    case leaseSummarization        = "lease_summarization"
    case portfolioCopilot          = "portfolio_copilot"
    case dashboardInsights         = "dashboard_insights"
    case riskDetection             = "risk_detection"
    case suggestedReply            = "suggested_reply"
    case documentSummary           = "document_summary"
    case propertyHealth            = "property_health"
    case smartRecommendations      = "smart_recommendations"
    case activitySummary           = "activity_summary"

    var displayName: String {
        switch self {
        case .maintenanceClassification: "Maintenance triage"
        case .leaseSummarization:        "Lease summary"
        case .portfolioCopilot:          "Copilot"
        case .dashboardInsights:         "Dashboard insights"
        case .riskDetection:             "Risk detection"
        case .suggestedReply:            "Suggested reply"
        case .documentSummary:           "Document summary"
        case .propertyHealth:            "Property health"
        case .smartRecommendations:      "Recommendations"
        case .activitySummary:           "Activity summary"
        }
    }

    var icon: String {
        switch self {
        case .maintenanceClassification: DS.Icons.maintenance
        case .leaseSummarization:        DS.Icons.lease
        case .portfolioCopilot:          DS.Icons.aiAssistant
        case .dashboardInsights:         DS.Icons.dashboard
        case .riskDetection:             DS.Icons.warning
        case .suggestedReply:            DS.Icons.messages
        case .documentSummary:           DS.Icons.documents
        case .propertyHealth:            DS.Icons.occupancy
        case .smartRecommendations:      DS.Icons.ai
        case .activitySummary:           DS.Icons.clock
        }
    }

    /// Whether accepting this task's output changes data.
    ///
    /// Read-only tasks (a summary, an insight) can render immediately.
    /// Anything that would write — a triage that sets priority, a reply
    /// that gets sent — needs a human to say yes first.
    var proposesMutation: Bool {
        switch self {
        case .maintenanceClassification, .suggestedReply, .smartRecommendations:
            true
        case .leaseSummarization, .portfolioCopilot, .dashboardInsights,
             .riskDetection, .documentSummary, .propertyHealth, .activitySummary:
            false
        }
    }
}

// MARK: - Task

/// One AI capability.
///
/// Conformers own their prompt and schema and nothing else — no network,
/// no persistence, no UI. That makes each one unit-testable against a
/// canned `AIResponse`.
protocol AITask: Sendable {

    associatedtype Input: Sendable
    associatedtype Output: Decodable & Sendable

    static var kind: AITaskKind { get }

    /// Bumped whenever the prompt or schema changes. Recorded per
    /// invocation so quality regressions can be attributed.
    static var promptVersion: String { get }

    var preference: AIModelPreference { get }
    var temperature: Double { get }
    var maxOutputTokens: Int { get }

    /// The schema the model must satisfy. Nil for free-text tasks.
    var responseSchema: AIJSONSchema? { get }

    /// Builds the conversation. The system prompt belongs here, not in a
    /// shared constant — a triage prompt and a tenant-reply prompt want
    /// genuinely different instructions.
    func messages(for input: Input) throws -> [AIMessage]

    /// What this call is about, for the audit trail.
    func subject(for input: Input) -> AISubject?

    /// Turns the raw response into the typed output.
    func decode(_ response: AIResponse) throws -> Output
}

// MARK: - Defaults

extension AITask {

    var temperature: Double { 0 }
    var maxOutputTokens: Int { 1_024 }

    func subject(for input: Input) -> AISubject? { nil }

    /// Default decoding for a schema-constrained task.
    ///
    /// Providers are inconsistent about whether structured output arrives
    /// in a dedicated field or embedded in the text, and some wrap it in
    /// a markdown fence despite being told not to. All three cases are
    /// handled here so no individual task has to care.
    func decode(_ response: AIResponse) throws -> Output {
        let data: Data
        if let structured = response.structuredJSON, !structured.isEmpty {
            data = structured
        } else if let extracted = Self.extractJSON(from: response.text) {
            data = extracted
        } else {
            throw AIError.malformedOutput(
                "\(Self.kind.rawValue): no JSON in response (finish: \(response.finishReason.rawValue))"
            )
        }

        do {
            return try AICoding.decoder.decode(Output.self, from: data)
        } catch {
            throw AIError.malformedOutput("\(Self.kind.rawValue): \(error)")
        }
    }

    /// Pulls the outermost JSON object or array out of a text response,
    /// tolerating markdown fences and leading commentary.
    static func extractJSON(from text: String) -> Data? {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if body.hasPrefix("```") {
            // Strip ```json … ``` fencing.
            let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
            let inner = lines.dropFirst().prefix { !$0.hasPrefix("```") }
            body = inner.joined(separator: "\n")
        }

        guard let start = body.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return nil }
        let opener = body[start]
        let closer: Character = opener == "{" ? "}" : "]"
        guard let end = body.lastIndex(of: closer), end > start else { return nil }

        return String(body[start...end]).data(using: .utf8)
    }

    /// Builds the transport request. The one place task metadata becomes
    /// an `AIRequest`, so a task can never accidentally bypass the router.
    func makeRequest(for input: Input) throws -> AIRequest {
        AIRequest(
            messages: try messages(for: input),
            preference: preference,
            responseSchema: responseSchema,
            maxOutputTokens: maxOutputTokens,
            temperature: temperature,
            subject: subject(for: input)
        )
    }
}

// MARK: - Coding

enum AICoding {

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    /// Compact JSON for embedding portfolio context in a prompt.
    ///
    /// Pretty-printing context is a real cost: whitespace is tokens, and
    /// on a long portfolio digest it is a meaningful fraction of the bill.
    static func compactJSON(_ value: some Encodable) -> String {
        (try? String(data: encoder.encode(value), encoding: .utf8)) ?? "{}"
    }
}

// MARK: - Shared Prompt Fragments

/// Instructions every task inherits.
///
/// Kept minimal on purpose. A large shared preamble looks efficient and
/// then quietly degrades every task, because instructions that help
/// triage often hurt drafting.
enum AIPrompt {

    /// The house rules: scope, honesty about uncertainty, and no invented
    /// facts. The last one matters most — a confidently wrong rent figure
    /// is worse than no figure.
    static let houseRules = """
        You are the assistant inside RentOS, a property management platform \
        used by landlords and property managers in Toronto, Canada.

        Rules:
        - Use only the data provided. Never invent names, amounts, dates, or \
        addresses. If something is not in the data, say so.
        - Amounts are Canadian dollars. Dates are ISO-8601.
        - Be concise and specific. Prefer "3 units vacant since May" over \
        "some units have been vacant for a while".
        - You advise; you do not decide. A human reviews everything you produce.
        - You are not a lawyer. For anything touching the Residential \
        Tenancies Act, describe the situation and recommend professional review \
        rather than asserting a legal conclusion.
        """

    /// Appended to schema-constrained tasks.
    static let jsonOnly = """
        Respond with JSON only, matching the provided schema exactly. \
        No markdown, no commentary, no code fences.
        """
}
