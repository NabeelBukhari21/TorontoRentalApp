//
//  PortfolioIntents.swift
//  RentalApp (Purrperty)
//
//  Intents — Siri and Shortcuts actions for owners and managers:
//  rent status, a maintenance summary, opening the new-request form and
//  the rent roll, and recording a payment received.
//
//  Answers come from the same repositories the screens use, so Siri never
//  says something the app wouldn't show.
//

import AppIntents
import Foundation

// MARK: - Rent Status

struct RentStatusIntent: AppIntent {

    static let title: LocalizedStringResource = "Rent Status"
    static let description = IntentDescription("How much of this month's rent is in, and who still owes.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ShortcutContext.requireStaff()
        let roll = try await ShortcutContext.container.payments.rentRoll(for: .now, forceRefresh: false)

        let month = roll.month.formatted(.dateTime.month(.wide))
        var answer = "You've collected \(roll.collected.formatted(.cad)) of \(roll.expected.formatted(.cad)) for \(month)."
        if roll.owingCount == 0 {
            answer += " Everyone is paid up."
        } else {
            let owing = roll.outstanding + roll.arrears
            answer += " \(roll.owingCount) \(roll.owingCount == 1 ? "tenant owes" : "tenants owe") \(owing.formatted(.cad)) in total."
        }
        return .result(dialog: IntentDialog(stringLiteral: answer))
    }
}

// MARK: - Maintenance Summary

struct MaintenanceSummaryIntent: AppIntent {

    static let title: LocalizedStringResource = "Maintenance Summary"
    static let description = IntentDescription("Open repair requests, how many are urgent, and how many have no vendor.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ShortcutContext.requireStaff()
        let summary = try await ShortcutContext.container.maintenance.summary(forceRefresh: false)

        let answer: String
        if summary.open == 0 {
            answer = "No open repair requests."
        } else {
            answer = "\(summary.open) open requests: \(summary.urgent) urgent and \(summary.unassigned) without a vendor."
        }
        return .result(dialog: IntentDialog(stringLiteral: answer))
    }
}

// MARK: - Open the App

struct NewMaintenanceRequestIntent: AppIntent {

    static let title: LocalizedStringResource = "New Maintenance Request"
    static let description = IntentDescription("Opens Purrperty at the new-request form.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        try ShortcutContext.requireStaff()
        let router = AppRouter.shared
        router.select(.maintenance)
        router.present(.newMaintenanceRequest)
        return .result()
    }
}

struct OpenRentIntent: AppIntent {

    static let title: LocalizedStringResource = "Open Rent"
    static let description = IntentDescription("Opens this month's rent roll in Purrperty.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        try ShortcutContext.requireStaff()
        let router = AppRouter.shared
        router.dismissPresentation()
        router.popToRoot(in: .dashboard)
        router.push(.rentCollection, in: .dashboard)
        return .result()
    }
}

// MARK: - Record Payment

struct RecordPaymentIntent: AppIntent {

    static let title: LocalizedStringResource = "Record Rent Payment"
    static let description = IntentDescription("Records rent you've received from a tenant. Purrperty doesn't move money.")

    @Parameter(title: "Tenant", requestValueDialog: "Who paid?")
    var tenant: OwingTenantEntity

    @Parameter(title: "Amount", description: "Leave empty to record everything owing for the oldest month.", inclusiveRange: (1, 100_000))
    var amount: Int?

    @Parameter(title: "Method", default: .eTransfer)
    var method: PaymentMethodAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Record \(\.$amount) from \(\.$tenant) by \(\.$method)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ShortcutContext.requireStaff()
        let payments = ShortcutContext.container.payments

        // Re-read: what's owing may have changed since Siri listed tenants.
        let roll = try await payments.rentRoll(for: .now, forceRefresh: false)
        guard let row = roll.rows.first(where: { $0.tenantID == tenant.id }), row.isOwing,
              let month = row.oldestOwingMonth else {
            throw ShortcutError.failed("\(tenant.name) doesn't owe any rent right now.")
        }
        let monthOwing = month == row.dueOn.startOfMonth
            ? row.outstanding
            : row.arrears.first { $0.month == month }?.amount ?? row.outstanding
        let received = amount ?? monthOwing

        try await requestConfirmation(
            dialog: IntentDialog(stringLiteral: "Record \(received.formatted(.cad)) from \(tenant.name) for \(month.monthTitle) rent, paid by \(method.paymentMethod.rawValue)?")
        )

        do {
            try await payments.record(PaymentDraft(
                tenantID: tenant.id, month: month, amount: received, method: method.paymentMethod
            ))
        } catch let error as AppError {
            throw ShortcutError.failed(error.errorDescription ?? "Couldn't record the payment.")
        }
        await ShortcutContext.container.analytics.track(.paymentRecorded(method: method.paymentMethod.analyticsValue))
        await ShortcutContext.container.sync.publishLocalChange(.leases)

        return .result(dialog: IntentDialog(stringLiteral: "Recorded \(received.formatted(.cad)) from \(tenant.name)."))
    }
}

// MARK: - Entities

/// A tenant who owes rent — what Record Payment offers to pick from.
struct OwingTenantEntity: AppEntity {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tenant"
    static let defaultQuery = OwingTenantQuery()

    let id: String
    let name: String
    let unit: String
    let owing: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(unit) · \(owing.formatted(.cad)) owing"
        )
    }

    init(row: RentRollRow) {
        id = row.tenantID
        name = row.tenantName
        unit = "\(row.unitName), \(row.propertyName)"
        owing = row.totalOwing
    }
}

struct OwingTenantQuery: EntityStringQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [OwingTenantEntity] {
        try await owing().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [OwingTenantEntity] {
        try await owing().filter {
            $0.name.localizedCaseInsensitiveContains(string) || $0.unit.localizedCaseInsensitiveContains(string)
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [OwingTenantEntity] {
        try await owing()
    }

    @MainActor
    private func owing() async throws -> [OwingTenantEntity] {
        try ShortcutContext.requireStaff()
        let roll = try await ShortcutContext.container.payments.rentRoll(for: .now, forceRefresh: false)
        return roll.rows.filter(\.isOwing).map(OwingTenantEntity.init)
    }
}

enum PaymentMethodAppEnum: String, AppEnum {
    case eTransfer, preAuthorizedDebit, cheque, cash, card

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Payment Method"
    static let caseDisplayRepresentations: [PaymentMethodAppEnum: DisplayRepresentation] = [
        .eTransfer: "Interac e-Transfer",
        .preAuthorizedDebit: "Pre-authorized debit",
        .cheque: "Cheque",
        .cash: "Cash",
        .card: "Card"
    ]

    var paymentMethod: PaymentMethod {
        switch self {
        case .eTransfer: .eTransfer
        case .preAuthorizedDebit: .preAuthorizedDebit
        case .cheque: .cheque
        case .cash: .cash
        case .card: .card
        }
    }
}

// MARK: - Shortcuts

/// Phrases Siri recognizes without any setup, and the tiles shown in the
/// Shortcuts app and Spotlight.
struct PurrpertyShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RentStatusIntent(),
            phrases: [
                "Rent status in \(.applicationName)",
                "Who owes rent in \(.applicationName)",
                "How much rent is in on \(.applicationName)"
            ],
            shortTitle: "Rent Status",
            systemImageName: "dollarsign.circle"
        )
        AppShortcut(
            intent: MaintenanceSummaryIntent(),
            phrases: [
                "Maintenance summary in \(.applicationName)",
                "Open repairs in \(.applicationName)"
            ],
            shortTitle: "Maintenance Summary",
            systemImageName: "wrench.and.screwdriver"
        )
        AppShortcut(
            intent: NewMaintenanceRequestIntent(),
            phrases: [
                "New maintenance request in \(.applicationName)",
                "Report a repair in \(.applicationName)"
            ],
            shortTitle: "New Request",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: RecordPaymentIntent(),
            phrases: [
                "Record a rent payment in \(.applicationName)",
                "Record rent in \(.applicationName)"
            ],
            shortTitle: "Record Payment",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: OpenRentIntent(),
            phrases: ["Open rent in \(.applicationName)"],
            shortTitle: "Open Rent",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
