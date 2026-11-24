//
//  WardrobeView.swift
//  RentalApp (Purrperty)
//
//  Wardrobe — Purr in front of the mirror: try on what's been earned, and
//  see what earns the rest.
//

import SwiftUI

struct WardrobeView: View {

    let wardrobe: WardrobeStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.feedback) private var feedback

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LivingPurr(mood: wardrobe.worn.mood ?? .welcome, size: 260, beat: wardrobe.worn)
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .center) {
                        LiquidBlobs(color: DS.Colors.accentGold.opacity(0.5), blobs: [
                            .init(x: 0.5, y: 0.5, r: 0.25, phase: 0), .init(x: 0.2, y: 0.4, r: 0.1, phase: 2), .init(x: 0.82, y: 0.5, r: 0.12, phase: 4),
                        ])
                    }
                Text(wardrobe.worn.title)
                    .font(DS.Typography.brand(.title2, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .contentTransition(.opacity)
                Text("\(wardrobe.earned.count) of \(PurrOutfit.allCases.count) earned")
                    .font(DS.Typography.brand(.subheadline, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(PurrOutfit.allCases.enumerated()), id: \.element) { index, outfit in
                            tile(outfit, index: index)
                        }
                    }
                    .padding(16)
                }
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous)
                        .fill(DS.Colors.background)
                        .ignoresSafeArea()
                }
            }
            .background(LinearGradient(colors: [DS.Colors.accentGold.opacity(0.35), DS.Colors.accentGold.opacity(0.1)], startPoint: .top, endPoint: .center).ignoresSafeArea())
            .navigationTitle("Purr's wardrobe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: AppSymbol.done.rawValue) { dismiss() }
                }
            }
        }
    }

    private func tile(_ outfit: PurrOutfit, index: Int) -> some View {
        let isEarned = wardrobe.earned.contains(outfit)
        let isWorn = wardrobe.worn == outfit
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        return Button {
            feedback?.play(.select(index % 5))
            withAnimation(DS.Motion.bouncy) { wardrobe.worn = outfit }
        } label: {
            VStack(spacing: 4) {
                if isEarned {
                    PurrMascot(mood: outfit.mood ?? .welcome, size: 76, isInteractive: false)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title2.bold())
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(height: 76)
                }
                Text(outfit.title)
                    .font(DS.Typography.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(outfit.milestone)
                    .font(DS.Typography.brand(.caption, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
            .background(shape.fill(isWorn ? DS.Colors.accentGold.mix(with: DS.Colors.background, by: 0.75) : DS.Colors.surface)
                .strokeBorder(isWorn ? DS.Colors.accentGold : .clear, lineWidth: 3))
        }
        .buttonStyle(SquishStyle(scale: 0.95))
        .disabled(!isEarned)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(outfit.title). \(outfit.milestone)")
        .accessibilityValue(isEarned ? (isWorn ? "Wearing" : "Earned") : "Locked")
        .accessibilityAddTraits(isWorn ? [.isButton, .isSelected] : .isButton)
    }
}
