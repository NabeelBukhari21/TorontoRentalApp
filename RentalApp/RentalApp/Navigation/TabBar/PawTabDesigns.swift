//
//  PawTabDesigns.swift
//  RentalApp (Purrperty)
//
//  Navigation — The five tab bar designs. Each only draws: what's active,
//  whether a finger is down, and how the screen is scrolling come in.
//

import SwiftUI

// MARK: - A · Liquid drop

/// A drop of cherry liquid lives inside a glass pill. It pulls apart from
/// one tab and flows into the next, and swells up into the paw.
struct LiquidTabBar: View {
    let active: AppTab
    let isDown: Bool
    let model: TabBarModel

    private var index: CGFloat { CGFloat(AppTab.pawOrder.firstIndex(of: active) ?? 2) }

    var body: some View {
        let height: CGFloat = model.isCollapsed ? 54 : 68
        ZStack {
            Capsule().fill(.clear)
                .glassEffect(.regular, in: .capsule)
                .shadow(color: DS.Colors.groundShadow, radius: 16, y: 8)
                .frame(height: height)
            Goo(position: index, energy: model.energy, lift: active == .properties ? 1 : 0)
                .frame(height: 140)
                .allowsHitTesting(false)
            HStack(spacing: 0) {
                ForEach(AppTab.pawOrder) { tab in
                    ZStack {
                        if tab == .properties {
                            PawShape(spread: active == tab ? 1 : 0)
                                .fill(.clear)
                                .glassEffect(.regular.tint(active == tab ? .clear : DS.Colors.brand.opacity(0.16)), in: PawShape(spread: active == tab ? 1 : 0))
                                .frame(width: 66, height: 62)
                                .overlay {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(active == tab ? DS.Colors.textOnBrand : DS.Colors.brandInk)
                                        .offset(y: 13)
                                }
                                .scaleEffect(active == tab ? 1.1 : model.isCollapsed ? 0.86 : 1)
                                .offset(y: active == tab ? -14 : -4)
                        } else {
                            TabGlyph(tab: tab, isActive: active == tab, showsTitle: !model.isCollapsed && active != tab, activeInk: DS.Colors.textOnBrand)
                                .scaleEffect(active == tab ? 1.15 : 1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 78)
        .animation(DS.Motion.bouncy, value: active)
    }

    /// Two circles chasing one another: the second lags, so the drop
    /// stretches, necks and snaps together.
    private struct Goo: View {
        var position: CGFloat
        let energy: CGFloat
        var lift: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            ZStack {
                Drops(head: position, tail: position, lift: lift, energy: energy, reduceMotion: reduceMotion)
                    .animation(.spring(response: 0.42, dampingFraction: 0.72), value: position)
            }
        }
    }

    private struct Drops: View, Animatable {
        var head: CGFloat
        var tail: CGFloat
        var lift: CGFloat
        let energy: CGFloat
        let reduceMotion: Bool

        nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
            get { AnimatablePair(head, lift) }
            set { head = newValue.first; lift = newValue.second }
        }

        var body: some View {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
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
                                let y = size.height / 2 - lift * 12
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

// MARK: - B · Paw cradle

/// A glass bar with a dip; the glass paw floats in it. Choosing a tab
/// walks paw prints along the bar to it.
struct NotchTabBar: View {
    let active: AppTab
    let isDown: Bool
    let model: TabBarModel

    @State private var walk: (from: Int, to: Int) = (2, 2)
    @State private var steps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var index: Int { AppTab.pawOrder.firstIndex(of: active) ?? 2 }

    var body: some View {
        ZStack(alignment: .top) {
            NotchedBar(dip: active == .properties ? 52 : 44)
                .fill(.clear)
                .glassEffect(.regular, in: NotchedBar(dip: active == .properties ? 52 : 44))
                .shadow(color: DS.Colors.groundShadow, radius: 18, y: 8)
                .frame(height: model.isCollapsed ? 54 : 66)
                .padding(.top, 22)

            prints.frame(height: 66).padding(.top, 22)

            HStack(spacing: 0) {
                ForEach(AppTab.pawOrder) { tab in
                    if tab == .properties {
                        paw.frame(maxWidth: .infinity)
                    } else {
                        TabGlyph(tab: tab, isActive: active == tab, showsTitle: !model.isCollapsed, activeInk: tab.accent.ink)
                            .offset(y: active == tab ? -3 : 0)
                            .scaleEffect(active == tab ? 1.12 : 1)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 22)
                            .frame(height: model.isCollapsed ? 76 : 88)
                    }
                }
            }
        }
        .frame(height: 88, alignment: .top)
        .animation(DS.Motion.bouncy, value: active)
        .onChange(of: index) { old, new in
            walk = (old, new)
            steps += 1
        }
    }

    private var paw: some View {
        let isActive = active == .properties
        return PawShape(spread: isActive ? 1 : isDown ? 0.4 : 0)
            .fill(.clear)
            .frame(width: 76, height: 72)
            .glassEffect(.regular.tint(DS.Colors.brand.opacity(isActive ? 0.85 : 0.3)).interactive(), in: PawShape(spread: isActive ? 1 : isDown ? 0.4 : 0))
            .overlay {
                Image(systemName: AppTab.properties.icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(isActive ? DS.Colors.textOnBrand : DS.Colors.brandInk)
                    .symbolEffect(.bounce, value: isActive)
                    .offset(y: 15)
            }
            .shadow(color: DS.Colors.brand.opacity(isActive ? 0.45 : 0.15), radius: isActive ? 16 : 8, y: 6)
            .rotationEffect(.degrees(Double(model.energy) * 16))
            .scaleEffect(isActive ? 1.1 : model.isCollapsed ? 0.82 : 1)
            .offset(y: (isActive ? -20 : -16) + model.energy * 5)
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
}

// MARK: - C · Clay keys

/// Five clay keys that press in. Each has its own colour; the middle one
/// is a moulded paw. A wave runs through them as you scroll.
struct ClayTabBar: View {
    let active: AppTab
    let isDown: Bool
    let model: TabBarModel

    private var index: Int { AppTab.pawOrder.firstIndex(of: active) ?? 2 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(AppTab.pawOrder.enumerated()), id: \.element) { i, tab in
                key(tab, i)
                    .frame(maxWidth: .infinity)
                    // Neighbours lean away from a press, and scrolling
                    // rolls through them.
                    .offset(y: wave(i))
                    .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(Double(i) * 0.03), value: model.energy)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .padding(.bottom, 13)
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(DS.Colors.surfaceRaised.opacity(0.35))
                .glassEffect(.regular, in: .rect(cornerRadius: 34))
                .shadow(color: DS.Colors.groundShadow, radius: 18, y: 10)
        }
        .scaleEffect(model.isCollapsed ? 0.86 : 1, anchor: .bottom)
        .frame(height: 84, alignment: .bottom)
        .animation(DS.Motion.bouncy, value: active)
    }

    private func wave(_ i: Int) -> CGFloat { model.energy * 9 * sin(CGFloat(i) * 1.3 + 0.6) }

    private func key(_ tab: AppTab, _ i: Int) -> some View {
        let isActive = active == tab
        let isPaw = tab == .properties
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let fill = isActive || isPaw ? tab.accent.fill : DS.Colors.surfaceRaised
        let ink = isActive || isPaw ? tab.accent.onFill : DS.Colors.textPrimary

        return ZStack {
            if isPaw {
                // A glass paw set into the key.
                let paw = PawShape(spread: isActive ? 0.8 : 0)
                paw.fill(.clear)
                    .frame(width: 80, height: 76)
                    .glassEffect(.regular.tint(DS.Colors.brand.opacity(isActive ? 0.95 : 0.8)), in: paw)
                    .background(paw.fill(DS.Colors.brandDeep).offset(y: isActive ? 2 : 6))
                    .overlay { Image(systemName: tab.icon).font(.system(size: 19, weight: .bold)).foregroundStyle(ink).offset(y: 15) }
                    .offset(y: isActive ? -4 : -10)
            } else {
                TabGlyph(tab: tab, isActive: isActive, size: 19, ink: ink, activeInk: ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(shape.fill(.clay(fill, shade: tab.accent.ink, size: 54)))
                    .background(shape.fill(isActive ? tab.accent.ink : DS.Colors.track).offset(y: isActive ? 1 : 6))
                    .offset(y: isActive ? 5 : 0)
            }
        }
        .frame(height: 60)
        .scaleEffect(x: isActive ? 1.06 : 1, y: isActive ? 0.97 : 1, anchor: .bottom)
        .background { DropletBurst(isOn: isActive && !isDown, color: tab.accent.fill, radius: 52) }
    }
}

// MARK: - D · Purr on patrol

/// Purr himself rides the bar: he trots to the tab you pick and acts it
/// out, ducks when you scroll down, and peeks back up.
struct PeekTabBar: View {
    let active: AppTab
    let isDown: Bool
    let model: TabBarModel

    @State private var isRunning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var index: CGFloat { CGFloat(AppTab.pawOrder.firstIndex(of: active) ?? 2) }

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                let cell = proxy.size.width / 5
                // Behind the glass: only his top half shows.
                PurrMascot(mood: isRunning || abs(model.energy) > 0.5 ? .zoomies : active.purrMood, size: 116, isInteractive: false)
                    .scaleEffect(x: 1, y: 1 - abs(model.energy) * 0.12, anchor: .bottom)
                    .rotationEffect(.degrees(Double(model.energy) * 6))
                    .position(x: (index + 0.5) * cell, y: model.isCollapsed ? 30 : -16)
                    .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.75), value: index)
            }
            .frame(height: 82)
            .mask { Rectangle().padding(.top, -90).padding(.bottom, 20) }

            RoundedRectangle(cornerRadius: 33, style: .continuous).fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 33))
                .shadow(color: DS.Colors.groundShadow, radius: 18, y: 8)
                .frame(height: model.isCollapsed ? 54 : 66)

            HStack(spacing: 0) {
                ForEach(AppTab.pawOrder) { tab in
                    ZStack {
                        if tab == .properties {
                            PawShape(spread: active == tab ? 0.8 : 0)
                                .fill(.clear)
                                .frame(width: 64, height: 60)
                                .glassEffect(.regular.tint(DS.Colors.brand.opacity(active == tab ? 0.9 : 0.4)), in: PawShape(spread: active == tab ? 0.8 : 0))
                                .overlay {
                                    Image(systemName: tab.icon).font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(active == tab ? DS.Colors.textOnBrand : DS.Colors.brandInk).offset(y: 12)
                                }
                                .scaleEffect(active == tab ? 1.08 : 1)
                        } else {
                            TabGlyph(tab: tab, isActive: active == tab, showsTitle: !model.isCollapsed, activeInk: tab.accent.ink)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 5)
                                .background { if active == tab { Capsule().fill(tab.accent.tint).transition(.scale) } }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: model.isCollapsed ? 54 : 66)
        }
        .frame(height: 82, alignment: .bottom)
        .animation(DS.Motion.bouncy, value: active)
        .onChange(of: active) { _, _ in
            isRunning = true
            Task {
                try? await Task.sleep(for: .milliseconds(480))
                isRunning = false
            }
        }
    }
}

// MARK: - E · Big paw

/// No bar at all: the tabs are one big glass paw. Properties is the pad,
/// the other four are toe beans. Scrolling curls it into a small paw.
struct BigPawTabBar: View {
    let active: AppTab
    let isDown: Bool
    let model: TabBarModel

    private static let toes: [AppTab] = [.dashboard, .maintenance, .messages, .search]

    /// Where each tab is, in the bar.
    static func centers(in size: CGSize, isCollapsed: Bool) -> [AppTab: CGPoint] {
        let k: CGFloat = isCollapsed ? 0.62 : 1
        let x = size.width / 2, base = size.height - 4
        return [
            .properties: CGPoint(x: x, y: base - 38 * k),
            .dashboard: CGPoint(x: x - 98 * k, y: base - 56 * k),
            .maintenance: CGPoint(x: x - 38 * k, y: base - 108 * k),
            .messages: CGPoint(x: x + 38 * k, y: base - 108 * k),
            .search: CGPoint(x: x + 98 * k, y: base - 56 * k),
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let spots = Self.centers(in: proxy.size, isCollapsed: model.isCollapsed)
            let k: CGFloat = model.isCollapsed ? 0.62 : 1
            GlassEffectContainer(spacing: 0) {
                ZStack {
                    ForEach(Self.toes) { tab in
                        toe(tab, scale: k).position(spots[tab]!)
                    }
                    pad(scale: k).position(spots[.properties]!)
                }
            }
            // Over the glass: inside it, they'd blur with what's behind.
            .overlay {
                ForEach(AppTab.pawOrder) { tab in
                    let isActive = active == tab
                    TabGlyph(tab: tab, isActive: isActive, size: (tab == .properties ? 25 : 20) * k,
                             showsTitle: !model.isCollapsed && tab == .properties,
                             activeInk: tab.accent.onFill)
                        .scaleEffect(isActive ? 1.1 : 1)
                        .position(spots[tab]!)
                        .offset(y: tab == .properties ? 6 * k : isActive ? -5 : 0)
                }
            }
            .rotationEffect(.degrees(Double(model.energy) * 5), anchor: .bottom)
        }
        .frame(height: 148)
        .padding(.top, -14)
        .animation(DS.Motion.bouncy, value: active)
    }

    private func pad(scale k: CGFloat) -> some View {
        let isActive = active == .properties
        return PawPad().fill(.clear)
            .frame(width: 116 * k, height: 74 * k)
            .glassEffect(.regular.tint(DS.Colors.brand.opacity(isActive ? 0.9 : 0.35)).interactive(), in: PawPad())
            .shadow(color: DS.Colors.brand.opacity(isActive ? 0.4 : 0.1), radius: 16, y: 8)
            .scaleEffect(isActive ? 1.08 : 1, anchor: .bottom)
    }

    private func toe(_ tab: AppTab, scale k: CGFloat) -> some View {
        let isActive = active == tab
        let tilt: Double = switch tab { case .dashboard: -20; case .maintenance: -7; case .messages: 7; default: 20 }
        return Ellipse().fill(.clear)
            .frame(width: 56 * k, height: 64 * k)
            .glassEffect(.regular.tint(tab.accent.fill.opacity(isActive ? 0.95 : 0.22)).interactive(), in: .ellipse)
            .rotationEffect(.degrees(tilt))
            .scaleEffect(isActive ? 1.12 : 1)
            .offset(y: isActive ? -5 : 0)
            .shadow(color: tab.accent.fill.opacity(isActive ? 0.5 : 0), radius: 14, y: 6)
    }
}
