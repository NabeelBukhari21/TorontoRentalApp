//
//  OnboardingAnswers.swift
//  RentalApp (Purrperty)
//
//  Onboarding — The three ways an answer looks: a card on the counter, a
//  3D key, and a bubble floating around Purr.
//

import SwiftUI

// MARK: - Card

/// A white answer card with a clay icon; picked, it lifts and turns to
/// its own colour.
struct OnboardingAnswerCard: View {
    let choice: OnboardingChoice
    var isCompact = false

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Big enough that the words need to wrap.
    private var isLarge: Bool { typeSize > .xLarge }

    var body: some View {
        Button(action: choice.select) {
            HStack(spacing: isLarge && isCompact ? 8 : 12) {
                ClayToken(symbol: choice.symbol, accent: choice.accent, size: isCompact ? 42 : 48)
                    .shadow(color: DS.Colors.groundShadow, radius: 4, y: 4)
                    .rotationEffect(.degrees(choice.isSelected ? -10 : 0))
                    .scaleEffect(choice.isSelected ? 1.15 : 1)
                    .background { DropletBurst(isOn: choice.isSelected, color: choice.accent.fill, radius: 54) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(choice.title)
                        .font(DS.Typography.brand(isCompact ? 17 : 20, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .minimumScaleFactor(0.8).lineLimit(isLarge ? nil : isCompact && choice.subtitle.isEmpty ? 2 : 1)
                    if !choice.subtitle.isEmpty {
                        Text(choice.subtitle).font(DS.Typography.brand(.footnote, weight: .regular)).foregroundStyle(DS.Colors.textSecondary).lineLimit(isLarge ? nil : isCompact ? 2 : 1).minimumScaleFactor(0.75)
                    }
                }
                Spacer(minLength: 0)
                if !isCompact {
                    SakugaRadioMark(isOn: choice.isSelected, size: 26)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, typeSize.isAccessibilitySize ? 14 : isLarge ? 9 : 0)
            .frame(minHeight: isCompact ? 66 : 72)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(choice.isSelected ? choice.accent.fill.mix(with: DS.Colors.background, by: 0.78) : DS.Colors.surface)
                    .strokeBorder(choice.isSelected ? choice.accent.fill : .clear, lineWidth: 3)
            }
            .overlay(alignment: .topTrailing) {
                if isCompact && choice.isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.title3)
                        .foregroundStyle(DS.Colors.background, choice.accent.ink)
                        .offset(x: 4, y: -6).transition(.scale)
                }
            }
        }
        .buttonStyle(PressableDepthStyle(edge: choice.isSelected ? choice.accent.fill : DS.Colors.track, depth: 4, shape: .init(cornerRadius: 24, style: .continuous)))
        .jelly(on: choice.isSelected, strength: isCompact ? 0.5 : 0.3)
        .zIndex(choice.isSelected ? 1 : 0)
        .accessibilityAddTraits(choice.isSelected ? .isSelected : [])
    }
}

// MARK: - Key

/// A big soft key. Picked, it stays pressed in and glows its colour.
struct OnboardingAnswerKey: View {
    let choice: OnboardingChoice

    var body: some View {
        Button(action: choice.select) {
            VStack(spacing: 6) {
                Image(systemName: choice.symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(choice.isSelected ? choice.accent.onFill : choice.accent.ink)
                    .symbolEffect(.bounce, value: choice.isSelected)
                Text(choice.title)
                    .font(DS.Typography.brand(17, weight: .semibold, relativeTo: .headline))
                    .multilineTextAlignment(.center).minimumScaleFactor(0.75).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !choice.subtitle.isEmpty {
                    Text(choice.subtitle).font(DS.Typography.brand(.caption)).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(choice.isSelected ? choice.accent.onFill : DS.Colors.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 92)
            .fixedSize(horizontal: false, vertical: true)
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.clay(choice.isSelected ? choice.accent.fill : DS.Colors.surfaceRaised, shade: choice.accent.ink, size: 80)))
            .offset(y: choice.isSelected ? 6 : 0)
        }
        .buttonStyle(PressableDepthStyle(edge: choice.accent.ink, depth: 9))
        .shadow(color: .black.opacity(0.16), radius: 10, y: 12)
        .background { DropletBurst(isOn: choice.isSelected, color: choice.accent.fill, radius: 82) }
        .jelly(on: choice.isSelected)
        .zIndex(choice.isSelected ? 1 : 0)
        .accessibilityAddTraits(choice.isSelected ? .isSelected : [])
    }
}

// MARK: - Bubble

/// A glossy ball with a highlight and a shadow under it.
struct BubbleShape: View {
    let color: Color
    let shade: Color
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(.clay(color, shade: shade, size: diameter * 0.9))
            .overlay(alignment: .topLeading) {
                Ellipse().fill(.white.opacity(0.85))
                    .frame(width: diameter * 0.24, height: diameter * 0.13)
                    .rotationEffect(.degrees(-34))
                    .blur(radius: 1.5)
                    .offset(x: diameter * 0.15, y: diameter * 0.12)
            }
            .frame(width: diameter, height: diameter)
            .shadow(color: DS.Colors.groundShadow, radius: diameter * 0.12, y: diameter * 0.12)
    }
}

/// An answer in a bubble; picked, it swells and fills.
struct OnboardingAnswerBubble: View {
    let choice: OnboardingChoice
    let diameter: CGFloat

    var body: some View {
        Button(action: choice.select) {
            ZStack {
                BubbleShape(color: choice.isSelected ? choice.accent.fill : DS.Colors.surfaceRaised, shade: choice.accent.ink, diameter: diameter)
                VStack(spacing: 4) {
                    Image(systemName: choice.symbol)
                        .font(.system(size: diameter * 0.24, weight: .bold))
                        .foregroundStyle(choice.isSelected ? choice.accent.onFill : choice.accent.ink)
                        .symbolEffect(.bounce, value: choice.isSelected)
                    Text(choice.title)
                        .font(DS.Typography.brand(15, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(choice.isSelected ? choice.accent.onFill : DS.Colors.textPrimary)
                        .multilineTextAlignment(.center).minimumScaleFactor(0.8).lineLimit(2)
                }
                .padding(diameter * 0.12)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(choice.isSelected ? 1.1 : 1)
        }
        .buttonStyle(SquishStyle(scale: 0.88, cue: .press))
        .contentShape(.circle)
        .background { DropletBurst(isOn: choice.isSelected, color: choice.accent.fill, radius: diameter * 0.82) }
        .jelly(on: choice.isSelected)
        .accessibilityHint(choice.subtitle)
        .accessibilityAddTraits(choice.isSelected ? .isSelected : [])
    }
}
