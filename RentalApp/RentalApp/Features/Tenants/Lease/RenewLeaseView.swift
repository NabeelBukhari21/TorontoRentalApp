//
//  RenewLeaseView.swift
//  RentalApp (Purrperty)
//
//  Tenants — Renew a lease: a new fixed term or month-to-month, the new
//  rent, and where that rent sits under Ontario's rules.
//

import SwiftUI

struct RenewLeaseView: View {

    @State private var viewModel: LeaseRenewalViewModel
    private let onRenewed: (LeaseSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    init(tenantID: String, container: AppContainer, onRenewed: @escaping (LeaseSummary) -> Void = { _ in }) {
        _viewModel = State(initialValue: LeaseRenewalViewModel(
            tenantID: tenantID,
            repository: container.tenants,
            sync: container.sync,
            analytics: container.analytics
        ))
        self.onRenewed = onRenewed
    }

    var body: some View {
        NavigationStack {
            Group {
                if let current = viewModel.current {
                    form(current)
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
            .navigationTitle("Renew Lease")
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
                Button("Renew", systemImage: AppSymbol.done.rawValue) { submit() }
                    .disabled(!viewModel.canSubmit)
            }
        }
    }

    // MARK: Form

    private func form(_ current: LeaseSummary) -> some View {
        @Bindable var viewModel = viewModel

        return Form {
            Section("Current Lease") {
                LabeledContent("Unit", value: "\(current.unitName), \(current.propertyName)")
                LabeledContent("Term", value: current.termText)
                LabeledContent("Rent") { Text(current.rent, format: .cad) }
            }

            Section {
                Picker("Term", selection: $viewModel.kind.animation()) {
                    ForEach(LeaseTermKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("New Term")
            }

            Section {
                DatePicker("Starts", selection: $viewModel.start, displayedComponents: .date)

                if viewModel.kind == .fixedTerm {
                    Picker("Length", selection: $viewModel.lengthMonths) {
                        ForEach(LeaseRenewalViewModel.lengthOptions, id: \.self) { months in
                            Text("\(months) months").tag(months)
                        }
                    }
                    LabeledContent("Ends") {
                        Text(viewModel.end, format: .dateTime.day().month(.abbreviated).year())
                    }
                }
            } footer: {
                if viewModel.kind == .monthToMonth {
                    Text("In Ontario a tenancy carries on month to month when a fixed term ends, so the tenant doesn't have to sign anything new.")
                }
            }

            rentSection(current)

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, symbol: .caution)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: Rent

    private func rentSection(_ current: LeaseSummary) -> some View {
        @Bindable var viewModel = viewModel

        return Section {
            AmountField("Monthly rent", amount: $viewModel.rent)

            if viewModel.change != 0 {
                LabeledContent("Change") {
                    Text("\(viewModel.change > 0 ? "+" : "−")\(abs(viewModel.change).formatted(.cad)) (\(viewModel.changePercent.formatted(.number.precision(.fractionLength(1))))%)")
                        .monospacedDigit()
                }
            }

            if let maximum = viewModel.guidelineMaximum, viewModel.rent != maximum {
                Button("Use Guideline Maximum (\(maximum.formatted(.cad)))") {
                    viewModel.useGuidelineMaximum()
                }
            }
        } header: {
            Text("Rent")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                guidelineFooter
                if viewModel.isNoticeLate {
                    Label(
                        "To raise the rent from \(viewModel.start.formatted(date: .abbreviated, time: .omitted)), written notice was due by \(viewModel.noticeDeadline.formatted(date: .abbreviated, time: .omitted)). Choose a later start date.",
                        symbol: .caution
                    )
                    .foregroundStyle(.orange)
                } else if viewModel.change > 0 {
                    Text("Give the tenant written notice (Form N1) by \(viewModel.noticeDeadline.formatted(date: .abbreviated, time: .omitted)), at least \(OntarioTenancyRules.increaseNoticeDays) days before the increase.")
                }
            }
        }
    }

    @ViewBuilder
    private var guidelineFooter: some View {
        switch viewModel.guidelineStatus {
        case .exempt:
            Text("This building was first lived in after 15 November 2018, so Ontario's rent-increase guideline doesn't apply.")
        case .noIncrease:
            EmptyView()
        case .within(let percent, let year):
            Text("Within Ontario's \(String(year)) guideline of \(percent.formatted())%.")
        case .above(let percent, let year):
            Label(
                "Above Ontario's \(String(year)) guideline of \(percent.formatted())%. An increase above the guideline needs approval from the Landlord and Tenant Board.",
                symbol: .caution
            )
            .foregroundStyle(.red)
        case .unknown(let year):
            Text("Purrperty doesn't have Ontario's \(String(year)) guideline yet. Check it on ontario.ca before sending notice.")
        }
    }

    // MARK: Actions

    private func submit() {
        Task {
            if let renewed = await viewModel.submit() {
                onRenewed(renewed)
                toasts.success("Lease renewed: \(renewed.termText)")
                dismiss()
            }
        }
    }
}

// MARK: - Previews

#Preview("Renew lease") {
    RenewLeaseView(tenantID: "preview", container: .preview)
}
