//
//  Communication.swift
//  RentalApp (Purrperty)
//
//  Domain — Threads, messages, and alerts.
//
//      Conversation ──> Message
//
//  Participants are modelled as a `[Participant]` value rather than a
//  join table because threads here are small and always loaded whole.
//  `Participant` carries a role tag so a thread can mix staff, renters,
//  and vendors without three nullable id columns.
//

import Foundation

// MARK: - Conversation

extension Domain {

    /// A message thread.
    struct Conversation: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Conversation
        static let tableName = "conversations"

        // Identity
        let id: Identifier<Conversation>
        let organizationID: Identifier<Organization>
        var participants: [Participant]

        // Optional context — what the thread is about.
        var propertyID: Identifier<Property>?
        var unitID: Identifier<Unit>?
        var maintenanceRequestID: Identifier<MaintenanceRequest>?

        // Display
        /// Nil for direct threads; the UI derives a title from participants.
        var subject: String?
        var kind: Kind

        // Denormalised thread preview — avoids an N+1 on the list screen.
        var lastMessagePreview: String?
        var lastMessageAt: Date?

        var isArchived: Bool
        var pinnedByUserIDs: [Identifier<User>]

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Conversation> = .init(),
            organizationID: Identifier<Organization>,
            participants: [Participant],
            propertyID: Identifier<Property>? = nil,
            unitID: Identifier<Unit>? = nil,
            maintenanceRequestID: Identifier<MaintenanceRequest>? = nil,
            subject: String? = nil,
            kind: Kind = .direct,
            lastMessagePreview: String? = nil,
            lastMessageAt: Date? = nil,
            isArchived: Bool = false,
            pinnedByUserIDs: [Identifier<User>] = [],
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.participants = participants
            self.propertyID = propertyID
            self.unitID = unitID
            self.maintenanceRequestID = maintenanceRequestID
            self.subject = subject
            self.kind = kind
            self.lastMessagePreview = lastMessagePreview
            self.lastMessageAt = lastMessageAt
            self.isArchived = isArchived
            self.pinnedByUserIDs = pinnedByUserIDs
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        enum Kind: String, FallbackDecodable, CaseIterable {
            case direct
            case group
            /// Attached to a work order; visible in the request timeline.
            case maintenance
            /// Broadcast to a building or property.
            case announcement
            case unknown
        }

        /// Someone on a thread. The role tag lets one array hold staff,
        /// renters, and vendors without separate columns.
        struct Participant: Codable, Hashable, Sendable, Identifiable {

            enum Role: String, FallbackDecodable, CaseIterable {
                case staff
                case tenant
                case vendor
                case unknown
            }

            /// The underlying user/tenant/vendor id.
            var id: UUID
            var role: Role
            /// Denormalised so the list renders without extra fetches.
            var displayName: String
            var avatarPath: String?
            /// Per-participant read cursor; drives unread counts.
            var lastReadAt: Date?

            init(
                id: UUID,
                role: Role,
                displayName: String,
                avatarPath: String? = nil,
                lastReadAt: Date? = nil
            ) {
                self.id = id
                self.role = role
                self.displayName = displayName
                self.avatarPath = avatarPath
                self.lastReadAt = lastReadAt
            }

            enum CodingKeys: String, CodingKey {
                case id, role
                case displayName = "display_name"
                case avatarPath = "avatar_path"
                case lastReadAt = "last_read_at"
            }
        }

        func isPinned(by userID: Identifier<User>) -> Bool {
            pinnedByUserIDs.contains(userID)
        }

        /// Unread when the participant's cursor trails the last message.
        func hasUnread(for participantID: UUID) -> Bool {
            guard let lastMessageAt,
                  let participant = participants.first(where: { $0.id == participantID })
            else { return false }
            guard let lastReadAt = participant.lastReadAt else { return true }
            return lastMessageAt > lastReadAt
        }

        enum CodingKeys: String, CodingKey {
            case id, participants, subject, kind
            case organizationID = "organization_id"
            case propertyID = "property_id"
            case unitID = "unit_id"
            case maintenanceRequestID = "maintenance_request_id"
            case lastMessagePreview = "last_message_preview"
            case lastMessageAt = "last_message_at"
            case isArchived = "is_archived"
            case pinnedByUserIDs = "pinned_by_user_ids"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}

// MARK: - Message

extension Domain {

    /// A single message. Edits keep history via `editedAt`; deletions
    /// are soft so threads never develop holes.
    struct Message: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Message
        static let tableName = "messages"

        let id: Identifier<Message>
        let organizationID: Identifier<Organization>
        let conversationID: Identifier<Conversation>

        /// Matches a `Conversation.Participant.id`.
        var senderID: UUID
        var senderRole: Conversation.Participant.Role

        var body: String
        var attachments: [Attachment]
        var kind: Kind
        var deliveryStatus: DeliveryStatus

        /// Read receipts, keyed by participant id.
        var readBy: [UUID: Date]

        var editedAt: Date?
        /// Threaded replies, if the UI ever surfaces them.
        var replyToMessageID: Identifier<Message>?

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Message> = .init(),
            organizationID: Identifier<Organization>,
            conversationID: Identifier<Conversation>,
            senderID: UUID,
            senderRole: Conversation.Participant.Role,
            body: String,
            attachments: [Attachment] = [],
            kind: Kind = .text,
            deliveryStatus: DeliveryStatus = .sending,
            readBy: [UUID: Date] = [:],
            editedAt: Date? = nil,
            replyToMessageID: Identifier<Message>? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.conversationID = conversationID
            self.senderID = senderID
            self.senderRole = senderRole
            self.body = body
            self.attachments = attachments
            self.kind = kind
            self.deliveryStatus = deliveryStatus
            self.readBy = readBy
            self.editedAt = editedAt
            self.replyToMessageID = replyToMessageID
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        enum Kind: String, FallbackDecodable, CaseIterable {
            case text
            case attachment
            /// Generated by the app, e.g. "Vendor assigned".
            case system
            /// Copilot-drafted, pending human approval.
            case aiDraft = "ai_draft"
            case unknown
        }

        enum DeliveryStatus: String, FallbackDecodable, CaseIterable {
            case sending
            case sent
            case delivered
            case read
            case failed
            case unknown
        }

        var isEdited: Bool { editedAt != nil }

        enum CodingKeys: String, CodingKey {
            case id, body, attachments, kind
            case organizationID = "organization_id"
            case conversationID = "conversation_id"
            case senderID = "sender_id"
            case senderRole = "sender_role"
            case deliveryStatus = "delivery_status"
            case readBy = "read_by"
            case editedAt = "edited_at"
            case replyToMessageID = "reply_to_message_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}

// MARK: - Notification

extension Domain {

    /// An alert delivered to one user.
    ///
    /// One row per recipient rather than a shared row with a read-state
    /// join: notifications are high-volume, per-user, and short-lived,
    /// so duplication is cheaper than the join forever after.
    struct Notification: Record, OrganizationScoped {

        typealias Subject = Notification
        static let tableName = "notifications"

        let id: Identifier<Notification>
        let organizationID: Identifier<Organization>
        let recipientUserID: Identifier<User>

        var category: Category
        var title: String
        var body: String
        /// What to open when tapped.
        var subject: EntityReference?
        /// Deep link, e.g. `rentos://maintenance/<id>`.
        var deepLink: String?

        var priority: Priority
        var readAt: Date?
        /// When the push was handed to APNs.
        var pushedAt: Date?

        let createdAt: Date
        var updatedAt: Date

        init(
            id: Identifier<Notification> = .init(),
            organizationID: Identifier<Organization>,
            recipientUserID: Identifier<User>,
            category: Category,
            title: String,
            body: String,
            subject: EntityReference? = nil,
            deepLink: String? = nil,
            priority: Priority = .normal,
            readAt: Date? = nil,
            pushedAt: Date? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.organizationID = organizationID
            self.recipientUserID = recipientUserID
            self.category = category
            self.title = title
            self.body = body
            self.subject = subject
            self.deepLink = deepLink
            self.priority = priority
            self.readAt = readAt
            self.pushedAt = pushedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        /// Mirrors the per-category toggles in notification settings.
        enum Category: String, FallbackDecodable, CaseIterable {
            case maintenance
            case payment
            case message
            case lease
            case inspection
            case aiInsight = "ai_insight"
            case system
            case unknown
        }

        enum Priority: String, FallbackDecodable, CaseIterable {
            case critical
            case high
            case normal
            case low
            case unknown

            /// Bypasses quiet hours.
            var ignoresQuietHours: Bool { self == .critical }
        }

        var isUnread: Bool { readAt == nil }

        enum CodingKeys: String, CodingKey {
            case id, category, title, body, priority
            case organizationID = "organization_id"
            case recipientUserID = "recipient_user_id"
            case deepLink = "deep_link"
            case readAt = "read_at"
            case pushedAt = "pushed_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            // EntityReference flattens to subject_type / subject_id.
            case subject
        }
    }
}
