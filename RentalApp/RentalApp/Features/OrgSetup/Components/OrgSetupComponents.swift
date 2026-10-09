//
//  OrgSetupComponents.swift
//  RentalApp
//
//  Org Setup — Shared wizard chrome: progress bar, step header,
//  selectable option cards, and invite chips.
//

import SwiftUI

// MARK: - Progress Bar

struct OrgSetupProgressBar: View {

    /// 0...1
    let progress: Double
    let stepIndex: Int
    let stepCount: Int

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Text("Step \(stepIndex + 1) of \(stepCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText())

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DS.Colors.brand)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.12))

                    Capsule()
                        .fill(DS.Gradients.ai)
                        .frame(width: proxy.size.width * progress)
                        .dsShadow(DS.Shadows.glow(DS.Colors.brand, intensity: 0.4))
                }
            }
            .frame(height: 6)
        }
        .animation(DS.Motion.smooth, value: progress)
    }
}

// MARK: - Step Header

struct OrgSetupStepHeader: View {

    let step: OrgSetupStep

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(step.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, RentOSBrand.champagne],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .multilineTextAlignment(.center)

            Text(step.subtitle)
                .font(DS.Typography.callout)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }
}

// MARK: - Option Card

/// Selectable glass card used for property type and portfolio size.
struct OrgOptionCard: View {

    let icon: String
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(DS.Colors.brand))
                    .frame(width: 42, height: 42)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .fill(DS.Gradients.brand)
                        } else {
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .fill(.white.opacity(0.08))
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.clear : .white.opacity(0.25),
                            lineWidth: 1.5
                        )
                        .background(
                            Circle().fill(isSelected ? AnyShapeStyle(DS.Gradients.ai) : AnyShapeStyle(Color.clear))
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [DS.Colors.brand.opacity(0.9), DS.Colors.brandViolet.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                              )
                            : AnyShapeStyle(Color.white.opacity(0.14)),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .dsShadow(
                isSelected
                    ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.3)
                    : DSShadowStyle(color: .clear, radius: 0, y: 0)
            )
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(DSPressStyle())
        .animation(DS.Motion.bouncy, value: isSelected)
    }
}

// MARK: - Invite Chip

struct OrgInviteChip: View {

    let email: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            DSAvatar(name: email, size: .small)

            Text(email)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(DSPressStyle(scale: 0.85))
            .accessibilityLabel("Remove \(email)")
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs + 2)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}
