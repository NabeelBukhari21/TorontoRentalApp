//
//  AIOperationsTasks.swift
//  RentalApp (Purrperty)
//
//  Core/AI — Tasks that act on day-to-day operations:
//  maintenance triage, suggested replies, risk detection, recommendations.
//
//  These are the tasks whose output can *change* something, which is why
//  each returns a structured proposal with a confidence score rather than
//  prose. A number the UI can threshold on is the difference between
//  "auto-triage low-risk tickets" and "make a human read all of them".
//

import Foundation

// MARK: - 1 · Maintenance Classification

struct MaintenanceClassificationTask: AITask {

    static let kind: AITaskKind = .maintenanceClassification
    static let promptVersion = "2026-07-24.1"

    let preference: AIModelPreference = .fast
    let maxOutputTokens = 700

    struct Input: Sendable {
        let requestID: String
        let title: String
        let details: String?
        let propertyName: String
        let unitLabel: String?
        let reportedAt: Date
        /// Trade names the workspace actually has vendors for, so the model
        /// suggests a category someone can act on.
        let availableTrades: [String]
    }

    struct Output: Decodable, Sendable {
        let category: String
        let priority: String
        let urgencyScore: Double
        let categoryConfidence: Double
        let summary: String
        let suggestedActions: [String]
        let isEmergency: Bool
        /// Why it landed here. Shown in the AI panel so a manager can
        /// disagree with the reasoning, not just the verdict.
        let rationale: String
    }

    var responseSchema: AIJSONSchema? {
        .object(
            properties: [
                "category": .enumeration(
                    values: ["plumbing", "electrical", "hvac", "appliance", "carpentry",
                             "roofing", "landscaping", "cleaning", "pest_control", "general"],
                    description: "Best-matching trade"
                ),
                "priority": .enumeration(
                    values: ["emergency", "urgent", "high", "medium", "low"],
                    description: "Emergency means risk to safety or property right now"
                ),
                "urgency_score": .number(description: "0.0 to 1.0"),
                "category_confidence": .number(description: "0.0 to 1.0"),
                "summary": .string(description: "One sentence a manager can scan"),
                "suggested_actions": .array(of: .string(), description: "2-4 concrete next steps"),
                "is_emergency": .boolean(description: "True only for flood, fire, gas, no heat in winter, security"),
                "rationale": .string(description: "One or two sentences explaining the classification")
            ],
            required: ["category", "priority", "urgency_score", "category_confidence",
                       "summary", "suggested_actions", "is_emergency", "rationale"]
        )
    }

    func subject(for input: Input) -> AISubject? { .maintenanceRequest(input.requestID) }

    func messages(for input: Input) throws -> [AIMessage] {
        [
            .system("""
                \(AIPrompt.houseRules)

                You are triaging a maintenance request. Classify it by trade and \
                urgency so it reaches the right vendor quickly.

                Toronto-specific judgement:
                - No heat between October and April is an emergency, not a \
                convenience issue — it is a statutory obligation.
                - Water ingress is urgent even when it sounds minor; in a \
                multi-unit building it becomes several claims fast.
                - "Not working" with no detail means low confidence. Say so \
                rather than guessing a trade.

                \(AIPrompt.jsonOnly)
                """),
            .user("""
                Property: \(input.propertyName)
                Unit: \(input.unitLabel ?? "building-wide")
                Reported: \(ISO8601DateFormatter().string(from: input.reportedAt))
                Trades with vendors available: \(input.availableTrades.joined(separator: ", "))

                Title: \(input.title)
                Details: \(input.details ?? "(none provided)")
                """)
        ]
    }
}

// MARK: - 2 · Suggested Reply

struct SuggestedReplyTask: AITask {

    static let kind: AITaskKind = .suggestedReply
    static let promptVersion = "2026-07-24.1"

    let preference: AIModelPreference = .reasoning
    // Non-zero: a reply that reads like a form letter is worse than no
    // draft at all, because the manager rewrites it anyway.
    let temperature = 0.4
    let maxOutputTokens = 800

    struct Input: Sendable {
        let conversationID: String
        let tenantName: String
        let propertyName: String
        /// Oldest first. Only the tail is sent — a two-year thread would
        /// cost more than it informs.
        let recentMessages: [(sender: String, body: String)]
        let openRequestTitles: [String]
        let isRentOverdue: Bool
    }

    struct Output: Decodable, Sendable {
        let draft: String
        let tone: String
        /// Set when the right answer is "a human needs to handle this" —
        /// eviction talk, legal threats, distress.
        let requiresHumanAttention: Bool
        let attentionReason: String?
    }

    var responseSchema: AIJSONSchema? {
        .object(
            properties: [
                "draft": .string(description: "The reply, ready to send or edit. No greeting placeholders."),
                "tone": .enumeration(values: ["warm", "neutral", "firm"], description: nil),
                "requires_human_attention": .boolean(
                    description: "True if legal, eviction, harassment, or distress is involved"
                ),
                "attention_reason": .string(description: "Why, if requires_human_attention is true")
            ],
            required: ["draft", "tone", "requires_human_attention"]
        )
    }

    func subject(for input: Input) -> AISubject? { .conversation(input.conversationID) }

    func messages(for input: Input) throws -> [AIMessage] {
        let transcript = input.recentMessages
            .map { "\($0.sender): \($0.body)" }
            .joined(separator: "\n")

        return [
            .system("""
                \(AIPrompt.houseRules)

                Draft a reply from the property manager to a tenant. It will be \
                reviewed and edited before sending — so write the best version \
                you can, not a hedged template.

                - Address what was actually asked. Do not add unrelated reminders.
                - Commit to specifics only where the data supports them. Never \
                promise a date that is not in the context.
                - If rent is overdue, do not raise it unless the tenant did; a \
                maintenance thread is the wrong place to chase payment.
                - If the message involves eviction, legal action, harassment, or \
                a tenant in distress, set requires_human_attention and keep the \
                draft short and non-committal.

                \(AIPrompt.jsonOnly)
                """),
            .user("""
                Tenant: \(input.tenantName)
                Property: \(input.propertyName)
                Rent overdue: \(input.isRentOverdue ? "yes" : "no")
                Their open maintenance requests: \(input.openRequestTitles.isEmpty
                    ? "none" : input.openRequestTitles.joined(separator: "; "))

                Recent conversation:
                \(transcript)
                """)
        ]
    }
}

// MARK: - 3 · Risk Detection

struct RiskDetectionTask: AITask {

    static let kind: AITaskKind = .riskDetection
    static let promptVersion = "2026-07-24.1"

    let preference: AIModelPreference = .reasoning
    let maxOutputTokens = 1_400

    struct Input: Sendable, Encodable {
        let portfolioDigest: AIPortfolioDigest
    }

    struct Output: Decodable, Sendable {
        let risks: [Risk]

        struct Risk: Decodable, Sendable, Identifiable {
            var id: String { "\(subjectType)-\(subjectID)-\(kind)" }
            let kind: String
            let severity: String
            let headline: String
            let detail: String
            let subjectType: String
            let subjectID: String
            let confidence: Double
            let recommendedAction: String
        }
    }

    var responseSchema: AIJSONSchema? {
        .object(
            properties: [
                "risks": .array(of: .object(
                    properties: [
                        "kind": .enumeration(
                            values: ["rent_collection", "lease_renewal", "compliance_risk",
                                     "tenant_retention", "preventive_maintenance", "cost_saving"],
                            description: nil
                        ),
                        "severity": .enumeration(values: ["critical", "important", "informational"], description: nil),
                        "headline": .string(description: "Under 60 characters"),
                        "detail": .string(description: "Two sentences with the specific numbers"),
                        "subject_type": .enumeration(
                            values: ["property", "unit", "tenant", "lease", "maintenance_request", "organization"],
                            description: nil
                        ),
                        "subject_id": .string(description: "Id from the digest. Use the organization id if portfolio-wide."),
                        "confidence": .number(description: "0.0 to 1.0"),
                        "recommended_action": .string(description: "One concrete step")
                    ],
                    required: ["kind", "severity", "headline", "detail",
                               "subject_type", "subject_id", "confidence", "recommended_action"]
                ), description: "Highest severity first. At most 6. Empty array if nothing is wrong.")
            ],
            required: ["risks"]
        )
    }

    func messages(for input: Input) throws -> [AIMessage] {
        [
            .system("""
                \(AIPrompt.houseRules)

                Identify genuine risks in this portfolio. You are looking for \
                things that will cost money or cause a dispute if nobody acts.

                What counts:
                - A pattern, not a single data point. One late payment is not a \
                collection risk; three consecutive months is.
                - Something actionable this month.
                - Every claim tied to an id from the digest.

                An empty array is a correct and useful answer. Manufacturing a \
                risk to fill space destroys trust in every other risk you flag.

                \(AIPrompt.jsonOnly)
                """),
            .user("Portfolio digest:\n\(AICoding.compactJSON(input.portfolioDigest))")
        ]
    }
}

// MARK: - 4 · Smart Recommendations

struct SmartRecommendationsTask: AITask {

    static let kind: AITaskKind = .smartRecommendations
    static let promptVersion = "2026-07-24.1"

    let preference: AIModelPreference = .reasoning
    let maxOutputTokens = 1_400

    struct Input: Sendable, Encodable {
        let portfolioDigest: AIPortfolioDigest
        /// Recommendations the user already dismissed, so the same advice
        /// is not offered every morning.
        let dismissedKinds: [String]
    }

    struct Output: Decodable, Sendable {
        let recommendations: [Recommendation]

        struct Recommendation: Decodable, Sendable, Identifiable {
            var id: String { "\(kind)-\(subjectID)" }
            let kind: String
            let title: String
            let rationale: String
            let subjectType: String
            let subjectID: String
            let confidence: Double
            let estimatedImpactCAD: Double?
            let impactSummary: String
            /// The mutation this would perform if accepted. Names an app
            /// action, not free text, so the UI can bind a real button.
            let proposedAction: String
        }
    }

    var responseSchema: AIJSONSchema? {
        .object(
            properties: [
                "recommendations": .array(of: .object(
                    properties: [
                        "kind": .enumeration(
                            values: ["pricing_adjustment", "lease_renewal", "vendor_assignment",
                                     "preventive_maintenance", "cost_saving", "tenant_retention"],
                            description: nil
                        ),
                        "title": .string(description: "Under 60 characters, imperative"),
                        "rationale": .string(description: "Two sentences citing the numbers"),
                        "subject_type": .enumeration(
                            values: ["property", "unit", "tenant", "lease", "maintenance_request", "organization"],
                            description: nil
                        ),
                        "subject_id": .string(description: nil),
                        "confidence": .number(description: "0.0 to 1.0"),
                        "estimated_impact_cad": .number(description: "Monthly dollar impact, or omit if unknown"),
                        "impact_summary": .string(description: "e.g. '+$180/mo' or 'avoids ~$4k repair'"),
                        "proposed_action": .enumeration(
                            values: ["review_rent", "start_renewal", "assign_vendor",
                                     "schedule_inspection", "contact_tenant", "no_action"],
                            description: "Which app action this maps to"
                        )
                    ],
                    required: ["kind", "title", "rationale", "subject_type", "subject_id",
                               "confidence", "impact_summary", "proposed_action"]
                ), description: "At most 5, highest confidence first")
            ],
            required: ["recommendations"]
        )
    }

    func messages(for input: Input) throws -> [AIMessage] {
        [
            .system("""
                \(AIPrompt.houseRules)

                Recommend actions that improve this portfolio. Each must map to \
                something the manager can actually do in Purrperty today.

                - Quantify the impact where the data allows it; omit the number \
                rather than inventing one.
                - Do not repeat a kind the user has already dismissed.
                - Rent increases must respect Ontario's annual guideline. Never \
                state a specific legal maximum — recommend a review and say the \
                guideline applies.

                \(AIPrompt.jsonOnly)
                """),
            .user("""
                Already dismissed (do not repeat): \(input.dismissedKinds.isEmpty
                    ? "none" : input.dismissedKinds.joined(separator: ", "))

                Portfolio digest:
                \(AICoding.compactJSON(input.portfolioDigest))
                """)
        ]
    }
}

// MARK: - Portfolio Digest
//
// The context object several tasks share.
//
// Deliberately a *digest*, not raw rows. Sending every lease and payment
// would blow the context window on a mid-size portfolio, cost real money
// per call, and bury the signal. It is assembled server-side from the
// same aggregate views the dashboard uses, so the numbers the AI reasons
// about are the numbers the user sees.

struct AIPortfolioDigest: Codable, Sendable {

    let organizationID: String
    let generatedAt: Date

    let propertyCount: Int
    let unitCount: Int
    let occupiedCount: Int
    let monthlyRevenueCAD: Double

    let openRequestCount: Int
    let urgentRequestCount: Int
    let unassignedRequestCount: Int
    let averageResolutionHours: Double?

    let overduePaymentCount: Int
    let overdueAmountCAD: Double
    let leasesExpiringIn60Days: Int

    let properties: [PropertyLine]
    let expiringLeases: [LeaseLine]
    let strugglingTenants: [TenantLine]
    let staleRequests: [RequestLine]

    struct PropertyLine: Codable, Sendable {
        let id: String
        let name: String
        let unitCount: Int
        let occupiedCount: Int
        let monthlyRevenueCAD: Double
        let openRequestCount: Int
    }

    struct LeaseLine: Codable, Sendable {
        let id: String
        let tenantName: String
        let unitLabel: String
        let propertyName: String
        let rentCAD: Double
        let termEnd: Date
    }

    struct TenantLine: Codable, Sendable {
        let id: String
        let name: String
        let onTimePaymentRate: Double?
        let overdueAmountCAD: Double
        let monthsOverdue: Int
    }

    struct RequestLine: Codable, Sendable {
        let id: String
        let title: String
        let priority: String
        let status: String
        let ageDays: Int
        let propertyName: String
    }
}
