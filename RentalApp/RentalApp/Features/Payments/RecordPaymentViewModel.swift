//
//  RecordPaymentViewModel.swift
//  RentalApp (Purrperty)
//
//  Payments — Recording rent a landlord has received, against one
//  month's charge. Starts from what's still owing and how this tenant
//  usually pays.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class RecordPaymentViewModel {

    // MARK: Dependencies

    private let payments: PaymentRepositoryProtocol
    private let sync: SyncEngine
    private let analytics: AnalyticsService

    // MARK: State

    private(set) var row: RentRollRow?
    private(set) var loadError: String?
    private(set) var isSubmitting = false
    var errorMessage: String?
    var draft: PaymentDraft

    init(
        tenantID: String,
        month: Date,
        payments: PaymentRepositoryProtocol,
        sync: SyncEngine,
        analytics: AnalyticsService
    ) {
        self.payments = payments
        self.sync = sync
        self.analytics = analytics
        self.draft = PaymentDraft(tenantID: tenantID, month: month.startOfMonth, amount: 0, method: .eTransfer)
    }

    // MARK: Loading

    func load() async {
        guard row == nil else { return }
        do {
            let roll = try await payments.rentRoll(for: draft.month, forceRefresh: false)
            guard let match = roll.rows.first(where: { $0.tenantID == draft.tenantID }) else {
                loadError = "There's no rent for \(draft.month.monthTitle) on this tenant's lease."
                return
            }
            row = match
            draft.amount = match.outstanding
            draft.method = match.usualMethod
        } catch {
            loadError = (error as? AppError ?? .unknown).errorDescription
        }
    }

    // MARK: Derived

    var isPartial: Bool {
        guard let row else { return false }
        return draft.amount > 0 && draft.amount < row.outstanding
    }

    var canSubmit: Bool {
        guard let row else { return false }
        return draft.amount > 0 && draft.amount <= row.outstanding && !isSubmitting
    }

    // MARK: Submit

    func submit() async -> LedgerEntry? {
        guard canSubmit else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        do {
            let entry = try await payments.record(draft)
            await analytics.track(.paymentRecorded(method: draft.method.analyticsValue))
            await sync.publishLocalChange(.leases)
            return entry
        } catch {
            errorMessage = (error as? AppError ?? .unknown).errorDescription
            return nil
        }
    }
}
