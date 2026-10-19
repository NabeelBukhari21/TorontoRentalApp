//
//  AmountField.swift
//  RentalApp (Purrperty)
//
//  AppStyle — A whole-dollar amount in a form row.
//
//  A formatted `TextField(value:format:)` regroups the digits while you
//  type ("1,8|00" → "18,000"), so this edits plain digits and shows the
//  dollar sign beside them. Rent is always whole dollars.
//

import SwiftUI

struct AmountField: View {

    let title: String
    @Binding var amount: Int

    init(_ title: String, amount: Binding<Int>) {
        self.title = title
        self._amount = amount
    }

    /// Seven digits is ten million dollars, far beyond any rent.
    private static let maxDigits = 7

    private var digits: Binding<String> {
        Binding(
            get: { amount == 0 ? "" : String(amount) },
            set: { text in
                let filtered = String(text.filter(\.isNumber).prefix(Self.maxDigits))
                amount = Int(filtered) ?? 0
            }
        )
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 2) {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField(title, text: digits, prompt: Text("0"))
                    .keyboardType(.numberPad)
                    .fixedSize()
            }
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(amount.formatted(.cad))
    }
}

// MARK: - Formatting

extension FormatStyle where Self == IntegerFormatStyle<Int>.Currency {
    /// Whole Canadian dollars: "$2,340".
    static var cad: IntegerFormatStyle<Int>.Currency {
        .currency(code: "CAD").precision(.fractionLength(0))
    }
}
