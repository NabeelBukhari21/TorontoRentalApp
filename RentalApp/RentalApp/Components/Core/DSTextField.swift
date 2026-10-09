//
//  DSTextField.swift
//  RentalApp
//
//  Design System — Text input with animated focus ring, icon,
//  secure entry toggle, and inline error state.
//

import SwiftUI
import UIKit

struct DSTextField: View {

    let label: String
    let placeholder: String
    @Binding var text: String

    var icon: String? = nil
    var isSecure: Bool = false
    var errorMessage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    @FocusState private var isFocused: Bool
    @State private var isSecureVisible = false

    private var hasError: Bool { errorMessage != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Colors.textSecondary)

            HStack(spacing: DS.Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isFocused ? DS.Colors.brand : DS.Colors.textTertiary)
                }

                Group {
                    if isSecure && !isSecureVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .focused($isFocused)

                if isSecure {
                    Button {
                        isSecureVisible.toggle()
                    } label: {
                        Image(systemName: isSecureVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused || hasError ? 1.5 : 1)
            )
            .dsShadow(isFocused ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.15) : DS.Shadows.soft)
            .animation(DS.Motion.gentle, value: isFocused)
            .animation(DS.Motion.gentle, value: hasError)

            if let errorMessage {
                Label(errorMessage, systemImage: DS.Icons.warning)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.danger)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var borderColor: Color {
        if hasError { return DS.Colors.danger }
        if isFocused { return DS.Colors.brand }
        return DS.Colors.outline
    }
}

// MARK: - Previews

#Preview("Text Fields") {
    struct Demo: View {
        @State private var email = ""
        @State private var password = ""
        @State private var name = "Syed"

        var body: some View {
            ZStack {
                DS.Colors.background.ignoresSafeArea()

                VStack(spacing: DS.Spacing.xl) {
                    DSTextField(
                        label: "Email",
                        placeholder: "you@example.com",
                        text: $email,
                        icon: "envelope.fill",
                        keyboardType: .emailAddress
                    )
                    DSTextField(
                        label: "Password",
                        placeholder: "Enter your password",
                        text: $password,
                        icon: "lock.fill",
                        isSecure: true
                    )
                    DSTextField(
                        label: "Full Name",
                        placeholder: "Your name",
                        text: $name,
                        icon: "person.fill",
                        errorMessage: "This name is already taken"
                    )
                }
                .padding(DS.Spacing.xxl)
            }
        }
    }
    return Demo()
}
