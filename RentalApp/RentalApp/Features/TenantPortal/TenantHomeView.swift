//
//  TenantHomeView.swift
//  RentalApp (Purrperty)
//
//  Tenant Portal — Home: is my rent paid, when is it next due, how do I
//  pay, what's happening with my repairs, and how do I reach my landlord.
//

import SwiftUI

struct TenantHomeView: View {

    let viewModel: TenantPortalViewModel
    @Binding var selectedTab: TenantPortalView.PortalTab
    let onReportProblem: () -> Void

    var body: some View {
        List {
            if let ledger = viewModel.ledger {
                rentSection(ledger)
            }
            if let account = viewModel.account {
                howToPaySection(account.landlord)
            }
            requestsSection
            if let lease = viewModel.lease {
                leaseSection(lease)
            }
            if let account = viewModel.account {
                contactSection(account.landlord)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Hi, \(viewModel.firstName)")
        .navigationSubtitle(viewModel.lease.map { "\($0.unitName) · \($0.propertyName)" } ?? "")
        .refreshable { await viewModel.load() }
    }

    // MARK: Rent

    private func rentSection(_ ledger: TenantLedger) -> some View {
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
            if let due = viewModel.nextRentDue {
                LabeledContent("Next rent") {
                    Text("\(ledger.monthlyRent.formatted(.cad)) on \(due.formatted(.dateTime.month(.abbreviated).day()))")
                        .monospacedDigit()
                }
            }
            Button("See Payments", systemImage: "list.bullet.rectangle") { selectedTab = .payments }
        } header: {
            Text("Rent")
        } footer: {
            if let since = ledger.oldestUnpaidMonth {
                Text("Rent has been owing since \(since.monthTitle). If you've already paid, it may not be recorded yet. Message your landlord to check.")
            }
        }
    }

    private func howToPaySection(_ landlord: LandlordContact) -> some View {
        Section {
            LabeledContent("Interac e-Transfer to") {
                Text(landlord.eTransferEmail)
                    .textSelection(.enabled)
            }
        } header: {
            Text("How to Pay")
        } footer: {
            Text("Put your unit number in the message. Your landlord records your payment when it arrives, and you can get a receipt for it from Payments.")
        }
    }

    // MARK: Requests

    private var requestsSection: some View {
        Section {
            if viewModel.openRequests.isEmpty {
                Text("No open requests.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.openRequests.prefix(3)) { ticket in
                    NavigationLink {
                        TenantRequestDetailView(ticket: ticket, tracker: viewModel.visitTracker)
                    } label: {
                        TenantRequestRow(ticket: ticket)
                    }
                }
                if viewModel.openRequests.count > 3 {
                    Button("See All \(viewModel.openRequests.count)") { selectedTab = .requests }
                }
            }
            Button("Report a Problem", systemImage: AppSymbol.add.rawValue, action: onReportProblem)
        } header: {
            Text("Repairs")
        }
    }

    // MARK: Lease

    private func leaseSection(_ lease: LeaseSummary) -> some View {
        Section {
            LabeledContent("Home", value: "\(lease.unitName), \(lease.propertyName)")
            LabeledContent("Term", value: lease.termText)
            LabeledContent("Monthly rent") { Text(lease.rent, format: .cad) }
            LabeledContent("Last month's rent deposit") { Text(lease.deposit, format: .cad) }
        } header: {
            Text("Lease")
        } footer: {
            if viewModel.isRenewalDue {
                Text("Your lease ends soon. If you stay, it carries on month to month in Ontario; you don't have to sign a new one.")
            }
        }
    }

    // MARK: Contact

    private func contactSection(_ landlord: LandlordContact) -> some View {
        Section {
            Button("Message \(landlord.name)", systemImage: AppSymbol.messages.rawValue) { selectedTab = .messages }
            if let url = URL(string: "mailto:\(landlord.email)") {
                Link(destination: url) {
                    Label(landlord.email, systemImage: AppSymbol.email.rawValue)
                }
            }
            if let phone = landlord.phone,
               let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                Link(destination: url) {
                    Label(phone, systemImage: AppSymbol.phone.rawValue)
                }
            }
        } header: {
            Text("Your Landlord")
        }
    }
}
