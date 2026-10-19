//
//  TenantPortalRepository.swift
//  RentalApp (Purrperty)
//
//  Repositories — Finds the tenancy behind a tenant's sign-in.
//
//  The mock identity provider's tenants aren't rows in the seeded
//  portfolio, so this links them: by email first (a tenant invited with
//  the address they sign in with), then the demo tenant account to one
//  seeded tenant chosen so every portal screen has something to show.
//

import Foundation

@MainActor
final class InMemoryTenantPortalRepository: TenantPortalRepositoryProtocol {

    func account(for session: AuthSession) async throws -> PortalAccount? {
        try await SimulatedLatency.wait(.detail)
        guard session.role == .tenant else { return nil }

        let backend = FakeBackend.shared
        let email = session.email.lowercased()
        let tenant = backend.tenants.first { $0.email.lowercased() == email && backend.activeLease(for: $0.id) != nil }
            ?? (session.email.lowercased() == Self.demoTenantEmail ? Self.demoTenant(in: backend) : nil)
        guard let tenant else { return nil }

        let conversationID = backend.conversations
            .first { $0.participants.contains { $0.id == tenant.id.rawValue } }?
            .id.description
        let organization = backend.organization
        let contactEmail = organization.supportEmail ?? "hello@purrperty.ca"

        return PortalAccount(
            tenantID: tenant.id.description,
            tenantName: tenant.fullName,
            conversationID: conversationID,
            landlord: LandlordContact(
                name: organization.name,
                email: contactEmail,
                phone: organization.phone,
                eTransferEmail: contactEmail
            )
        )
    }

    // MARK: Demo Link

    private static let demoTenantEmail = "tenant@rentos.ca"

    /// A tenant with a current lease, a message thread and a request on
    /// their unit, picked the same way every launch.
    private static func demoTenant(in backend: FakeBackend) -> Domain.Tenant? {
        let candidates = backend.tenants
            .sorted { $0.fullName < $1.fullName }
            .filter { tenant in
                guard let lease = backend.activeLease(for: tenant.id) else { return false }
                let hasThread = backend.conversations.contains { $0.participants.contains { $0.id == tenant.id.rawValue } }
                let hasRequest = backend.requests.contains { $0.unitID == lease.unitID }
                return hasThread && hasRequest
            }
        return candidates.first
    }
}
