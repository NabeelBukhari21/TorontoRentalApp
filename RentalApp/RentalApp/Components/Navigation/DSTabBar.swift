//
//  DSTabBar.swift
//  RentalApp
//
//  Navigation — Custom floating glass tab bar with a sliding
//  selection indicator (matched geometry) and press feedback.
//

import SwiftUI

struct DSTabBar: View {

    @Binding var selectedTab: AppTab
    var onReselect: ((AppTab) -> Void)? = nil

    /// Bottom padding content should add so it clears the floating bar.
    static let overlayClearance: CGFloat = 104

    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(DS.Gradients.glassHighlight, lineWidth: 1)
        )
        .dsShadow(DS.Shadows.floating)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.sm)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = tab == selectedTab

        return Button {
            if isSelected {
                onReselect?(tab)
            } else {
                withAnimation(DS.Motion.smooth) {
                    selectedTab = tab
                }
            }
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? AnyShapeStyle(DS.Gradients.brand)
                            : AnyShapeStyle(DS.Colors.textTertiary)
                    )
                    .symbolEffect(.bounce, value: isSelected)

                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? DS.Colors.brand : DS.Colors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background {
                if isSelected {
                    Capsule()
                        .fill(DS.Colors.brand.opacity(0.12))
                        .matchedGeometryEffect(id: "ds.tabbar.indicator", in: indicatorNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(DSPressStyle(scale: 0.92))
        .accessibilityLabel(tab.title)
    }
}

#Preview("Tab Bar") {
    struct Demo: View {
        @State private var tab: AppTab = .dashboard

        var body: some View {
            ZStack(alignment: .bottom) {
                DSAmbientBackground()
                DSTabBar(selectedTab: $tab)
            }
        }
    }
    return Demo()
}
