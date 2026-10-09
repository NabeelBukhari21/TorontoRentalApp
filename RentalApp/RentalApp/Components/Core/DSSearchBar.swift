//
//  DSSearchBar.swift
//  RentalApp
//
//  Design System — Search bar with focus glow and animated clear button.
//

import SwiftUI

struct DSSearchBar: View {

    @Binding var text: String
    var placeholder: String = "Search"

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icons.search)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isFocused ? DS.Colors.brand : DS.Colors.textTertiary)

            TextField(placeholder, text: $text)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)
                .focused($isFocused)
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    withAnimation(DS.Motion.snappy) { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(
                    isFocused ? DS.Colors.brand.opacity(0.5) : DS.Colors.outline,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .dsShadow(isFocused ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.12) : DS.Shadows.soft)
        .animation(DS.Motion.gentle, value: isFocused)
        .animation(DS.Motion.snappy, value: text.isEmpty)
    }
}

#Preview("Search Bar") {
    struct Demo: View {
        @State private var query = ""

        var body: some View {
            ZStack {
                DSAmbientBackground()
                DSSearchBar(text: $query, placeholder: "Search properties…")
                    .padding(DS.Spacing.xxl)
            }
        }
    }
    return Demo()
}
