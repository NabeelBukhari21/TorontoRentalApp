//
//  OnboardingComponents.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Building blocks shared by the onboarding and
//  getting-started flows: choice cards, the progress bar, the honest
//  build checklist, unlock rows and the live password checklist.
//

import SwiftUI

// MARK: - Progress

/// Goal-gradient progress (playbook §5): a filled bar plus "Step x of y".
struct OnboardingProgressBar: View {

    let progress: Double
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.Colors.track)
                    Capsule()
                        .fill(DS.Gradients.progress)
                        .frame(width: max(proxy.size.width * progress, 8))
                }
            }
            .frame(height: 8)
            .animation(DS.Motion.smooth, value: progress)

            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
                .contentTransition(.numericText())
                .animation(DS.Motion.smooth, value: label)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// MARK: - Choice Card

/// A big, colourful answer card. One accent per option so the choices
/// read as distinct (playbook §5, Von Restorff), with the brand ring
/// reserved for the selected one.
struct OnboardingChoiceCard: View {

    let icon: String
    let tint: Color
    /// Dark ink on the bright accents; pass `textOnBrand` for a brand tint.
    var iconColor: Color = DS.Colors.textOnAccent
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    /// Multi-select answers show a checkbox instead of a radio dot.
    var isMultiSelect = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 52, height: 52)
                    .background(tint, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .scaleEffect(isSelected ? 1.06 : 1)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Colors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                selectionMark
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(isSelected ? DS.Colors.brand.opacity(0.08) : DS.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(isSelected ? DS.Colors.brand : DS.Colors.outline, lineWidth: isSelected ? 2.5 : 1)
            )
            .dsShadow(isSelected ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.18) : DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle(scale: 0.97))
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectionMark: some View {
        // A rounded square for multi-select, a circle for single: the
        // same corner radius gets both, so one shape type covers them.
        let shape = RoundedRectangle(cornerRadius: isMultiSelect ? 7 : 13, style: .continuous)

        ZStack {
            shape.strokeBorder(isSelected ? DS.Colors.brand : DS.Colors.outline, lineWidth: 2)
            shape.fill(DS.Colors.brand).opacity(isSelected ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(DS.Colors.textOnBrand)
                .opacity(isSelected ? 1 : 0)
                .scaleEffect(isSelected ? 1 : 0.3)
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - Build Checklist

/// The "Building your Purrperty…" lines. Each ticks when its real work
/// finishes.
struct OnboardingBuildChecklist: View {

    let tasks: [OnboardingBuildTask]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(tasks) { task in
                HStack(spacing: DS.Spacing.md) {
                    ZStack {
                        Circle()
                            .strokeBorder(DS.Colors.outline, lineWidth: 2)
                            .opacity(task.state == .done ? 0 : 1)
                        if task.state == .running {
                            ProgressView()
                                .controlSize(.small)
                                .tint(DS.Colors.brand)
                        }
                        Circle()
                            .fill(DS.Colors.success)
                            .scaleEffect(task.state == .done ? 1 : 0.2)
                            .opacity(task.state == .done ? 1 : 0)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(DS.Colors.onFixedColor)
                            .opacity(task.state == .done ? 1 : 0)
                    }
                    .frame(width: 26, height: 26)

                    Text(task.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(task.state == .pending ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                }
                .sensoryFeedback(.success, trigger: task.state == .done)
                .accessibilityElement(children: .combine)
                .accessibilityValue(task.state == .done ? "Done" : task.state == .running ? "In progress" : "Waiting")
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(DS.Colors.outline, lineWidth: 1)
        )
        .dsShadow(DS.Shadows.card)
    }
}

// MARK: - Unlock Row

struct OnboardingUnlockRow: View {

    let unlock: OnboardingUnlock

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: unlock.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(unlock.iconColor)
                .frame(width: 44, height: 44)
                .background(unlock.tint, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(unlock.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(unlock.detail)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundStyle(DS.Colors.accentMintInk)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Colors.outline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Password Checklist

/// Each rule ticks with an animated check and a light haptic as it's met
/// (playbook §3).
struct OnboardingPasswordChecklist: View {

    let requirements: [PasswordRequirement]

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(requirements) { requirement in
                HStack(spacing: DS.Spacing.xs) {
                    ZStack {
                        Circle()
                            .strokeBorder(DS.Colors.outline, lineWidth: 1.5)
                        Circle()
                            .fill(DS.Colors.success)
                            .scaleEffect(requirement.isMet ? 1 : 0.1)
                            .opacity(requirement.isMet ? 1 : 0)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(DS.Colors.onFixedColor)
                            .opacity(requirement.isMet ? 1 : 0)
                    }
                    .frame(width: 16, height: 16)

                    Text(requirement.rule.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(requirement.isMet ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .animation(DS.Motion.bouncy, value: requirement.isMet)
                .sensoryFeedback(.impact(weight: .light), trigger: requirement.isMet) { _, met in met }
                .accessibilityElement(children: .combine)
                .accessibilityValue(requirement.isMet ? "Met" : "Not met")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Components") {
    ScrollView {
        VStack(spacing: DS.Spacing.lg) {
            OnboardingProgressBar(progress: 0.4, label: "Step 3 of 7")
            OnboardingChoiceCard(
                icon: "key.fill", tint: DS.Colors.accentSunny,
                title: "I own rentals", subtitle: "Landlord or owner",
                isSelected: true, action: {}
            )
            OnboardingChoiceCard(
                icon: "wrench.and.screwdriver.fill", tint: DS.Colors.accentCoral,
                title: "Repairs", isSelected: false, isMultiSelect: true, action: {}
            )
            OnboardingBuildChecklist(tasks: [
                .init(id: "a", title: "Saving your answers", state: .done),
                .init(id: "b", title: "Switching on your alerts", state: .running),
                .init(id: "c", title: "Preparing your dashboard")
            ])
            OnboardingUnlockRow(unlock: OnboardingHeadache.repairs.unlock)
        }
        .padding()
    }
}
