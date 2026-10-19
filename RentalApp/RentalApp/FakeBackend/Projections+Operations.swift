//
//  Projections+Operations.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — Maintenance, messaging, documents, notifications,
//  and dashboard projections.
//

import SwiftUI

extension Projections {

    private static var backend: FakeBackend { .shared }

    // MARK: - Maintenance

    static func tickets() -> [MaintenanceTicket] {
        backend.requests.enumerated().map { index, request in
            let unit = request.unitID.flatMap { backend.unitByID[$0] }
            let property = backend.propertyByID[request.propertyID]
            let tenant = request.reportedByTenantID.flatMap { backend.tenantByID[$0] }
            let vendor = request.assignedVendorID.flatMap { backend.vendorByID[$0] }

            let comments = backend.updates(for: request.id)
                .filter { $0.kind == .comment || $0.kind == .resolved }
                .compactMap { update -> TicketComment? in
                    guard let body = update.body else { return nil }
                    let isManager = update.authorUserID != nil
                    let author = isManager
                        ? (update.authorUserID.flatMap { backend.userByID[$0]?.fullName } ?? "You")
                        : (update.authorVendorID.flatMap { backend.vendorByID[$0]?.contactName }
                            ?? tenant?.fullName ?? "Tenant")
                    return TicketComment(
                        author: author,
                        isManager: isManager,
                        text: body,
                        time: FakeDateFormat.relative(update.createdAt)
                    )
                }

            return MaintenanceTicket(
                id: request.id.description,
                title: request.title,
                description: request.details,
                propertyName: property?.name ?? "Property",
                unitName: unit?.label ?? "Common area",
                tenantName: tenant?.fullName ?? "Staff report",
                priority: priority(from: request.priority),
                status: status(from: request.status),
                category: category(from: request.category),
                createdAgo: FakeDateFormat.relative(request.createdAt),
                photoCount: request.photos.count,
                paletteIndex: index % 6,
                ai: request.aiAnalysis.map { analysis in
                    TicketAIAnalysis(
                        urgencyScore: analysis.urgencyScore,
                        categoryConfidence: analysis.categoryConfidence,
                        summary: analysis.summary,
                        suggestedActions: analysis.suggestedActions,
                        draftReply: analysis.draftTenantReply ?? "",
                        suggestedVendorID: analysis.suggestedVendorID?.description ?? ""
                    )
                },
                vendor: vendor.map(projectVendor),
                comments: comments
            )
        }
    }

    static func vendors() -> [Vendor] {
        backend.vendors.map(projectVendor)
    }

    private static func projectVendor(_ vendor: Domain.Vendor) -> Vendor {
        Vendor(
            id: vendor.id.description,
            name: vendor.contactName ?? vendor.companyName,
            company: vendor.companyName,
            specialty: category(from: vendor.trades.first ?? .general),
            rating: (vendor.rating.map { ($0 as NSDecimalNumber).doubleValue }) ?? 4.5,
            completedJobs: vendor.completedJobCount,
            responseTime: vendor.responseTimeHours.map { $0 >= 24 ? "~\($0 / 24)d" : "~\($0)h" } ?? "~1d"
        )
    }

    static func priority(from value: Domain.MaintenanceRequest.Priority) -> TicketPriority {
        switch value {
        case .emergency, .urgent: .urgent
        case .high: .high
        case .medium: .medium
        default: .low
        }
    }

    static func status(from value: Domain.MaintenanceRequest.Status) -> TicketStatus {
        switch value {
        case .new, .triaged: .new
        case .scheduled: .scheduled
        case .inProgress, .awaitingParts: .inProgress
        default: .done
        }
    }

    static func category(from trade: Domain.Vendor.Trade) -> TicketCategory {
        switch trade {
        case .plumbing: .plumbing
        case .electrical: .electrical
        case .hvac: .hvac
        case .appliance: .appliance
        default: .general
        }
    }

    static func timeline(forTicketID id: String) -> [TenantEvent] {
        guard let request = backend.requests.first(where: { $0.id.description == id })
        else { return [] }

        return backend.updates(for: request.id).reversed().map { update in
            TenantEvent(
                icon: icon(for: update.kind),
                kind: update.kind == .resolved ? .success
                    : (update.kind == .aiTriaged ? .warning : .info),
                title: title(for: update.kind),
                detail: update.body ?? "",
                date: FakeDateFormat.relative(update.createdAt)
            )
        }
    }

    private static func icon(for kind: Domain.MaintenanceUpdate.Kind) -> String {
        switch kind {
        case .created: "tray.fill"
        case .aiTriaged: DS.Icons.ai
        case .vendorAssigned: "person.badge.shield.checkmark.fill"
        case .scheduled: "calendar"
        case .resolved: "checkmark.seal.fill"
        case .photosAdded: DS.Icons.camera
        default: DS.Icons.messages
        }
    }

    private static func title(for kind: Domain.MaintenanceUpdate.Kind) -> String {
        switch kind {
        case .created: "Request received"
        case .aiTriaged: "AI triage complete"
        case .vendorAssigned: "Vendor assigned"
        case .scheduled: "Visit scheduled"
        case .resolved: "Resolved"
        case .comment: "Comment added"
        case .photosAdded: "Photos added"
        default: "Update"
        }
    }

    // MARK: - Messaging

    static func conversations() -> [Conversation] {
        backend.conversations.compactMap { conversation -> Conversation? in
            guard let participant = conversation.participants.first else { return nil }

            let context: String = {
                if let unitID = conversation.unitID,
                   let unit = backend.unitByID[unitID],
                   let property = backend.propertyByID[unit.propertyID] {
                    return "\(unit.label) · \(property.name)"
                }
                if participant.role == .vendor,
                   let vendor = backend.vendors.first(where: { $0.id.rawValue == participant.id }) {
                    return vendor.companyName
                }
                return "Purrperty"
            }()

            let thread = backend.messages(in: conversation.id)
            let unread = thread.suffix(3).filter { $0.senderRole != .staff }.count

            return Conversation(
                id: conversation.id.description,
                name: participant.displayName,
                role: participant.role == .vendor ? .vendor : .tenant,
                context: context,
                lastMessage: conversation.lastMessagePreview ?? "",
                lastTime: FakeDateFormat.compact(conversation.lastMessageAt ?? conversation.createdAt),
                unreadCount: (conversation.lastMessageAt.map { $0 > Date().addingTimeInterval(-172_800) } ?? false)
                    ? unread : 0,
                isOnline: (conversation.lastMessageAt.map { $0 > Date().addingTimeInterval(-7_200) } ?? false),
                isPinned: false
            )
        }
    }

    static func messages(forConversationID id: String) -> [ChatMessage] {
        guard let conversation = backend.conversations.first(where: { $0.id.description == id })
        else { return [] }

        let thread = backend.messages(in: conversation.id)
        var lastDay: String?

        return thread.map { message in
            let day = FakeDateFormat.monthDay(message.createdAt)
            let separator: String? = day == lastDay ? nil : day
            lastDay = day

            return ChatMessage(
                text: message.body,
                isMine: message.senderRole == .staff,
                time: FakeDateFormat.time(message.createdAt),
                status: .read,
                attachment: nil,
                showsDateSeparator: separator
            )
        }
    }

    // MARK: - Documents

    static func files() -> [DocFile] {
        backend.documents.enumerated().map { index, document in
            DocFile(
                name: document.name,
                type: fileType(for: document),
                size: byteLabel(document.file.byteSize),
                date: FakeDateFormat.monthYear(document.createdAt),
                folderID: folderID(for: document.category),
                tags: document.tags,
                paletteIndex: index % 6,
                isFavorite: document.signatureStatus == .signed && index % 9 == 0
            )
        }
    }

    private static func fileType(for document: Domain.Document) -> DocFileType {
        switch document.category {
        case .lease: .contract
        case .financial: .spreadsheet
        case .photo: .image
        default: .pdf
        }
    }

    private static func folderID(for category: Domain.Document.Category) -> String {
        switch category {
        case .lease: "leases"
        case .insurance: "insurance"
        case .financial: "financials"
        case .inspection: "inspections"
        case .photo: "photos"
        default: "financials"
        }
    }

    // MARK: - Notifications

    static func notifications() -> [AppNotification] {
        let calendar = Calendar.current

        return backend.notifications.map { notification in
            let group: NotificationGroup = {
                if calendar.isDateInToday(notification.createdAt) { return .today }
                if calendar.isDateInYesterday(notification.createdAt) { return .yesterday }
                return .earlier
            }()

            return AppNotification(
                id: notification.id.rawValue,
                category: NotificationCategory(rawValue: notification.category.rawValue) ?? .system,
                priority: NotificationPriority(rawValue: notification.priority.rawValue) ?? .normal,
                title: notification.title,
                message: notification.body,
                time: FakeDateFormat.compact(notification.createdAt),
                group: group,
                isUnread: notification.isUnread,
                subjectType: notification.subject?.kind.rawValue,
                subjectID: notification.subject?.id.uuidString,
                deepLink: notification.deepLink,
                createdAt: notification.createdAt
            )
        }
    }

            // MARK: - Dashboard

    static func portfolioSummary() -> PortfolioSummary {
        let units = backend.units
        let occupied = units.filter { $0.status.countsAsOccupied }
        let revenue = occupied.reduce(Decimal(0)) { $0 + $1.marketRent.amount }
        let value = backend.properties.reduce(Decimal(0)) { $0 + ($1.marketValue?.amount ?? 0) }

        return PortfolioSummary(
            greetingName: backend.users.first?.fullName.components(separatedBy: " ").first ?? "there",
            portfolioValue: String(format: "$%.1fM", (value as NSDecimalNumber).doubleValue / 1_000_000),
            monthlyRevenue: (revenue as NSDecimalNumber).doubleValue / 1_000,
            revenueTrend: "+$1.2K vs last month",
            propertyCount: backend.properties.count,
            unitCount: units.count,
            occupancyRate: units.isEmpty ? 0 : Double(occupied.count) / Double(units.count),
            occupiedUnits: occupied.count,
            vacantUnits: units.filter { $0.status == .vacant }.count,
            turnoverUnits: units.filter { $0.status == .turnover || $0.status == .notice }.count
        )
    }

    static func revenueSeries() -> [RevenuePoint] {
        let monthly = backend.units
            .filter { $0.status.countsAsOccupied }
            .reduce(Decimal(0)) { $0 + $1.marketRent.amount }
        let base = (monthly as NSDecimalNumber).doubleValue / 1_000

        return (0..<8).map { index in
            let date = Calendar.current.date(byAdding: .month, value: index - 7, to: .now) ?? .now
            return RevenuePoint(
                month: FakeDateFormat.monthYear(date).prefix(3).description,
                amount: base * (0.88 + Double(index) * 0.017 + sin(Double(index)) * 0.012)
            )
        }
    }

    static func maintenanceCounts() -> [MaintenanceStatusCount] {
        let open = backend.requests.filter { $0.status.isOpen }
        let doneThisWeek = backend.requests.filter {
            guard let resolved = $0.resolvedAt else { return false }
            return resolved > Date().addingTimeInterval(-604_800)
        }

        return [
            .init(label: "New", count: open.filter { $0.status == .new || $0.status == .triaged }.count, kind: .info),
            .init(label: "In Progress", count: open.filter { $0.status == .inProgress || $0.status == .awaitingParts }.count, kind: .warning),
            .init(label: "Scheduled", count: open.filter { $0.status == .scheduled }.count, kind: .neutral),
            .init(label: "Done this week", count: doneThisWeek.count, kind: .success)
        ]
    }

    static func activityFeed() -> [ActivityItem] {
        backend.activities.prefix(8).map { activity in
            ActivityItem(
                icon: icon(for: activity.verb),
                kind: kind(for: activity.verb),
                title: activity.summary,
                subtitle: FakeDateFormat.monthDay(activity.createdAt),
                time: FakeDateFormat.compact(activity.createdAt),
                isNew: activity.createdAt > Date().addingTimeInterval(-10_800)
            )
        }
    }

    private static func icon(for verb: Domain.Activity.Verb) -> String {
        switch verb {
        case .paid: DS.Icons.payment
        case .signed: DS.Icons.lease
        case .created: DS.Icons.maintenance
        case .messaged: DS.Icons.messages
        case .completed: "checkmark.seal.fill"
        default: DS.Icons.notifications
        }
    }

    private static func kind(for verb: Domain.Activity.Verb) -> DSStatusKind {
        switch verb {
        case .paid, .signed, .completed: .success
        case .created: .warning
        default: .info
        }
    }

    static func upcomingTasks() -> [UpcomingTask] {
        backend.tasks.filter { $0.status.isOpen }.prefix(5).map { task in
            UpcomingTask(
                title: task.title,
                due: task.dueAt.map { FakeDateFormat.dueLabel($0) } ?? "No date",
                icon: task.subject?.kind == .lease ? DS.Icons.lease : DS.Icons.maintenance,
                isUrgent: task.priority == .urgent || task.isOverdue(),
                isDone: false
            )
        }
    }
}
