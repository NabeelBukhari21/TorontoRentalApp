//
//  LeaseRenewalViewModel.swift
//  RentalApp (Purrperty)
//
//  Tenants — State and Ontario rules for renewing a lease.
//
//  The form starts from the current lease: the renewal begins the day
//  after it ends, at the same rent. As the rent changes it explains where
//  that sits against the rent-increase guideline and whether there's
//  still time for the 90-day notice.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class LeaseRenewalViewModel {

    /// Where a proposed rent sits against Ontario's guideline.
    enum GuidelineStatus: Equatable {
        case exempt
        case noIncrease
        case within(percent: Double, year: Int)
        case above(percent: Double, year: Int)
        /// No guideline for that year in `OntarioTenancyRules` yet.
        case unknown(year: Int)
    }

    static let lengthOptions = [6, 12, 24]

    // MARK: Dependencies

    private let repository: TenantRepositoryProtocol
    private let sync: SyncEngine
    private let analytics: AnalyticsService
    let tenantID: String

    // MARK: State

    private(set) var current: LeaseSummary?
    private(set) var loadError: String?
    private(set) var isSubmitting = false
    var errorMessage: String?

    var kind: LeaseTermKind = .fixedTerm
    var start: Date = .now
    var lengthMonths = 12
    var rent = 0

    init(
        tenantID: String,
        repository: TenantRepositoryProtocol,
        sync: SyncEngine,
        analytics: AnalyticsService
    ) {
        self.tenantID = tenantID
        self.repository = repository
        self.sync = sync
        self.analytics = analytics
    }

    // MARK: Loading

    func load() async {
        guard current == nil else { return }
        do {
            let lease = try await repository.lease(forTenantID: tenantID)
            current = lease
            rent = lease.rent
            // A renewal picks up the day after the current term ends; a
            // month-to-month tenancy is renewed from the first of next month.
            let calendar = Calendar.current
            start = lease.end.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
                ?? calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: 1, to: .now) ?? .now))
                ?? .now
        } catch {
            loadError = (error as? AppError ?? .unknown).errorDescription
        }
    }

    // MARK: Derived

    /// Last day of a fixed term.
    var end: Date {
        Calendar.current.date(byAdding: DateComponents(month: lengthMonths, day: -1), to: start) ?? start
    }

    var change: Int { rent - (current?.rent ?? rent) }

    var changePercent: Double {
        guard let current, current.rent > 0 else { return 0 }
        return Double(change) / Double(current.rent) * 100
    }

    var guidelineStatus: GuidelineStatus {
        guard let current else { return .noIncrease }
        if current.isRentControlExempt { return .exempt }
        guard change > 0 else { return .noIncrease }
        let year = Calendar.current.component(.year, from: start)
        guard let guideline = OntarioTenancyRules.guideline(for: start) else { return .unknown(year: year) }
        return changePercent > guideline + 0.0001
            ? .above(percent: guideline, year: year)
            : .within(percent: guideline, year: year)
    }

    /// The highest rent within the guideline, when one applies.
    var guidelineMaximum: Int? {
        guard let current, !current.isRentControlExempt,
              let guideline = OntarioTenancyRules.guideline(for: start) else { return nil }
        return OntarioTenancyRules.maximumRent(from: current.rent, guideline: guideline)
    }

    /// The last day to give written notice of an increase starting `start`.
    var noticeDeadline: Date {
        Calendar.current.date(byAdding: .day, value: -OntarioTenancyRules.increaseNoticeDays, to: start) ?? start
    }

    /// An increase whose notice window has already closed.
    var isNoticeLate: Bool {
        change > 0 && Calendar.current.startOfDay(for: .now) > noticeDeadline
    }

    var canSubmit: Bool {
        current != nil && rent > 0 && !isSubmitting
            && (current.map { start > $0.start } ?? false)
    }

    // MARK: Intents

    func useGuidelineMaximum() {
        if let guidelineMaximum { rent = guidelineMaximum }
    }

    func submit() async -> LeaseSummary? {
        guard canSubmit else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        let draft = LeaseRenewalDraft(kind: kind, start: start, end: end, rent: rent)
        do {
            let renewed = try await repository.renewLease(forTenantID: tenantID, with: draft)
            let isAbove = if case .above = guidelineStatus { true } else { false }
            await analytics.track(.leaseRenewed(
                term: kind == .fixedTerm ? "\(lengthMonths)_months" : "month_to_month",
                aboveGuideline: isAbove
            ))
            await sync.publishLocalChange(.leases)
            return renewed
        } catch {
            errorMessage = (error as? AppError ?? .unknown).errorDescription
            return nil
        }
    }
}
