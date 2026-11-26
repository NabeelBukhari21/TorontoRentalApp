//
//  PawTabBar.swift
//  RentalApp (Purrperty)
//
//  Navigation — The tab bar: a glass bar with a dip, where Properties sits
//  on a glass paw. A drop of cherry liquid flows to the tab you choose,
//  paw prints walk there with it, and in the middle it fills the paw. The
//  bar shrinks and the paw rocks as the screen scrolls.
//
//  Tap a tab, or slide a finger along the bar (each tab ticks as you cross
//  it) and let go. VoiceOver and Switch Control get five plain buttons.
//

import SwiftUI

struct PawTabBar: View {

    /// Room a screen leaves for it.
    static let height: CGFloat = 88

    @Binding var selection: AppTab
    let model: TabBarModel

    @State private var walk: (from: Int, to: Int) = (2, 2)
    @State private var steps = 0
    @Environment(\.feedback) private var feedback
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What the bar shows as active: the finger leads.
    private var active: AppTab { model.hovered ?? selection }
    private var index: Int { AppTab.pawOrder.firstIndex(of: active) ?? 2 }
    private var isOnPaw: Bool { active == .properties }

    var body: some View {
        ZStack(alignment: .top) {
            NotchedBar(dip: isOnPaw ? 52 : 44)
                .fill(.clear)
                .glassEffect(.regular, in: NotchedBar(dip: isOnPaw ? 52 : 44))
                .shadow(color: DS.Colors.groundShadow, radius: 18, y: 8)
                .frame(height: model.isCollapsed ? 54 : 66)
                .padding(.top, 22)

            LiquidDrop(position: CGFloat(index), energy: model.energy, lift: isOnPaw ? 1 : 0)
                .frame(height: 140)
                .padding(.top, -34)
                .offset(y: model.isCollapsed ? -6 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            prints.frame(height: 66).padding(.top, 22)

            HStack(spacing: 0) {
                ForEach(AppTab.pawOrder) { tab in
                    if tab == .properties {
                        paw.frame(maxWidth: .infinity)
                    } else {
                        TabGlyph(tab: tab, isActive: active == tab, showsTitle: !model.isCollapsed && active != tab, activeInk: DS.Colors.textOnBrand)
                            .scaleEffect(active == tab ? 1.12 : 1)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 22)
                            .frame(height: model.isCollapsed ? 76 : 88)
                    }
                }
            }
        }
        .frame(height: Self.height, alignment: .top)
        .animation(reduceMotion ? nil : DS.Motion.bouncy, value: active)
        .frame(maxWidth: 460)
        .overlay { GeometryReader { proxy in touchLayer(proxy.size) } }
        .padding(.horizontal, 14)
        .padding(.bottom, -8)
        .onChange(of: index) { old, new in
            walk = (old, new)
            steps += 1
        }
    }

    // MARK: Paw

    private var paw: some View {
        let shape = PawShape(spread: isOnPaw ? 1 : model.hovered != nil ? 0.4 : 0)
        return shape
            .fill(.clear)
            .frame(width: 76, height: 72)
            .glassEffect(.regular.tint(isOnPaw ? .clear : DS.Colors.brand.opacity(colorScheme == .dark ? 0.6 : 0.28)), in: shape)
            .overlay {
                Image(systemName: AppTab.properties.icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(isOnPaw || colorScheme == .dark ? DS.Colors.textOnBrand : DS.Colors.brandInk)
                    .symbolEffect(.bounce, value: isOnPaw)
                    .offset(y: 15)
            }
            .shadow(color: DS.Colors.brand.opacity(isOnPaw ? 0.4 : 0.15), radius: isOnPaw ? 16 : 8, y: 6)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(model.energy) * 14))
            .scaleEffect(model.isCollapsed ? 0.86 : 1)
            .offset(y: (isOnPaw ? -14 : -10) + (reduceMotion ? 0 : model.energy * 5))
    }

    /// Prints from the old tab to the new, one after another, then fading.
    private var prints: some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / 5
            let count = 5
            ForEach(0..<count, id: \.self) { i in
                let p = CGFloat(i + 1) / CGFloat(count + 1)
                let x = (CGFloat(walk.from) + (CGFloat(walk.to - walk.from)) * p + 0.5) * cell
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Colors.brand)
                    .rotationEffect(.degrees(walk.to > walk.from ? 90 : -90))
                    .position(x: x, y: 12 + (i.isMultiple(of: 2) ? 0 : 9))
                    .keyframeAnimator(initialValue: 0.0, trigger: steps) { [reduceMotion] view, v in
                        view.opacity(reduceMotion ? 0 : v)
                    } keyframes: { _ in
                        LinearKeyframe(0, duration: Double(i) * 0.05)
                        CubicKeyframe(0.9, duration: 0.08)
                        LinearKeyframe(0.9, duration: 0.22)
                        CubicKeyframe(0, duration: 0.35)
                    }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Touch

    private func touchLayer(_ size: CGSize) -> some View {
        Color.clear
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let tab = tab(at: value.location.x, width: size.width)
                        guard tab != model.hovered else { return }
                        feedback?.play(model.hovered == nil ? .tabPress : .scrub)
                        model.hovered = tab
                    }
                    .onEnded { value in
                        let tab = model.hovered
                        model.hovered = nil
                        // Dragged well off the bar: never mind.
                        guard let tab, value.location.y > -70 else { return }
                        selection = tab
                        feedback?.play(.tabSelect)
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

    private func tab(at x: CGFloat, width: CGFloat) -> AppTab {
        AppTab.pawOrder[min(4, max(0, Int(x / max(1, width) * 5)))]
    }
}

// MARK: - Liquid

/// A drop of cherry liquid that flows along the bar.
private struct LiquidDrop: View {
    var position: CGFloat
    let energy: CGFloat
    var lift: CGFloat

    var body: some View {
        Goo(position: position, energy: energy, lift: lift)
    }

    /// The drop. Between tabs it stretches, necks and snaps together; in
    /// the middle it swells into a paw.
    private struct Goo: View {
        var position: CGFloat
        let energy: CGFloat
        var lift: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// The surface wobbles while the drop travels or the page scrolls,
        /// then settles: a bar wobbling at 60 fps on every screen kept the
        /// whole app busy.
        @State private var isLive = true
        @State private var nudges = 0

        var body: some View {
            Drops(head: position, lift: lift, energy: energy, isLive: isLive && !reduceMotion)
                .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.72), value: position)
                .onChange(of: position) { wake() }
                .onChange(of: energy) { wake() }
                .task { wake() }
        }

        private func wake() {
            nudges += 1
            let turn = nudges
            isLive = true
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                if nudges == turn { isLive = false }
            }
        }
    }

    private struct Drops: View, Animatable {
        var head: CGFloat
        var lift: CGFloat
        /// Where the drop sits, down the bar: on a tab, and in the paw.
        private static let tabCenter: CGFloat = 89, pawCenter: CGFloat = 76
        let energy: CGFloat
        let isLive: Bool

        nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
            get { AnimatablePair(head, lift) }
            set { head = newValue.first; lift = newValue.second }
        }

        var body: some View {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !isLive)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Rectangle()
                    .fill(LinearGradient(colors: [DS.Colors.accentBlush, DS.Colors.brand, DS.Colors.brandDeep], startPoint: .top, endPoint: .bottom))
                    .mask {
                        Canvas { canvas, size in
                            canvas.liquidLayer(color: .black, blur: 7) { layer in
                                let cell = size.width / 5
                                let x = (head + 0.5) * cell
                                // Between tabs the drop stretches and thins.
                                let between = 0.5 - abs(head - head.rounded())
                                let stretch = (0.5 - between) * 2
                                let r: CGFloat = 25 + lift * 13 - stretch * 5
                                let y = Self.tabCenter - lift * (Self.tabCenter - Self.pawCenter)
                                layer.fill(.wobblyCircle(center: CGPoint(x: x, y: y), radius: r, time: t, amount: 0.05 + abs(energy) * 0.12), with: .color(.black))
                                layer.fill(.wobblyCircle(center: CGPoint(x: x - stretch * cell * 0.5, y: y + 5), radius: r * 0.72, time: t + 3, amount: 0.06), with: .color(.black))
                                layer.fill(.wobblyCircle(center: CGPoint(x: x + stretch * cell * 0.5, y: y + 5), radius: r * 0.72, time: t + 6, amount: 0.06), with: .color(.black))
                                // Scrolling shakes a bead loose.
                                let bead = CGPoint(x: x + sin(t * 3) * 10, y: y - energy * 34)
                                layer.fill(Path(ellipseIn: CGRect(x: bead.x - 7, y: bead.y - 7, width: 14, height: 14)), with: .color(.black))
                                if lift > 0.01 {
                                    for bean in PawShape.beans {
                                        let c = CGPoint(x: x + (bean.x - 0.5) * 84 * lift, y: y + (bean.y - 0.62) * 84 * lift)
                                        layer.fill(Path(ellipseIn: CGRect(x: c.x - 11 * lift, y: c.y - 14 * lift, width: 22 * lift, height: 28 * lift)), with: .color(.black))
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Glyph

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
