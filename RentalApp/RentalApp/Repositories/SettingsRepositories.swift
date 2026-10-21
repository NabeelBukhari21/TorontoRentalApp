//
//  SettingsRepositories.swift
//  RentalApp (Purrperty)
//
//  Repositories — The former `SettingsStore` God object, split into
//  four single-responsibility data sources. Each settings page depends
//  on exactly one of them.
//

import SwiftUI
import Observation

// MARK: - Profile & Organization

@MainActor
@Observable
final class InMemoryProfileRepository: ProfileRepositoryProtocol {

    /// One profile per workspace, seeded from that workspace's owner and
    /// staff, so a new account's Settings shows its own name and team.
    private struct Record {
        var fullName: String
        var email: String
        var phone: String
        var jobTitle: String
        var orgName: String
        var orgSlug: String
        var orgCity: String
        var members: [TeamMember]

        @MainActor
        init(backend: FakeBackend) {
            let owner = backend.users.first { $0.role == .owner } ?? backend.users.first
            fullName = owner?.fullName ?? ""
            email = owner?.email ?? ""
            phone = owner?.phone ?? ""
            jobTitle = owner?.jobTitle ?? "Owner"
            orgName = backend.organization.name
            orgSlug = backend.organization.slug
            orgCity = "Toronto, ON"
            members = backend.users.map { user in
                let invited = user.status == .invited
                return TeamMember(
                    name: user.fullName,
                    email: user.email,
                    role: user.jobTitle ?? (user.role == .owner ? "Owner" : "Property Manager"),
                    isOwner: user.role == .owner,
                    status: invited ? "Invited" : "Active",
                    statusKind: invited ? .warning : .success
                )
            }
        }
    }

    private var records: [String: Record] = [:]

    private var record: Record {
        get { records[FakeBackend.workspace.key] ?? Record(backend: FakeBackend.shared) }
        set { records[FakeBackend.workspace.key] = newValue }
    }

    // Person
    var fullName: String {
        get { record.fullName }
        set { record.fullName = newValue }
    }
    var email: String {
        get { record.email }
        set { record.email = newValue }
    }
    var phone: String {
        get { record.phone }
        set { record.phone = newValue }
    }
    var jobTitle: String {
        get { record.jobTitle }
        set { record.jobTitle = newValue }
    }

    // Workspace
    var orgName: String {
        get { record.orgName }
        set { record.orgName = newValue }
    }
    var orgSlug: String {
        get { record.orgSlug }
        set { record.orgSlug = newValue }
    }
    var orgCity: String {
        get { record.orgCity }
        set { record.orgCity = newValue }
    }

    // Team
    var members: [TeamMember] { record.members }

    /// Persists the profile. Local today; one call away from a PATCH.
    func save() async throws {
        try await Task.sleep(for: .milliseconds(700))
    }

    func invite(email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("@") else { return }

        withAnimation(DS.Motion.bouncy) {
            record.members.append(
                TeamMember(
                    name: trimmed.components(separatedBy: "@").first?.capitalized ?? "Invitee",
                    email: trimmed,
                    role: "Property Manager",
                    isOwner: false,
                    status: "Invited",
                    statusKind: .warning
                )
            )
        }
    }
}

// MARK: - Preferences

@MainActor
@Observable
final class InMemoryPreferencesRepository: PreferencesRepositoryProtocol {

    // Notifications
    var notifyUrgentMaintenance = true
    var notifyPayments = true
    var notifyMessages = true
    var notifyLeaseEvents = true
    var notifyAIInsights = true
    var emailWeeklyDigest = true
    var emailMonthlyReport = false
    var quietHoursEnabled = true

    // Appearance
    //
    // System by default, like every first-party app: dark mode, Increase
    // Contrast and Reduce Transparency then come from the user's device
    // settings. Light and Dark stay one tap away in Settings → Appearance.
    // Persisted, unlike the rest of this mock: onboarding asks for it, and
    // an answer that resets on the next launch is a broken promise.
    var theme: AppTheme = InMemoryPreferencesRepository.storedTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey) }
    }
    var reduceGlassEffects = false
    var showPortfolioValueOnHome = true

    // Copilot behaviour
    var aiAutoTriage = true
    var aiDraftReplies = true
    var aiVendorMatching = true
    var aiWeeklyBriefing = true
    var aiPricingAlerts = false
    /// 0 (only urgent) ... 1 (highly proactive)
    var aiProactiveness: Double = 0.7

    // MARK: Persistence

    private static let themeKey = "appearance.theme.v1"

    /// System when nothing has been chosen yet — see the note on `theme`.
    private static var storedTheme: AppTheme {
        UserDefaults.standard.string(forKey: themeKey).flatMap(AppTheme.init(rawValue:)) ?? .system
    }
}

// MARK: - Billing

@MainActor
@Observable
final class InMemoryBillingRepository: BillingRepositoryProtocol {

    let planName = "Purrperty Premium"
    let planPrice = "$49/mo"
    let unitQuota = 60
    let unitsUsed = 48

    let invoices: [InvoiceItem] = [
        InvoiceItem(period: "July 2026", amount: "$49.00", status: "Paid"),
        InvoiceItem(period: "June 2026", amount: "$49.00", status: "Paid"),
        InvoiceItem(period: "May 2026", amount: "$49.00", status: "Paid")
    ]
}

// MARK: - Integrations

@MainActor
@Observable
final class InMemoryIntegrationsRepository: IntegrationsRepositoryProtocol {

    // Nothing is connected: these are planned, not built.
    private(set) var integrations: [IntegrationItem] = [
        IntegrationItem(id: "quickbooks", name: "QuickBooks", icon: "book.closed.fill",
                        detail: "Sync rent payments & expenses", isConnected: false),
        IntegrationItem(id: "interac", name: "Interac e-Transfer", icon: DS.Icons.payment,
                        detail: "Match e-Transfers to tenants", isConnected: false),
        IntegrationItem(id: "gcal", name: "Google Calendar", icon: "calendar",
                        detail: "Vendor visits & inspections", isConnected: false),
        IntegrationItem(id: "docusign", name: "DocuSign", icon: "signature",
                        detail: "Digital lease signatures", isConnected: false),
        IntegrationItem(id: "slack", name: "Slack", icon: "bubble.left.and.bubble.right.fill",
                        detail: "Team alerts channel", isConnected: false)
    ]
}
