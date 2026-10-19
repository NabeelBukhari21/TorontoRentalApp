//
//  LedgerEntryRow.swift
//  RentalApp (Purrperty)
//
//  Payments — One line of a rent account: a charge, a payment or a
//  returned payment, with the balance after it. Shared by the staff
//  ledger and the tenant portal.
//

import SwiftUI

struct LedgerEntryRow: View {

    let entry: LedgerEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let note = entry.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if entry.amount != 0 {
                    Text(amountText)
                        .monospacedDigit()
                        .foregroundStyle(entry.isPayment ? .green : .primary)
                }
                Text("Balance \(entry.balanceAfter.formatted(.cad))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var amountText: String {
        entry.amount < 0 ? "−\((-entry.amount).formatted(.cad))" : entry.amount.formatted(.cad)
    }

    private var detail: String {
        let date = entry.date.formatted(.dateTime.month(.abbreviated).day().year())
        switch entry.kind {
        case .payment(let method):
            return [date, method.rawValue, entry.reference].compactMap { $0 }.joined(separator: " · ")
        case .returned(let reason):
            return "\(date) · \(reason)"
        case .rentCharge, .feeCharge:
            return "Due \(date)"
        }
    }

    private var symbol: String {
        switch entry.kind {
        case .rentCharge: "house"
        case .feeCharge: "exclamationmark.circle"
        case .payment(let method): method.symbol
        case .returned: "arrow.uturn.backward.circle"
        }
    }

    private var tint: Color {
        switch entry.kind {
        case .rentCharge: .secondary
        case .feeCharge, .returned: .orange
        case .payment: .green
        }
    }
}
