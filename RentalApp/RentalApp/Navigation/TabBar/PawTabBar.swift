//
//  PawTabBar.swift
//  RentalApp (Purrperty)
//
//  Navigation — The tab bar with Properties on a glass paw in the middle.
//  Touch is the same in every design: tap a tab, or slide a finger along
//  the bar (each tab ticks as you cross it) and let go. VoiceOver and
//  Switch Control get five plain buttons.
//

import SwiftUI

struct PawTabBar: View {

    let style: PawTabStyle
    @Binding var selection: AppTab
    let model: TabBarModel

    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What the bar shows as active: the finger leads.
    private var active: AppTab { model.hovered ?? selection }

    var body: some View {
        Group {
            switch style {
            case .liquid: LiquidTabBar(active: active, isDown: model.hovered != nil, model: model)
            case .notch: NotchTabBar(active: active, isDown: model.hovered != nil, model: model)
            case .clay: ClayTabBar(active: active, isDown: model.hovered != nil, model: model)
            case .peek: PeekTabBar(active: active, isDown: model.hovered != nil, model: model)
            case .bigPaw: BigPawTabBar(active: active, isDown: model.hovered != nil, model: model)
            }
        }
        .frame(maxWidth: 460)
        .overlay { GeometryReader { proxy in touchLayer(proxy.size) } }
        .padding(.horizontal, 14)
        .padding(.bottom, -8)
    }

    // MARK: Touch

    private func touchLayer(_ size: CGSize) -> some View {
        Color.clear
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let tab = tab(at: value.location, in: size)
                        guard tab != model.hovered else { return }
                        if model.hovered != nil { feedback?.play(.scrub) } else { feedback?.play(.press) }
                        withAnimation(reduceMotion ? nil : DS.Motion.bouncy) { model.hovered = tab }
                    }
                    .onEnded { _ in
                        let tab = model.hovered
                        withAnimation(reduceMotion ? nil : DS.Motion.bouncy) {
                            model.hovered = nil
                            if let tab { selection = tab }
                        }
                        if let tab, let index = AppTab.pawOrder.firstIndex(of: tab) { feedback?.play(.select(index)) }
                    }
            )
            .accessibilityRepresentation {
                HStack {
                    ForEach(AppTab.pawOrder) { tab in
                        Button(tab.title) { selection = tab }
                            .accessibilityAddTraits(selection == tab ? .isSelected : [])
                    }
                }
            }
    }

    private func tab(at point: CGPoint, in size: CGSize) -> AppTab {
        if style == .bigPaw {
            let spots = BigPawTabBar.centers(in: size, isCollapsed: model.isCollapsed)
            return AppTab.pawOrder.min {
                hypot(spots[$0]!.x - point.x, spots[$0]!.y - point.y) < hypot(spots[$1]!.x - point.x, spots[$1]!.y - point.y)
            } ?? .properties
        }
        let index = Int(point.x / max(1, size.width) * 5)
        return AppTab.pawOrder[min(4, max(0, index))]
    }
}

/// A tab's icon (filled when active) and name.
struct TabGlyph: View {
    let tab: AppTab
    let isActive: Bool
    var size: CGFloat = 21
    var showsTitle = true
    var ink: Color = DS.Colors.textPrimary
    var activeInk: Color = DS.Colors.brandInk

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: tab.icon)
                .font(.system(size: size, weight: .bold))
                .symbolEffect(.bounce, value: isActive)
                .frame(height: size + 5)
            if showsTitle {
                Text(tab.title)
                    .font(DS.Typography.brandFixed(11, weight: isActive ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(isActive ? activeInk : ink)
    }
}
