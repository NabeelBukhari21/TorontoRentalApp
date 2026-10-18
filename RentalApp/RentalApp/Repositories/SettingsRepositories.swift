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

    // Person
    var fullName = "Syed Bukhari"
    var email = "nabeelbukhari21@gmail.com"
    var phone = "(416) 555-0100"
    var jobTitle = "Portfolio Owner"

    // Workspace
    var orgName = "Bukhari Properties"
    var orgSlug = "bukhari-properties"
    var orgCity = "Toronto, ON"

    // Team
    private(set) var members: [TeamMember] = [
        TeamMember(name: "Syed Bukhari", email: "nabeelbukhari21@gmail.com",
                   role: "Owner", isOwner: true, status: "Active", statusKind: .success),
        TeamMember(name: "Sarah Mitchell", email: "sarah.m@bukhariproperties.ca",
                   role: "Property Manager", isOwner: false, status: "Active", statusKind: .success),
        TeamMember(name: "David Park", email: "d.park@bukhariproperties.ca",
                   role: "Maintenance Coordinator", isOwner: false, status: "Active", statusKind: .success),
        TeamMember(name: "Alex Rivera", email: "alex.r@bukhariproperties.ca",
                   role: "Property Manager", isOwner: false, status: "Invited", statusKind: .warning)
    ]

    /// Persists the profile. Local today; one call away from a PATCH.
    func save() async throws {
        try await Task.sleep(for: .milliseconds(700))
    }

    func invite(email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("@") else { return }

        withAnimation(DS.Motion.bouncy) {
            members.append(
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

    private(set) var integrations: [IntegrationItem] = [
        IntegrationItem(id: "quickbooks", name: "QuickBooks", icon: "book.closed.fill",
                        detail: "Sync rent payments & expenses", isConnected: true),
        IntegrationItem(id: "interac", name: "Interac e-Transfer", icon: DS.Icons.payment,
                        detail: "Automatic rent collection", isConnected: true),
        IntegrationItem(id: "gcal", name: "Google Calendar", icon: "calendar",
                        detail: "Vendor visits & inspections", isConnected: false),
        IntegrationItem(id: "docusign", name: "DocuSign", icon: "signature",
                        detail: "Digital lease signatures", isConnected: false),
        IntegrationItem(id: "slack", name: "Slack", icon: "bubble.left.and.bubble.right.fill",
                        detail: "Team alerts channel", isConnected: false)
    ]

    func toggleIntegration(_ id: String) {
        guard let index = integrations.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(DS.Motion.bouncy) {
            integrations[index].isConnected.toggle()
        }
    }
}
