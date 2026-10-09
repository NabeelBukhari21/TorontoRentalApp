//
//  DSFormField.swift
//  RentalApp (RentOS)
//
//  Components — A validated form field.
//
//  Wraps `DSTextField` and binds it to a `Field`, so validation state,
//  touched-tracking, and error display are wired once rather than in
//  every form. The important behaviour is in `onFocusChange`: the error
//  appears when the user *leaves* the field, not while they are still
//  typing into it.
//

import SwiftUI

struct DSFormField: View {

    let title: String
    let field: Field
    var placeholder: String = ""
    var icon: String? = nil
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    /// Appends "Optional" to the label so a blank field doesn't read as
    /// something the user forgot.
    var isOptional: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Text(title.uppercased()).dsOverline()
                if isOptional {
                    Text("OPTIONAL")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .kerning(0.8)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            DSTextField(
                label: "",
                placeholder: placeholder,
                text: Binding(
                    get: { field.value },
                    set: { field.value = $0 }
                ),
                icon: icon,
                errorMessage: field.displayedError,
                keyboardType: keyboard,
                textContentType: contentType
            )
            .focused($isFocused)
            .onChange(of: isFocused) { wasFocused, nowFocused in
                // Mark touched on blur only. Marking on focus would flash
                // "required" the instant the user tapped in.
                if wasFocused && !nowFocused {
                    field.markTouched()
                }
            }
        }
        .animation(DS.Motion.gentle, value: field.displayedError)
    }
}

// MARK: - Stepper Field

/// Numeric field with increment controls, for counts a user nudges
/// rather than types (bedrooms, bathrooms, floors).
struct DSStepperField: View {

    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...20
    var suffix: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title.uppercased()).dsOverline()

            HStack(spacing: DS.Spacing.md) {
                stepButton("minus", enabled: value > range.lowerBound) {
                    value = max(range.lowerBound, value - 1)
                }

                Text(suffix.map { "\(value) \($0)" } ?? "\(value)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .frame(minWidth: 56)
                    .contentTransition(.numericText())

                stepButton("plus", enabled: value < range.upperBound) {
                    value = min(range.upperBound, value + 1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Colors.outline, lineWidth: 1)
            )
            .animation(DS.Motion.snappy, value: value)
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? DS.Colors.brand : DS.Colors.textTertiary)
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(enabled ? DS.Colors.brand.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(DSPressStyle(scale: 0.88))
        .disabled(!enabled)
    }
}

// MARK: - Previews

#Preview("Form Fields") {
    struct Demo: View {
        @State private var beds = 2
        private let name = Field(rules: [.required("Name"), .minLength(2, "Name")])
        private let email = Field(rules: [.email])

        var body: some View {
            ZStack {
                DSAmbientBackground()
                VStack(spacing: DS.Spacing.lg) {
                    DSFormField(title: "Name", field: name, placeholder: "Queen West Lofts")
                    DSFormField(title: "Email", field: email, placeholder: "you@example.com",
                                keyboard: .emailAddress, isOptional: true)
                    DSStepperField(title: "Bedrooms", value: $beds, range: 0...8)
                }
                .padding(DS.Spacing.xl)
            }
        }
    }
    return Demo()
}
