//
//  FakeBackend.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — The simulated database.
//
//  Generates one relationally-consistent portfolio at launch and holds
//  it in memory. Everything downstream (repositories, view models,
//  screens) reads from here, so the whole app shares one coherent
//  world: the tenant named on a lease is the tenant messaging you
//  about the maintenance request raised against their unit.
//
//  Generation order follows the dependency graph exactly — parents
//  before children — which is also the order a real seed migration
//  would run in.
//

import Foundation

@MainActor
final class FakeBackend {

    /// The dataset in use: the seeded demo portfolio, or an empty
    /// workspace for an account that set up its own organization. Every
    /// reader goes through this, so swapping it swaps the whole world.
    private(set) static var shared = demo

    /// The demo portfolio. Built once, on first access, and kept so going
    /// back to it never regenerates it.
    private static let demo = FakeBackend()

    /// Which world `shared` holds.
    enum Workspace: Equatable {
        case demo
        /// A new organization with nothing in it yet.
        case empty(organizationName: String, ownerName: String, ownerEmail: String)
    }

    private(set) static var workspace: Workspace = .demo

    /// Switches the dataset. Returns whether anything changed, so callers
    /// only drop caches when they need to.
    @discardableResult
    static func activate(_ next: Workspace) -> Bool {
        guard next != workspace else { return false }
        workspace = next
        switch next {
        case .demo:
            shared = demo
        case let .empty(organizationName, ownerName, ownerEmail):
            shared = FakeBackend(emptyWorkspaceFor: organizationName, ownerName: ownerName, ownerEmail: ownerEmail)
        }
        return true
    }

    // MARK: Tables

    private(set) var organization: Domain.Organization
    private(set) var users: [Domain.User] = []
    private(set) var properties: [Domain.Property] = []
    private(set) var buildings: [Domain.Building] = []
    private(set) var units: [Domain.Unit] = []
    private(set) var tenants: [Domain.Tenant] = []
    private(set) var leases: [Domain.Lease] = []
    private(set) var payments: [Domain.Payment] = []
    private(set) var vendors: [Domain.Vendor] = []
    private(set) var requests: [Domain.MaintenanceRequest] = []
    private(set) var updates: [Domain.MaintenanceUpdate] = []
    private(set) var conversations: [Domain.Conversation] = []
    private(set) var messages: [Domain.Message] = []
    private(set) var documents: [Domain.Document] = []
    private(set) var notifications: [Domain.Notification] = []
    private(set) var inspections: [Domain.Inspection] = []
    private(set) var activities: [Domain.Activity] = []
    private(set) var tasks: [Domain.Task] = []

    // MARK: Init

    /// A workspace with only its organization and owner: no properties,
    /// tenants or history until the account adds them.
    private init(emptyWorkspaceFor organizationName: String, ownerName: String, ownerEmail: String) {
        let organization = Domain.Organization(
            name: organizationName,
            slug: organizationName.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
        )
        self.organization = organization
        users = [Domain.User(
            organizationID: organization.id,
            email: ownerEmail,
            fullName: ownerName,
            role: .owner
        )]
    }

    private init(seed: UInt64 = 0x52_65_6E_74_4F_53) { // "Purrperty"
        var rng = SeededRandom(seed: seed)

        let orgID = Domain.Identifier<Domain.Organization>(rng.uuid())
        organization = Domain.Organization(
            id: orgID,
            name: "Bukhari Properties",
            slug: "bukhari-properties",
            address: Domain.Address(
                line1: "48 Maple Grove Ave",
                city: "Toronto",
                postalCode: "M4M 2K7"
            ),
            supportEmail: "hello@bukhariproperties.ca",
            phone: "(416) 555-0100",
            plan: .premium,
            unitQuota: 250
        )

        users = Self.makeUsers(orgID: orgID, rng: &rng)
        vendors = Self.makeVendors(orgID: orgID, rng: &rng)

        let portfolio = Self.makePortfolio(orgID: orgID, users: users, rng: &rng)
        properties = portfolio.properties
        buildings = portfolio.buildings
        units = portfolio.units

        let leasing = Self.makeLeasing(orgID: orgID, units: units, rng: &rng)
        tenants = leasing.tenants
        leases = leasing.leases
        payments = leasing.payments

        // Occupancy is derived from leases, never guessed.
        units = Self.applyOccupancy(to: units, leases: leases)

        let maintenance = Self.makeMaintenance(
            orgID: orgID, units: units, leases: leases,
            tenants: tenants, vendors: vendors, users: users, rng: &rng
        )
        requests = maintenance.requests
        updates = maintenance.updates

        let comms = Self.makeConversations(
            orgID: orgID, tenants: tenants, leases: leases, units: units,
            vendors: vendors, requests: requests, rng: &rng
        )
        conversations = comms.conversations
        messages = comms.messages

        documents = Self.makeDocuments(
            orgID: orgID, properties: properties, leases: leases,
            tenants: tenants, units: units, rng: &rng
        )

        inspections = Self.makeInspections(
            orgID: orgID, properties: properties, units: units, users: users, rng: &rng
        )

        tasks = Self.makeTasks(
            orgID: orgID, users: users, leases: leases,
            tenants: tenants, requests: requests, rng: &rng
        )

        activities = Self.makeActivities(
            orgID: orgID, users: users, tenants: tenants, leases: leases,
            payments: payments, requests: requests, units: units, rng: &rng
        )

        notifications = Self.makeNotifications(
            orgID: orgID, users: users, requests: requests, payments: payments,
            leases: leases, tenants: tenants, units: units, rng: &rng
        )
    }

    // MARK: - Lookups
    //
    // Dictionaries built once; every projection needs these joins and
    // linear scans across ~200 units would show on the dashboard.

    private(set) lazy var propertyByID: [Domain.Identifier<Domain.Property>: Domain.Property] =
        Dictionary(uniqueKeysWithValues: properties.map { ($0.id, $0) })

    private(set) lazy var unitByID: [Domain.Identifier<Domain.Unit>: Domain.Unit] =
        Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })

    private(set) lazy var tenantByID: [Domain.Identifier<Domain.Tenant>: Domain.Tenant] =
        Dictionary(uniqueKeysWithValues: tenants.map { ($0.id, $0) })

    private(set) lazy var vendorByID: [Domain.Identifier<Domain.Vendor>: Domain.Vendor] =
        Dictionary(uniqueKeysWithValues: vendors.map { ($0.id, $0) })

    private(set) lazy var userByID: [Domain.Identifier<Domain.User>: Domain.User] =
        Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    /// Current lease for a unit, if any.
    private(set) lazy var activeLeaseByUnit: [Domain.Identifier<Domain.Unit>: Domain.Lease] = {
        var map: [Domain.Identifier<Domain.Unit>: Domain.Lease] = [:]
        for lease in leases where lease.status.isCurrent {
            map[lease.unitID] = lease
        }
        return map
    }()

    func units(in property: Domain.Identifier<Domain.Property>) -> [Domain.Unit] {
        units.filter { $0.propertyID == property }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    func requests(for property: Domain.Identifier<Domain.Property>) -> [Domain.MaintenanceRequest] {
        requests.filter { $0.propertyID == property }
    }

    func updates(for request: Domain.Identifier<Domain.MaintenanceRequest>) -> [Domain.MaintenanceUpdate] {
        updates.filter { $0.requestID == request }.sorted { $0.createdAt < $1.createdAt }
    }

    func messages(in conversation: Domain.Identifier<Domain.Conversation>) -> [Domain.Message] {
        messages.filter { $0.conversationID == conversation }.sorted { $0.createdAt < $1.createdAt }
    }

    func payments(for lease: Domain.Identifier<Domain.Lease>) -> [Domain.Payment] {
        payments.filter { $0.leaseID == lease }.sorted { $0.dueOn > $1.dueOn }
    }

    func leases(for tenant: Domain.Identifier<Domain.Tenant>) -> [Domain.Lease] {
        leases.filter { $0.tenantIDs.contains(tenant) }
    }

    func activeLease(for tenant: Domain.Identifier<Domain.Tenant>) -> Domain.Lease? {
        leases.first { $0.tenantIDs.contains(tenant) && $0.status.isCurrent }
    }

    /// Total record count — surfaced in diagnostics.
    var recordCount: Int {
        1 + users.count + properties.count + buildings.count + units.count
            + tenants.count + leases.count + payments.count + vendors.count
            + requests.count + updates.count + conversations.count + messages.count
            + documents.count + notifications.count + inspections.count
            + activities.count + tasks.count
    }
}
