//
//  SupabaseOrganizationService.swift
//  RentalApp (Purrperty)
//
//  Supabase — Organization creation and membership.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY THIS IS AN RPC AND NOT AN INSERT
//  ─────────────────────────────────────────────────────────────────
//  Creating a workspace has to do two things atomically: insert the
//  organization, and make the caller its owner. If the client did that
//  as two statements, a request that died in between would leave an
//  orphaned organization with no members — unreachable and undeletable.
//
//  Worse, an INSERT policy permissive enough to let a client create an
//  organization is also permissive enough to let it create one and
//  attach itself to somebody else's. So `organizations` has no INSERT
//  policy at all, and `create_organization()` is the only door.
//

import Foundation
import Supabase

@MainActor
final class SupabaseOrganizationService: OrganizationServiceProtocol {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func createOrganization(_ draft: OrganizationDraft) async throws {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else {
            throw AppError.validation("Give your workspace a name of at least 2 characters.")
        }

        do {
            // The function derives the slug, enforces uniqueness, grants
            // ownership, and writes the audit row — all in one transaction.
            let organization: CreatedOrganizationRow = try await client
                .rpc("create_organization", params: CreateOrganizationParams(
                    name: name,
                    slug: nil,                       // the function derives it
                    propertyType: draft.propertyTypeID,
                    portfolioSize: draft.portfolioSizeID
                ))
                .single()
                .execute()
                .value

            // Invites are best-effort: the workspace exists either way, and
            // failing setup because one address was malformed would be a
            // poor trade. Failures surface later in Settings → Team.
            for email in draft.inviteEmails {
                _ = try? await client
                    .rpc("invite_member", params: InviteMemberParams(
                        email: email,
                        role: "property_manager"
                    ))
                    .execute()
            }

            _ = organization
        } catch {
            throw SupabaseErrorMapper.map(error)
        }
    }
}

// MARK: - RPC Parameters
//
// Encodable structs rather than dictionaries: a typo in a key becomes a
// compile error instead of a Postgres "function does not exist" at run
// time, and optionals encode as JSON null so the function's own defaults
// take over.

private struct CreateOrganizationParams: Encodable {
    let name: String
    let slug: String?
    let propertyType: String?
    let portfolioSize: String?

    enum CodingKeys: String, CodingKey {
        case name          = "p_name"
        case slug          = "p_slug"
        case propertyType  = "p_property_type"
        case portfolioSize = "p_portfolio_size"
    }
}

private struct InviteMemberParams: Encodable {
    let email: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case email = "p_email"
        case role  = "p_role"
    }
}

// MARK: - RPC Row

/// The `organizations` row returned by `create_organization()`.
private struct CreatedOrganizationRow: Decodable, Sendable {
    let id: UUID
    let name: String
    let slug: String
}
