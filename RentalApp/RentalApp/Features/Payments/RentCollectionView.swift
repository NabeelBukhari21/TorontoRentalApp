//
//  RentCollectionView.swift
//  RentalApp (Purrperty)
//
//  Payments — The rent roll. How much of the month's rent is in, who
//  still owes, and the two things to do about it: record a payment that
//  arrived, or send a reminder.
//

import SwiftUI

/// Reads the container from the environment for the navigation module.
struct RentCollectionRoot: View {
    @Environment(\.container) private var container

    var body: some View {
        RentCollectionView(container: container)
    }
}

struct RentCollectionView: View {

    @State private var viewModel: RentCollectionViewModel
    @State private var recordTarget: RentRollRow?
    @State private var reminderTarget: RentRollRow?

    @Environment(\.container) private var container
    @Environment(\.toasts) private var toasts

    init(container: AppContainer) {
        _viewModel = State(initialValue: RentCollectionViewModel(
            payments: container.payments,
            reminders: RentReminderSender(
                messages: container.messages,
                payments: container.payments,
                analytics: container.analytics
            )
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            summarySection

            Section {
                SakugaTabs(values: RentCollectionViewModel.Filter.allCases, title: \.rawValue, selection: $viewModel.filter)
                .padding(.vertical, 18)
                .padding(.trailing, 5)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            rowsSection
        }
        .listStyle(.insetGrouped)
        .overlay { overlay }
        .searchable(text: $viewModel.searchText, prompt: "Tenant, unit or property")
        .navigationTitle("Rent")
        .navigationSubtitle(viewModel.month.monthTitle)
        .toolbar { toolbar }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(item: $recordTarget) { row in
            RecordPaymentView(tenantID: row.tenantID, month: row.oldestOwingMonth ?? viewModel.roll.month, container: container) {
                Task { await viewModel.load() }
            }
        }
        .confirmationDialog(
            "Send a reminder to \(reminderTarget?.firstName ?? "")?",
            isPresented: Binding(get: { reminderTarget != nil }, set: { if !$0 { reminderTarget = nil } }),
            titleVisibility: .visible,
            presenting: reminderTarget
        ) { row in
            Button("Send Reminder") { remind(row) }
            Button("Cancel", role: .cancel) {}
        } message: { row in
            Text(viewModel.reminderText(for: row))
        }
    }

    // MARK: Summary

    private var summarySection: some View {
        let roll = viewModel.roll

        return Section {
            PurrNote(
                mood: roll.owingCount > 0 ? .rentDue : (roll.collectionRate >= 1 ? .moneyDance : .paymentHistory),
                text: roll.owingCount > 0
                    ? "\(roll.owingCount) \(roll.owingCount == 1 ? "tenant owes" : "tenants owe") rent."
                    : (roll.collectionRate >= 1 ? "All of this month's rent is in!" : "No rent is overdue.")
            )
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Collected") {
                    Text("\(roll.collected.formatted(.cad)) of \(roll.expected.formatted(.cad))")
                        .monospacedDigit()
                }
                ProgressView(value: roll.collectionRate)
                    .tint(.green)
                    .accessibilityLabel("Collected")
                    .accessibilityValue(roll.collectionRate.formatted(.percent.precision(.fractionLength(0))))
            }
            LabeledContent("Due this month, unpaid") {
                Text(roll.outstanding, format: .cad)
                    .monospacedDigit()
                    .foregroundStyle(roll.outstanding > 0 ? .red : .secondary)
            }
            LabeledContent {
                Text(roll.arrears, format: .cad)
                    .monospacedDigit()
                    .foregroundStyle(roll.arrears > 0 ? .red : .secondary)
            } label: {
                HStack(spacing: 0) {
                    Text("Owing from earlier months")
                    SakugaHint(text: "Ontario doesn't allow late fees on rent. A returned payment can cost a tenant up to $20, and unpaid rent starts with an N4 notice.")
                }
            }
            LabeledContent("Tenants owing", value: roll.owingCount, format: .number)
        } footer: {
            Text("Purrperty records rent you've received; it doesn't move money. Ontario doesn't allow late fees on rent.")
        }
    }

    // MARK: Rows

    @ViewBuilder
    private var rowsSection: some View {
        let rows = viewModel.visibleRows
        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    NavigationLink(value: AppRoute.tenantLedger(tenantID: row.tenantID)) {
                        RentRollRowView(row: row)
                    }
                    .swipeActions(edge: .trailing) { actions(for: row) }
                    .contextMenu { actions(for: row) }
                }
            } header: {
                Text("\(rows.count) \(rows.count == 1 ? "tenant" : "tenants")")
            }
        } else if !viewModel.isLoading, viewModel.loadError == nil {
            // A row, not an overlay: it must not cover the summary.
            Section {
                ContentUnavailableView {
                    if viewModel.searchText.isEmpty {
                        PurrLabel("Nothing Here", mood: .paymentHistory)
                    } else {
                        PurrLabel("No Results for \u{201C}\(viewModel.searchText)\u{201D}", mood: .noResults)
                    }
                } description: {
                    Text(viewModel.searchText.isEmpty
                        ? "No rent is \(viewModel.filter == .paid ? "paid" : "listed") for \(viewModel.month.monthTitle) with this filter."
                        : "Check the spelling or try a new search.")
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private func actions(for row: RentRollRow) -> some View {
        if row.isOwing {
            Button("Record Payment", systemImage: "checkmark.circle") { recordTarget = row }
                .tint(.green)
        }
        if viewModel.canRemind(row) {
            Button("Send Reminder", systemImage: "bell") { reminderTarget = row }
                .tint(.orange)
        } else if viewModel.canShareReminder(row) {
            ShareLink(item: viewModel.reminderText(for: row)) {
                Label("Share Reminder", systemImage: "bell")
            }
            .tint(.orange)
        }
    }

    // MARK: Overlay

    @ViewBuilder
    private var overlay: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if let error = viewModel.loadError {
            ContentUnavailableView {
                PurrLabel("Couldn't Load Rent", mood: .error)
            } description: {
                Text(error.errorDescription ?? "")
            } actions: {
                Button("Try Again") { Task { await viewModel.load() } }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var viewModel = viewModel

        ToolbarItem(placement: .topBarTrailing) {
            Menu("Month", systemImage: AppSymbol.calendar.rawValue) {
                Picker("Month", selection: $viewModel.month) {
                    ForEach(viewModel.monthOptions, id: \.self) { month in
                        Text(month.monthTitle).tag(month)
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func remind(_ row: RentRollRow) {
        Task {
            if let failure = await viewModel.sendReminder(to: row) {
                toasts.failure(.validation(failure))
            } else {
                toasts.success("Reminder sent to \(row.firstName)", mood: .messageSent)
            }
        }
    }
}

// MARK: - Previews

#Preview("Rent") {
    NavigationStack {
        RentCollectionView(container: .preview)
    }
}
