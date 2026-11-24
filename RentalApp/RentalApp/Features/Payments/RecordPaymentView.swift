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
                if let receipt = viewModel.receipt {
                    RentJarView(receipt: receipt) { dismiss() }
                        .transition(.opacity)
                } else if let row = viewModel.row {
                    form(row)
                } else if let error = viewModel.loadError {
                    ContentUnavailableView {
                        PurrLabel("Can't Record a Payment", mood: .error)
                    } description: {
                        Text(error)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(viewModel.receipt == nil ? "Record Payment" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await viewModel.load() }
        }
        .sakugaScreen()
        .presentationDetents([.large])
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if viewModel.receipt == nil {
            formToolbar
        }
    }

    @ToolbarContentBuilder
    private var formToolbar: some ToolbarContent {
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
                    PurrLabel("That's more than the \(row.outstanding.formatted(.cad)) still owing.", mood: .error)
                        .foregroundStyle(.red)
                }
            }

            Section("Method") {
                ForEach(PaymentMethod.allCases) { method in
                    Button { viewModel.draft.method = method } label: {
                        HStack(spacing: 12) {
                            Label(method.rawValue, systemImage: method.symbol).foregroundStyle(DS.Colors.textPrimary)
                            Spacer()
                            SakugaRadioMark(isOn: viewModel.draft.method == method, size: 26)
                        }
                    }
                    .accessibilityAddTraits(viewModel.draft.method == method ? .isSelected : [])
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
                if viewModel.receipt == nil {
                    toasts.success("Recorded \((-entry.amount).formatted(.cad)) from \(viewModel.row?.firstName ?? "tenant")", mood: .paymentSuccess)
                }
                // The jar says it better than a toast; it has its own Done.
                if viewModel.receipt == nil { dismiss() }
            }
        }
    }
}

// MARK: - Previews

#Preview("Record payment") {
    RecordPaymentView(tenantID: "preview", month: .now, container: .preview)
}
