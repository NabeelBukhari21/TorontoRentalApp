//
//  VendorPortalRepository.swift
//  RentalApp (Purrperty)
//
//  Repositories — Finds the vendor behind a vendor's sign-in.
//
//  Same approach as the tenant portal: match by email first, then link
//  the demo vendor account to the seeded vendor with the most open work,
//  so every screen has something to show.
//

import Foundation

@MainActor
final class InMemoryVendorPortalRepository: VendorPortalRepositoryProtocol {

    func account(for session: AuthSession) async throws -> VendorAccount? {
        try await SimulatedLatency.wait(.detail)
        guard session.role == .vendor else { return nil }

        let backend = FakeBackend.shared
        let email = session.email.lowercased()
        let vendor = backend.vendors.first { $0.email?.lowercased() == email }
            ?? (email == Self.demoVendorEmail ? Self.demoVendor(in: backend) : nil)
        guard let vendor else { return nil }

        let conversationID = backend.conversations
            .first { $0.participants.contains { $0.id == vendor.id.rawValue } }?
            .id.description
        let organization = backend.organization
        let contactEmail = organization.supportEmail ?? "hello@purrperty.ca"

        return VendorAccount(
            vendorID: vendor.id.description,
            company: vendor.companyName,
            contactName: vendor.contactName ?? vendor.companyName,
            conversationID: conversationID,
            client: LandlordContact(
                name: organization.name,
                email: contactEmail,
                phone: organization.phone,
                eTransferEmail: contactEmail
            )
        )
    }

    // MARK: Demo Link

    private static let demoVendorEmail = "vendor@rentos.ca"

    /// The vendor with the most open jobs, preferring one with a thread.
    private static func demoVendor(in backend: FakeBackend) -> Domain.Vendor? {
        func openJobs(_ vendor: Domain.Vendor) -> Int {
            backend.requests.filter { $0.assignedVendorID == vendor.id && $0.status.isOpen }.count
        }
        func hasThread(_ vendor: Domain.Vendor) -> Bool {
            backend.conversations.contains { $0.participants.contains { $0.id == vendor.id.rawValue } }
        }
        return backend.vendors
            .sorted { $0.companyName < $1.companyName }
            .max { lhs, rhs in
                (hasThread(lhs) ? 1 : 0, openJobs(lhs)) < (hasThread(rhs) ? 1 : 0, openJobs(rhs))
            }
    }
}
