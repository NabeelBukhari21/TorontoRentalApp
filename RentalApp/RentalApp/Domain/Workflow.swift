//
//  Workflow.swift
//  RentalApp (RentOS)
//
//  Domain — Files, audit history, and to-dos.
//
//  All three attach to arbitrary entities via `EntityReference`
//  rather than a nullable foreign key per type. That keeps these
//  tables stable as new entities are introduced, and keeps the
//  module graph acyclic.
//

import Foundation

// MARK: - Document

extension Domain {

    /// A stored file with its own lifecycle — leases, insurance
    /// certificates, tax statements, signed reports.
    ///
    /// Distinct from `Attachment`, which is an inseparable part of its
    /// parent row. Documents are searched, tagged, versioned, and
    /// shared on their own.
    struct Document: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Document
        static let tableName = "documents"

        let id: Identifier<Document>
        let organizationID: Identifier<Organization>

        var name: String
        var category: Category
        var file: Attachment
        /// What this document belongs to, if anything.
        var owner: EntityReference?
        var tags: [String]

        // Versioning — new versions are new rows pointing at the original.
        var version: Int
        var supersedesDocumentID: Identifier<Document>?

        // Access
        var uploadedByUserID: Identifier<User>?
        /// Whether the tenant portal can see it.
        var isVisibleToTenant: Bool
        /// Documents with retention rules, e.g. tax records.
        var retainUntil: Date?

        // Signature
        var signatureStatus: SignatureStatus
        var signedAt: Date?

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Document> = .init(),
            organizationID: Identifier<Organization>,
            name: String,
            category: Category,
            file: Attachment,
            owner: EntityReference? = nil,
            tags: [String] = [],
            version: Int = 1,
            supersedesDocumentID: Identifier<Document>? = nil,
            uploadedByUserID: Identifier<User>? = nil,
            isVisibleToTenant: Bool = false,
            retainUntil: Date? = nil,
            signatureStatus: SignatureStatus = .notRequired,
            signedAt: Date? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.name = name
            self.category = category
            self.file = file
            self.owner = owner
            self.tags = tags
            self.version = version
            self.supersedesDocumentID = supersedesDocumentID
            self.uploadedByUserID = uploadedByUserID
            self.isVisibleToTenant = isVisibleToTenant
            self.retainUntil = retainUntil
            self.signatureStatus = signatureStatus
            self.signedAt = signedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        enum Category: String, FallbackDecodable, CaseIterable {
            case lease
            case insurance
            case financial
            case inspection
            case identification
            case notice
            case invoice
            case photo
            case other
            case unknown
        }

        enum SignatureStatus: String, FallbackDecodable, CaseIterable {
            case notRequired = "not_required"
            case pending
            case signed
            case declined
            case expired
            case unknown
        }

        var isLatestVersion: Bool { supersedesDocumentID == nil || version > 1 }

        enum CodingKeys: String, CodingKey {
            case id, name, category, file, owner, tags, version
            case organizationID = "organization_id"
            case supersedesDocumentID = "supersedes_document_id"
            case uploadedByUserID = "uploaded_by_user_id"
            case isVisibleToTenant = "is_visible_to_tenant"
            case retainUntil = "retain_until"
            case signatureStatus = "signature_status"
            case signedAt = "signed_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}

// MARK: - Activity

extension Domain {

    /// An immutable audit record: who did what to which entity.
    ///
    /// Append-only. Powers the dashboard feed, entity timelines, and
    /// compliance export. Never updated, never deleted.
    struct Activity: Record, OrganizationScoped {

        typealias Subject = Activity
        static let tableName = "activities"

        let id: Identifier<Activity>
        let organizationID: Identifier<Organization>

        // Actor — nil for system/automated events.
        var actorUserID: Identifier<User>?
        var actorTenantID: Identifier<Tenant>?
        var isSystemGenerated: Bool

        var verb: Verb
        /// The entity acted upon.
        var subject: EntityReference
        /// Human-readable line, rendered server-side so the feed stays
        /// correct even after the underlying row changes.
        var summary: String

        /// Structured before/after for field-level auditing.
        var changes: [FieldChange]

        let createdAt: Date
        var updatedAt: Date

        init(
            id: Identifier<Activity> = .init(),
            organizationID: Identifier<Organization>,
            actorUserID: Identifier<User>? = nil,
            actorTenantID: Identifier<Tenant>? = nil,
            isSystemGenerated: Bool = false,
            verb: Verb,
            subject: EntityReference,
            summary: String,
            changes: [FieldChange] = [],
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.organizationID = organizationID
            self.actorUserID = actorUserID
            self.actorTenantID = actorTenantID
            self.isSystemGenerated = isSystemGenerated
            self.verb = verb
            self.subject = subject
            self.summary = summary
            self.changes = changes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        enum Verb: String, FallbackDecodable, CaseIterable {
            case created
            case updated
            case deleted
            case statusChanged = "status_changed"
            case assigned
            case signed
            case paid
            case messaged
            case uploaded
            case invited
            case completed
            case unknown
        }

        /// One changed field, stored as strings so the audit log never
        /// depends on a type that may later be refactored away.
        struct FieldChange: Codable, Hashable, Sendable {
            var field: String
            var before: String?
            var after: String?
        }

        enum CodingKeys: String, CodingKey {
            case id, verb, subject, summary, changes
            case organizationID = "organization_id"
            case actorUserID = "actor_user_id"
            case actorTenantID = "actor_tenant_id"
            case isSystemGenerated = "is_system_generated"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
}

// MARK: - Task

extension Domain {

    /// A unit of work assigned to a person.
    ///
    /// Named `Domain.Task` deliberately: the namespace keeps it clear
    /// of Swift Concurrency's `Task` with no awkward renaming.
    struct Task: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Task
        static let tableName = "tasks"

        let id: Identifier<Task>
        let organizationID: Identifier<Organization>

        var title: String
        var details: String?
        var status: Status
        var priority: Priority

        // Assignment
        var assigneeUserID: Identifier<User>?
        var createdByUserID: Identifier<User>?

        // Scheduling
        var dueAt: Date?
        var completedAt: Date?
        var reminderAt: Date?

        /// What this task is about, if anything.
        var subject: EntityReference?
        /// Set when generated from an AI recommendation, so outcomes
        /// can be measured against suggestions.
        var sourceRecommendationID: Identifier<AIRecommendation>?

        var recurrence: Recurrence?

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Task> = .init(),
            organizationID: Identifier<Organization>,
            title: String,
            details: String? = nil,
            status: Status = .open,
            priority: Priority = .normal,
            assigneeUserID: Identifier<User>? = nil,
            createdByUserID: Identifier<User>? = nil,
            dueAt: Date? = nil,
            completedAt: Date? = nil,
            reminderAt: Date? = nil,
            subject: EntityReference? = nil,
            sourceRecommendationID: Identifier<AIRecommendation>? = nil,
            recurrence: Recurrence? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.title = title
            self.details = details
            self.status = status
            self.priority = priority
            self.assigneeUserID = assigneeUserID
            self.createdByUserID = createdByUserID
            self.dueAt = dueAt
            self.completedAt = completedAt
            self.reminderAt = reminderAt
            self.subject = subject
            self.sourceRecommendationID = sourceRecommendationID
            self.recurrence = recurrence
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        enum Status: String, FallbackDecodable, CaseIterable {
            case open
            case inProgress = "in_progress"
            case blocked
            case completed
            case cancelled
            case unknown

            var isOpen: Bool { self == .open || self == .inProgress || self == .blocked }
        }

        enum Priority: String, FallbackDecodable, CaseIterable {
            case urgent
            case high
            case normal
            case low
            case unknown
        }

        /// Repeat rule for recurring work (annual inspections, filter
        /// changes). Kept minimal — RFC 5545 is overkill here.
        struct Recurrence: Codable, Hashable, Sendable {

            enum Frequency: String, FallbackDecodable, CaseIterable {
                case daily, weekly, monthly, quarterly, yearly, unknown
            }

            var frequency: Frequency
            /// Repeat every N periods, e.g. every 2 weeks.
            var interval: Int
            var endsOn: Date?

            init(frequency: Frequency, interval: Int = 1, endsOn: Date? = nil) {
                self.frequency = frequency
                self.interval = interval
                self.endsOn = endsOn
            }

            enum CodingKeys: String, CodingKey {
                case frequency, interval
                case endsOn = "ends_on"
            }
        }

        func isOverdue(asOf date: Date = .now) -> Bool {
            guard status.isOpen, let dueAt else { return false }
            return dueAt < date
        }

        enum CodingKeys: String, CodingKey {
            case id, title, details, status, priority, subject, recurrence
            case organizationID = "organization_id"
            case assigneeUserID = "assignee_user_id"
            case createdByUserID = "created_by_user_id"
            case dueAt = "due_at"
            case completedAt = "completed_at"
            case reminderAt = "reminder_at"
            case sourceRecommendationID = "source_recommendation_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}
