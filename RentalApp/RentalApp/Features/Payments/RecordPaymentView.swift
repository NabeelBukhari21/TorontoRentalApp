//
//  RecordPaymentView.swift
//  RentalApp (Purrperty)
//
//  Payments — Record a payment received: how much, how, when, and the
//  reference that ties it to the bank or the cheque.
//

import SwiftUI

struct RecordPaymentView: View {

    @State private var viewModel: RecordPaymentViewModel
    private let onRecorded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    init(tenantID: String, month: Date, container: AppContainer, onRecorded: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: RecordPaymentViewModel(
            tenantID: tenantID,
            month: month,
            payments: container.payments,
            sync: container.sync,
            analytics: container.analytics
        ))
        self.onRecorded = onRecorded
    }

    var body: some View {
        NavigationStack {
            Group {
                if let row = viewModel.row {
                    form(row)
                } else if let error = viewModel.loadError {
                    ContentUnavailableView {
                        Label("Can't Record a Payment", symbol: .caution)
                    } description: {
                        Text(error)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await viewModel.load() }
        }
        .presentationDetents([.large])
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: AppSymbol.close.rawValue) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if viewModel.isSubmitting {
                ProgressView()
            } else {
                Button("Record", systemImage: AppSymbol.done.rawValue) { submit() }
                    .disabled(!viewModel.canSubmit)
            }
        }
    }

    // MARK: Form

    private func form(_ row: RentRollRow) -> some View {
        @Bindable var viewModel = viewModel

        return Form {
            Section {
                LabeledContent("Tenant", value: row.tenantName)
                LabeledContent("Unit", value: "\(row.unitName), \(row.propertyName)")
                LabeledContent("\(row.dueOn.monthTitle) rent") {
                    Text(row.amountDue, format: .cad)
                }
                if row.amountPaid > 0 {
                    LabeledContent("Already paid") { Text(row.amountPaid, format: .cad) }
                }
            }

            Section {
                AmountField("Amount received", amount: $viewModel.draft.amount)

                Picker("Method", selection: $viewModel.draft.method) {
                    ForEach(PaymentMethod.allCases) { method in
                        Label(method.rawValue, systemImage: method.symbol).tag(method)
                    }
                }

                DatePicker("Received", selection: $viewModel.draft.receivedOn, in: ...Date.now, displayedComponents: .date)

                TextField(viewModel.draft.method.referencePrompt, text: $viewModel.draft.reference, prompt: Text("\(viewModel.draft.method.referencePrompt) (optional)"))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            } header: {
                Text("Payment")
            } footer: {
                if viewModel.isPartial {
                    Text("\((row.outstanding - viewModel.draft.amount).formatted(.cad)) will still be owing for \(row.dueOn.monthTitle).")
                } else if viewModel.draft.amount > row.outstanding {
                    Label("That's more than the \(row.outstanding.formatted(.cad)) still owing.", symbol: .caution)
                        .foregroundStyle(.red)
                }
            }

            Section {
                TextField("Note", text: $viewModel.draft.note, prompt: Text("Note (optional)"), axis: .vertical)
                    .lineLimit(1...4)
            } footer: {
                Text("This records money you've already received. Purrperty doesn't move money.")
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, symbol: .caution)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: Actions

    private func submit() {
        Task {
            if let entry = await viewModel.submit() {
                onRecorded()
                toasts.success("Recorded \((-entry.amount).formatted(.cad)) from \(viewModel.row?.firstName ?? "tenant")")
                dismiss()
            }
        }
    }
}

// MARK: - Previews

#Preview("Record payment") {
    RecordPaymentView(tenantID: "preview", month: .now, container: .preview)
}
