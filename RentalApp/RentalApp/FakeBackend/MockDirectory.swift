//
//  MockDirectory.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — The mock identity provider's directory: accounts made
//  in the app, and invites to join an organization. Kept on the phone
//  (`WorkspaceArchive`), so a sign-up still works after a relaunch and an
//  invite waits until the teammate signs up.
//
//  Passwords are kept only as salted SHA-256 hashes. This is a stand-in
//  for Supabase Auth, which owns the real directory once it's set up.
//

import CryptoKit
import Foundation
import Observation

@MainActor
@Observable
final class MockDirectory {

    static let shared = MockDirectory()

    struct Account: Codable, Equatable {
        let userID: String
        let email: String
        var passwordHash: String
        let fullName: String
        let role: AppRole
        var organizationID: String?
        var organizationName: String?
    }

    /// An invitation to join an organization as a property manager.
    struct Invite: Codable, Equatable, Identifiable {
        var id: String { "\(organizationID)|\(email)" }
        let email: String
        let organizationID: String
        let organizationName: String
        let sentAt: Date
    }

    private(set) var accounts: [Account]
    private(set) var invites: [Invite]

    private let archive: WorkspaceArchive
    private static let file = "directory"

    init(archive: WorkspaceArchive? = nil) {
        let archive = archive ?? .shared
        self.archive = archive
        accounts = archive.value("accounts", in: Self.file) ?? []
        invites = archive.value("invites", in: Self.file) ?? []
    }

    // MARK: Accounts

    func account(email: String) -> Account? {
        let email = Self.normalized(email)
        return accounts.first { $0.email == email }
    }

    func add(_ account: Account) {
        accounts.removeAll { $0.email == account.email }
        accounts.append(account)
        save()
    }

    func attach(email: String, organizationID: String, organizationName: String) {
        guard let index = accounts.firstIndex(where: { $0.email == Self.normalized(email) }) else { return }
        accounts[index].organizationID = organizationID
        accounts[index].organizationName = organizationName
        save()
    }

    func setPassword(_ password: String, email: String) {
        let email = Self.normalized(email)
        guard let index = accounts.firstIndex(where: { $0.email == email }) else { return }
        accounts[index].passwordHash = Self.hash(password, email: email)
        save()
    }

    func checks(_ password: String, for account: Account) -> Bool {
        account.passwordHash == Self.hash(password, email: account.email)
    }

    /// Who has joined an organization through the app.
    func members(of organizationID: String) -> [Account] {
        accounts.filter { $0.organizationID == organizationID }
    }

    // MARK: Invites

    /// Invites someone to an organization. Nothing happens if they're
    /// already in it or already invited.
    func invite(_ email: String, to organizationID: String, named organizationName: String) {
        let email = Self.normalized(email)
        guard !email.isEmpty,
              account(email: email)?.organizationID != organizationID,
              !invites.contains(where: { $0.email == email && $0.organizationID == organizationID })
        else { return }
        invites.append(Invite(email: email, organizationID: organizationID, organizationName: organizationName, sentAt: .now))
        save()
    }

    /// The newest invite waiting for an email.
    func invite(for email: String) -> Invite? {
        let email = Self.normalized(email)
        return invites.last { $0.email == email }
    }

    func invites(to organizationID: String) -> [Invite] {
        invites.filter { $0.organizationID == organizationID }
    }

    /// The invite is used: it leaves the list.
    func accept(_ invite: Invite) {
        invites.removeAll { $0.email == invite.email }
        save()
    }

    // MARK: Internals

    static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Salted with the address, so two people with the same password
    /// don't share a hash.
    static func hash(_ password: String, email: String) -> String {
        SHA256.hash(data: Data("purrperty|\(normalized(email))|\(password)".utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    private func save() {
        archive.set(accounts, for: "accounts", in: Self.file)
        archive.set(invites, for: "invites", in: Self.file)
    }
}
