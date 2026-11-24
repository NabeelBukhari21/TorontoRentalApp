//
//  SakugaStage.swift
//  RentalApp (Purrperty)
//
//  Components/Sakuga — Drawn impact effects, the way an anime key animator
//  would sell a hit: smoke, bursts, claw slashes, chips, splashes, smoke
//  rings and lettering, on one canvas over the screen.
//
//  Ported from Sakuga VFX (https://github.com/finktheartist/sakuga-vfx),
//  MIT © 2026 Justin Finkelman; licence in tools/sakuga-LICENSE.txt. The
//  drawing follows its core.js; the palette and the cat parts are ours.
//

import Observation
import SwiftUI

// MARK: - Palette

/// Fixed, like the mascot's: ink on paper looks the same in both themes.
enum SakugaInk {
    static let fill = Color(hex: 0xFFFDF8)
    static let shade = Color(hex: 0xFFB3A6)
    static let line = Color(hex: 0xB02727)
    static let accent = Color(hex: 0xF2B83A)
    static let cherry = Color(hex: 0xCC2E2E)
    static let ink = Color(hex: 0x2B1712)
}

// MARK: - Stage

/// Holds the effects that are playing. Points are in the space of the
/// layer that draws it (the whole screen, for the shared one).
@MainActor
@Observable
final class SakugaStage {

    struct Effect: Identifiable {
        let id = UUID()
        let start: Date
        let life: Double
        /// Draws one frame: the context, 0…1 through its life, seconds in.
        let draw: (inout GraphicsContext, Double, Double) -> Void
    }

    private(set) var effects: [Effect] = []

    /// The hint that's open, if any.
    struct Hint: Equatable {
        let id: UUID
        let text: String
        let anchor: CGRect
    }
    var hint: Hint?
    /// Reduce Motion turns every effect off.
    @ObservationIgnored var isCalm = false
    @ObservationIgnored private var sweep: Task<Void, Never>?

    var isPlaying: Bool { !effects.isEmpty }

    func add(_ life: Double, _ draw: @escaping (inout GraphicsContext, Double, Double) -> Void) {
        guard !isCalm else { return }
        effects.append(Effect(start: .now, life: life, draw: draw))
        // Clears out what's finished, so the canvas can rest.
        guard sweep == nil else { return }
        sweep = Task {
            while !effects.isEmpty {
                try? await Task.sleep(for: .milliseconds(250))
                let now = Date.now
                effects.removeAll { now.timeIntervalSince($0.start) >= $0.life }
            }
            sweep = nil
        }
    }

    func later(_ milliseconds: Int, _ work: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(milliseconds))
            work()
        }
    }
}

/// Draws a stage.
struct SakugaLayer: View {
    let stage: SakugaStage
    /// Points are the screen's, wherever this layer sits on it.
    var followsScreen = false
    @State private var origin: CGPoint = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !stage.isPlaying)) { timeline in
            Canvas { context, _ in
                for effect in stage.effects {
                    let t = timeline.date.timeIntervalSince(effect.start)
                    guard t >= 0, t < effect.life else { continue }
                    var copy = context
                    if followsScreen { copy.translateBy(x: -origin.x, y: -origin.y) }
                    effect.draw(&copy, t / effect.life, t)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { origin = $0 }
        .onChange(of: reduceMotion, initial: true) { _, calm in stage.isCalm = calm }
    }
}

extension EnvironmentValues {
    /// The screen's effects layer. Nil where there isn't one.
    @Entry var sakuga: SakugaStage? = nil
}

// MARK: - Maths

private let tau = Double.pi * 2
private func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
private func out(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
private func inn(_ t: Double) -> Double { t * t * t }
private func back(_ t: Double) -> Double { 1 + 2.70158 * pow(t - 1, 3) + 1.70158 * pow(t - 1, 2) }
private func rnd(_ a: Double, _ b: Double) -> Double { Double.random(in: min(a, b)...max(a, b)) }
private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

// MARK: - Brush

extension GraphicsContext {

    /// Two-tone with an ink edge: the shade, then the light slid up-left.
    func sakugaShape(_ path: Path, line: Double = 1.5, off: Double = 3, fill: Color = SakugaInk.fill, evenOdd: Bool = false) {
        stroke(path, with: .color(SakugaInk.line), style: StrokeStyle(lineWidth: line * 2, lineCap: .round, lineJoin: .round))
        var c = self
        c.clip(to: path, style: FillStyle(eoFill: evenOdd))
        c.fill(path, with: .color(SakugaInk.shade), style: FillStyle(eoFill: evenOdd))
        c.translateBy(x: -off * 0.7, y: -off)
        c.fill(path, with: .color(fill), style: FillStyle(eoFill: evenOdd))
    }

    /// Circles drawn as one cloud.
    func sakugaBlob(_ circles: [(x: Double, y: Double, r: Double)], line: Double = 1.5, lx: Double = -1, arcs: Bool = false, deep: Double = 1) {
        var union = Path()
        for c in circles where c.r > 0.3 { union.addEllipse(in: CGRect(x: c.x - c.r, y: c.y - c.r, width: c.r * 2, height: c.r * 2)) }
        guard let first = circles.first else { return }
        stroke(union, with: .color(SakugaInk.line), lineWidth: line * 2)
        var c = self
        c.clip(to: union)
        c.fill(union, with: .color(SakugaInk.shade))
        var light = c
        light.translateBy(x: lx * first.r * 0.2 * deep, y: -first.r * 0.26 * deep)
        light.fill(union, with: .color(SakugaInk.fill))
        if arcs {
            var lines = Path()
            for b in circles where b.r > 3 {
                lines.move(to: pt(b.x + cos(-2.7) * b.r, b.y + sin(-2.7) * b.r))
                lines.addArc(center: pt(b.x, b.y), radius: b.r, startAngle: .radians(-2.7), endAngle: .radians(-0.5), clockwise: false)
            }
            c.stroke(lines, with: .color(SakugaInk.line), lineWidth: line * 0.75)
        }
    }
}

// MARK: - Effects

extension SakugaStage {

    /// Smoke: lobes swell with a little overshoot, roll, and shrink away.
    func puff(_ x: Double, _ y: Double, n: Int = 5, size: Double = 13, vx: Double = 0, vy: Double = -18, life: Double = 0.8) {
        struct Lobe { let a, d, r, ph, sp: Double }
        var lobes = [Lobe(a: 0, d: 0, r: size, ph: 0, sp: 1)]
        for i in 0..<n { lobes.append(Lobe(a: Double(i) / Double(n) * tau + rnd(0, 0.6), d: rnd(0.25, 0.9) * size, r: rnd(0.55, 1) * size, ph: rnd(0, tau), sp: rnd(0.6, 1.3))) }
        add(life) { g, k, t in
            let grow = back(clamp(t / 0.22)), die = 1 - inn(clamp((k - 0.55) / 0.45))
            let px = x + vx * out(k) * life, py = y + vy * out(k) * life
            g.sakugaBlob(lobes.map { l in
                let reach = l.d * (0.5 + out(k) * 0.9), a = l.a + t * 0.9 * l.sp
                return (px + cos(a) * reach, py + sin(a) * reach - out(k) * 5 * l.sp, l.r * grow * die * (1 + sin(t * 9 + l.ph) * 0.05))
            }, lx: 0.5, arcs: size > 6.5, deep: 1.5)
        }
    }

    /// Ours: smoke in the shape of a paw, pressed into the air.
    func pawPuff(_ x: Double, _ y: Double, size: Double = 16, rot: Double = 0, vx: Double = 0, vy: Double = -22, life: Double = 0.95) {
        add(life) { g, k, t in
            let s = size * back(clamp(t / 0.22)) * (1 - inn(clamp((k - 0.6) / 0.4)))
            guard s > 0.4 else { return }
            var c = g
            c.translateBy(x: x + vx * out(k) * life, y: y + vy * out(k) * life)
            c.rotate(by: .radians(rot + sin(t * 4) * 0.06))
            c.sakugaBlob([(0, s * 0.35, s * 0.72), (-s * 0.42, s * 0.62, s * 0.42), (s * 0.42, s * 0.62, s * 0.42)], lx: 0.4, deep: 1.2)
            for bean in [(-0.95, -0.2, 0.33), (-0.36, -0.74, 0.36), (0.36, -0.74, 0.36), (0.95, -0.2, 0.33)] {
                // Toes land a beat after the pad.
                let b = back(clamp((t - 0.06) / 0.2))
                c.sakugaBlob([(bean.0 * s, bean.1 * s, bean.2 * s * b)], lx: 0.4, deep: 1.2)
            }
        }
    }

    /// The impact: gold needles, a star in the shadow tone, a paper star.
    func burst(_ x: Double, _ y: Double, r: Double = 44, spikes: Int = 13, life: Double = 0.34, paw: Bool = false) {
        let radii = (0..<spikes * 2).map { $0 % 2 == 1 ? rnd(0.34, 0.5) : rnd(0.75, 1.15) }
        let rot = rnd(0, tau)
        let pins = (0..<8).map { (a: Double($0) / 8 * tau + rnd(0, 0.5), l: rnd(1.25, 1.75), w: rnd(0.03, 0.055)) }
        func star(_ R: Double, _ turn: Double, _ inner: Double) -> Path {
            var p = Path()
            for (i, m) in radii.enumerated() {
                let a = rot + turn + Double(i) / Double(radii.count) * tau, rr = R * (i % 2 == 1 ? m * inner : m)
                let q = pt(x + cos(a) * rr, y + sin(a) * rr)
                i == 0 ? p.move(to: q) : p.addLine(to: q)
            }
            p.closeSubpath()
            return p
        }
        add(life) { g, k, _ in
            let R = r * out(clamp(k / 0.3)), hollow = 1 + inn(clamp((k - 0.35) / 0.65)) * 1.3, r0 = R * 0.6 * min(1.9, hollow)
            var needles = Path()
            for n in pins where R * n.l > r0 {
                needles.move(to: pt(x + cos(n.a - n.w) * r0, y + sin(n.a - n.w) * r0))
                needles.addLine(to: pt(x + cos(n.a) * R * n.l, y + sin(n.a) * R * n.l))
                needles.addLine(to: pt(x + cos(n.a + n.w) * r0, y + sin(n.a + n.w) * r0))
            }
            g.fill(needles, with: .color(SakugaInk.accent))
            let big = star(R * 1.16, 0.19, hollow)
            g.fill(big, with: .color(SakugaInk.shade))
            g.stroke(big, with: .color(SakugaInk.line), lineWidth: 1.2)
            g.sakugaShape(star(R * 0.84, 0, hollow), line: 1.4)
            if paw {
                let s = R * 0.62 * (1 - inn(clamp((k - 0.5) / 0.5)))
                let print = PawShape().path(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s))
                g.fill(print, with: .color(SakugaInk.cherry))
            }
        }
    }

    /// Chips, tumbling and falling: crystal, or a cat's own claw tips.
    func shards(_ x: Double, _ y: Double, n: Int = 7, speed: Double = 190, size: Double = 5, life: Double = 0.75, dir: Double = -.pi / 2, arc: Double = .pi, grav: Double = 420) {
        for i in 0..<n {
            let a = dir + rnd(-arc, arc) / 2, v = speed * rnd(0.5, 1.15), s = size * rnd(0.6, 1.4), spin = rnd(-7, 7)
            let isPaw = i % 3 == 0
            let pts = [(-1.4, 0.1), (-0.6, -0.7), (1.2, -0.45), (1.5, 0.15), (0.4, 0.75)].map { ($0.0 * rnd(0.8, 1.2), $0.1 * rnd(0.8, 1.2)) }
            add(life * rnd(0.7, 1)) { g, k, t in
                let sc = s * (1 - inn(clamp((k - 0.6) / 0.4)))
                g.translateBy(x: x + cos(a) * v * t, y: y + sin(a) * v * t + grav * t * t)
                g.rotate(by: .radians(spin * t + a))
                if isPaw {
                    let w = sc * 2.9
                    g.sakugaShape(PawShape().path(in: CGRect(x: -w / 2, y: -w / 2, width: w, height: w)), line: 1, off: sc * 0.3, fill: SakugaInk.cherry)
                } else {
                    var p = Path()
                    for (q, u) in pts.enumerated() { q == 0 ? p.move(to: pt(u.0 * sc, u.1 * sc)) : p.addLine(to: pt(u.0 * sc, u.1 * sc)) }
                    p.closeSubpath()
                    g.sakugaShape(p, line: 1.1, off: sc * 0.45)
                }
            }
        }
    }

    func ring(_ x: Double, _ y: Double, rx: Double = 40, ry: Double = 12, life: Double = 0.5, w: Double = 5) {
        add(life) { g, k, _ in
            let s = 0.3 + out(k), lw = w * (1 - k)
            let e = Path(ellipseIn: CGRect(x: x - rx * s, y: y - ry * s, width: rx * s * 2, height: ry * s * 2))
            g.stroke(e, with: .color(SakugaInk.line), lineWidth: lw + 2.4)
            if lw > 0.3 { g.stroke(e, with: .color(SakugaInk.fill), lineWidth: lw) }
        }
    }

    /// A splash crown with flying drops.
    func splash(_ x: Double, _ y: Double, w: Double = 34, h: Double = 26, life: Double = 0.7) {
        let n = 7
        let tongues = (0..<n).map { i in
            let u = Double(i) / Double(n - 1) - 0.5
            return (u: u, h: h * rnd(0.55, 1.1) * (1 - abs(u) * 0.7), lean: rnd(-0.4, 0.4), d: rnd(0, 0.14))
        }
        add(life) { g, k, _ in
            var p = Path()
            p.move(to: pt(x - w * 0.62, y))
            for s in tongues {
                let kk = clamp((k - s.d) / 0.8), up = sin(kk * .pi) * s.h * (1 - kk * 0.25), bx = x + s.u * w, half = w / Double(n) * 0.62
                let tx = bx + (s.u * 1.6 + s.lean) * up * 0.5
                p.addQuadCurve(to: pt(tx, y - up), control: pt(bx - half, y - up * 0.25))
                p.addQuadCurve(to: pt(bx + half, y), control: pt(bx + half * 0.5, y - up * 0.3))
            }
            p.addLine(to: pt(x + w * 0.62, y))
            p.closeSubpath()
            g.sakugaShape(p, line: 1.4, off: 4)
        }
        for _ in 0..<7 {
            let a = -Double.pi / 2 + rnd(-1.1, 1.1), v = rnd(100, 210), r0 = rnd(2, 4)
            add(life * rnd(0.8, 1.15)) { g, k, t in
                let r = r0 * (1 - inn(clamp((k - 0.6) / 0.4)))
                guard r > 0.5 else { return }
                g.translateBy(x: x + cos(a) * v * t, y: y - 6 + sin(a) * v * t + 520 * t * t)
                g.rotate(by: .radians(atan2(sin(a) * v + 1040 * t, cos(a) * v)))
                var d = Path()
                d.move(to: pt(-r * 2.6, 0))
                d.addQuadCurve(to: pt(r * 0.5, -r * 0.9), control: pt(-r * 0.6, -r * 1.05))
                d.addArc(center: pt(r * 0.4, 0), radius: r * 0.95, startAngle: .radians(-1.4), endAngle: .radians(1.4), clockwise: false)
                d.addQuadCurve(to: pt(-r * 2.6, 0), control: pt(-r * 0.6, r * 1.05))
                g.sakugaShape(d, line: 1, off: r * 0.5)
            }
        }
    }

    /// A slash: a crescent whose head races ahead and whose tail catches up.
    func slash(_ x: Double, _ y: Double, len: Double = 110, ang: Double = -0.5, life: Double = 0.42, thick: Double = 15, color: Color = SakugaInk.accent) {
        let R = len * 0.9, cx = x - cos(ang - .pi / 2) * R * 0.86, cy = y - sin(ang - .pi / 2) * R * 0.86, a0 = ang - .pi / 2 - 0.62, sweep = 1.24
        add(life) { g, k, _ in
            let head = out(clamp(k / 0.42)), tail = inn(clamp((k - 0.22) / 0.78))
            guard head - tail > 0.01 else { return }
            func crescent(_ T: Double) -> Path {
                var p = Path()
                let N = 26
                for i in 0...N {
                    let a = a0 + sweep * (tail + (head - tail) * Double(i) / Double(N)), q = pt(cx + cos(a) * R, cy + sin(a) * R)
                    i == 0 ? p.move(to: q) : p.addLine(to: q)
                }
                for i in stride(from: N, through: 0, by: -1) {
                    let u = Double(i) / Double(N), a = a0 + sweep * (tail + (head - tail) * u), rr = R - T * pow(max(0, sin(u * .pi)), 0.7)
                    p.addLine(to: pt(cx + cos(a) * rr, cy + sin(a) * rr))
                }
                p.closeSubpath()
                return p
            }
            g.fill(crescent(thick), with: .color(color))
            g.fill(crescent(thick * 0.42), with: .color(SakugaInk.fill))
            g.stroke(crescent(thick), with: .color(SakugaInk.line), lineWidth: 1.3)
        }
    }

    /// Ours: a swipe of claws, three slashes side by side.
    func claws(_ x: Double, _ y: Double, len: Double = 120, ang: Double = -0.5, thick: Double = 10, life: Double = 0.46, gap: Double = 16) {
        for i in 0..<3 {
            let o = Double(i - 1) * gap
            later(i * 28) {
                self.slash(x - sin(ang) * o, y + cos(ang) * o, len: len * (i == 1 ? 1.1 : 0.92), ang: ang, life: life, thick: thick, color: i == 1 ? SakugaInk.cherry : SakugaInk.accent)
            }
        }
    }

    /// Speed lines.
    func lines(_ x: Double, _ y: Double, n: Int = 7, dir: Double = .pi, len: Double = 46, spread: Double = 26, life: Double = 0.3) {
        for _ in 0..<n {
            let o = rnd(-spread, spread), l = len * rnd(0.5, 1.3), d = rnd(0, 0.25), w = rnd(1, 2.6)
            add(life) { g, k, _ in
                let kk = clamp((k - d) / (1 - d))
                guard kk > 0 else { return }
                let a = out(kk), b = inn(kk), px = x - sin(dir) * o, py = y + cos(dir) * o
                var p = Path()
                p.move(to: pt(px + cos(dir) * l * b * 1.4, py + sin(dir) * l * b * 1.4))
                p.addLine(to: pt(px + cos(dir) * l * (0.2 + a * 1.2), py + sin(dir) * l * (0.2 + a * 1.2)))
                g.stroke(p, with: .color(SakugaInk.line), style: StrokeStyle(lineWidth: w * (1 - b), lineCap: .round))
            }
        }
    }

    /// Little wedges that point at something and fly off it, like whiskers.
    func ticks(_ x: Double, _ y: Double, n: Int = 3, r: Double = 16, len: Double = 9, dir: Double = -0.9, life: Double = 0.4, fan: Double = 0.42) {
        add(life) { g, k, _ in
            let a = out(clamp(k / 0.5)), b = inn(clamp((k - 0.4) / 0.6))
            var p = Path()
            for i in 0..<n {
                let an = dir + (Double(i) - Double(n - 1) / 2) * fan, r0 = r + len * b * 1.25, r1 = r + len * a * 1.25, hw = 0.07 + 2.2 / (r1 + 8)
                guard r1 - r0 > 0.6 else { continue }
                p.move(to: pt(x + cos(an) * r0, y + sin(an) * r0))
                p.addLine(to: pt(x + cos(an - hw) * r1, y + sin(an - hw) * r1))
                p.addLine(to: pt(x + cos(an + hw) * r1, y + sin(an + hw) * r1))
                p.closeSubpath()
            }
            g.fill(p, with: .color(SakugaInk.accent))
        }
    }

    /// A smoke ring that drifts off, with a cat's ears.
    func donut(_ x: Double, _ y: Double, r: Double = 20, vx: Double = 30, vy: Double = -50, life: Double = 1, tilt: Double = -0.25) {
        let ph = rnd(0, tau)
        add(life) { g, k, t in
            let s = back(clamp(t / 0.22)) * (1 - inn(clamp((k - 0.6) / 0.4)))
            guard s > 0.03 else { return }
            let hole = 0.42 + 0.22 * k
            g.translateBy(x: x + vx * out(k) * life, y: y + vy * out(k) * life)
            g.rotate(by: .radians(tilt))
            for side in [-1.0, 1.0] {
                var ear = Path()
                ear.move(to: pt(side * r * s * 0.86, -r * s * 0.22))
                ear.addLine(to: pt(side * r * s * 0.8, -r * s * 0.92))
                ear.addLine(to: pt(side * r * s * 0.3, -r * s * 0.46))
                ear.closeSubpath()
                g.sakugaShape(ear, line: 1.4, off: 2)
            }
            var p = Path()
            for (m, bump) in [(1.0, 0.09), (hole, 0.05)] {
                for i in 0...48 {
                    let a = Double(i) / 48 * tau, rr = r * s * m * (1 + bump * sin(a * 9 + ph + t * 2)), q = pt(cos(a) * rr, sin(a) * rr * 0.56)
                    i == 0 ? p.move(to: q) : p.addLine(to: q)
                }
                p.closeSubpath()
            }
            g.sakugaShape(p, line: 1.5, off: r * 0.16, evenOdd: true)
        }
    }

    /// The two little arcs beside something that has just stopped.
    func wob(_ x: Double, _ y: Double, dir: Double = 1, r: Double = 16, life: Double = 0.45) {
        add(life) { g, k, _ in
            let w = 2.2 * (1 - k)
            guard w > 0.2 else { return }
            var p = Path()
            let c = dir > 0 ? 0 : Double.pi
            for d in [0.0, 7] {
                let rr = r + d + out(k) * 8
                p.move(to: pt(x - dir * r + cos(c - 0.45) * rr, y + sin(c - 0.45) * rr))
                p.addArc(center: pt(x - dir * r, y), radius: rr, startAngle: .radians(c - 0.45), endAngle: .radians(c + 0.45), clockwise: false)
            }
            g.stroke(p, with: .color(SakugaInk.line), lineWidth: w)
        }
    }

    /// A four-pointed glint.
    func kira(_ x: Double, _ y: Double, r: Double = 9, life: Double = 0.6) {
        add(life) { g, k, t in
            let s = r * pow(max(0, sin(k * .pi)), 0.6), q = s * 0.16
            g.translateBy(x: x, y: y)
            g.rotate(by: .radians(sin(t * 3) * 0.2))
            var p = Path()
            p.move(to: pt(0, -s))
            p.addQuadCurve(to: pt(s * 0.7, 0), control: pt(q, -q))
            p.addQuadCurve(to: pt(0, s), control: pt(q, q))
            p.addQuadCurve(to: pt(-s * 0.7, 0), control: pt(-q, q))
            p.addQuadCurve(to: pt(0, -s), control: pt(-q, -q))
            g.fill(p, with: .color(SakugaInk.fill))
            g.stroke(p, with: .color(SakugaInk.accent), lineWidth: 2)
        }
    }

    // MARK: Lettering

    enum Lettering { case solid, hollow, dotted, cherry }

    /// A sound-effect word. Lands a size too big and wobbles while it stays.
    func sfx(_ word: String, _ x: Double, _ y: Double, size: Double = 34, rot: Double = -0.14, life: Double = 0.95, style: Lettering = .solid) {
        let (fill, edge): (Color, Color) = switch style {
        case .solid: (SakugaInk.ink, SakugaInk.fill)
        case .hollow, .dotted: (SakugaInk.fill, SakugaInk.ink)
        case .cherry: (SakugaInk.cherry, SakugaInk.fill)
        }
        let font = Font.custom("Fredoka", fixedSize: size).weight(.bold)
        add(life) { g, k, t in
            let pop = 0.2 + 0.8 * LiquidMotion.spring(t, damping: 17, stiffness: 520)
            let sc = pop * (1 - inn(clamp((k - 0.86) / 0.14)))
            guard sc > 0.02 else { return }
            g.translateBy(x: x + sin(t * 31) * 0.8, y: y + cos(t * 27) * 0.8)
            g.rotate(by: .radians(rot + sin(t * 6) * 0.03))
            // Leaning and stretched, as if it were thrown.
            g.concatenate(CGAffineTransform(a: sc, b: 0, c: -0.26 * sc, d: sc * 1.18, tx: 0, ty: 0))
            let outline = g.resolve(Text(word).font(font).foregroundStyle(edge))
            let e = size * 0.075
            for i in 0..<16 {
                let a = Double(i) / 16 * tau
                g.draw(outline, at: pt(cos(a) * e, sin(a) * e))
            }
            // A drop shadow in ink, so it lifts off the page.
            if style == .dotted {
                g.draw(g.resolve(Text(word).font(font).foregroundStyle(SakugaInk.fill)), at: .zero)
                g.drawLayer { layer in
                    layer.clipToLayer { $0.draw(g.resolve(Text(word).font(font).foregroundStyle(.black)), at: .zero) }
                    let step = size * 0.15
                    var dots = Path()
                    for row in -8...8 {
                        for col in -26...26 {
                            let c = pt((Double(col) + (row % 2 == 0 ? 0 : 0.5)) * step, Double(row) * step)
                            dots.addEllipse(in: CGRect(x: c.x - step * 0.3, y: c.y - step * 0.3, width: step * 0.6, height: step * 0.6))
                        }
                    }
                    layer.fill(dots, with: .color(SakugaInk.cherry))
                }
            } else {
                g.draw(g.resolve(Text(word).font(font).foregroundStyle(fill)), at: .zero)
            }
        }
    }
}
