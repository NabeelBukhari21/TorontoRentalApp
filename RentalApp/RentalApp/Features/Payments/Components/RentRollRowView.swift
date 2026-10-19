//
//  RentRollRowView.swift
//  RentalApp (Purrperty)
//
//  Payments — One tenant's rent for the month: who, where, how much, and
//  where it stands.
//

import SwiftUI

extension RentStatus {

    var role: StatusRole {
        switch self {
        case .paid: .positive
        case .partial: .caution
        case .upcoming: .neutral
        case .overdue: .critical
        }
    }

    /// "Paid Oct 1", "$900 of $1,800", "Due Nov 1", "12 days late".
    func label(amountDue: Int, dueOn: Date) -> String {
        switch self {
        case .paid(let date):
            "Paid \(date.formatted(.dateTime.month(.abbreviated).day()))"
        case .partial(let paid):
            "\(paid.formatted(.cad)) of \(amountDue.formatted(.cad))"
        case .upcoming:
            "Due \(dueOn.formatted(.dateTime.month(.abbreviated).day()))"
        case .overdue(let days):
            days == 0 ? "Due today" : days == 1 ? "1 day late" : "\(days) days late"
        }
    }
}

struct RentRollRowView: View {

    let row: RentRollRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(name: row.tenantName, size: .subheadline)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.tenantName)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(row.amountDue, format: .cad)
                        .monospacedDigit()
                }

                Text("\(row.unitName) · \(row.propertyName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                statusLabels

                if let remindedAt = row.remindedAt {
                    Label("Reminded \(remindedAt.formatted(.relative(presentation: .named)))", systemImage: "bell")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusLabels: some View {
        StatusLabel(row.status.label(amountDue: row.amountDue, dueOn: row.dueOn), role: row.status.role)
            .lineLimit(1)
        if let oldest = row.arrears.first {
            StatusLabel("\(row.arrearsTotal.formatted(.cad)) owing since \(oldest.month.formatted(.dateTime.month(.abbreviated)))", role: .critical)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }
}
