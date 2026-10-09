//
//  DSDropdown.swift
//  RentalApp
//
//  Design System — Dropdown selector built on Menu.
//  Generic over any Hashable option type.
//

import SwiftUI

struct DSDropdown<Option: Hashable>: View {

    let label: String
    let options: [Option]
    @Binding var selection: Option?
    var placeholder: String = "Select"
    let optionLabel: (Option) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Colors.textSecondary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        if selection == option {
                            Label(optionLabel(option), systemImage: "checkmark")
                        } else {
                            Text(optionLabel(option))
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selection.map(optionLabel) ?? placeholder)
                        .font(DS.Typography.body)
                        .foregroundStyle(
                            selection == nil ? DS.Colors.textTertiary : DS.Colors.textPrimary
                        )

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(DS.Colors.outline, lineWidth: 1)
                )
                .dsShadow(DS.Shadows.soft)
            }
        }
    }
}

#Preview("Dropdown") {
    struct Demo: View {
        @State private var propertyType: String?

        var body: some View {
            ZStack {
                DS.Colors.background.ignoresSafeArea()

                DSDropdown(
                    label: "Property Type",
                    options: ["Condo", "Duplex", "Triplex", "Detached", "Multi-unit"],
                    selection: $propertyType,
                    placeholder: "Choose a type"
                ) { $0 }
                .padding(DS.Spacing.xxl)
            }
        }
    }
    return Demo()
}
