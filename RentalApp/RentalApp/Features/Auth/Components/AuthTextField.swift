//
//  AuthTextField.swift
//  RentalApp
//
//  Auth — Dark glass text field with a floating label, animated
//  validation states, secure-entry toggle, and shake-on-error.
//

import SwiftUI

// MARK: - Shake Effect

/// Horizontal shake driven by an incrementing trigger value.
struct DSShakeEffect: GeometryEffect {

    var travel: CGFloat = 7
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travel * sin(animatableData * .pi * shakesPerUnit * 2),
                y: 0
            )
        )
    }
}

// MARK: - Auth Text Field

struct AuthTextField: View {

    let label: String
    @Binding var text: String
    var icon: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var error: String? = nil
    /// Shows an animated checkmark when true (e.g. live email validity).
    var showsValidCheck: Bool = false
    var shakeTrigger: Int = 0

    @FocusState private var isFocused: Bool
    @State private var isPasswordVisible = false

    private var isFloating: Bool { isFocused || !text.isEmpty }
    private var hasError: Bool { error != nil }
    private var showsCheck: Bool { showsValidCheck && !hasError && !text.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)

                ZStack(alignment: .leading) {
                    // Floating label.
                    Text(label)
                        .font(.system(
                            size: isFloating ? 11 : 15.5,
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundStyle(labelColor)
                        .offset(y: isFloating ? -15 : 0)

                    // Input.
                    Group {
                        if isSecure && !isPasswordVisible {
                            SecureField("", text: $text)
                        } else {
                            TextField("", text: $text)
                        }
                    }
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(DS.Colors.brand)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
                    .autocorrectionDisabled(keyboardType == .emailAddress || isSecure)
                    .focused($isFocused)
                    .offset(y: isFloating ? 7 : 0)
                    .opacity(isFloating ? 1 : 0)
                }
                .animation(DS.Motion.snappy, value: isFloating)

                // Trailing affordances.
                if isSecure {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.45))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                }

                if showsCheck {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(DS.Colors.success)
                        .transition(.scale.combined(with: .opacity))
                }

                if hasError {
                    Image(systemName: DS.Icons.warning)
                        .font(.system(size: 15))
                        .foregroundStyle(DS.Colors.danger)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(.white.opacity(isFocused ? 0.10 : 0.06))
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(borderStyle, lineWidth: isFocused || hasError ? 1.5 : 1)
            )
            .dsShadow(
                isFocused
                    ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.2)
                    : DSShadowStyle(color: .clear, radius: 0, y: 0)
            )
            .animation(DS.Motion.gentle, value: isFocused)
            .animation(DS.Motion.snappy, value: hasError)
            .animation(DS.Motion.snappy, value: showsCheck)

            // Animated error message.
            if let error {
                Label(error, systemImage: DS.Icons.warning)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.Colors.danger)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .modifier(DSShakeEffect(animatableData: CGFloat(shakeTrigger)))
        .animation(DS.Motion.gentle, value: error)
    }

    // MARK: Styling

    private var iconColor: Color {
        if hasError { return DS.Colors.danger }
        return isFocused ? DS.Colors.brand : .white.opacity(0.45)
    }

    private var labelColor: Color {
        if hasError { return DS.Colors.danger.opacity(0.9) }
        if isFocused { return DS.Colors.brand }
        return .white.opacity(0.5)
    }

    private var borderStyle: AnyShapeStyle {
        if hasError {
            return AnyShapeStyle(DS.Colors.danger.opacity(0.8))
        }
        if isFocused {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [DS.Colors.brand.opacity(0.85), DS.Colors.accentAmber.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.white.opacity(0.14))
    }
}

// MARK: - Password Strength Meter

struct AuthPasswordStrengthMeter: View {

    /// 0...1
    let strength: Double

    private var filledSegments: Int {
        strength <= 0 ? 0 : max(1, Int(ceil(strength * 4)))
    }

    private var tint: Color {
        switch strength {
        case ..<0.35: DS.Colors.danger
        case ..<0.6: DS.Colors.accentAmber
        case ..<0.85: DS.Colors.brandCyan
        default: DS.Colors.success
        }
    }

    private var caption: String {
        switch strength {
        case ..<0.01: ""
        case ..<0.35: "Weak"
        case ..<0.6: "Fair"
        case ..<0.85: "Good"
        default: "Strong"
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < filledSegments ? tint : Color.white.opacity(0.12))
                    .frame(height: 4)
            }

            Text(caption)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 44, alignment: .trailing)
                .contentTransition(.opacity)
        }
        .animation(DS.Motion.smooth, value: filledSegments)
    }
}

// MARK: - Previews

#Preview("Auth Fields") {
    struct Demo: View {
        @State private var email = "syed@example.com"
        @State private var password = "Secret123!"
        @State private var broken = ""

        var body: some View {
            ZStack {
                SplashBackground()

                VStack(spacing: DS.Spacing.xl) {
                    AuthTextField(
                        label: "Email",
                        text: $email,
                        icon: "envelope.fill",
                        keyboardType: .emailAddress,
                        showsValidCheck: true
                    )
                    AuthTextField(
                        label: "Password",
                        text: $password,
                        icon: "lock.fill",
                        isSecure: true
                    )
                    AuthPasswordStrengthMeter(strength: 0.8)
                    AuthTextField(
                        label: "Confirm password",
                        text: $broken,
                        icon: "lock.fill",
                        isSecure: true,
                        error: "Passwords don't match"
                    )
                }
                .padding(DS.Spacing.xxl)
            }
            .environment(\.colorScheme, .dark)
        }
    }
    return Demo()
}
