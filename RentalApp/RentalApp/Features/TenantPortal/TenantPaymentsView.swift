//
//  TenantPaymentsView.swift
//  RentalApp (Purrperty)
//
//  Tenant Portal — The tenant's rent account: balance, every charge and
//  payment, and a receipt for each payment. Read-only; the landlord
//  records payments as they arrive.
//

import SwiftUI

struct TenantPaymentsView: View {

    let viewModel: TenantPortalViewModel

    var body: some View {
        Group {
            if let ledger = viewModel.ledger {
                list(ledger)
            } else {
                ContentUnavailableView("No Rent Account Yet", systemImage: AppSymbol.rent.rawValue)
            }
        }
        .navigationTitle("Payments")
        .refreshable { await viewModel.load() }
    }

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
                LabeledContent("Monthly rent") { Text(ledger.monthlyRent, format: .cad) }
                LabeledContent("Last month's rent deposit") { Text(ledger.depositHeld, format: .cad) }
            }

            Section {
                ForEach(ledger.entries) { entry in
                    LedgerEntryRow(entry: entry)
                        .swipeActions {
                            if entry.isPayment {
                                ShareLink(item: receipt(for: entry, in: ledger)) {
                                    Label("Receipt", systemImage: AppSymbol.share.rawValue)
                                }
                                .tint(.blue)
                            }
                        }
                        .contextMenu {
                            if entry.isPayment {
                                ShareLink("Share Receipt", item: receipt(for: entry, in: ledger))
                            }
                        }
                }
            } header: {
                Text("Activity")
            } footer: {
                Text("Swipe a payment for a receipt. Your landlord must give you a receipt for rent if you ask, free of charge.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func receipt(for entry: LedgerEntry, in ledger: TenantLedger) -> String {
        ledger.receipt(for: entry, issuedBy: viewModel.account?.landlord.name ?? "your landlord")
    }
}

// MARK: - Messages

/// The tenant's thread with their landlord, or how to reach them when
/// there isn't one yet.
struct TenantMessagesView: View {

    let viewModel: TenantPortalViewModel
    @Environment(\.container) private var container

    var body: some View {
        if let conversationID = viewModel.account?.conversationID, let account = viewModel.account {
            ChatView(
                conversationID: conversationID,
                perspective: .counterpart(otherName: account.landlord.name, context: "Your landlord"),
                container: container
            )
        } else if let landlord = viewModel.account?.landlord {
            ContentUnavailableView {
                Label("No Messages Yet", systemImage: AppSymbol.messages.rawValue)
            } description: {
                Text("Your landlord hasn't started a conversation with you in Purrperty yet. You can email \(landlord.email).")
            } actions: {
                if let url = URL(string: "mailto:\(landlord.email)") {
                    Link("Email \(landlord.name)", destination: url)
                }
            }
            .navigationTitle("Messages")
        }
    }
}
