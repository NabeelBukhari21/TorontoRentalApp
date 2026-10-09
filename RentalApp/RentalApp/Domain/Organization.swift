//
//  Organization.swift
//  RentalApp (RentOS)
//
//  Domain — Tenancy root and people.
//
//  `Organization` is the multi-tenancy boundary: every other row in
//  the system carries an `organization_id` and Supabase row-level
//  security filters on it. `User` is a member of exactly one
//  organization with one role.
//

import Foundation

// MARK: - Organization

extension Domain {

    /// A customer workspace. The root of the ownership graph.
    struct Organization: Record, SoftDeletable {

        typealias Subject = Organization
        static let tableName = "organizations"

        // Identity
        let id: Identifier<Organization>
        var name: String
        /// URL-safe handle, e.g. `bukhari-properties`. Unique per install.
        var slug: String
        /// Storage path of the logo, if uploaded.
        var logoPath: String?

        // Contact
        var address: Address?
        var supportEmail: String?
        var phone: String?

        // Commercial
        var plan: Plan
        var unitQuota: Int
        /// Nil for legacy or comped accounts.
        var trialEndsAt: Date?

        // Locale
        var currency: Money.Currency
        /// IANA identifier, e.g. `America/Toronto`.
        var timeZoneIdentifier: String

        // Lifecycle
        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Organization> = .init(),
            name: String,
            slug: String,
            logoPath: String? = nil,
            address: Address? = nil,
            supportEmail: String? = nil,
            phone: String? = nil,
            plan: Plan = .starter,
            unitQuota: Int = 10,
            trialEndsAt: Date? = nil,
            currency: Money.Currency = .cad,
            timeZoneIdentifier: String = "America/Toronto",
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.slug = slug
            self.logoPath = logoPath
            self.address = address
            self.supportEmail = supportEmail
            self.phone = phone
            self.plan = plan
            self.unitQuota = unitQuota
            self.trialEndsAt = trialEndsAt
            self.currency = currency
            self.timeZoneIdentifier = timeZoneIdentifier
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        /// Subscription tier. Drives quotas and feature gates.
        enum Plan: String, FallbackDecodable, CaseIterable {
            case starter
            case professional
            case premium
            case enterprise
            case unknown

            /// Whether copilot features are included.
            var includesAI: Bool {
                self == .premium || self == .enterprise
            }
        }

        var timeZone: TimeZone {
            TimeZone(identifier: timeZoneIdentifier) ?? .current
        }

        enum CodingKeys: String, CodingKey {
            case id, name, slug, plan, currency, phone
            case logoPath = "logo_path"
            case supportEmail = "support_email"
            case unitQuota = "unit_quota"
            case trialEndsAt = "trial_ends_at"
            case timeZoneIdentifier = "time_zone"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}

// MARK: - User

extension Domain {

    /// A person who signs in. Staff only — renters are `Domain.Tenant`.
    ///
    /// `id` matches the Supabase `auth.users` UUID so the profile row
    /// and the auth record stay in lockstep.
    struct User: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = User
        static let tableName = "users"

        // Identity
        let id: Identifier<User>
        let organizationID: Identifier<Organization>
        var email: String
        var fullName: String
        var phone: String?
        var avatarPath: String?
        /// Free-text title shown in the UI, e.g. "Portfolio Owner".
        var jobTitle: String?

        // Access
        var role: Role
        var status: Status

        // Activity
        var lastSeenAt: Date?

        // Lifecycle
        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<User> = .init(),
            organizationID: Identifier<Organization>,
            email: String,
            fullName: String,
            phone: String? = nil,
            avatarPath: String? = nil,
            jobTitle: String? = nil,
            role: Role = .propertyManager,
            status: Status = .active,
            lastSeenAt: Date? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.email = email
            self.fullName = fullName
            self.phone = phone
            self.avatarPath = avatarPath
            self.jobTitle = jobTitle
            self.role = role
            self.status = status
            self.lastSeenAt = lastSeenAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        /// Permission tier. Ordered loosely from most to least privileged.
        enum Role: String, FallbackDecodable, CaseIterable {
            case owner
            case admin
            case propertyManager = "property_manager"
            case maintenanceCoordinator = "maintenance_coordinator"
            case viewer
            case unknown

            /// Can change billing, invite admins, delete the workspace.
            var canManageOrganization: Bool {
                self == .owner || self == .admin
            }

            /// Can create and edit properties, units, and leases.
            var canManagePortfolio: Bool {
                self == .owner || self == .admin || self == .propertyManager
            }

            /// Can assign vendors and close maintenance requests.
            var canManageMaintenance: Bool {
                canManagePortfolio || self == .maintenanceCoordinator
            }
        }

        enum Status: String, FallbackDecodable, CaseIterable {
            case invited
            case active
            case suspended
            case unknown
        }

        /// Up to two initials for avatar fallbacks.
        var initials: String {
            fullName
                .split(separator: " ")
                .prefix(2)
                .compactMap { $0.first.map(String.init) }
                .joined()
                .uppercased()
        }

        enum CodingKeys: String, CodingKey {
            case id, email, phone, role, status
            case organizationID = "organization_id"
            case fullName = "full_name"
            case avatarPath = "avatar_path"
            case jobTitle = "job_title"
            case lastSeenAt = "last_seen_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}
