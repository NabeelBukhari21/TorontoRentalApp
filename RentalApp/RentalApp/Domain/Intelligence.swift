//
//  Intelligence.swift
//  RentalApp (Purrperty)
//
//  Domain — Copilot output and dashboard composition.
//
//  Two rules keep this layer honest over time:
//
//  1. AI output is DATA, not ephemera. Recommendations and insights
//     are persisted rows with a model version and an outcome, so the
//     product can answer "did the copilot actually help?" — the
//     question every AI feature eventually has to survive.
//
//  2. Metrics carry their own units and comparison basis. A number
//     without a period and a unit is a bug waiting to happen.
//

import Foundation

// MARK: - AI Recommendation

extension Domain {

    /// A specific action the copilot proposes, with an expected impact
    /// and a recorded outcome once the user accepts or dismisses it.
    struct AIRecommendation: Record, OrganizationScoped {

        typealias Subject = AIRecommendation
        static let tableName = "ai_recommendations"

        let id: Identifier<AIRecommendation>
        let organizationID: Identifier<Organization>

        var kind: Kind
        var title: String
        var rationale: String
        /// What the recommendation concerns.
        var subject: EntityReference?

        // Impact
        var severity: Severity
        /// Estimated financial effect, positive or negative.
        var estimatedImpact: Money?
        /// One-line impact summary, e.g. "Protects $28.1K/yr".
        var impactSummary: String?
        /// 0...1 model confidence.
        var confidence: Double

        // Outcome — the feedback loop.
        var state: State
        var respondedByUserID: Identifier<User>?
        var respondedAt: Date?
        /// Task spawned on acceptance, if any.
        var resultingTaskID: Identifier<Task>?

        // Provenance
        var modelVersion: String
        /// Recommendations go stale; hide rather than mislead.
        var expiresAt: Date?

        let createdAt: Date
        var updatedAt: Date

        init(
            id: Identifier<AIRecommendation> = .init(),
            organizationID: Identifier<Organization>,
            kind: Kind,
            title: String,
            rationale: String,
            subject: EntityReference? = nil,
            severity: Severity = .informational,
            estimatedImpact: Money? = nil,
            impactSummary: String? = nil,
            confidence: Double = 0.5,
            state: State = .pending,
            respondedByUserID: Identifier<User>? = nil,
            respondedAt: Date? = nil,
            resultingTaskID: Identifier<Task>? = nil,
            modelVersion: String,
            expiresAt: Date? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.organizationID = organizationID
            self.kind = kind
            self.title = title
            self.rationale = rationale
            self.subject = subject
            self.severity = severity
            self.estimatedImpact = estimatedImpact
            self.impactSummary = impactSummary
            self.confidence = confidence
            self.state = state
            self.respondedByUserID = respondedByUserID
            self.respondedAt = respondedAt
            self.resultingTaskID = resultingTaskID
            self.modelVersion = modelVersion
            self.expiresAt = expiresAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        enum Kind: String, FallbackDecodable, CaseIterable {
            case rentCollection = "rent_collection"
            case leaseRenewal = "lease_renewal"
            case pricingAdjustment = "pricing_adjustment"
            case preventiveMaintenance = "preventive_maintenance"
            case vendorAssignment = "vendor_assignment"
            case costSaving = "cost_saving"
            case complianceRisk = "compliance_risk"
            case tenantRetention = "tenant_retention"
            case unknown
        }

        enum Severity: String, FallbackDecodable, CaseIterable {
            case critical
            case important
            case informational
            case unknown
        }

        /// Lifecycle of a single recommendation.
        enum State: String, FallbackDecodable, CaseIterable {
            case pending
            case accepted
            case dismissed
            case expired
            /// Accepted and the resulting work finished.
            case completed
            case unknown
        }

        func isActionable(asOf date: Date = .now) -> Bool {
            guard state == .pending else { return false }
            guard let expiresAt else { return true }
            return expiresAt > date
        }

        enum CodingKeys: String, CodingKey {
            case id, kind, title, rationale, subject, severity, confidence, state
            case organizationID = "organization_id"
            case estimatedImpact = "estimated_impact"
            case impactSummary = "impact_summary"
            case respondedByUserID = "responded_by_user_id"
            case respondedAt = "responded_at"
            case resultingTaskID = "resulting_task_id"
            case modelVersion = "model_version"
            case expiresAt = "expires_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
}

// MARK: - AI Insight

extension Domain {

    /// An observation about the portfolio — narrative rather than a
    /// call to action. Insights explain; recommendations ask.
    struct AIInsight: Record, OrganizationScoped {

        typealias Subject = AIInsight
        static let tableName = "ai_insights"

        let id: Identifier<AIInsight>
        let organizationID: Identifier<Organization>

        var topic: Topic
        var headline: String
        var detail: String
        var sentiment: Sentiment
        /// Entities the insight draws on — powers "show me why".
        var relatedSubjects: [EntityReference]

        /// Window the insight was computed over.
        var period: DateRange?
        var modelVersion: String
        var isPinned: Bool
        var dismissedAt: Date?

        let createdAt: Date
        var updatedAt: Date

        init(
            id: Identifier<AIInsight> = .init(),
            organizationID: Identifier<Organization>,
            topic: Topic,
            headline: String,
            detail: String,
            sentiment: Sentiment = .neutral,
            relatedSubjects: [EntityReference] = [],
            period: DateRange? = nil,
            modelVersion: String,
            isPinned: Bool = false,
            dismissedAt: Date? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.organizationID = organizationID
            self.topic = topic
            self.headline = headline
            self.detail = detail
            self.sentiment = sentiment
            self.relatedSubjects = relatedSubjects
            self.period = period
            self.modelVersion = modelVersion
            self.isPinned = isPinned
            self.dismissedAt = dismissedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        enum Topic: String, FallbackDecodable, CaseIterable {
            case maintenance
            case leasing
            case occupancy
            case revenue
            case tenantSentiment = "tenant_sentiment"
            case marketComparison = "market_comparison"
            case portfolioHealth = "portfolio_health"
            case unknown
        }

        enum Sentiment: String, FallbackDecodable, CaseIterable {
            case positive
            case neutral
            case caution
            case negative
            case unknown
        }

        var isVisible: Bool { dismissedAt == nil }

        enum CodingKeys: String, CodingKey {
            case id, topic, headline, detail, sentiment, period
            case organizationID = "organization_id"
            case relatedSubjects = "related_subjects"
            case modelVersion = "model_version"
            case isPinned = "is_pinned"
            case dismissedAt = "dismissed_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
}

// MARK: - Dashboard Metric

extension Domain {

    /// One computed number, with everything needed to render and
    /// compare it. Values are stored as `Decimal` with an explicit
    /// unit so formatting never has to guess.
    struct DashboardMetric: Record, OrganizationScoped {

        typealias Subject = DashboardMetric
        static let tableName = "dashboard_metrics"

        let id: Identifier<DashboardMetric>
        let organizationID: Identifier<Organization>

        var key: Key
        var value: Decimal
        var unit: MetricUnit
        /// Window the value covers.
        var period: DateRange
        /// Same metric, previous comparable period. Nil on first run.
        var previousValue: Decimal?
        /// Optional narrowing — a metric for one property, not the portfolio.
        var scope: EntityReference?

        /// When the value was last recomputed.
        var computedAt: Date

        let createdAt: Date
        var updatedAt: Date

        init(
            id: Identifier<DashboardMetric> = .init(),
            organizationID: Identifier<Organization>,
            key: Key,
            value: Decimal,
            unit: MetricUnit,
            period: DateRange,
            previousValue: Decimal? = nil,
            scope: EntityReference? = nil,
            computedAt: Date = .now,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.organizationID = organizationID
            self.key = key
            self.value = value
            self.unit = unit
            self.period = period
            self.previousValue = previousValue
            self.scope = scope
            self.computedAt = computedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        /// The catalogue of things Purrperty measures. Adding a metric is
        /// a case here plus a server-side calculation — nothing else.
        enum Key: String, FallbackDecodable, CaseIterable {
            case occupancyRate = "occupancy_rate"
            case monthlyRevenue = "monthly_revenue"
            case rentCollectionRate = "rent_collection_rate"
            case openMaintenanceCount = "open_maintenance_count"
            case averageResolutionHours = "average_resolution_hours"
            case activeTenantCount = "active_tenant_count"
            case vacantUnitCount = "vacant_unit_count"
            case upcomingRenewalCount = "upcoming_renewal_count"
            case overduePaymentTotal = "overdue_payment_total"
            case portfolioValue = "portfolio_value"
            case maintenanceSpend = "maintenance_spend"
            case portfolioHealthScore = "portfolio_health_score"
            case unknown
        }

        /// Named `MetricUnit` rather than `Unit` so it can never be
        /// confused with `Domain.Unit`, the leasable space.
        enum MetricUnit: String, FallbackDecodable, CaseIterable {
            case count
            case currency
            case percentage
            case hours
            case days
            /// 0–100 composite index.
            case score
            case unknown
        }

        /// Signed change versus the previous period, as a fraction.
        var changeFraction: Decimal? {
            guard let previousValue, previousValue != 0 else { return nil }
            return (value - previousValue) / abs(previousValue)
        }

        /// Whether the movement is favourable. Some metrics are better
        /// when they fall, which the caller can't infer from the number.
        var lowerIsBetter: Bool {
            switch key {
            case .openMaintenanceCount, .averageResolutionHours,
                 .vacantUnitCount, .overduePaymentTotal, .maintenanceSpend:
                true
            default:
                false
            }
        }

        enum CodingKeys: String, CodingKey {
            case id, key, value, unit, period, scope
            case organizationID = "organization_id"
            case previousValue = "previous_value"
            case computedAt = "computed_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
}

// MARK: - Dashboard Widget

extension Domain {

    /// A user's placement of one card on their dashboard.
    ///
    /// Layout is per-user data, not app configuration — which is why
    /// it is a persisted row rather than a hardcoded screen.
    struct DashboardWidget: Record, OrganizationScoped {

        typealias Subject = DashboardWidget
        static let tableName = "dashboard_widgets"

        let id: Identifier<DashboardWidget>
        let organizationID: Identifier<Organization>
        let ownerUserID: Identifier<User>

        var kind: Kind
        /// Metrics this widget renders, in display order.
        var metricKeys: [DashboardMetric.Key]
        var size: Size
        /// Ascending display order within the dashboard.
        var position: Int
        var isVisible: Bool
        /// Optional narrowing, e.g. a single-property revenue card.
        var scope: EntityReference?
        var title: String?

        let createdAt: Date
        var updatedAt: Date

        init(
            id: Identifier<DashboardWidget> = .init(),
            organizationID: Identifier<Organization>,
            ownerUserID: Identifier<User>,
            kind: Kind,
            metricKeys: [DashboardMetric.Key] = [],
            size: Size = .medium,
            position: Int = 0,
            isVisible: Bool = true,
            scope: EntityReference? = nil,
            title: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.organizationID = organizationID
            self.ownerUserID = ownerUserID
            self.kind = kind
            self.metricKeys = metricKeys
            self.size = size
            self.position = position
            self.isVisible = isVisible
            self.scope = scope
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        /// Presentation archetype. The feature layer maps each to a view.
        enum Kind: String, FallbackDecodable, CaseIterable {
            case metricGrid = "metric_grid"
            case revenueChart = "revenue_chart"
            case occupancyRing = "occupancy_ring"
            case maintenanceOverview = "maintenance_overview"
            case activityFeed = "activity_feed"
            case taskList = "task_list"
            case aiInsights = "ai_insights"
            case quickActions = "quick_actions"
            case portfolioHealth = "portfolio_health"
            case unknown
        }

        enum Size: String, FallbackDecodable, CaseIterable {
            case small
            case medium
            case large
            /// Spans the full dashboard width.
            case full
            case unknown
        }

        enum CodingKeys: String, CodingKey {
            case id, kind, size, position, scope, title
            case organizationID = "organization_id"
            case ownerUserID = "owner_user_id"
            case metricKeys = "metric_keys"
            case isVisible = "is_visible"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
}
