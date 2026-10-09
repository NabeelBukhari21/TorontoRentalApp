//
//  MFAChallengeView.swift
//  RentalApp (RentOS)
//
//  Auth — Second factor. Six segmented digit boxes backed by one
//  hidden field, auto-submitting on the last digit.
//
//  Present now, in full, even though the mock provider only enrolls one
//  demo account: MFA changes the *shape* of sign-in (credentials no
//  longer produce a session directly), and retrofitting that branch
//  later would mean reworking the flow container, the session machine,
//  and every call site. Building it now costs one screen.
//

import SwiftUI

struct MFAChallengeView: View {

    let challenge: MFAChallenge
    let session: SessionViewModel

    @State private var code = ""
    @State private var isResending = false
    @FocusState private var isFocused: Bool

    private var digits: Int { challenge.digitCount }

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            AuthHeader(
                title: "Verify it's you",
                subtitle: challenge.hint.map { "\(challenge.method.instruction) \($0)" }
                    ?? challenge.method.instruction
            )
            .dsEntrance(index: 0)

            AuthCard {
                VStack(spacing: DS.Spacing.lg) {
                    codeBoxes

                    if let error = session.mfaError {
                        Text(error)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(DS.Colors.danger)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    DSButton(
                        title: "Verify",
                        variant: .primary,
                        size: .large,
                        isFullWidth: true,
                        isLoading: session.isVerifyingMFA
                    ) {
                        submit()
                    }
                    .disabled(code.count < digits)

                    Button {
                        resend()
                    } label: {
                        HStack(spacing: DS.Spacing.xs + 2) {
                            if isResending {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(DS.Colors.brand)
                            }
                            Text(isResending ? "Sending…" : "Send a new code")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.Colors.brand)
                        }
                    }
                    .buttonStyle(DSPressStyle(scale: 0.95))
                    .disabled(isResending)
                }
            }
            .dsEntrance(index: 1)
            .animation(DS.Motion.gentle, value: session.mfaError)

            AuthFooterLink(prompt: "Wrong account?", actionTitle: "Sign in again") {
                session.cancelMFA()
            }
            .dsEntrance(index: 2)
        }
        .onAppear { isFocused = true }
    }

    // MARK: Code Entry

    /// One hidden text field drives every box. Six real fields would
    /// mean six focus states and manual backspace handling — this keeps
    /// the system keyboard and one-time-code autofill working.
    private var codeBoxes: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0.001)
                .frame(height: 1)
                .onChange(of: code) { _, newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(digits))
                    if filtered != newValue { code = filtered }
                    if filtered.count == digits { submit() }
                }

            HStack(spacing: DS.Spacing.sm + 2) {
                ForEach(0..<digits, id: \.self) { index in
                    DigitBox(
                        character: character(at: index),
                        isActive: isFocused && index == code.count
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
        }
    }

    private func character(at index: Int) -> String? {
        guard index < code.count else { return nil }
        return String(Array(code)[index])
    }

    // MARK: Actions

    private func submit() {
        guard code.count == digits, !session.isVerifyingMFA else { return }
        isFocused = false
        Task { await session.verifyMFA(code: code) }
    }

    private func resend() {
        isResending = true
        code = ""
        Task {
            await session.resendMFACode()
            isResending = false
            isFocused = true
        }
    }
}

// MARK: - Digit Box

private struct DigitBox: View {

    let character: String?
    let isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(
                        isActive ? RentOSBrand.gold.opacity(0.8) : Color.white.opacity(0.14),
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
            .overlay(
                Text(character ?? "")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            )
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .dsShadow(
                isActive ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.25) : DS.Shadows.soft
            )
            .scaleEffect(character == nil ? 1 : 1.03)
            .animation(DS.Motion.bouncy, value: character)
            .animation(DS.Motion.gentle, value: isActive)
    }
}
