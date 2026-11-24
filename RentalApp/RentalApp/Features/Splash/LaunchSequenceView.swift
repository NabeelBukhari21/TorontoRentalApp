//
//  LaunchSequenceView.swift
//  RentalApp (Purrperty)
//
//  Splash — Purr's launch: a drop splashes into a blob, Purr pops
//  out of it, then melts into six dots that keep turning while the app
//  checks the session, and finally merge into the logo and name.
//
//  The dots are the real loading indicator: they turn until `isReady`
//  (the session check is done), so the sequence never waits on nothing
//  and never fakes work. A first launch gets the whole thing (about 4.5
//  seconds, the brand's first impression); a returning user gets just
//  the pop, so getting back into the app stays quick.
//
//  Ported from the Remotion studies in tools/motion (LaunchB "Drip & pop"
//  and LogoA "Orbit merge"); the timings below are those, in seconds.
//

import SwiftUI

// MARK: - Mode

enum LaunchSequenceMode: Equatable {
    /// First launch: splash, dots, logo and name.
    case full
    /// Returning user: Purr pops in and the app opens.
    case brief
}

// MARK: - Timeline

/// Every beat of the sequence, in seconds from the first frame. The dots
/// gather once the app is ready, so everything after that is relative to
/// `gather`.
private struct LaunchTimeline {

    let mode: LaunchSequenceMode
    /// When the dots start to merge: after the minimum show, and only once
    /// the app is ready. Nil while still loading.
    let gather: Double?

    // Splash (full mode only; brief starts at the pop).
    var impact: Double { mode == .full ? 0.42 : 0 }
    var pop: Double { mode == .full ? 0.8 : 0.08 }
    var sparkles: Double { pop + 0.4 }

    // Loader.
    static let melt = 1.55
    static let split = 2.27
    /// The dots show for at least this long, even if the app is ready.
    static let minimumGather = 2.6

    // Logo, relative to `gather`.
    func tile(_ g: Double) -> Double { g + 0.4 }
    func whiten(_ g: Double) -> Double { g + 0.6 }
    func build(_ g: Double) -> Double { g + 0.75 }
    func letters(_ g: Double) -> Double { g + 1.0 }

    /// When the sequence has said everything and can hand over.
    func end(readyAt: Double) -> Double {
        switch mode {
        case .brief: max(1.1, readyAt + 0.1)
        case .full: max(Self.minimumGather, readyAt) + 1.95
        }
    }
}

// MARK: - View

struct LaunchSequenceView: View {

    let mode: LaunchSequenceMode
    /// The session check is done; the dots may gather.
    let isReady: Bool
    /// The sequence has finished; fade it away.
    let onFinished: () -> Void

    @State private var start = Date.now
    @State private var readyAt: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.feedback) private var feedback

    private var mood: PurrMood { mode == .full ? .splash : .welcomeBack }

    private var timeline: LaunchTimeline {
        LaunchTimeline(mode: mode, gather: readyAt.map { max(LaunchTimeline.minimumGather, $0) })
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if reduceMotion {
                    still(in: geometry.size)
                } else {
                    TimelineView(.animation) { context in
                        scene(at: context.date.timeIntervalSince(start), in: geometry.size)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(DS.Colors.launchBackground)
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Purrperty"))
        .accessibilityAddTraits(.isImage)
        .onAppear { if isReady { readyAt = 0 } }
        // The drop landing. Only the first launch; every launch would grate.
        .task {
            guard mode == .full, !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(timeline.impact))
            if !Task.isCancelled { feedback?.play(.drop) }
        }
        .onChange(of: isReady) { _, ready in
            if ready, readyAt == nil { readyAt = Date.now.timeIntervalSince(start) }
        }
        // Hands over once the last beat has played.
        .task(id: readyAt) {
            guard let readyAt else { return }
            let end = reduceMotion ? max(0.5, readyAt) : timeline.end(readyAt: readyAt)
            let remaining = end - Date.now.timeIntervalSince(start)
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }

    // MARK: Geometry

    /// The composition is laid out on a 360-point-wide phone and scaled to fit.
    private func scale(for size: CGSize) -> CGFloat { min(size.width / 360, size.height / 780) }
    private func center(in size: CGSize) -> CGPoint { CGPoint(x: size.width / 2, y: size.height * 0.49) }

    // MARK: Animated Scene

    @ViewBuilder
    private func scene(at t: Double, in size: CGSize) -> some View {
        let s = scale(for: size)
        let c = center(in: size)
        let tl = timeline
        let headSide = 260 * s

        // Splash.
        let blob = LiquidMotion.spring(t - tl.impact, damping: 9, stiffness: 140)
        let pop = LiquidMotion.spring(t - tl.pop, damping: 8, stiffness: 150, mass: 0.8)

        // Loader (full mode).
        let isFull = mode == .full
        let melt = isFull ? LiquidMotion.easeInCubic(LiquidMotion.progress(t, from: LaunchTimeline.melt, to: LaunchTimeline.melt + 0.6)) : 0
        let split = isFull ? LiquidMotion.easeOutBack(LiquidMotion.progress(t, from: LaunchTimeline.split, to: LaunchTimeline.split + 0.5), overshoot: 1.6) : 0
        let gather = tl.gather.map { LiquidMotion.easeInCubic(LiquidMotion.progress(t, from: $0, to: $0 + 0.45)) } ?? 0

        ZStack {
            Canvas { context, _ in
                drawSplash(in: context, t: t, c: c, s: s, blob: blob, pop: pop, melt: melt)
                if isFull { drawLoader(in: context, t: t, c: c, s: s, melt: melt, split: split, gather: gather) }
            }

            if isFull { colouredDots(t: t, c: c, s: s, split: split, gather: gather) }

            PurrMascot(mood: mood, size: headSide, isInteractive: false)
                .scaleEffect(LiquidMotion.mix(0.15, 1, pop) * (1 - melt), anchor: UnitPoint(x: 0.5, y: 0.6))
                .rotationEffect(.degrees(-25 * melt))
                .offset(y: LiquidMotion.mix(80, 0, pop) / 3 * s)
                .opacity(t >= tl.pop ? min(1, (1 - melt) * 2.5) : 0)
                .position(c)

            sparkles(t: t, c: c, s: s)

            if isFull, let g = tl.gather {
                logo(t: t, g: g, c: c, s: s)
            }
        }
    }

    /// The drop, the splash and the blob that becomes a halo behind Purr.
    private func drawSplash(in context: GraphicsContext, t: Double, c: CGPoint, s: CGFloat, blob: Double, pop: Double, melt: Double) {
        let tl = timeline
        // After the pop the blob thins to a halo; the melt drains it.
        let opacity = LiquidMotion.mix(1, 0.22, pop) * (1 - melt)
        guard opacity > 0.01 else { return }
        var halo = context
        halo.opacity = opacity
        halo.liquidLayer(color: PurrpertyBrand.cherry, blur: 6 * s) { layer in
            if mode == .full, t < tl.impact + 0.07 {
                let fall = LiquidMotion.easeInCubic(LiquidMotion.progress(t, from: 0, to: tl.impact))
                let y = LiquidMotion.mix(-50 * s, c.y, fall)
                let stretch = 1 + fall * 0.9
                let rx = 15 * s / stretch.squareRoot()
                let ry = 15 * s * stretch
                layer.fill(Path(ellipseIn: CGRect(x: c.x - rx, y: y - ry, width: rx * 2, height: ry * 2)), with: .color(.black))
            }
            if t >= tl.impact {
                let radius = (LiquidMotion.mix(17, 110, blob) - pop * 13) * s
                let wobble = 0.09 * exp(-max(0, t - tl.impact) / 0.66) + 0.015
                layer.fill(.wobblyCircle(center: CGPoint(x: c.x, y: c.y + 10 * s), radius: radius, time: t * 3, amount: wobble), with: .color(.black))
            }
            // Droplets flung out on impact; drawn only once clear of the blob.
            if mode == .full, t > tl.impact {
                let life = t - tl.impact
                let distance = 173 * life - 300 * life * life
                for i in 0..<9 {
                    let spread = max(0, distance) * 1.1 * s
                    guard spread > 50 * s else { continue }
                    let a = Double(i) / 9 * .pi * 2 + 0.3
                    let r = CGFloat(8 - (i % 3) * 2) * s
                    let p = CGPoint(x: c.x + cos(a) * spread, y: c.y + 13 * s + sin(a) * spread * 0.64)
                    layer.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.black))
                }
            }
        }
    }

    /// The drop the head melts into, the six dots, and the gathering blob
    /// that grows into the logo tile.
    private func drawLoader(in context: GraphicsContext, t: Double, c: CGPoint, s: CGFloat, melt: Double, split: Double, gather: Double) {
        let tl = timeline
        let drop = LiquidMotion.easeOutBack(LiquidMotion.progress(t, from: LaunchTimeline.melt + 0.25, to: LaunchTimeline.melt + 0.72), overshoot: 2)
        let tileProgress = tl.gather.map { LiquidMotion.spring(t - tl.tile($0), damping: 13, stiffness: 120) } ?? 0
        let whiten = tl.gather.map { LiquidMotion.progress(t, from: tl.whiten($0), to: tl.whiten($0) + 0.4) } ?? 0
        guard drop > 0, whiten < 1 else { return }

        var liquid = context
        liquid.opacity = 1 - whiten
        liquid.liquidLayer(color: PurrpertyBrand.cherry, blur: 5 * s) { layer in
            let core = (23 * drop * (1 - min(split, 1)) + 20 * gather) * s
            if core > 0.5, tileProgress < 0.2 {
                layer.fill(Path(ellipseIn: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2)), with: .color(.black))
            }
            if split > 0, tileProgress < 0.2 {
                for dot in dots(t: t, c: c, s: s, split: split, gather: gather) {
                    layer.fill(Path(ellipseIn: CGRect(x: dot.x - dot.r, y: dot.y - dot.r, width: dot.r * 2, height: dot.r * 2)), with: .color(.black))
                }
            }
            if tileProgress > 0 {
                let side = 150 * s * tileProgress
                let radius = LiquidMotion.mix(side / 2, side * 0.23, tileProgress)
                let rect = CGRect(x: c.x - side / 2, y: c.y - side / 2, width: side, height: side)
                layer.fill(Path(roundedRect: rect, cornerRadius: radius, style: .continuous), with: .color(.black))
            }
        }
    }

    private struct Dot { let x: CGFloat; let y: CGFloat; let r: CGFloat; let color: Color }

    private static let dotColors: [Color] = [
        PurrpertyBrand.cherry, PurrpertyBrand.gold, PurrpertyBrand.blush,
        PurrpertyBrand.mint, PurrpertyBrand.sky, PurrpertyBrand.honey,
    ]

    /// Six dots in a ring, Cosmos style: the ring turns and each dot
    /// swells in turn.
    private func dots(t: Double, c: CGPoint, s: CGFloat, split: Double, gather: Double) -> [Dot] {
        let spin = (t - LaunchTimeline.split) * 2.4
        let radius = 43 * s * split * (1 - gather)
        return Self.dotColors.enumerated().map { i, color in
            let a = Double(i) / 6 * .pi * 2 - .pi / 2 + spin
            let pulse = 0.5 + 0.5 * sin(t * 7.5 - Double(i) * 1.05)
            return Dot(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius, r: (10 + pulse * 3.3) * s, color: color)
        }
    }

    /// The dots' own colours over the liquid, so the ring reads as a
    /// rainbow while it turns and goes back to one drop as it merges.
    private func colouredDots(t: Double, c: CGPoint, s: CGFloat, split: Double, gather: Double) -> some View {
        let visibility = min(1, max(0, split)) * (1 - min(1, gather * 1.6))
        return Canvas { context, _ in
            guard visibility > 0.01 else { return }
            for dot in dots(t: t, c: c, s: s, split: split, gather: gather) {
                let r = dot.r * 0.9
                context.fill(Path(ellipseIn: CGRect(x: dot.x - r, y: dot.y - r, width: r * 2, height: r * 2)), with: .color(dot.color.opacity(visibility)))
            }
        }
        .allowsHitTesting(false)
    }

    private func sparkles(t: Double, c: CGPoint, s: CGFloat) -> some View {
        let tl = timeline
        let spots: [(dx: CGFloat, dy: CGFloat, delay: Double)] = [(-83, -83, 0), (90, -67, 0.17), (100, 20, 0.3)]
        return ZStack {
            ForEach(spots.indices, id: \.self) { i in
                let spot = spots[i]
                let grow = LiquidMotion.spring(t - tl.sparkles - spot.delay, damping: 10, stiffness: 100)
                let fade = 1 - LiquidMotion.progress(t, from: tl.sparkles + 0.47 + spot.delay, to: tl.sparkles + 0.87 + spot.delay)
                Image(systemName: "sparkle")
                    .font(.system(size: 22 * s, weight: .bold))
                    .foregroundStyle(PurrpertyBrand.gold)
                    .scaleEffect(grow)
                    .opacity(fade)
                    .position(x: c.x + spot.dx * s, y: c.y + spot.dy * s)
            }
        }
    }

    /// The tile turns cream as the house rises and Purr pops up behind it,
    /// then the name springs up letter by letter.
    private func logo(t: Double, g: Double, c: CGPoint, s: CGFloat) -> some View {
        let tl = timeline
        let whiten = LiquidMotion.progress(t, from: tl.whiten(g), to: tl.whiten(g) + 0.4)
        let side = 150 * s
        return ZStack {
            PurrpertyLogoTile(size: side, isBuilt: t >= tl.build(g))
                .opacity(whiten)
                .position(c)

            LaunchWordmark(size: 50 * s, t: t - tl.letters(g))
                .position(x: c.x, y: c.y + 120 * s)
        }
    }

    // MARK: Reduce Motion

    /// Reduce Motion: the finished frame, no movement.
    @ViewBuilder
    private func still(in size: CGSize) -> some View {
        let s = scale(for: size)
        let c = center(in: size)
        if mode == .full {
            ZStack {
                PurrpertyLogoTile(size: 150 * s, animates: false)
                    .position(c)
                PurrpertyWordmark(fontSize: 50 * s)
                    .position(x: c.x, y: c.y + 120 * s)
            }
        } else {
            PurrMascot(mood: mood, size: 260 * s, isInteractive: false)
                .position(c)
        }
    }
}

// MARK: - Wordmark Reveal

/// "Purrperty" with each letter springing up in turn. `t` is seconds since
/// the first letter started.
private struct LaunchWordmark: View {

    let size: CGFloat
    let t: Double

    private static let letters = Array("Purrperty")

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.letters.indices, id: \.self) { i in
                let p = LiquidMotion.spring(t - Double(i) * 0.07, damping: 11, stiffness: 170)
                Text(String(Self.letters[i]))
                    .foregroundStyle(i < 4 ? AnyShapeStyle(purrGradient) : AnyShapeStyle(DS.Colors.textPrimary))
                    .offset(y: (1 - p) * size * 0.6)
                    .scaleEffect(0.6 + 0.4 * p)
                    .opacity(min(1, p * 1.4))
            }
        }
        .font(DS.Typography.brandFixed(size, weight: .bold))
        .fixedSize()
    }

    private var purrGradient: LinearGradient {
        LinearGradient(colors: [PurrpertyBrand.cherry, PurrpertyBrand.ember], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Previews

#Preview("First launch") {
    LaunchSequenceView(mode: .full, isReady: true) {}
}

#Preview("Returning") {
    LaunchSequenceView(mode: .brief, isReady: true) {}
}
