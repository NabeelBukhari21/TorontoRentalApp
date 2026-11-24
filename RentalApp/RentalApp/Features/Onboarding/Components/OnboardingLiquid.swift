//
//  OnboardingLiquid.swift
//  RentalApp (Purrperty)
//
//  Onboarding — The liquid behind the scene: a backdrop whose next colour
//  spreads over the last, the wave that fills while building, the pool
//  Purr stands in, and the rays behind a celebration.
//

import SwiftUI

// MARK: - Look

/// How one step's background is painted.
struct OnboardingLook: Equatable {
    enum Finish: Equatable { case stage, flat, glow }
    let accent: DSAccent
    let finish: Finish
}

// MARK: - Backdrop

/// Paints the current look. When it changes, the new one spreads from
/// `origin` as a drop of liquid until it covers the old.
struct LiquidBackdrop: View {

    let look: OnboardingLook
    let origin: UnitPoint

    @State private var base: OnboardingLook
    @State private var layers: [Layer] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Layer: Identifiable {
        let id = UUID()
        let look: OnboardingLook
        let origin: UnitPoint
    }

    init(look: OnboardingLook, origin: UnitPoint) {
        self.look = look
        self.origin = origin
        _base = State(initialValue: look)
    }

    var body: some View {
        ZStack {
            LookPaint(look: base)
            ForEach(layers) { layer in
                SpreadingDrop(origin: layer.origin, reduceMotion: reduceMotion) {
                    LookPaint(look: layer.look)
                } onCovered: {
                    // Everything below it is hidden now.
                    guard let index = layers.firstIndex(where: { $0.id == layer.id }) else { return }
                    base = layer.look
                    layers.removeFirst(index + 1)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: look) { _, new in
            layers.append(Layer(look: new, origin: origin))
        }
        .accessibilityHidden(true)
    }
}

private struct SpreadingDrop<Content: View>: View {
    let origin: UnitPoint
    let reduceMotion: Bool
    @ViewBuilder var content: Content
    let onCovered: () -> Void

    @State private var progress: CGFloat = 0

    var body: some View {
        content
            .mask { reduceMotion ? AnyView(Rectangle()) : AnyView(DropShape(progress: progress, origin: origin).fill(.black)) }
            .opacity(reduceMotion ? progress : min(1, progress * 5))
            .onAppear {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .timingCurve(0.3, 0.05, 0.1, 1, duration: 0.85)) {
                    progress = 1
                } completion: {
                    onCovered()
                }
            }
    }
}

/// A drop that grows from a point until it covers the rect.
private struct DropShape: Shape {
    var progress: CGFloat
    let origin: UnitPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width * origin.x, y: rect.height * origin.y)
        let reach = hypot(max(center.x, rect.width - center.x), max(center.y, rect.height - center.y))
        // The edge ripples most mid-way and settles as it lands.
        let ripple = 0.10 * sin(progress * .pi)
        return .wobblyCircle(center: center, radius: reach * 1.15 * progress, time: Double(progress) * 3.4, amount: ripple, points: 120)
    }
}

/// One look, painted: the wash and its drifting blobs.
private struct LookPaint: View {
    let look: OnboardingLook
    @Environment(\.colorScheme) private var colorScheme

    private var color: Color { look.accent.fill }
    private var strength: Double { colorScheme == .dark ? 0.6 : 1 }

    var body: some View {
        ZStack {
            DS.Colors.background
            switch look.finish {
            case .stage:
                LinearGradient(colors: [color.opacity(0.42 * strength), color.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                LiquidBlobs(color: color.opacity(0.55 * strength), blobs: [
                    .init(x: 0.5, y: 0.5, r: 0.44, phase: 0), .init(x: 0.1, y: 0.36, r: 0.17, phase: 2),
                    .init(x: 0.93, y: 0.45, r: 0.2, phase: 4), .init(x: 0.78, y: 0.3, r: 0.1, phase: 5),
                ])
            case .flat:
                LinearGradient(colors: [color.mix(with: .white, by: 0.25), color], startPoint: .top, endPoint: .bottom)
                LiquidBlobs(color: .white.opacity(0.28), blobs: [
                    .init(x: 0.1, y: 0.12, r: 0.3, phase: 0), .init(x: 0.95, y: 0.3, r: 0.25, phase: 3),
                    .init(x: 0.5, y: 0.95, r: 0.62, phase: 1), .init(x: 0.12, y: 0.62, r: 0.16, phase: 2),
                ])
            case .glow:
                RadialGradient(colors: [color.opacity(0.5 * strength), color.opacity(0.08)], center: UnitPoint(x: 0.5, y: 0.52), startRadius: 30, endRadius: 420)
            }
        }
    }
}

// MARK: - Blobs

/// Slow liquid: wobbling blobs that fuse where they touch.
struct LiquidBlobs: View {
    struct Blob { let x: Double, y: Double, r: Double, phase: Double }
    let color: Color
    let blobs: [Blob]
    var amount = 0.05
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                canvas.liquidLayer(color: color, blur: 14) { layer in
                    for blob in blobs {
                        let c = CGPoint(x: blob.x * size.width + sin(t * 0.5 + blob.phase) * 10,
                                        y: blob.y * size.height + cos(t * 0.6 + blob.phase) * 10)
                        layer.fill(.wobblyCircle(center: c, radius: blob.r * size.width, time: t * 0.6 + blob.phase, amount: amount), with: .color(.black))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Wave

/// Liquid filling a rect to `level`, its surface rolling.
struct LiquidWave: Shape {
    var level: CGFloat
    var phase: Double
    var animatableData: CGFloat { get { level } set { level = newValue } }

    func path(in rect: CGRect) -> Path {
        let top = rect.height * (1 - level)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        for i in 0...60 {
            let x = rect.width * CGFloat(i) / 60
            path.addLine(to: CGPoint(x: x, y: top + sin(Double(i) / 9 + phase) * 9 + sin(Double(i) / 5 - phase * 0.7) * 4))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
// MARK: - Rays

/// Slowly turning rays behind a celebrating Purr.
struct SunRays: View {
    let color: Color
    var center = UnitPoint(x: 0.5, y: 0.4)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 0.15
            Canvas { canvas, size in
                let c = CGPoint(x: size.width * center.x, y: size.height * center.y)
                for i in 0..<14 {
                    let a = Double(i) / 14 * .pi * 2 + t
                    var ray = Path()
                    ray.move(to: c)
                    ray.addLine(to: CGPoint(x: c.x + cos(a - 0.11) * 800, y: c.y + sin(a - 0.11) * 800))
                    ray.addLine(to: CGPoint(x: c.x + cos(a + 0.11) * 800, y: c.y + sin(a + 0.11) * 800))
                    canvas.fill(ray, with: .radialGradient(Gradient(colors: [color.opacity(0.7), color.opacity(0)]), center: c, startRadius: 40, endRadius: 460))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
// MARK: - Pool

/// The pool under Purr, and a strand of liquid that runs out to each
/// picked bubble.
struct LiquidPool: View {

    struct Target: Equatable {
        let id: String
        let point: CGPoint
        let radius: CGFloat
        let color: Color
    }

    let accent: DSAccent
    let feet: CGPoint
    let targets: [Target]

    /// When each strand set out.
    @State private var departures: [String: Date] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The shape is a mask, so the colour under it can animate.
        Rectangle()
            .fill(targets.last?.color ?? accent.fill)
            .animation(.easeInOut(duration: 0.5), value: targets.last?.id)
            .mask {
                TimelineView(.animation(minimumInterval: 1 / 40, paused: reduceMotion)) { context in
                    Canvas { canvas, _ in
                        canvas.liquidLayer(color: .black, blur: 10) { draw(in: &$0, at: context.date) }
                    }
                }
            }
            .ignoresSafeArea(edges: .horizontal)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: targets.map(\.id), initial: true) { old, new in
                for id in new where departures[id] == nil { departures[id] = .now }
                for id in old where !new.contains(id) { departures[id] = nil }
            }
    }

    private func draw(in layer: inout GraphicsContext, at date: Date) {
        let t = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate
        var pool = Path()
        for i in 0...80 {
            let a = Double(i) / 80 * .pi * 2
            let r = 1 + 0.06 * sin(a * 3 + t * 1.6) + 0.04 * sin(a * 5 - t)
            let p = CGPoint(x: feet.x + cos(a) * 165 * r, y: feet.y + sin(a) * 40 * r)
            if i == 0 { pool.move(to: p) } else { pool.addLine(to: p) }
        }
        layer.fill(pool, with: .color(.black))

        for target in targets {
            let age = departures[target.id].map { date.timeIntervalSince($0) } ?? 0
            let reach = reduceMotion ? 1 : LiquidMotion.easeOutCubic(LiquidMotion.progress(age, from: 0, to: 0.4))
            let swell = reduceMotion ? 1 : LiquidMotion.spring(age - 0.25, damping: 9, stiffness: 120)
            let mid = CGPoint(
                x: target.point.x + (target.point.x - feet.x) * 0.15 + sin(t * 1.4) * 10,
                y: (feet.y + target.point.y) / 2 + 20
            )
            var strand = Path()
            strand.move(to: feet)
            strand.addQuadCurve(to: target.point, control: mid)
            layer.stroke(strand.trimmedPath(from: 0, to: reach), with: .color(.black),
                         style: StrokeStyle(lineWidth: 34 + sin(t * 2) * 5, lineCap: .round))
            if swell > 0 {
                layer.fill(.wobblyCircle(center: target.point, radius: target.radius * 1.2 * swell, time: t, amount: 0.07), with: .color(.black))
            }
        }
    }
}
