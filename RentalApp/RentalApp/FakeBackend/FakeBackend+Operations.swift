//
//  FakeBackend+Operations.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — Maintenance, conversations, documents, inspections,
//  tasks, activity, and notifications.
//
//  Everything here is *derived* from records that already exist. A
//  notification about an overdue payment points at a payment that is
//  genuinely overdue; a maintenance thread involves the tenant who
//  actually occupies that unit. That consistency is what separates
//  believable demo data from filler.
//

import Foundation

extension FakeBackend {

    // MARK: - Maintenance

    static func makeMaintenance(
        orgID: Domain.Identifier<Domain.Organization>,
        units: [Domain.Unit],
        leases: [Domain.Lease],
        tenants: [Domain.Tenant],
        vendors: [Domain.Vendor],
        users: [Domain.User],
        rng: inout SeededRandom
    ) -> (requests: [Domain.MaintenanceRequest], updates: [Domain.MaintenanceUpdate]) {

        var requests: [Domain.MaintenanceRequest] = []
        var updates: [Domain.MaintenanceUpdate] = []

        let tenantByID = Dictionary(uniqueKeysWithValues: tenants.map { ($0.id, $0) })
        let coordinators = users.filter { $0.role.canManageMaintenance }
        let occupied = units.filter { $0.status.countsAsOccupied }

        // ~130 tickets spread across 18 months of history.
        for _ in 0..<130 {
            guard let unit = occupied.randomElement(using: &rng) else { break }
            let lease = leases.first { $0.unitID == unit.id && $0.status.isCurrent }
            let tenant = lease.flatMap { tenantByID[$0.primaryTenantID] }
            let issue = rng.pick(TorontoSeeds.issues)

            // Recent tickets are more likely to still be open.
            let daysAgo = rng.weighted([
                (rng.int(0...3), 3.0),
                (rng.int(4...20), 3.5),
                (rng.int(21...120), 3.0),
                (rng.int(121...540), 2.0)
            ])
            let createdAt = rng.date(daysAgo: daysAgo...daysAgo)

            let status: Domain.MaintenanceRequest.Status = {
                if daysAgo > 30 { return rng.chance(0.94) ? .completed : .cancelled }
                if daysAgo > 10 { return rng.weighted([(.completed, 6), (.inProgress, 2), (.awaitingParts, 1)]) }
                if daysAgo > 3 { return rng.weighted([(.inProgress, 4), (.scheduled, 3), (.completed, 2)]) }
                return rng.weighted([(.new, 5), (.triaged, 2), (.scheduled, 2)])
            }()

            let matching = vendors.filter { $0.trades.contains(issue.trade) }
            let vendor = status == .new ? nil : matching.randomElement(using: &rng)
            let suggested = matching.randomElement(using: &rng)

            let resolvedAt: Date? = status == .completed
                ? Calendar.current.date(byAdding: .hour, value: rng.int(4...96), to: createdAt)
                : nil

            let requestID = Domain.Identifier<Domain.MaintenanceRequest>(rng.uuid())

            let request = Domain.MaintenanceRequest(
                id: requestID,
                organizationID: orgID,
                propertyID: unit.propertyID,
                unitID: unit.id,
                reportedByTenantID: tenant?.id,
                title: issue.title,
                details: issue.detail,
                category: issue.trade,
                priority: issue.priority,
                status: status,
                photos: Self.makePhotos(count: rng.weighted([(0, 3), (1, 3), (2, 2), (3, 1)]), rng: &rng),
                tags: rng.chance(0.3) ? [rng.pick(["recurring", "warranty", "after-hours"])] : [],
                assignedVendorID: vendor?.id,
                assignedUserID: coordinators.randomElement(using: &rng)?.id,
                scheduledFor: status == .scheduled
                    ? rng.date(daysAhead: 1...6)
                    : nil,
                estimatedCost: .init(Decimal(rng.int(90...1_400))),
                actualCost: status == .completed ? .init(Decimal(rng.int(85...1_650))) : nil,
                isTenantResponsible: rng.chance(0.08),
                aiAnalysis: .init(
                    urgencyScore: Self.urgencyScore(for: issue.priority, rng: &rng),
                    categoryConfidence: rng.double(0.78...0.98),
                    summary: issue.aiSummary,
                    suggestedActions: issue.aiActions,
                    suggestedVendorID: suggested?.id,
                    draftTenantReply: Self.draftReply(
                        tenantName: tenant?.fullName.components(separatedBy: " ").first ?? "there",
                        issue: issue
                    ),
                    modelVersion: "rentos-triage-2.1",
                    analyzedAt: createdAt.addingTimeInterval(24)
                ),
                acknowledgedAt: createdAt.addingTimeInterval(Double(rng.int(120...5_400))),
                resolvedAt: resolvedAt,
                resolutionNotes: resolvedAt != nil ? rng.pick([
                    "Part replaced and tested. Tenant confirmed working.",
                    "Cleared blockage and flushed the line.",
                    "Adjusted and re-sealed. No further action needed.",
                    "Replaced unit under warranty."
                ]) : nil,
                createdAt: createdAt,
                updatedAt: resolvedAt ?? createdAt
            )

            requests.append(request)
            updates.append(contentsOf: Self.makeUpdates(
                for: request, orgID: orgID, tenant: tenant,
                vendor: vendor, coordinators: coordinators, rng: &rng
            ))
        }

        return (requests.sorted { $0.createdAt > $1.createdAt }, updates)
    }

    /// The append-only history for one request.
    private static func makeUpdates(
        for request: Domain.MaintenanceRequest,
        orgID: Domain.Identifier<Domain.Organization>,
        tenant: Domain.Tenant?,
        vendor: Domain.Vendor?,
        coordinators: [Domain.User],
        rng: inout SeededRandom
    ) -> [Domain.MaintenanceUpdate] {

        var result: [Domain.MaintenanceUpdate] = []
        var clock = request.createdAt

        func advance(_ minutes: Int) -> Date {
            clock = clock.addingTimeInterval(Double(minutes) * 60)
            return clock
        }

        result.append(.init(
            organizationID: orgID, requestID: request.id,
            authorTenantID: tenant?.id, kind: .created,
            body: request.details, createdAt: clock
        ))

        result.append(.init(
            organizationID: orgID, requestID: request.id,
            kind: .aiTriaged,
            body: "Classified \(request.category.rawValue) · \(request.priority.rawValue) priority in 0.4s",
            createdAt: advance(1)
        ))

        if let vendor {
            result.append(.init(
                organizationID: orgID, requestID: request.id,
                authorUserID: coordinators.randomElement(using: &rng)?.id,
                kind: .vendorAssigned,
                body: "Assigned to \(vendor.contactName ?? vendor.companyName) · \(vendor.companyName)",
                createdAt: advance(rng.int(20...260))
            ))
        }

        if request.status != .new && rng.chance(0.7) {
            result.append(.init(
                organizationID: orgID, requestID: request.id,
                authorVendorID: vendor?.id, kind: .comment,
                body: rng.pick(TorontoSeeds.vendorMessages),
                createdAt: advance(rng.int(30...600))
            ))
        }

        if request.status == .completed {
            result.append(.init(
                organizationID: orgID, requestID: request.id,
                authorUserID: coordinators.randomElement(using: &rng)?.id,
                kind: .resolved,
                body: request.resolutionNotes,
                fromStatus: .inProgress, toStatus: .completed,
                createdAt: request.resolvedAt ?? advance(120)
            ))
        }

        return result
    }

    private static func makePhotos(count: Int, rng: inout SeededRandom) -> [Domain.Attachment] {
        (0..<count).map { index in
            Domain.Attachment(
                id: rng.uuid(),
                kind: .image,
                storagePath: "maintenance/\(rng.uuid().uuidString).jpg",
                fileName: "IMG_\(String(format: "%04d", rng.int(1000...9999))).jpg",
                byteSize: rng.int(420_000...3_800_000),
                uploadedAt: .now
            )
        }
    }

    private static func urgencyScore(
        for priority: Domain.MaintenanceRequest.Priority,
        rng: inout SeededRandom
    ) -> Double {
        switch priority {
        case .emergency: rng.double(0.92...0.99)
        case .urgent: rng.double(0.80...0.95)
        case .high: rng.double(0.58...0.79)
        case .medium: rng.double(0.32...0.57)
        default: rng.double(0.12...0.34)
        }
    }

    private static func draftReply(tenantName: String, issue: TorontoSeeds.Issue) -> String {
        "Hi \(tenantName) — thanks for reporting this. \(issue.aiActions.first ?? "We're on it.") "
        + "I'll confirm the appointment window shortly."
    }

    // MARK: - Conversations

    static func makeConversations(
        orgID: Domain.Identifier<Domain.Organization>,
        tenants: [Domain.Tenant],
        leases: [Domain.Lease],
        units: [Domain.Unit],
        vendors: [Domain.Vendor],
        requests: [Domain.MaintenanceRequest],
        rng: inout SeededRandom
    ) -> (conversations: [Domain.Conversation], messages: [Domain.Message]) {

        var conversations: [Domain.Conversation] = []
        var messages: [Domain.Message] = []

        let unitByID = Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })
        let leaseByTenant = Dictionary(
            leases.map { ($0.primaryTenantID, $0) }, uniquingKeysWith: { first, _ in first }
        )

        // Tenants with the most recent activity get threads.
        let chatty = rng.sample(tenants, count: 34)

        for tenant in chatty {
            guard let lease = leaseByTenant[tenant.id],
                  let unit = unitByID[lease.unitID] else { continue }

            let conversationID = Domain.Identifier<Domain.Conversation>(rng.uuid())
            let lastAt = rng.date(daysAgo: 0...9)

            let thread = Self.makeThread(
                orgID: orgID,
                conversationID: conversationID,
                counterpartID: tenant.id.rawValue,
                role: .tenant,
                endingAt: lastAt,
                rng: &rng
            )
            messages.append(contentsOf: thread)

            conversations.append(
                Domain.Conversation(
                    id: conversationID,
                    organizationID: orgID,
                    participants: [
                        .init(id: tenant.id.rawValue, role: .tenant, displayName: tenant.fullName)
                    ],
                    propertyID: unit.propertyID,
                    unitID: unit.id,
                    kind: .direct,
                    lastMessagePreview: thread.last?.body,
                    lastMessageAt: lastAt,
                    createdAt: rng.date(daysAgo: 10...120),
                    updatedAt: lastAt
                )
            )
        }

        // A handful of vendor threads.
        for vendor in rng.sample(vendors, count: 9) {
            let conversationID = Domain.Identifier<Domain.Conversation>(rng.uuid())
            let lastAt = rng.date(daysAgo: 0...12)

            let thread = Self.makeThread(
                orgID: orgID,
                conversationID: conversationID,
                counterpartID: vendor.id.rawValue,
                role: .vendor,
                endingAt: lastAt,
                rng: &rng
            )
            messages.append(contentsOf: thread)

            conversations.append(
                Domain.Conversation(
                    id: conversationID,
                    organizationID: orgID,
                    participants: [
                        .init(id: vendor.id.rawValue, role: .vendor,
                              displayName: vendor.contactName ?? vendor.companyName)
                    ],
                    kind: .maintenance,
                    lastMessagePreview: thread.last?.body,
                    lastMessageAt: lastAt,
                    createdAt: rng.date(daysAgo: 12...90),
                    updatedAt: lastAt
                )
            )
        }

        return (
            conversations.sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) },
            messages
        )
    }

    /// Builds an alternating thread that ends at a known time.
    private static func makeThread(
        orgID: Domain.Identifier<Domain.Organization>,
        conversationID: Domain.Identifier<Domain.Conversation>,
        counterpartID: UUID,
        role: Domain.Conversation.Participant.Role,
        endingAt: Date,
        rng: inout SeededRandom
    ) -> [Domain.Message] {

        let count = rng.int(2...8)
        var result: [Domain.Message] = []
        var timestamp = endingAt.addingTimeInterval(-Double(count) * 900)

        for index in 0..<count {
            let fromCounterpart = index % 2 == 0
            let body = fromCounterpart
                ? (role == .tenant ? rng.pick(TorontoSeeds.tenantOpeners) : rng.pick(TorontoSeeds.vendorMessages))
                : rng.pick(TorontoSeeds.managerReplies)

            result.append(
                Domain.Message(
                    id: .init(rng.uuid()),
                    organizationID: orgID,
                    conversationID: conversationID,
                    senderID: fromCounterpart ? counterpartID : UUID(),
                    senderRole: fromCounterpart ? role : .staff,
                    body: body,
                    kind: .text,
                    deliveryStatus: .read,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            )
            timestamp = timestamp.addingTimeInterval(Double(rng.int(300...5_400)))
        }

        return result
    }

    // MARK: - Documents

    static func makeDocuments(
        orgID: Domain.Identifier<Domain.Organization>,
        properties: [Domain.Property],
        leases: [Domain.Lease],
        tenants: [Domain.Tenant],
        units: [Domain.Unit],
        rng: inout SeededRandom
    ) -> [Domain.Document] {

        var result: [Domain.Document] = []
        let tenantByID = Dictionary(uniqueKeysWithValues: tenants.map { ($0.id, $0) })
        let unitByID = Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })

        // A signed lease for a sample of agreements.
        for lease in rng.sample(leases, count: 40) {
            guard let tenant = tenantByID[lease.primaryTenantID],
                  let unit = unitByID[lease.unitID] else { continue }

            result.append(
                Domain.Document(
                    id: .init(rng.uuid()),
                    organizationID: orgID,
                    name: "Lease — \(tenant.fullName) · \(unit.label)",
                    category: .lease,
                    file: .init(
                        id: rng.uuid(), kind: .pdf,
                        storagePath: "documents/\(rng.uuid().uuidString).pdf",
                        fileName: "lease.pdf",
                        byteSize: rng.int(680_000...1_800_000),
                        uploadedAt: lease.signedAt ?? lease.term.start
                    ),
                    owner: .lease(lease.id),
                    tags: ["Signed", String(Calendar.current.component(.year, from: lease.term.start))],
                    uploadedByUserID: nil,
                    isVisibleToTenant: true,
                    signatureStatus: .signed,
                    signedAt: lease.signedAt,
                    createdAt: lease.signedAt ?? lease.term.start
                )
            )
        }

        // Per-property compliance paperwork.
        for property in properties {
            let bundle: [(String, Domain.Document.Category)] = [
                ("Insurance Certificate — \(property.name)", .insurance),
                ("Property Tax Statement — \(property.name)", .financial),
                ("Fire Safety Plan — \(property.name)", .inspection)
            ]
            for (name, category) in bundle where rng.chance(0.8) {
                let created = rng.date(daysAgo: 20...400)
                result.append(
                    Domain.Document(
                        id: .init(rng.uuid()),
                        organizationID: orgID,
                        name: name,
                        category: category,
                        file: .init(
                            id: rng.uuid(), kind: .pdf,
                            storagePath: "documents/\(rng.uuid().uuidString).pdf",
                            fileName: "document.pdf",
                            byteSize: rng.int(180_000...2_400_000),
                            uploadedAt: created
                        ),
                        owner: .property(property.id),
                        tags: ["2026"],
                        createdAt: created
                    )
                )
            }
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Inspections

    static func makeInspections(
        orgID: Domain.Identifier<Domain.Organization>,
        properties: [Domain.Property],
        units: [Domain.Unit],
        users: [Domain.User],
        rng: inout SeededRandom
    ) -> [Domain.Inspection] {

        var result: [Domain.Inspection] = []
        let inspectors = users.filter { $0.role.canManagePortfolio }

        for property in properties {
            for _ in 0..<rng.int(1...3) {
                let isPast = rng.chance(0.6)
                let scheduled = isPast ? rng.date(daysAgo: 5...300) : rng.date(daysAhead: 2...60)
                let unit = units.filter { $0.propertyID == property.id }.randomElement(using: &rng)

                result.append(
                    Domain.Inspection(
                        id: .init(rng.uuid()),
                        organizationID: orgID,
                        propertyID: property.id,
                        unitID: unit?.id,
                        kind: rng.weighted([(.routine, 4), (.annual, 3), (.moveIn, 2), (.moveOut, 2), (.safety, 1)]),
                        status: isPast ? .completed : .scheduled,
                        inspectorUserID: inspectors.randomElement(using: &rng)?.id,
                        scheduledFor: scheduled,
                        completedAt: isPast ? scheduled : nil,
                        findings: isPast ? Self.makeFindings(rng: &rng) : [],
                        summary: isPast ? rng.pick([
                            "Unit in good condition. Minor wear consistent with tenancy length.",
                            "No safety concerns. Two follow-up items raised.",
                            "Well maintained. Recommend filter replacement next visit."
                        ]) : nil,
                        createdAt: scheduled
                    )
                )
            }
        }

        return result
    }

    private static func makeFindings(rng: inout SeededRandom) -> [Domain.Inspection.Finding] {
        let areas = ["Kitchen", "Main bathroom", "Living room", "Primary bedroom",
                     "Balcony", "Utility room", "Entryway", "Windows"]
        return rng.sample(areas, count: rng.int(2...5)).map { area in
            Domain.Inspection.Finding(
                id: rng.uuid(),
                area: area,
                severity: rng.weighted([(.ok, 6), (.minor, 3), (.major, 1), (.hazard, 0.3)]),
                notes: rng.chance(0.5) ? rng.pick([
                    "Minor scuffing on the wall, no action needed.",
                    "Caulking showing wear — schedule reseal.",
                    "Smoke detector tested and functional.",
                    "Slight draft at the frame; seal recommended."
                ]) : nil
            )
        }
    }
}
