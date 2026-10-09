//
//  SettingsViewModels.swift
//  RentalApp (RentOS)
//
//  Settings — One small ViewModel per page, each depending on exactly
//  the repository facet it needs. Replaces the former single
//  `SettingsStore` that every page reached into.
//

import SwiftUI
import Observation

// MARK: - Hub

@MainActor
@Observable
final class SettingsHubViewModel {

    private let profileRepo: ProfileRepositoryProtocol
    private let billingRepo: BillingRepositoryProtocol
    private let integrationsRepo: IntegrationsRepositoryProtocol

    init(
        profile: ProfileRepositoryProtocol,
        billing: BillingRepositoryProtocol,
        integrations: IntegrationsRepositoryProtocol
    ) {
        self.profileRepo = profile
        self.billingRepo = billing
        self.integrationsRepo = integrations
    }

    var fullName: String { profileRepo.fullName }
    var email: String { profileRepo.email }
    var jobTitle: String { profileRepo.jobTitle }
    var orgName: String { profileRepo.orgName }
    var memberCount: Int { profileRepo.members.count }
    var planName: String { billingRepo.planName }
    var connectedIntegrations: Int { integrationsRepo.integrations.filter(\.isConnected).count }
}

// MARK: - Profile & Organization

@MainActor
@Observable
final class ProfileSettingsViewModel {

    private let repo: ProfileRepositoryProtocol

    init(repository: ProfileRepositoryProtocol) {
        self.repo = repository
    }

    var fullName: String {
        get { repo.fullName } set { repo.fullName = newValue }
    }
    var email: String {
        get { repo.email } set { repo.email = newValue }
    }
    var phone: String {
        get { repo.phone } set { repo.phone = newValue }
    }
    var jobTitle: String {
        get { repo.jobTitle } set { repo.jobTitle = newValue }
    }

    var orgName: String {
        get { repo.orgName } set { repo.orgName = newValue }
    }
    var orgSlug: String {
        get { repo.orgSlug } set { repo.orgSlug = newValue }
    }
    var orgCity: String {
        get { repo.orgCity } set { repo.orgCity = newValue }
    }
}

// MARK: - Team

@MainActor
@Observable
final class TeamSettingsViewModel {

    private let repo: ProfileRepositoryProtocol

    var inviteEmail = ""

    init(repository: ProfileRepositoryProtocol) {
        self.repo = repository
    }

    var members: [TeamMember] { repo.members }

    func sendInvite() {
        repo.invite(email: inviteEmail)
        inviteEmail = ""
    }
}

// MARK: - Billing

@MainActor
@Observable
final class BillingSettingsViewModel {

    private let repo: BillingRepositoryProtocol

    init(repository: BillingRepositoryProtocol) {
        self.repo = repository
    }

    var planName: String { repo.planName }
    var planPrice: String { repo.planPrice }
    var unitQuota: Int { repo.unitQuota }
    var unitsUsed: Int { repo.unitsUsed }
    var invoices: [InvoiceItem] { repo.invoices }

    var usageFraction: Double {
        unitQuota == 0 ? 0 : Double(unitsUsed) / Double(unitQuota)
    }
}

// MARK: - Preferences (notifications · appearance · copilot)

@MainActor
@Observable
final class PreferencesSettingsViewModel {

    private let repo: PreferencesRepositoryProtocol

    init(repository: PreferencesRepositoryProtocol) {
        self.repo = repository
    }

    // Notifications
    var notifyUrgentMaintenance: Bool {
        get { repo.notifyUrgentMaintenance } set { repo.notifyUrgentMaintenance = newValue }
    }
    var notifyPayments: Bool {
        get { repo.notifyPayments } set { repo.notifyPayments = newValue }
    }
    var notifyMessages: Bool {
        get { repo.notifyMessages } set { repo.notifyMessages = newValue }
    }
    var notifyLeaseEvents: Bool {
        get { repo.notifyLeaseEvents } set { repo.notifyLeaseEvents = newValue }
    }
    var notifyAIInsights: Bool {
        get { repo.notifyAIInsights } set { repo.notifyAIInsights = newValue }
    }
    var emailWeeklyDigest: Bool {
        get { repo.emailWeeklyDigest } set { repo.emailWeeklyDigest = newValue }
    }
    var emailMonthlyReport: Bool {
        get { repo.emailMonthlyReport } set { repo.emailMonthlyReport = newValue }
    }
    var quietHoursEnabled: Bool {
        get { repo.quietHoursEnabled } set { repo.quietHoursEnabled = newValue }
    }

    // Appearance
    var theme: AppTheme {
        get { repo.theme } set { repo.theme = newValue }
    }
    var reduceGlassEffects: Bool {
        get { repo.reduceGlassEffects } set { repo.reduceGlassEffects = newValue }
    }
    var showPortfolioValueOnHome: Bool {
        get { repo.showPortfolioValueOnHome } set { repo.showPortfolioValueOnHome = newValue }
    }

    // Copilot
    var aiAutoTriage: Bool {
        get { repo.aiAutoTriage } set { repo.aiAutoTriage = newValue }
    }
    var aiDraftReplies: Bool {
        get { repo.aiDraftReplies } set { repo.aiDraftReplies = newValue }
    }
    var aiVendorMatching: Bool {
        get { repo.aiVendorMatching } set { repo.aiVendorMatching = newValue }
    }
    var aiWeeklyBriefing: Bool {
        get { repo.aiWeeklyBriefing } set { repo.aiWeeklyBriefing = newValue }
    }
    var aiPricingAlerts: Bool {
        get { repo.aiPricingAlerts } set { repo.aiPricingAlerts = newValue }
    }
    var aiProactiveness: Double {
        get { repo.aiProactiveness } set { repo.aiProactiveness = newValue }
    }
}

// MARK: - Integrations

@MainActor
@Observable
final class IntegrationsSettingsViewModel {

    private let repo: IntegrationsRepositoryProtocol

    init(repository: IntegrationsRepositoryProtocol) {
        self.repo = repository
    }

    var integrations: [IntegrationItem] { repo.integrations }
    var connectedCount: Int { integrations.filter(\.isConnected).count }

    func toggle(_ id: String) {
        repo.toggleIntegration(id)
    }
}
