//
//  TenantLedgerView.swift
//  RentalApp (Purrperty)
//
//  Payments — A tenant's account: balance, what to do when they owe, and
//  every charge and payment, newest first, with a receipt for each
//  payment.
//

import SwiftUI

/// Reads the container from the environment for the navigation module.
struct TenantLedgerRoot: View {
    let tenantID: String
    @Environment(\.container) private var container

    var body: some View {
        TenantLedgerView(tenantID: tenantID, container: container)
    }
}

struct TenantLedgerView: View {

    @State private var viewModel: TenantLedgerViewModel
    @State private var isRecording = false
    @State private var isConfirmingReminder = false

    @Environment(\.container) private var container
    @Environment(\.toasts) private var toasts

    init(tenantID: String, container: AppContainer) {
        _viewModel = State(initialValue: TenantLedgerViewModel(
            tenantID: tenantID,
            payments: container.payments,
            reminders: RentReminderSender(
                messages: container.messages,
                payments: container.payments,
                analytics: container.analytics
            ),
            landlordName: container.profile.orgName
        ))
    }

    var body: some View {
        Group {
            if let ledger = viewModel.ledger {
                list(ledger)
            } else if let error = viewModel.loadError {
                ContentUnavailableView {
                    Label("Couldn't Load Payments", symbol: .caution)
                } description: {
                    Text(error.errorDescription ?? "")
                } actions: {
                    Button("Try Again") { Task { await viewModel.load() } }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Payments")
        .navigationSubtitle(viewModel.ledger?.tenantName ?? "")
        .toolbar {
            if viewModel.ledger != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Record Payment", systemImage: AppSymbol.add.rawValue) { isRecording = true }
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $isRecording) {
            RecordPaymentView(tenantID: viewModel.tenantID, month: viewModel.monthToRecord, container: container) {
                Task { await viewModel.load() }
            }
        }
        .confirmationDialog("Send a reminder to \(viewModel.firstName)?", isPresented: $isConfirmingReminder, titleVisibility: .visible) {
            Button("Send Reminder") { remind() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.reminderText)
        }
    }

    // MARK: List

    private func list(_ ledger: TenantLedger) -> some View {
        List {
            Section {
                LabeledContent("Balance") {
                    if ledger.balance > 0 {
                        Text("\(ledger.balance.formatted(.cad)) owing")
                            .foregroundStyle(.red)
                            .monospacedDigit()
                    } else {
                        StatusLabel("Up to date", role: .positive)
                    }
                }
                LabeledContent("Unit", value: "\(ledger.unitName), \(ledger.propertyName)")
                LabeledContent("Monthly rent") { Text(ledger.monthlyRent, format: .cad) }
                LabeledContent("Last month's rent deposit") { Text(ledger.depositHeld, format: .cad) }
            }

            if viewModel.isOwing {
                owingSection(ledger)
            }

            Section {
                if ledger.entries.isEmpty {
                    Text("No charges or payments yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(ledger.entries) { entry in
                    LedgerEntryRow(entry: entry)
                        .contextMenu {
                            if entry.isPayment {
                                ShareLink("Share Receipt", item: viewModel.receipt(for: entry))
                            }
                        }
                        .swipeActions {
                            if entry.isPayment {
                                ShareLink(item: viewModel.receipt(for: entry)) {
                                    Label("Receipt", systemImage: AppSymbol.share.rawValue)
                                }
                                .tint(.blue)
                            }
                        }
                }
            } header: {
                Text("Activity")
            } footer: {
                Text("Swipe a payment to share a receipt. Ontario landlords must give a free receipt for rent when a tenant asks.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func owingSection(_ ledger: TenantLedger) -> some View {
        Section {
            Button("Record Payment", systemImage: "checkmark.circle") { isRecording = true }
            if viewModel.canRemind {
                Button("Send Reminder", systemImage: "bell") { isConfirmingReminder = true }
            } else {
                ShareLink(item: viewModel.reminderText) {
                    Label("Share Reminder", systemImage: "bell")
                }
            }
        } footer: {
            if let since = ledger.oldestUnpaidMonth {
                Text("Rent has been owing since \(since.monthTitle). In Ontario you can serve Form N4 once rent is late; its termination date must be at least \(OntarioTenancyRules.n4NoticeDays) days later, and it's void if the tenant pays everything owing before then.")
            }
        }
    }

    // MARK: Actions

    private func remind() {
        Task {
            if let failure = await viewModel.sendReminder() {
                toasts.failure(.validation(failure))
            } else {
                toasts.success("Reminder sent to \(viewModel.firstName)")
            }
        }
    }
}

// MARK: - Previews

#Preview("Payments") {
    NavigationStack {
        TenantLedgerView(tenantID: "preview", container: .preview)
    }
}
