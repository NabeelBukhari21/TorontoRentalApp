//
//  DSAccentPicker.swift
//  RentalApp (Purrperty)
//
//  Components — A row of accent swatches. Shared by onboarding's
//  "Make it yours" step and Settings → Appearance, so the choice looks
//  and behaves the same in both places.
//

import SwiftUI
import UIKit

struct DSAccentPicker: View {

    @Binding var selection: AccentTheme
    var swatchSize: CGFloat = 52

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(AccentTheme.allCases) { accent in
                swatch(accent)
                    .frame(maxWidth: .infinity)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func swatch(_ accent: AccentTheme) -> some View {
        let isSelected = selection == accent

        return Button {
            withAnimation(DS.Motion.bouncy) { selection = accent }
        } label: {
            VStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(accent.swatch)
                        .frame(width: swatchSize, height: swatchSize)

                    Circle()
                        .strokeBorder(accent.brand, lineWidth: 3)
                        .frame(width: swatchSize + 10, height: swatchSize + 10)
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1 : 0.8)

                    Image(systemName: "checkmark")
                        .font(.system(size: swatchSize * 0.34, weight: .heavy))
                        .foregroundStyle(DS.Colors.textOnAccent)
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1 : 0.4)
                }
                .frame(width: swatchSize + 10, height: swatchSize + 10)

                Text(accent.title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            }
        }
        .buttonStyle(DSPressStyle(scale: 0.92))
        .accessibilityLabel("\(accent.title) accent")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var accent = AccentTheme.violet
    DSAccentPicker(selection: $accent)
        .padding()
}
