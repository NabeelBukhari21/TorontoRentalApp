//
//  AIAnalysisTasks.swift
//  RentalApp (Purrperty)
//
//  Core/AI — Read-only tasks: summarisation, insight, health, copilot.
//
//  None of these write anything, which is why they render as soon as they
//  return rather than waiting behind an approval gate. The distinction is
//  declared once on `AITaskKind.proposesMutation`, not re-decided here.
//

import Foundation

// MARK: - 5 · Lease Summarization

struct LeaseSummarizationTask: AITask {

    static let kind: AITaskKind = .leaseSummarization
    static let promptVersion = "2026-07-24.1"

    // A lease is 8–20 pages. Anything but a long-context model will
    // silently truncate and summarise half a document.
    let preference: AIModelPreference = .longContext
    let maxOutputTokens = 1_600

    struct Input: Sendable {
        let leaseID: String
        let documentText: String
        /// What Purrperty already believes, so the model can flag mismatches
        /// between the record and the signed document.
        let recordedRentCAD: Double?
        let recordedTermStart: Date?
        let recordedTermEnd: Date?
    }

    struct Output: Decodable, Sendable {
        let overview: String
        let keyTerms: [KeyTerm]
        let obligations: [String]
        let unusualClauses: [String]
        /// Where the document disagrees with the Purrperty record. The most
        /// valuable output here — silent drift between the two is how
        /// disputes start.
        let discrepancies: [Discrepancy]

        struct KeyTerm: Decodable, Sendable, Identifiable {
            var id: String { label }
            let label: String
            let value: String
        }

        struct Discrepancy: Decodable, Sendable, Identifiable {
            var id: String { field }
            let field: String
            let documentSays: String
            let recordSays: String
        }
    }

    var responseSchema: AIJSONSchema? {
        .object(
            properties: [
                "overview": .string(description: "Three sentences: who, what, how long"),
                "key_terms": .array(of: .object(
                    properties: [
                        "label": .string(description: "e.g. Monthly rent, Term, Deposit, Parking"),
                        "value": .string(description: "Verbatim from the document where possible")
                    ],
                    required: ["label", "value"]
                ), description: nil),
                "obligations": .array(of: .string(), description: "What the landlord must do"),
                "unusual_clauses": .array(of: .string(),
                                          description: "Anything a manager should read closely. Empty if standard."),
                "discrepancies": .array(of: .object(
                    properties: [
                        "field": .string(description: nil),
                        "document_says": .string(description: nil),
                        "record_says": .string(description: nil)
                    ],
                    required: ["field", "document_says", "record_says"]
                ), description: "Only where the document and the record genuinely differ")
            ],
            required: ["overview", "key_terms", "obligations", "unusual_clauses", "discrepancies"]
        )
    }

    func subject(for input: Input) -> AISubject? { .lease(input.leaseID) }

    func messages(for input: Input) throws -> [AIMessage] {
        let formatter = ISO8601DateFormatter()
        let recorded = """
            Rent on file: \(input.recordedRentCAD.map { "$\($0)" } ?? "unknown")
            Term on file: \(input.recordedTermStart.map(formatter.string(from:)) ?? "unknown") \
            to \(input.recordedTermEnd.map(formatter.string(from:)) ?? "unknown")
            """

        return [
            .system("""
                \(AIPrompt.houseRules)

                Summarise a residential lease for a property manager who has \
                thirty seconds. Quote figures verbatim rather than paraphrasing \
                them — a rounded rent is a wrong rent.

                Compare the document against the Purrperty record and report every \
                genuine difference. Do not report a difference caused by \
                formatting (\\$2,400.00 vs 2400) — only substantive ones.

                Flag unusual clauses without ruling on enforceability. Many \
                clauses in Ontario leases are void regardless of what the \
                document says; that is a lawyer's call, not yours.

                \(AIPrompt.jsonOnly)
                """),
            .user("""
                Purrperty record:
                \(recorded)

                Lease document:
                \(input.documentText)
                """)
        ]
    }
}

// MARK: - 6 · Document Summary

struct DocumentSummaryTask: AITask {

    static let kind: AITaskKind = .documentSummary
    static let promptVersion = "2026-07-24.1"

    let preference: AIModelPreference = .longContext
    let maxOutputTokens = 900

    struct Input: Sendable {
        let documentID: String
        let fileName: String
        let category: String
        let documentText: String
    }

    struct Output: Decodable, Sendable {
        let summary: String
        let documentType: String
        let keyDates: [KeyDate]
        let amounts: [Amount]
        let suggestedTags: [String]
        let actionRequired: String?

        struct KeyDate: Decodable, Sendable, Identifiable {
            var id: String { "\(label)-\(date)" }
            let label: String
            let date: String
        }

        struct Amount: Decodable, Sendable, Identifiable {
            var id: String { label }
            let label: String
            let valueCAD: Double
        }
    }

    var responseSchema: AIJSONSchema? {
        .object(
            properties: [
                "summary": .string(description: "Two or three sentences"),
                "document_type": .string(description: "What this actually is, in the writer's own words"),
                "key_dates": .array(of: .object(
                    properties: ["label": .string(), "date": .string(description: "ISO-8601 date")],
                    required: ["label", "date"]
                ), description: "Deadlines, expiries, effective dates"),
                "amounts": .array(of: .object(
                    properties: ["label": .string(), "value_cad": .number()],
                    required: ["label", "value_cad"]
                ), description: nil),
                "suggested_tags": .array(of: .string(), description: "3-5 lowercase tags for search"),
                "action_required": .string(description: "What the manager must do, or omit if nothing")
            ],
            required: ["summary", "document_type", "key_dates", "amounts", "suggested_tags"]
        )
    }

    func subject(for input: Input) -> AISubject? { .document(input.documentID) }

    func messages(for input: Input) throws -> [AIMessage] {
        [
            .system("""
                \(AIPrompt.houseRules)

                Summarise an uploaded document so it can be found and acted on \
                later. Extract dates and amounts exactly as written.

                If the text looks like failed OCR — fragments, no sentences — say \
                so in the summary rather than guessing at the content.

                \(AIPrompt.jsonOnly)
                """),
            .user("""
                File: \(input.fileName)
                Filed under: \(input.category)

                Contents:
                \(input.documentText)
                """)
        ]
    }
}

// MARK: - 7 · Dashboard Insights

struct DashboardInsightsTask: AITask {

    static let kind: AITaskKind = .dashboardInsights
    static let promptVersion = "2026-07-24.1"

    let preference: AIModelPreference = .fast
    let maxOutputTokens = 900

    struct Input: Sendable, Encodable {
        let portfolioDigest: AIPortfolioDigest
        /// Same digest from a month ago, so the model can describe change
        /// rather than restating the current state.
        let previousDigest: AIPortfolioDigest?
    }

    struct Output: Decodable, Sendable {
        let insights: [Insight]

        struct Insight: Decodable, Sendable, Identifiable {
            var id: String { headline }
            let topic: String
            let headline: String
            let detail: String
            let sentiment: String
            let metric: String?
        }
    }

    var responseSchema: AIJSONSchema? {
        .object(
            properties: [
                "insights": .array(of: .object(
                    properties: [
                        "topic": .enumeration(
                            values: ["occupancy", "revenue", "maintenance", "leasing",
                                     "tenant_sentiment", "portfolio_health"],
                            description: nil
                        ),
                        "headline": .string(description: "Under 50 characters"),
                        "detail": .string(description: "One sentence with the number behind it"),
                        "sentiment": .enumeration(values: ["positive", "neutral", "caution", "negative"], description: nil),
                        "metric": .string(description: "The figure itself, e.g. '94% occupied'")
                    ],
                    required: ["topic", "headline", "detail", "sentiment"]
                ), description: "Exactly 3 to 4 insights")
            ],
            required: ["insights"]
        )
    }

    func messages(for input: Input) throws -> [AIMessage] {
        [
            .system("""
                \(AIPrompt.houseRules)

                Write the insights strip for the dashboard. Each one earns its \
                place by telling the manager something the numbers on screen do \
                not already say.

                - Describe change and its cause, not the current value. The \
                cards already show the value.
                - If a previous digest is provided, lead with what moved.
                - Do not congratulate. "Occupancy is healthy" is filler.

                \(AIPrompt.jsonOnly)
                """),
            .user("""
                Current:
                \(AICoding.compactJSON(input.portfolioDigest))

                One month ago:
                \(input.previousDigest.map(AICoding.compactJSON) ?? "(no prior snapshot)")
                """)
        ]
    }
}

// MARK: - 8 · Property Health

struct PropertyHealthTask: AITask {

    static let kind: AITaskKind = .propertyHealth
    static let promptVersion = "2026-07-24.1"

    let preference: AIModelPreference = .reasoning
    let maxOutputTokens = 900

    struct Input: Sendable, Encodable {
        let propertyID: String
        let propertyName: String
        let unitCount: Int
        let occupiedCount: Int
        let monthlyRevenueCAD: Double
        let openRequestCount: Int
        let urgentRequestCount: Int
        let averageResolutionHours: Double?
        let overduePaymentCount: Int
        let leasesExpiringIn60Days: Int
        let yearBuilt: Int?
    }

    struct Output: Decodable, Sendable {
        /// 0–100. A single number the dial can render.
        let score: Int
        let grade: String
        let factors: [Factor]
        let summary: String

        struct Factor: Decodable, Sendable, Identifiable {
            var id: String { label }
            let label: String
            /// -100…100. Negative drags the score down.
                let impact: Int
            let detail: String
        }
    }

    var responseSchema: AIJSONSchema? {
        .object(
            properties: [
                "score": .integer(description: "0-100 overall health"),
                "grade": .enumeration(values: ["excellent", "good", "fair", "poor"], description: nil),
                "factors": .array(of: .object(
                    properties: [
                        "label": .string(description: "e.g. Occupancy, Maintenance load, Rent collection"),
                        "impact": .integer(description: "-100 to 100; negative hurts the score"),
                        "detail": .string(description: "One sentence with the number")
                    ],
                    required: ["label", "impact", "detail"]
                ), description: "3 to 5 factors, largest absolute impact first"),
                "summary": .string(description: "Two sentences a manager can act on")
            ],
            required: ["score", "grade", "factors", "summary"]
        )
    }

    func subject(for input: Input) -> AISubject? { .property(input.propertyID) }

    func messages(for input: Input) throws -> [AIMessage] {
        [
            .system("""
                \(AIPrompt.houseRules)

                Score one property's operational health from 0 to 100 and explain \
                the score through its factors.

                Weight roughly: occupancy and rent collection dominate, \
                maintenance load and resolution speed matter, upcoming lease \
                expiries are a forward risk. A small property with one vacancy \
                is not in crisis — scale the judgement to the unit count.

                The factors must add up to something a human would arrive at \
                independently. If the score and the factors disagree, the score \
                is wrong.

                \(AIPrompt.jsonOnly)
                """),
            .user(AICoding.compactJSON(input))
        ]
    }
}

// MARK: - 9 · Portfolio Copilot

struct PortfolioCopilotTask: AITask {

    static let kind: AITaskKind = .portfolioCopilot
    static let promptVersion = "2026-07-24.1"

    let preference: AIModelPreference = .reasoning
    let temperature = 0.3
    let maxOutputTokens = 1_200

    struct Input: Sendable {
        let portfolioDigest: AIPortfolioDigest
        /// Nil for the unprompted morning briefing.
        let question: String?
        /// Prior turns, so follow-ups like "what about the second one?"
        /// resolve.
        let history: [AIMessage]
    }

    /// Free text, not a schema: the copilot answers open questions, and
    /// forcing prose into fields would flatten exactly what makes it
    /// useful.
    struct Output: Decodable, Sendable {
        let answer: String
    }

    var responseSchema: AIJSONSchema? { nil }

    func decode(_ response: AIResponse) throws -> Output {
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AIError.malformedOutput("portfolio_copilot: empty response")
        }
        return Output(answer: text)
    }

    func messages(for input: Input) throws -> [AIMessage] {
        var messages: [AIMessage] = [
            .system("""
                \(AIPrompt.houseRules)

                You are the operations copilot. The manager can ask you anything \
                about their portfolio, and you answer from the digest below.

                - Answer the question asked, in two or three sentences. This is \
                a chat panel, not a report.
                - Cite the specific number or name behind every claim.
                - When the digest cannot answer it, say exactly what is missing. \
                "I don't have payment history for that unit" is a good answer; \
                a plausible guess is not.
                - No headings, no bullet lists unless enumerating three or more \
                items.

                Portfolio digest:
                \(AICoding.compactJSON(input.portfolioDigest))
                """)
        ]

        messages.append(contentsOf: input.history)

        if let question = input.question {
            messages.append(.user(question))
        } else {
            messages.append(.user("""
                Give me this morning's briefing: what needs my attention today, \
                and what changed since yesterday.
                """))
        }

        return messages
    }
}

// MARK: - 10 · Activity Summary

struct ActivitySummaryTask: AITask {

    static let kind: AITaskKind = .activitySummary
    static let promptVersion = "2026-07-24.1"

    let preference: AIModelPreference = .fast
    let maxOutputTokens = 600

    struct Input: Sendable {
        /// Raw activity rows, newest first.
        let entries: [(verb: String, summary: String, at: Date)]
        let periodLabel: String
    }

    struct Output: Decodable, Sendable {
        let narrative: String
        let themes: [String]
        let notable: [String]
    }

    var responseSchema: AIJSONSchema? {
        .object(
            properties: [
                "narrative": .string(description: "Two or three sentences covering the period"),
                "themes": .array(of: .string(), description: "2-4 short phrases"),
                "notable": .array(of: .string(), description: "Anything that stands out. Empty if routine.")
            ],
            required: ["narrative", "themes", "notable"]
        )
    }

    func messages(for input: Input) throws -> [AIMessage] {
        let formatter = ISO8601DateFormatter()
        let log = input.entries
            .map { "\(formatter.string(from: $0.at)) · \($0.verb) · \($0.summary)" }
            .joined(separator: "\n")

        return [
            .system("""
                \(AIPrompt.houseRules)

                Summarise what happened in the portfolio over this period, for a \
                manager catching up.

                Group related events instead of listing them — "four maintenance \
                requests closed, three of them plumbing" is worth more than four \
                separate lines. A quiet period should read as quiet.

                \(AIPrompt.jsonOnly)
                """),
            .user("""
                Period: \(input.periodLabel)

                Activity:
                \(log)
                """)
        ]
    }
}
