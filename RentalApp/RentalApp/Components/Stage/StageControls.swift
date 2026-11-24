//
//  StageControls.swift
//  RentalApp (Purrperty)
//
//  Components/Stage — What goes on Purr's counter: the main button, the
//  quiet one under it, fields, and soft panels.
//

import SwiftUI

/// A stage's one main action.
struct StageButton: View {
    let title: String
    var isEnabled = true
    var isLoading = false
    var isProminent = false
    let action: () -> Void

    private var palette: (fill: Color, edge: Color, ink: Color) {
        guard isEnabled else { return (DS.Colors.surfaceSecondary, DS.Colors.track, DS.Colors.textSecondary) }
        return isProminent
            ? (DS.Colors.brand, DS.Colors.brandDeep, DS.Colors.textOnBrand)
            : (DS.Colors.textPrimary, DS.Colors.textSecondary, DS.Colors.background)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(palette.ink)
                } else {
                    HStack(spacing: 8) {
                        Text(title).lineLimit(1).minimumScaleFactor(0.7)
                        Image(systemName: "chevron.forward").font(.system(size: 15, weight: .heavy))
                    }
                    .id(title)
                    .transition(.blurReplace)
                }
            }
            .font(DS.Typography.brand(20, weight: .semibold, relativeTo: .headline))
            .foregroundStyle(palette.ink)
            .padding(.horizontal, 30)
            .frame(minWidth: 180, minHeight: 56)
            .background(Capsule().fill(.clay(palette.fill, shade: palette.edge, size: 56)))
            .sheen(isOn: isEnabled && !isLoading)
        }
        .buttonStyle(PressableDepthStyle(edge: palette.edge))
        .shadow(color: DS.Colors.groundShadow, radius: 12, y: 10)
        .jelly(on: isEnabled)
        .disabled(!isEnabled || isLoading)
        .animation(DS.Motion.bouncy, value: isEnabled)
        .padding(.bottom, 4)
    }
}

/// A text-only action under the main one.
struct StageLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(DS.Typography.brand(.subheadline, weight: .semibold))
            .foregroundStyle(DS.Colors.brandInk)
            .frame(minHeight: 40)
            .buttonStyle(SquishStyle(scale: 0.95))
    }
}

extension View {
    /// The look of a field or row on the counter.
    func stageField(isFocused: Bool = false, hasError: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        return padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(shape.fill(DS.Colors.surface.shadow(.inner(color: DS.Colors.groundShadow.opacity(0.5), radius: 3, y: 2))))
            .overlay(shape.strokeBorder(hasError ? DS.Colors.danger : isFocused ? DS.Colors.brand : .clear, lineWidth: 2))
            .animation(DS.Motion.snappy, value: isFocused)
    }

    /// A soft card on the counter.
    func stagePanel() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(DS.Colors.surface))
    }
}

/// A text field with an icon.
struct StageField: View {
    let symbol: String
    let prompt: String
    @Binding var text: String
    var error: String? = nil

    @FocusState private var isFocused: Bool
    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(DS.Colors.brandInk)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                TextField(prompt, text: $text)
                    .font(DS.Typography.brand(.body))
                    .multilineTextAlignment(.leading)
                    .focused($isFocused)
            }
            .stageField(isFocused: isFocused, hasError: error != nil)
            .contentShape(.rect)
            .onTapGesture { isFocused = true }
            if let error {
                Label(error, symbol: .caution)
                    .font(DS.Typography.brand(.footnote))
                    .foregroundStyle(DS.Colors.danger)
            }
        }
        .onChange(of: isFocused) { _, focused in if focused { feedback?.play(.focus) } }
    }
}

/// Answers as cards, two to a row when there are more than three. Plays
/// each answer's own note.
struct StageAnswers: View {
    let choices: [OnboardingChoice]
    @Environment(\.feedback) private var feedback
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let isCompact = choices.count > 3 && !typeSize.isAccessibilitySize
        VStack(spacing: 12) {
            ForEach(choices.rows(of: isCompact ? 2 : 1), id: \.first?.id) { row in
                HStack(spacing: 12) {
                    ForEach(row) { OnboardingAnswerCard(choice: $0, isCompact: isCompact) }
                }
            }
        }
        .onChange(of: choices.map(\.isSelected)) { old, new in
            guard old.count == new.count else { return }
            if let index = new.indices.first(where: { new[$0] && !old[$0] }) { feedback?.play(.select(index)) }
        }
    }
}

/// A big number with clay minus and plus keys.
struct StageStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String

    var body: some View {
        HStack {
            key("minus", enabled: value > range.lowerBound) { value -= 1 }
            VStack(spacing: 0) {
                Text(value, format: .number)
                    .font(DS.Typography.brand(52))
                    .contentTransition(.numericText(value: Double(value)))
                    .monospacedDigit()
                Text(label)
                    .font(DS.Typography.brand(.footnote, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(DS.Colors.textPrimary)
            key("plus", enabled: value < range.upperBound) { value += 1 }
        }
        .stagePanel()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value.formatted())
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }

    private func key(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(DS.Motion.bouncy, action) } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(enabled ? DS.Colors.textOnAccent : DS.Colors.textTertiary)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.clay(enabled ? DS.Colors.accentGold : DS.Colors.surfaceSecondary, shade: DSAccent.gold.ink, size: 60)))
        }
        .buttonStyle(PressableDepthStyle(edge: enabled ? DSAccent.gold.ink : DS.Colors.track, depth: 5))
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
    }
}
