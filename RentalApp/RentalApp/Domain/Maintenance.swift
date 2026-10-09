//
//  Maintenance.swift
//  RentalApp (RentOS)
//
//  Domain — Work orders, the people who do the work, and inspections.
//
//      MaintenanceRequest ──> MaintenanceUpdate  (append-only history)
//                        └──> Vendor             (assignment)
//
//  `MaintenanceUpdate` is a separate append-only table rather than a
//  mutable field on the request. Status history, comments, and vendor
//  changes all become rows, which is what makes an audit trail and a
//  real activity timeline possible years later.
//

import Foundation

// MARK: - Vendor

extension Domain {

    /// A contractor or service company.
    struct Vendor: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Vendor
        static let tableName = "vendors"

        // Identity
        let id: Identifier<Vendor>
        let organizationID: Identifier<Organization>
        var companyName: String
        var contactName: String?
        var email: String?
        var phone: String?
        var address: Address?

        // Capability
        var trades: [Trade]
        /// Typical acknowledgement time in hours — used by AI matching.
        var responseTimeHours: Int?
        var hourlyRate: Money?
        /// Willing to take after-hours emergency calls.
        var handlesEmergencies: Bool

        // Performance — maintained by the maintenance service.
        var rating: Decimal?
        var completedJobCount: Int

        // Compliance
        var isInsured: Bool
        var insuranceExpiresAt: Date?
        var isPreferred: Bool

        var notes: String?

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Vendor> = .init(),
            organizationID: Identifier<Organization>,
            companyName: String,
            contactName: String? = nil,
            email: String? = nil,
            phone: String? = nil,
            address: Address? = nil,
            trades: [Trade] = [],
            responseTimeHours: Int? = nil,
            hourlyRate: Money? = nil,
            handlesEmergencies: Bool = false,
            rating: Decimal? = nil,
            completedJobCount: Int = 0,
            isInsured: Bool = false,
            insuranceExpiresAt: Date? = nil,
            isPreferred: Bool = false,
            notes: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.companyName = companyName
            self.contactName = contactName
            self.email = email
            self.phone = phone
            self.address = address
            self.trades = trades
            self.responseTimeHours = responseTimeHours
            self.hourlyRate = hourlyRate
            self.handlesEmergencies = handlesEmergencies
            self.rating = rating
            self.completedJobCount = completedJobCount
            self.isInsured = isInsured
            self.insuranceExpiresAt = insuranceExpiresAt
            self.isPreferred = isPreferred
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        /// Shared with `MaintenanceRequest.category` so vendor matching
        /// is a set intersection rather than a mapping table.
        enum Trade: String, FallbackDecodable, CaseIterable {
            case plumbing
            case electrical
            case hvac
            case appliance
            case carpentry
            case roofing
            case landscaping
            case cleaning
            case pestControl = "pest_control"
            case general
            case unknown
        }

        /// Insurance lapsed or lapsing within 30 days.
        func insuranceNeedsAttention(asOf date: Date = .now) -> Bool {
            guard isInsured, let expiry = insuranceExpiresAt else { return true }
            let days = Calendar.current.dateComponents([.day], from: date, to: expiry).day ?? 0
            return days <= 30
        }

        enum CodingKeys: String, CodingKey {
            case id, email, phone, trades, rating, notes, address
            case organizationID = "organization_id"
            case companyName = "company_name"
            case contactName = "contact_name"
            case responseTimeHours = "response_time_hours"
            case hourlyRate = "hourly_rate"
            case handlesEmergencies = "handles_emergencies"
            case completedJobCount = "completed_job_count"
            case isInsured = "is_insured"
            case insuranceExpiresAt = "insurance_expires_at"
            case isPreferred = "is_preferred"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}

// MARK: - Maintenance Request

extension Domain {

    /// A work order. The flagship workflow object.
    struct MaintenanceRequest: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = MaintenanceRequest
        static let tableName = "maintenance_requests"

        // Identity
        let id: Identifier<MaintenanceRequest>
        let organizationID: Identifier<Organization>
        let propertyID: Identifier<Property>
        /// Nil for common-area work.
        var unitID: Identifier<Unit>?
        /// Nil when staff raised it rather than a renter.
        var reportedByTenantID: Identifier<Tenant>?
        var reportedByUserID: Identifier<User>?

        // Content
        var title: String
        var details: String
        var category: Vendor.Trade
        var priority: Priority
        var status: Status
        var photos: [Attachment]
        /// Free-form labels for filtering and reporting.
        var tags: [String]

        // Assignment
        var assignedVendorID: Identifier<Vendor>?
        var assignedUserID: Identifier<User>?
        var scheduledFor: Date?
        var accessInstructions: String?

        // Economics
        var estimatedCost: Money?
        var actualCost: Money?
        /// Charged back to the tenant (damage rather than wear).
        var isTenantResponsible: Bool

        // AI triage — nil until the copilot has processed the request.
        var aiAnalysis: AIAnalysis?

        // Resolution
        var acknowledgedAt: Date?
        var resolvedAt: Date?
        var resolutionNotes: String?

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<MaintenanceRequest> = .init(),
            organizationID: Identifier<Organization>,
            propertyID: Identifier<Property>,
            unitID: Identifier<Unit>? = nil,
            reportedByTenantID: Identifier<Tenant>? = nil,
            reportedByUserID: Identifier<User>? = nil,
            title: String,
            details: String,
            category: Vendor.Trade = .general,
            priority: Priority = .medium,
            status: Status = .new,
            photos: [Attachment] = [],
            tags: [String] = [],
            assignedVendorID: Identifier<Vendor>? = nil,
            assignedUserID: Identifier<User>? = nil,
            scheduledFor: Date? = nil,
            accessInstructions: String? = nil,
            estimatedCost: Money? = nil,
            actualCost: Money? = nil,
            isTenantResponsible: Bool = false,
            aiAnalysis: AIAnalysis? = nil,
            acknowledgedAt: Date? = nil,
            resolvedAt: Date? = nil,
            resolutionNotes: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.propertyID = propertyID
            self.unitID = unitID
            self.reportedByTenantID = reportedByTenantID
            self.reportedByUserID = reportedByUserID
            self.title = title
            self.details = details
            self.category = category
            self.priority = priority
            self.status = status
            self.photos = photos
            self.tags = tags
            self.assignedVendorID = assignedVendorID
            self.assignedUserID = assignedUserID
            self.scheduledFor = scheduledFor
            self.accessInstructions = accessInstructions
            self.estimatedCost = estimatedCost
            self.actualCost = actualCost
            self.isTenantResponsible = isTenantResponsible
            self.aiAnalysis = aiAnalysis
            self.acknowledgedAt = acknowledgedAt
            self.resolvedAt = resolvedAt
            self.resolutionNotes = resolutionNotes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        /// Urgency. `Comparable` so queues sort without a lookup table.
        enum Priority: String, FallbackDecodable, CaseIterable, Comparable {
            case emergency
            case urgent
            case high
            case medium
            case low
            case unknown

            /// Lower sorts first.
            private var rank: Int {
                switch self {
                case .emergency: 0
                case .urgent: 1
                case .high: 2
                case .medium: 3
                case .low: 4
                case .unknown: 5
                }
            }

            static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }

            /// Requires same-day attention.
            var isCritical: Bool { self == .emergency || self == .urgent }
        }

        /// Workflow stage. Terminal states are `completed` and `cancelled`.
        enum Status: String, FallbackDecodable, CaseIterable {
            case new
            case triaged
            case scheduled
            case inProgress = "in_progress"
            case awaitingParts = "awaiting_parts"
            case completed
            case cancelled
            case unknown

            var isOpen: Bool {
                self != .completed && self != .cancelled
            }
        }

        /// Copilot triage output, persisted so decisions are auditable.
        struct AIAnalysis: Codable, Hashable, Sendable {
            /// 0...1 model-assessed urgency.
            var urgencyScore: Double
            /// 0...1 confidence in the assigned category.
            var categoryConfidence: Double
            var summary: String
            var suggestedActions: [String]
            var suggestedVendorID: Identifier<Vendor>?
            var draftTenantReply: String?
            /// Model identifier, so old analyses stay interpretable.
            var modelVersion: String
            var analyzedAt: Date

            enum CodingKeys: String, CodingKey {
                case summary
                case urgencyScore = "urgency_score"
                case categoryConfidence = "category_confidence"
                case suggestedActions = "suggested_actions"
                case suggestedVendorID = "suggested_vendor_id"
                case draftTenantReply = "draft_tenant_reply"
                case modelVersion = "model_version"
                case analyzedAt = "analyzed_at"
            }
        }

        /// Hours from report to resolution. Nil while still open.
        var resolutionHours: Int? {
            guard let resolvedAt else { return nil }
            return Calendar.current
                .dateComponents([.hour], from: createdAt, to: resolvedAt).hour
        }

        var isAssigned: Bool { assignedVendorID != nil || assignedUserID != nil }

        enum CodingKeys: String, CodingKey {
            case id, title, details, category, priority, status, photos, tags
            case organizationID = "organization_id"
            case propertyID = "property_id"
            case unitID = "unit_id"
            case reportedByTenantID = "reported_by_tenant_id"
            case reportedByUserID = "reported_by_user_id"
            case assignedVendorID = "assigned_vendor_id"
            case assignedUserID = "assigned_user_id"
            case scheduledFor = "scheduled_for"
            case accessInstructions = "access_instructions"
            case estimatedCost = "estimated_cost"
            case actualCost = "actual_cost"
            case isTenantResponsible = "is_tenant_responsible"
            case aiAnalysis = "ai_analysis"
            case acknowledgedAt = "acknowledged_at"
            case resolvedAt = "resolved_at"
            case resolutionNotes = "resolution_notes"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}

// MARK: - Maintenance Update

extension Domain {

    /// One entry in a request's history. Append-only — never edited,
    /// never deleted. This is the audit trail and the UI timeline.
    struct MaintenanceUpdate: Record, OrganizationScoped {

        typealias Subject = MaintenanceUpdate
        static let tableName = "maintenance_updates"

        let id: Identifier<MaintenanceUpdate>
        let organizationID: Identifier<Organization>
        let requestID: Identifier<MaintenanceRequest>

        // Author — exactly one of these is set, or none for system events.
        var authorUserID: Identifier<User>?
        var authorTenantID: Identifier<Tenant>?
        var authorVendorID: Identifier<Vendor>?

        var kind: Kind
        var body: String?
        var attachments: [Attachment]

        /// Populated for `.statusChanged` so the timeline can render
        /// "New → In Progress" without diffing adjacent rows.
        var fromStatus: MaintenanceRequest.Status?
        var toStatus: MaintenanceRequest.Status?

        /// Hidden from the tenant portal.
        var isInternal: Bool

        let createdAt: Date
        var updatedAt: Date

        init(
            id: Identifier<MaintenanceUpdate> = .init(),
            organizationID: Identifier<Organization>,
            requestID: Identifier<MaintenanceRequest>,
            authorUserID: Identifier<User>? = nil,
            authorTenantID: Identifier<Tenant>? = nil,
            authorVendorID: Identifier<Vendor>? = nil,
            kind: Kind,
            body: String? = nil,
            attachments: [Attachment] = [],
            fromStatus: MaintenanceRequest.Status? = nil,
            toStatus: MaintenanceRequest.Status? = nil,
            isInternal: Bool = false,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.organizationID = organizationID
            self.requestID = requestID
            self.authorUserID = authorUserID
            self.authorTenantID = authorTenantID
            self.authorVendorID = authorVendorID
            self.kind = kind
            self.body = body
            self.attachments = attachments
            self.fromStatus = fromStatus
            self.toStatus = toStatus
            self.isInternal = isInternal
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        enum Kind: String, FallbackDecodable, CaseIterable {
            case created
            case comment
            case statusChanged = "status_changed"
            case vendorAssigned = "vendor_assigned"
            case scheduled
            case photosAdded = "photos_added"
            case costRecorded = "cost_recorded"
            case aiTriaged = "ai_triaged"
            case tenantNotified = "tenant_notified"
            case resolved
            case unknown
        }

        enum CodingKeys: String, CodingKey {
            case id, kind, body, attachments
            case organizationID = "organization_id"
            case requestID = "request_id"
            case authorUserID = "author_user_id"
            case authorTenantID = "author_tenant_id"
            case authorVendorID = "author_vendor_id"
            case fromStatus = "from_status"
            case toStatus = "to_status"
            case isInternal = "is_internal"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
}

// MARK: - Inspection

extension Domain {

    /// A scheduled or completed property inspection.
    struct Inspection: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Inspection
        static let tableName = "inspections"

        let id: Identifier<Inspection>
        let organizationID: Identifier<Organization>
        let propertyID: Identifier<Property>
        var unitID: Identifier<Unit>?
        /// The lease this inspection documents, for move-in/move-out.
        var leaseID: Identifier<Lease>?

        var kind: Kind
        var status: Status
        var inspectorUserID: Identifier<User>?

        var scheduledFor: Date
        var completedAt: Date?

        var findings: [Finding]
        var photos: [Attachment]
        var summary: String?
        /// Signed report, once generated.
        var reportDocumentID: Identifier<Document>?

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Inspection> = .init(),
            organizationID: Identifier<Organization>,
            propertyID: Identifier<Property>,
            unitID: Identifier<Unit>? = nil,
            leaseID: Identifier<Lease>? = nil,
            kind: Kind,
            status: Status = .scheduled,
            inspectorUserID: Identifier<User>? = nil,
            scheduledFor: Date,
            completedAt: Date? = nil,
            findings: [Finding] = [],
            photos: [Attachment] = [],
            summary: String? = nil,
            reportDocumentID: Identifier<Document>? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.propertyID = propertyID
            self.unitID = unitID
            self.leaseID = leaseID
            self.kind = kind
            self.status = status
            self.inspectorUserID = inspectorUserID
            self.scheduledFor = scheduledFor
            self.completedAt = completedAt
            self.findings = findings
            self.photos = photos
            self.summary = summary
            self.reportDocumentID = reportDocumentID
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        enum Kind: String, FallbackDecodable, CaseIterable {
            case moveIn = "move_in"
            case moveOut = "move_out"
            case routine
            case annual
            case safety
            case insurance
            case unknown
        }

        enum Status: String, FallbackDecodable, CaseIterable {
            case scheduled
            case inProgress = "in_progress"
            case completed
            case cancelled
            case unknown
        }

        /// A single observation. Nests here because findings have no
        /// life outside their inspection.
        struct Finding: Codable, Hashable, Sendable, Identifiable {

            enum Severity: String, FallbackDecodable, CaseIterable {
                case ok
                case minor
                case major
                case hazard
                case unknown
            }

            var id: UUID
            /// e.g. "Kitchen — under sink".
            var area: String
            var severity: Severity
            var notes: String?
            var photos: [Attachment]
            /// Set when a finding is escalated into a work order.
            var raisedRequestID: Identifier<MaintenanceRequest>?

            init(
                id: UUID = UUID(),
                area: String,
                severity: Severity = .ok,
                notes: String? = nil,
                photos: [Attachment] = [],
                raisedRequestID: Identifier<MaintenanceRequest>? = nil
            ) {
                self.id = id
                self.area = area
                self.severity = severity
                self.notes = notes
                self.photos = photos
                self.raisedRequestID = raisedRequestID
            }

            enum CodingKeys: String, CodingKey {
                case id, area, severity, notes, photos
                case raisedRequestID = "raised_request_id"
            }
        }

        /// Findings that need follow-up.
        var actionableFindings: [Finding] {
            findings.filter { $0.severity == .major || $0.severity == .hazard }
        }

        enum CodingKeys: String, CodingKey {
            case id, kind, status, findings, photos, summary
            case organizationID = "organization_id"
            case propertyID = "property_id"
            case unitID = "unit_id"
            case leaseID = "lease_id"
            case inspectorUserID = "inspector_user_id"
            case scheduledFor = "scheduled_for"
            case completedAt = "completed_at"
            case reportDocumentID = "report_document_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}
