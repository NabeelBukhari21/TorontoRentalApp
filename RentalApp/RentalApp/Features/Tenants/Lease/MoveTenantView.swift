//
//  MoveTenantView.swift
//  RentalApp (Purrperty)
//
//  Tenants — Move a tenant to another unit: which vacant unit, when, the
//  new rent, and what happens to their deposit.
//

import SwiftUI

struct MoveTenantView: View {

    @State private var viewModel: UnitTransferViewModel
    private let onMoved: (LeaseSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    init(tenantID: String, container: AppContainer, onMoved: @escaping (LeaseSummary) -> Void = { _ in }) {
        _viewModel = State(initialValue: UnitTransferViewModel(
            tenantID: tenantID,
            repository: container.tenants,
            sync: container.sync,
            analytics: container.analytics
        ))
        self.onMoved = onMoved
    }

    var body: some View {
        NavigationStack {
            Group {
                if let current = viewModel.current {
                    if viewModel.units.isEmpty {
                        ContentUnavailableView {
                            Label("No Vacant Units", symbol: .unit)
                        } description: {
                            Text("Every unit has a tenant. A unit appears here once it's vacant.")
                        }
                    } else {
                        form(current)
                    }
                } else if let error = viewModel.loadError {
                    ContentUnavailableView {
                        Label("Couldn't Load the Lease", symbol: .caution)
                    } description: {
                        Text(error)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Move to Another Unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await viewModel.load() }
        }
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
                Button("Move", systemImage: AppSymbol.done.rawValue) { submit() }
                    .disabled(!viewModel.canSubmit)
            }
        }
    }

    // MARK: Form

    private func form(_ current: LeaseSummary) -> some View {
        @Bindable var viewModel = viewModel

        return Form {
            Section("Moving From") {
                LabeledContent("Unit", value: "\(current.unitName), \(current.propertyName)")
                LabeledContent("Rent") { Text(current.rent, format: .cad) }
            }

            Section {
                NavigationLink {
                    VacantUnitPicker(groups: viewModel.unitsByProperty, selection: unitSelection)
                } label: {
                    LabeledContent("Unit", value: viewModel.target?.unitName ?? "Choose")
                }

                if let target = viewModel.target {
                    LabeledContent("Property", value: target.propertyName)
                    LabeledContent("Asking rent") { Text(target.marketRent, format: .cad) }
                }

                DatePicker("Move date", selection: $viewModel.draft.moveDate, in: (Calendar.current.date(byAdding: .day, value: 1, to: current.start) ?? current.start)..., displayedComponents: .date)
            } header: {
                Text("Moving To")
            } footer: {
                if let target = viewModel.target {
                    Text("The lease on \(current.unitName) ends on \(viewModel.currentLeaseEnds.formatted(date: .abbreviated, time: .omitted)), and a 12-month lease on \(target.unitName) starts on \(viewModel.draft.moveDate.formatted(date: .abbreviated, time: .omitted)).")
                }
            }

            Section {
                AmountField("Monthly rent", amount: $viewModel.draft.rent)
            } header: {
                Text("New Rent")
            } footer: {
                Text("A move is a new lease on the new unit, so the rent starts at its asking rent. You can change it.")
            }

            Section {
                Toggle("Carry over rent deposit", isOn: $viewModel.draft.carriesDeposit)
            } footer: {
                Text(depositFooter(current))
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, symbol: .caution)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    /// What happens to the last month's rent deposit, which in Ontario
    /// can't be more than one month's rent.
    private func depositFooter(_ current: LeaseSummary) -> String {
        let rent = viewModel.draft.rent
        guard viewModel.draft.carriesDeposit else {
            return "Refund the \(current.deposit.formatted(.cad)) deposit and collect a new one. In Ontario a deposit can only cover the last month's rent."
        }
        let carriedInFull = "The \(current.deposit.formatted(.cad)) last month's rent deposit moves to the new lease."
        // Nothing to compare against until there's a new rent.
        guard rent > 0 else { return carriedInFull }
        let (carried, refund) = OntarioTenancyRules.carriedDeposit(current.deposit, newRent: rent)
        if refund > 0 {
            return "\(carried.formatted(.cad)) of the \(current.deposit.formatted(.cad)) deposit moves to the new lease. Refund the \(refund.formatted(.cad)) difference, because a deposit can't be more than one month's rent."
        }
        if rent > current.deposit {
            return "The \(current.deposit.formatted(.cad)) deposit moves to the new lease. You can ask the tenant to top it up to \(rent.formatted(.cad)), one month's new rent."
        }
        return carriedInFull
    }

    private var unitSelection: Binding<String?> {
        Binding(
            get: { viewModel.draft.targetUnitID },
            set: { viewModel.selectUnit(id: $0) }
        )
    }

    // MARK: Actions

    private func submit() {
        Task {
            if let lease = await viewModel.submit() {
                onMoved(lease)
                toasts.success("Moving to \(lease.unitName) on \(lease.start.formatted(date: .abbreviated, time: .omitted))")
                dismiss()
            }
        }
    }
}

// MARK: - Unit Picker

/// Vacant units under their property's name, like Settings' list pickers:
/// a checkmark on the choice, and back to the form once one is picked.
private struct VacantUnitPicker: View {

    let groups: [(property: String, units: [VacantUnit])]
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(groups, id: \.property) { group in
                Section(group.property) {
                    ForEach(group.units) { unit in
                        Button {
                            selection = unit.id
                            dismiss()
                        } label: {
                            HStack {
                                LabeledContent {
                                    Text(unit.marketRent, format: .cad)
                                } label: {
                                    Text(unit.unitName)
                                    Text(unit.bedrooms == 0 ? "Studio" : "\(unit.bedrooms) bd")
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                                    .opacity(selection == unit.id ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(.rect)
                        }
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(selection == unit.id ? .isSelected : [])
                    }
                }
            }
        }
        .navigationTitle("Vacant Units")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#Preview("Move tenant") {
    MoveTenantView(tenantID: "preview", container: .preview)
}
