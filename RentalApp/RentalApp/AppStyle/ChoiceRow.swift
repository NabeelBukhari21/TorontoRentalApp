//
//  ChoiceRow.swift
//  RentalApp (Purrperty)
//
//  AppStyle — One answer in a choice list: a Settings-style icon tile,
//  title, optional subtitle, and a checkmark (single choice) or filled
//  circle (multi-select) when selected. Used by onboarding, sign-up's
//  role choice and workspace setup.
//

import SwiftUI


/// One answer in a choice list: icon tile, title, optional subtitle and a
/// checkmark when selected — the same pattern as a Settings picker row.
struct ChoiceRow: View {

    let symbol: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    /// Multi-select answers use a filled circle; single-select a checkmark.
    var isMultiSelect = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SymbolTile(systemName: symbol, color: tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }

                Spacer(minLength: 8)

                selectionMark
            }
            .contentShape(.rect)
        }
        .frame(minHeight: 44)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectionMark: some View {
        if isMultiSelect {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(uiColor: .tertiaryLabel)))
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
        } else if isSelected {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .transition(.symbolEffect(.appear))
                .accessibilityHidden(true)
        }
    }
}
