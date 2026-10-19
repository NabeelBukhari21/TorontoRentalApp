//
//  Leasing.swift
//  RentalApp (Purrperty)
//
//  Domain — Renters, agreements, and money in.
//
//      Tenant ──┐
//               ├──> Lease ──> Payment
//      Unit ────┘
//
//  `Tenant` is the *person* and outlives any single agreement.
//  `Lease` is the agreement, scoped in time. Keeping them separate is
//  what allows renewal history, tenants who move between units, and
//  roommates on one lease — all impossible if occupancy were a field
//  on the unit.
//

import Foundation

// MARK: - Tenant

extension Domain {

    /// A renter. Exists independently of any lease so history survives
    /// move-outs and renewals.
    struct Tenant: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Tenant
        static let tableName = "tenants"

        // Identity
        let id: Identifier<Tenant>
        let organizationID: Identifier<Organization>
        var fullName: String
        var email: String
        var phone: String?
        var avatarPath: String?
        var dateOfBirth: Date?

        // Portal access — nil until the tenant activates their account.
        var portalUserID: Identifier<User>?

        // Emergency
        var emergencyContactName: String?
        var emergencyContactPhone: String?

        // Standing
        var status: Status
        /// Percentage of on-time payments, 0...100. Maintained by the
        /// payments service, never edited by hand.
        var onTimePaymentRate: Int
        /// Flags a high-value relationship for retention workflows.
        var isPriority: Bool

        var notes: String?

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Tenant> = .init(),
            organizationID: Identifier<Organization>,
            fullName: String,
            email: String,
            phone: String? = nil,
            avatarPath: String? = nil,
            dateOfBirth: Date? = nil,
            portalUserID: Identifier<User>? = nil,
            emergencyContactName: String? = nil,
            emergencyContactPhone: String? = nil,
            status: Status = .prospective,
            onTimePaymentRate: Int = 100,
            isPriority: Bool = false,
            notes: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.fullName = fullName
            self.email = email
            self.phone = phone
            self.avatarPath = avatarPath
            self.dateOfBirth = dateOfBirth
            self.portalUserID = portalUserID
            self.emergencyContactName = emergencyContactName
            self.emergencyContactPhone = emergencyContactPhone
            self.status = status
            self.onTimePaymentRate = onTimePaymentRate
            self.isPriority = isPriority
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        /// Relationship stage — independent of any lease's own status.
        enum Status: String, FallbackDecodable, CaseIterable {
            case prospective
            case current
            case notice
            case past
            case evicted
            case unknown
        }

        var initials: String {
            fullName
                .split(separator: " ")
                .prefix(2)
                .compactMap { $0.first.map(String.init) }
                .joined()
                .uppercased()
        }

        enum CodingKeys: String, CodingKey {
            case id, email, phone, status, notes
            case organizationID = "organization_id"
            case fullName = "full_name"
            case avatarPath = "avatar_path"
            case dateOfBirth = "date_of_birth"
            case portalUserID = "portal_user_id"
            case emergencyContactName = "emergency_contact_name"
            case emergencyContactPhone = "emergency_contact_phone"
            case onTimePaymentRate = "on_time_payment_rate"
            case isPriority = "is_priority"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}

// MARK: - Lease

extension Domain {

    /// A rental agreement binding tenants to a unit for a term.
    ///
    /// `tenantIDs` is an array so roommates share one agreement, with
    /// `primaryTenantID` naming who receives correspondence.
    struct Lease: Record, OrganizationScoped, SoftDeletable {

        typealias Subject = Lease
        static let tableName = "leases"

        // Identity
        let id: Identifier<Lease>
        let organizationID: Identifier<Organization>
        let unitID: Identifier<Unit>
        /// Denormalised for portfolio-wide lease queries without a join.
        let propertyID: Identifier<Property>

        // Parties
        var primaryTenantID: Identifier<Tenant>
        /// Includes the primary tenant. Roommates are co-signers here.
        var tenantIDs: [Identifier<Tenant>]

        // Term
        var term: DateRange
        var kind: Kind
        var status: Status

        // Money
        var rent: Money
        var depositHeld: Money
        var rentDueDay: Int
        /// Set when the agreement renews into a new lease row.
        var renewedIntoLeaseID: Identifier<Lease>?

        // Paperwork
        var signedAt: Date?
        var documentID: Identifier<Document>?
        var moveInAt: Date?
        var moveOutAt: Date?

        let createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: Identifier<Lease> = .init(),
            organizationID: Identifier<Organization>,
            unitID: Identifier<Unit>,
            propertyID: Identifier<Property>,
            primaryTenantID: Identifier<Tenant>,
            tenantIDs: [Identifier<Tenant>]? = nil,
            term: DateRange,
            kind: Kind = .fixedTerm,
            status: Status = .draft,
            rent: Money,
            depositHeld: Money = .zero,
            rentDueDay: Int = 1,
            renewedIntoLeaseID: Identifier<Lease>? = nil,
            signedAt: Date? = nil,
            documentID: Identifier<Document>? = nil,
            moveInAt: Date? = nil,
            moveOutAt: Date? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.id = id
            self.organizationID = organizationID
            self.unitID = unitID
            self.propertyID = propertyID
            self.primaryTenantID = primaryTenantID
            self.tenantIDs = tenantIDs ?? [primaryTenantID]
            self.term = term
            self.kind = kind
            self.status = status
            self.rent = rent
            self.depositHeld = depositHeld
            self.rentDueDay = rentDueDay
            self.renewedIntoLeaseID = renewedIntoLeaseID
            self.signedAt = signedAt
            self.documentID = documentID
            self.moveInAt = moveInAt
            self.moveOutAt = moveOutAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        enum Kind: String, FallbackDecodable, CaseIterable {
            case fixedTerm = "fixed_term"
            /// Ontario leases roll to month-to-month after the first term.
            case monthToMonth = "month_to_month"
            case sublet
            case unknown
        }

        enum Status: String, FallbackDecodable, CaseIterable {
            case draft
            case pendingSignature = "pending_signature"
            case active
            case expiring
            case expired
            case terminated
            case renewed
            case unknown

            /// Contributes to occupancy and expected revenue.
            var isCurrent: Bool {
                self == .active || self == .expiring
            }
        }

        /// Fraction of the term elapsed, 0...1.
        func progress(asOf date: Date = .now) -> Double {
            term.progress(asOf: date)
        }

        /// Days until the term ends. Negative once expired.
        func daysRemaining(asOf date: Date = .now) -> Int {
            Calendar.current.dateComponents([.day], from: date, to: term.end).day ?? 0
        }

        /// Renewal window — the standard 60-day Ontario notice period.
        func isRenewalDue(asOf date: Date = .now) -> Bool {
            status.isCurrent && daysRemaining(asOf: date) <= 60
        }

        enum CodingKeys: String, CodingKey {
            case id, kind, status, rent, term
            case organizationID = "organization_id"
            case unitID = "unit_id"
            case propertyID = "property_id"
            case primaryTenantID = "primary_tenant_id"
            case tenantIDs = "tenant_ids"
            case depositHeld = "deposit_held"
            case rentDueDay = "rent_due_day"
            case renewedIntoLeaseID = "renewed_into_lease_id"
            case signedAt = "signed_at"
            case documentID = "document_id"
            case moveInAt = "move_in_at"
            case moveOutAt = "move_out_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case deletedAt = "deleted_at"
        }
    }
}

// MARK: - Payment

extension Domain {

    /// Money received (or attempted) against a lease.
    ///
    /// Immutable in spirit: corrections are new rows with a `reversal`
    /// kind rather than edits, so the ledger stays auditable.
    struct Payment: Record, OrganizationScoped {

        typealias Subject = Payment
        static let tableName = "payments"

        // Identity
        let id: Identifier<Payment>
        let organizationID: Identifier<Organization>
        let leaseID: Identifier<Lease>
        let tenantID: Identifier<Tenant>
        /// Denormalised for property-level revenue reporting.
        let propertyID: Identifier<Property>

        // Amounts
        var amount: Money
        var kind: Kind
        var method: Method
        var status: Status

        // Timing
        var dueOn: Date
        var paidAt: Date?

        // Reconciliation
        /// Processor or bank reference for support and disputes.
        var externalReference: String?
        var failureReason: String?
        /// Points at the payment this one reverses, when applicable.
        var reversesPaymentID: Identifier<Payment>?
        var memo: String?

        let createdAt: Date
        var updatedAt: Date

        init(
            id: Identifier<Payment> = .init(),
            organizationID: Identifier<Organization>,
            leaseID: Identifier<Lease>,
            tenantID: Identifier<Tenant>,
            propertyID: Identifier<Property>,
            amount: Money,
            kind: Kind = .rent,
            method: Method = .eTransfer,
            status: Status = .scheduled,
            dueOn: Date,
            paidAt: Date? = nil,
            externalReference: String? = nil,
            failureReason: String? = nil,
            reversesPaymentID: Identifier<Payment>? = nil,
            memo: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.organizationID = organizationID
            self.leaseID = leaseID
            self.tenantID = tenantID
            self.propertyID = propertyID
            self.amount = amount
            self.kind = kind
            self.method = method
            self.status = status
            self.dueOn = dueOn
            self.paidAt = paidAt
            self.externalReference = externalReference
            self.failureReason = failureReason
            self.reversesPaymentID = reversesPaymentID
            self.memo = memo
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        enum Kind: String, FallbackDecodable, CaseIterable {
            case rent
            case deposit
            /// Kept so old rows still decode. Ontario landlords can't charge
            /// late fees on rent (RTA s. 134); never create one.
            case lateFee = "late_fee"
            /// Administration charge for a returned cheque or debit. Ontario
            /// caps it at $20 plus the bank's own charges.
            case nsfFee = "nsf_fee"
            case utilities
            case parking
            case repairChargeback = "repair_chargeback"
            case refund
            case reversal
            case unknown
        }

        enum Method: String, FallbackDecodable, CaseIterable {
            case eTransfer = "e_transfer"
            case preAuthorizedDebit = "pre_authorized_debit"
            case card
            case cheque
            case cash
            case unknown
        }

        enum Status: String, FallbackDecodable, CaseIterable {
            case scheduled
            case processing
            case paid
            case failed
            case refunded
            case unknown
        }

        /// Unpaid and past its due date.
        func isOverdue(asOf date: Date = .now) -> Bool {
            (status == .scheduled || status == .failed) && dueOn < date
        }

        /// Whole days late. Zero when on time or not yet due.
        func daysLate(asOf date: Date = .now) -> Int {
            guard isOverdue(asOf: date) else { return 0 }
            return Calendar.current.dateComponents([.day], from: dueOn, to: date).day ?? 0
        }

        enum CodingKeys: String, CodingKey {
            case id, amount, kind, method, status, memo
            case organizationID = "organization_id"
            case leaseID = "lease_id"
            case tenantID = "tenant_id"
            case propertyID = "property_id"
            case dueOn = "due_on"
            case paidAt = "paid_at"
            case externalReference = "external_reference"
            case failureReason = "failure_reason"
            case reversesPaymentID = "reverses_payment_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
}
