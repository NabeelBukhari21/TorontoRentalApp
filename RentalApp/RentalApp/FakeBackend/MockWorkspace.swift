//
//  MockWorkspace.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — Chooses which world the mock backend shows.
//
//  The demo accounts (and the demo tenant and vendor) live in the seeded
//  portfolio. An account that set up its own organization gets an empty
//  workspace, so Home shows the property it just added rather than
//  someone else's fourteen.
//

import Foundation

@MainActor
final class MockWorkspace: WorkspaceActivating {

    private let cache: RepositoryCache

    init(cache: RepositoryCache) {
        self.cache = cache
    }

    func activate(for session: AuthSession?) {
        guard let workspace = Self.workspace(for: session) else { return }
        // Cached reads belong to the world they were read from.
        if FakeBackend.activate(workspace) {
            cache.invalidateAll()
        }
    }

    /// Nil keeps the current world: a new staff account between sign-up
    /// and setting up its organization has nothing to show yet.
    private static func workspace(for session: AuthSession?) -> FakeBackend.Workspace? {
        guard let session else { return .demo }
        // The mock tenant and vendor belong to the demo portfolio.
        guard session.role.isStaff else { return .demo }
        guard let organizationID = session.organizationID else { return nil }
        if organizationID == MockAccountDirectory.demoOrganizationID { return .demo }
        return .empty(
            organizationName: session.organizationName ?? "My Organization",
            ownerName: session.fullName,
            ownerEmail: session.email
        )
    }
}
