//
//  SakugaControls.swift
//  RentalApp (Purrperty)
//
//  Components/Sakuga — Plain controls that react like anime. After Sakuga
//  VFX's twelve (see SakugaStage.swift for the licence); each squashes on
//  springs and throws drawn effects, with a cat's touch.
//

import Combine
import SwiftUI
import UIKit

// MARK: - Support

/// Where a control is on screen, for placing effects.
private struct TracksFrame: ViewModifier {
    @Binding var frame: CGRect
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }
}

private extension View {
    func tracksFrame(_ frame: Binding<CGRect>) -> some View { modifier(TracksFrame(frame: frame)) }

    /// Effects drawn behind a control, spilling past its edges.
    func sakugaBehind(_ stage: SakugaStage) -> some View {
        background { SakugaLayer(stage: stage).padding(-170) }
    }
}

private extension CGRect {
    var cx: Double { midX }
    var cy: Double { midY }
}

/// Paper card with an ink edge and a hard shadow.
private struct PaperCard: ViewModifier {
    var radius: CGFloat = 15
    var fill: Color = SakugaInk.fill
    var edge: Color = SakugaInk.ink
    var shadow: Color = SakugaInk.shade
    var drop: CGSize = CGSize(width: 5, height: 6)

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            // Behind, so what's inside can break out over the edge.
            .background(shape.fill(fill).strokeBorder(edge, lineWidth: 3))
            .background(shape.fill(shadow).offset(drop))
    }
}

extension View {
    fileprivate func paperCard(radius: CGFloat = 15, fill: Color = SakugaInk.fill, drop: CGSize = CGSize(width: 5, height: 6)) -> some View {
        modifier(PaperCard(radius: radius, fill: fill, drop: drop))
    }
}

private func manga(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { DS.Typography.brand(size, weight: weight, relativeTo: .headline) }

// MARK: - Button

/// Primary: squashes flat, inverts for a frame, and a paw burst goes off
/// behind it. Secondary: a small squash and three whiskers.
struct SakugaButton: View {
    let title: String
    var isPrimary = true
    var fire = 0
    var action: () -> Void = {}

    @State private var frame: CGRect = .zero
    @State private var behind = SakugaStage()
    @State private var isDown = false
    @State private var isInverted = false
    @State private var isDone = false
    @State private var squash: CGFloat = 1
    @State private var pop: CGFloat = 1
    @State private var tilt: Double = 0
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback

    var body: some View {
        Button(action: hit) {
            HStack(spacing: 8) {
                Text(title).italic()
                if isDone { Image(systemName: "pawprint.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(SakugaInk.accent).transition(.scale(scale: 0.1)) }
            }
            .font(manga(21))
            .foregroundStyle(isInverted ? SakugaInk.fill : isPrimary ? SakugaInk.fill : SakugaInk.ink)
            .padding(.horizontal, 30)
            .frame(minHeight: 54)
            .paperCard(fill: isInverted ? SakugaInk.ink : isPrimary ? SakugaInk.cherry : SakugaInk.fill, drop: isDown ? .zero : CGSize(width: 5, height: 6))
            .tracksFrame($frame)
            .scaleEffect(x: (1 + (1 - squash) * 0.24) * pop, y: squash * pop)
            .rotationEffect(.degrees(tilt))
        }
        .buttonStyle(Press(isDown: $isDown))
        .sakugaBehind(behind)
        .onChange(of: isDown) { _, down in
            withAnimation(.spring(response: 0.16, dampingFraction: 0.6)) { squash = down ? (isPrimary ? 0.55 : 0.74) : 1 }
            guard down, isPrimary, let stage else { return }
            stage.ticks(frame.cx, frame.minY - 6, n: 3, r: 4, len: 14, dir: -.pi / 2, fan: 0.5)
            stage.wob(frame.minX - 6, frame.cy, dir: -1, r: 10, life: 0.3)
            stage.wob(frame.maxX + 6, frame.cy, dir: 1, r: 10, life: 0.3)
        }
        .onChange(of: fire) { _, _ in
            isDown = true
            behind.later(200) {
                isDown = false
                hit()
            }
        }
    }

    private struct Press: ButtonStyle {
        @Binding var isDown: Bool
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.onChange(of: configuration.isPressed) { _, p in isDown = p }
        }
    }

    private func hit() {
        action()
        guard isPrimary else {
            feedback?.play(.tap)
            stage?.ticks(frame.maxX - 8, frame.minY - 4, n: 3, r: 5, len: 17, dir: -1.05, life: 0.5, fan: 0.36)
            return
        }
        feedback?.play(.stamp)
        let c = frame
        isInverted = true
        pop = 1.2
        tilt = -5
        squash = 0.62
        withAnimation(.spring(response: 0.36, dampingFraction: 0.38)) { pop = 1; tilt = 0; squash = 1 }
        // Behind, in its own space: the layer is 170 bigger all round.
        behind.burst(170 + c.width / 2, 170 + c.height / 2, r: 104, spikes: 17, life: 0.5)
        stage?.shards(c.cx, c.cy, n: 11, speed: 260, size: 8, life: 0.95, arc: 6.28, grav: 300)
        for (dx, dy) in [(-1.0, -0.5), (1.0, -1.0), (-1.0, 0.9), (1.0, 1.0)] {
            stage?.puff(c.cx + dx * (c.width / 2 + 6), c.cy + dy * 26, size: .random(in: 12...16), vx: dx * 46, vy: dy * 30 - 6, life: .random(in: 0.75...1.05))
        }
        stage?.sfx("POW!", c.cx + 8, c.minY - 52, size: 60, rot: -0.12, life: 1.05)
        stage?.ticks(c.cx - 96, c.cy - 70, n: 2, r: 4, len: 22, dir: -2.4, life: 0.45)
        stage?.ticks(c.cx + 110, c.cy - 60, n: 2, r: 4, len: 22, dir: -0.7, life: 0.45)
        behind.later(170) { isInverted = false }
        behind.later(220) {
            stage?.wob(c.minX - 8, c.cy, dir: -1)
            stage?.wob(c.maxX + 8, c.cy, dir: 1)
            stage?.donut(c.cx + 6, c.cy - 44, r: 26, vx: 22, vy: -52, life: 1.25)
            stage?.pawPuff(c.cx + 62, c.cy - 48, size: 15, rot: 0.3, vx: 34, vy: -40, life: 1.1)
        }
        behind.later(420) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { isDone = true }
            stage?.kira(c.maxX - 12, c.minY + 2, r: 14, life: 0.9)
        }
        behind.later(2200) { withAnimation { isDone = false } }
    }
}

// MARK: - Toggle

/// A painted flip: the knob smears across and throws up a splash. A paw is
/// stamped on the knob while it rests.
struct SakugaToggle: View {
    @Binding var isOn: Bool
    var label = "Toggle"

    @State private var current = 0
    @State private var playing: Task<Void, Never>?
    @State private var frame: CGRect = .zero
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let count = 43, columns = 8
    private static let cell = CGSize(width: 150, height: 162.5)

    var body: some View {
        Button { isOn.toggle() } label: {
            Image("SakugaToggle")
                .resizable()
                .frame(width: Self.cell.width * CGFloat(Self.columns), height: Self.cell.height * 6)
                .offset(x: -CGFloat(current % Self.columns) * Self.cell.width, y: -CGFloat(current / Self.columns) * Self.cell.height)
                .frame(width: Self.cell.width, height: Self.cell.height, alignment: .topLeading)
                .clipped()
                .overlay(alignment: .topLeading) {
                    if current == 0 || current >= 36 {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(current == 0 ? SakugaInk.shade : SakugaInk.cherry)
                            .position(x: current == 0 ? 48 : 107, y: 116)
                            .transition(.scale(scale: 0.3))
                    }
                }
                // The drawing is bigger than the switch.
                .frame(width: 108, height: 54)
                .offset(y: -34)
        }
        .buttonStyle(.plain)
        .tracksFrame($frame)
        .accessibilityRepresentation { Toggle(label, isOn: $isOn) }
        .onAppear { current = isOn ? Self.count - 1 : 0 }
        .onChange(of: isOn) { _, on in flip(on) }
    }

    private func flip(_ on: Bool) {
        feedback?.play(on ? .fill : .tap)
        playing?.cancel()
        guard !reduceMotion else { current = on ? Self.count - 1 : 0; return }
        playing = Task {
            let frames = on ? Array(0..<Self.count) : Array((0..<12).reversed())
            for f in frames {
                guard !Task.isCancelled else { return }
                if f == 18, on { stage?.sfx("SPLISH!", frame.cx + 4, frame.cy - 74, size: 30, rot: -0.16, life: 0.75, style: .cherry) }
                withAnimation(f >= 36 && f < 38 ? .spring(response: 0.3, dampingFraction: 0.5) : nil) { current = f }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }
}

// MARK: - Slider

/// The thumb is a paw; dragged fast, clouds roll up behind it, and it
/// leaves claw marks when you let go at speed.
struct SakugaSlider: View {
    @Binding var value: Double
    var label = "Slider"

    @State private var frame: CGRect = .zero
    @State private var speed: Double = 0
    @State private var peak: Double = 0
    @State private var carry: Double = 0
    @State private var lastMove = Date.distantPast
    @State private var lastWord = Date.distantPast
    @State private var isDragging = false
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width - 30
            ZStack(alignment: .leading) {
                Capsule().fill(SakugaInk.fill).overlay(Capsule().strokeBorder(SakugaInk.ink, lineWidth: 3)).frame(height: 13)
                Capsule().fill(SakugaInk.cherry).overlay(Capsule().strokeBorder(SakugaInk.ink, lineWidth: 3)).frame(width: 22 + w * value, height: 13)
                Circle().fill(SakugaInk.fill)
                    .overlay { Image(systemName: "pawprint.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(SakugaInk.cherry) }
                    .overlay(Circle().strokeBorder(SakugaInk.ink, lineWidth: 3))
                    .frame(width: 32, height: 32)
                    // Stretches into a teardrop.
                    .scaleEffect(x: 1 + min(0.9, abs(speed) * 0.22), y: 1 / sqrt(1 + min(0.9, abs(speed) * 0.22)), anchor: speed > 0 ? .trailing : .leading)
                    .offset(x: w * value - 1)
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(manga(15)).foregroundStyle(SakugaInk.ink)
                    .padding(.horizontal, 8).frame(height: 28)
                    .paperCard(radius: 9, drop: CGSize(width: 2, height: 3))
                    .rotationEffect(.degrees(max(-14, min(14, -speed * 5))))
                    .offset(x: w * value - 8, y: -38)
            }
            .frame(height: proxy.size.height)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { move(to: ($0.location.x - 15) / w) }
                    .onEnded { _ in release() }
            )
        }
        .frame(height: 44)
        .tracksFrame($frame)
        .accessibilityRepresentation { Slider(value: $value) { Text(label) } }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .sakugaDemoSlide)) { _ in
            Task {
                for target in [0.92, 0.12, 0.7] {
                    let from = value
                    for i in 1...16 {
                        move(to: from + (target - from) * LiquidMotion.easeOutCubic(Double(i) / 16))
                        try? await Task.sleep(for: .milliseconds(20))
                    }
                    release()
                    try? await Task.sleep(for: .milliseconds(760))
                }
            }
        }
        #endif
    }

    private var thumbX: Double { frame.minX + 15 + (frame.width - 30) * value }

    func move(to new: Double) {
        let new = max(0, min(1, new)), now = Date.now
        let dt = max(0.008, min(0.1, now.timeIntervalSince(lastMove)))
        let v = (new - value) / dt
        lastMove = now
        withAnimation(.interactiveSpring) {
            value = new
            speed = speed * 0.6 + v * 0.4
        }
        if abs(speed) > abs(peak) { peak = speed } else { peak *= 0.96 }
        guard abs(speed) > 0.35, let stage else { return }
        let dir = speed > 0 ? 1.0 : -1.0, big = min(1, abs(speed) / 2.4)
        carry += dt * abs(speed) * 20
        while carry > 1 {
            carry -= 1
            stage.puff(thumbX - dir * .random(in: 14...30), frame.cy - .random(in: 2...12) - big * 8, n: 4, size: .random(in: 6...9) + big * 9, vx: -dir * .random(in: 26...70), vy: -.random(in: 22...58) * (0.5 + big), life: .random(in: 0.7...1.15))
            stage.lines(thumbX - dir * 16, frame.cy + .random(in: -4...12), n: 1, dir: dir > 0 ? .pi : 0, len: 50 + big * 50, spread: 2, life: 0.24)
        }
        if abs(speed) > 1.5, now.timeIntervalSince(lastWord) > 1.1 {
            lastWord = now
            feedback?.play(.scrub)
            stage.sfx("ZOOM", thumbX - dir * 6, frame.cy - 78, size: 38, rot: -0.16, life: 0.75, style: .cherry)
        }
    }

    func release() {
        let dir = peak >= 0 ? 1.0 : -1.0
        if abs(peak) > 1.3, let stage {
            feedback?.play(.stamp)
            stage.claws(thumbX + dir * 40, frame.cy, len: 120, ang: dir > 0 ? 0 : .pi, thick: 9, life: 0.5, gap: 13)
            stage.burst(thumbX + dir * 4, frame.cy, r: 26, spikes: 11, life: 0.28)
            stage.ticks(thumbX + dir * 52, frame.cy - 30, n: 3, r: 4, len: 10, dir: dir > 0 ? -0.6 : -2.5)
            let x = thumbX
            stage.later(380) { stage.pawPuff(x - dir * 50, frame.cy - 30, size: 13, rot: -0.2) }
        }
        peak = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) { speed = 0 }
    }
}

// MARK: - Checkbox

/// Claws swipe the box, chips fly, and the tick draws itself.
struct SakugaCheckbox: View {
    let title: String
    @Binding var isOn: Bool
    @State private var frame: CGRect = .zero
    @State private var pop: CGFloat = 1
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.clear)
                    .frame(width: 34, height: 34)
                    .paperCard(radius: 9, fill: isOn ? SakugaInk.cherry : SakugaInk.fill, drop: CGSize(width: 4, height: 5))
                    .overlay {
                        TickMark().trim(from: 0, to: isOn ? 1 : 0)
                            .stroke(SakugaInk.fill, style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))
                            .padding(8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(isOn ? 0.14 : 0), value: isOn)
                    }
                    .scaleEffect(pop)
                    .tracksFrame($frame)
                Text(title).font(manga(18, .semibold)).foregroundStyle(DS.Colors.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .onChange(of: isOn) { _, on in
            pop = on ? 0.6 : 0.85
            withAnimation(.spring(response: 0.3, dampingFraction: 0.35)) { pop = 1 }
            guard let stage else { return }
            let c = frame
            guard on else { feedback?.play(.deselect); return stage.puff(c.cx, c.cy, n: 3, size: 7, life: 0.4) }
            feedback?.play(.stamp)
            stage.claws(c.cx + 6, c.cy, len: 130, ang: -0.42, thick: 10, life: 0.5, gap: 13)
            stage.lines(c.cx - 34, c.cy + 26, n: 6, dir: 2.75, len: 60, spread: 14)
            stage.shards(c.cx, c.cy, n: 7, speed: 190, size: 6, arc: 6.28, grav: 260)
            stage.sfx("SCRATCH!", c.cx + 62, c.cy - 58, size: 32, rot: -0.12, style: .dotted)
            stage.later(380) { stage.kira(c.cx + 24, c.cy - 22) }
        }
    }

    struct TickMark: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY + 1))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.36, y: r.maxY - 1))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + 1))
            return p
        }
    }
}

// MARK: - Radio

struct SakugaRadio: View {
    let options: [String]
    @Binding var selection: Int
    @State private var frames: [Int: CGRect] = [:]
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(options.indices, id: \.self) { i in
                Button { selection = i } label: {
                    HStack(spacing: 12) {
                        Circle().fill(SakugaInk.fill)
                            .overlay(Circle().strokeBorder(SakugaInk.ink, lineWidth: 3))
                            .overlay {
                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(SakugaInk.cherry)
                                    .scaleEffect(selection == i ? 1 : 0.01)
                                    .rotationEffect(.degrees(selection == i ? 0 : -90))
                                    .animation(.spring(response: 0.32, dampingFraction: 0.4), value: selection)
                            }
                            .frame(width: 30, height: 30)
                            .tracksFrame(Binding(get: { frames[i] ?? .zero }, set: { frames[i] = $0 }))
                        Text(options[i]).font(manga(18, .semibold)).foregroundStyle(DS.Colors.textPrimary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == i ? .isSelected : [])
            }
        }
        .onChange(of: selection) { _, i in
            feedback?.play(.select(i))
            guard let stage, let c = frames[i] else { return }
            stage.ticks(c.cx, c.cy, n: 4, r: 20, len: 15, dir: -2.3, life: 0.5, fan: 0.36)
            stage.lines(c.cx - 26, c.cy + 18, n: 3, dir: 2.6, len: 26, spread: 6)
            stage.pawPuff(c.cx + 30, c.cy - 24, size: 11, rot: 0.3, vx: 16, vy: -14, life: 0.75)
            stage.later(120) { stage.puff(c.cx + 88, c.cy + 2, n: 3, size: 7, vx: 10, vy: -10, life: 0.6) }
            stage.sfx("POP", c.cx + 78, c.cy - 46, size: 34, rot: 0.06, life: 0.8, style: .hollow)
        }
    }
}

// MARK: - Input

/// Every key kicks up dust where the caret is.
struct SakugaInput: View {
    let prompt: String
    @Binding var text: String
    @State private var frame: CGRect = .zero
    @State private var squeeze: CGFloat = 1
    @FocusState private var isFocused: Bool
    @Environment(\.sakuga) private var stage

    var body: some View {
        TextField(prompt, text: $text)
            .font(manga(18, .semibold))
            .foregroundStyle(SakugaInk.ink)
            .tint(SakugaInk.cherry)
            .focused($isFocused)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .paperCard()
            .scaleEffect(x: squeeze, y: 2 - squeeze)
            .tracksFrame($frame)
            .onChange(of: isFocused) { _, focused in
                guard focused else { return }
                bounce(1.03)
                stage?.ticks(frame.maxX - 6, frame.minY - 4, n: 3, r: 5, len: 17, dir: -1.05, life: 0.5, fan: 0.36)
            }
            .onChange(of: text) { old, new in
                guard old != new, let stage else { return }
                // Where the caret roughly is.
                let width = (new as NSString).size(withAttributes: [.font: UIFont(name: "Fredoka", size: 18) ?? .systemFont(ofSize: 18)]).width
                let x = min(frame.minX + 18 + width, frame.maxX - 16)
                bounce(0.985)
                stage.puff(x, frame.cy + 10, n: 2, size: .random(in: 4...6), vx: .random(in: -10...10), vy: -22, life: 0.4)
                if Bool.random() { stage.shards(x, frame.cy + 6, n: 2, speed: 110, size: 3, life: 0.5) }
                if new.hasSuffix(" ") || new.hasSuffix("!") { stage.pawPuff(x, frame.minY - 8, size: 8, rot: .random(in: -0.4...0.4), vy: -30, life: 0.7) }
            }
    }

    private func bounce(_ to: CGFloat) {
        squeeze = to
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { squeeze = 1 }
    }
}

// MARK: - Tabs

struct SakugaTabs: View {
    let titles: [String]
    @Binding var selection: Int
    @State private var frames: [Int: CGRect] = [:]
    @State private var lift: CGFloat = 1
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback

    var body: some View {
        HStack(spacing: 0) {
            ForEach(titles.indices, id: \.self) { i in
                Button { selection = i } label: {
                    Text(titles[i])
                        .font(manga(16))
                        .foregroundStyle(selection == i ? SakugaInk.fill : SakugaInk.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .tracksFrame(Binding(get: { frames[i] ?? .zero }, set: { frames[i] = $0 }))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == i ? .isSelected : [])
            }
        }
        .background { raised }
        .paperCard()
        .animation(.spring(response: 0.36, dampingFraction: 0.62), value: selection)
        .onChange(of: selection) { old, i in
            feedback?.play(.tabSelect)
            lift = 0.75
            withAnimation(.spring(response: 0.34, dampingFraction: 0.35).delay(0.14)) { lift = 1 }
            guard let stage, let c = frames[i] else { return }
            let dir = i > old ? 1.0 : -1.0
            stage.lines(c.cx - dir * c.width / 2, c.cy, n: 4, dir: dir > 0 ? .pi : 0, len: 34, spread: 10)
            stage.later(150) {
                stage.ticks(c.cx, c.minY - 22, n: 3, r: 4, len: 15, dir: -.pi / 2, life: 0.5, fan: 0.5)
                stage.puff(c.cx - dir * (c.width / 2 + 8), c.cy - 6, n: 4, size: 9, vx: -dir * 20, vy: -12, life: 0.7)
                stage.pawPuff(c.cx - dir * (c.width / 2 + 16), c.cy + 18, size: 8, rot: -0.3, vx: -dir * 14, vy: -6, life: 0.6)
            }
        }
    }

    /// The raised tab, with ears. One piece, so it slides.
    private var raised: some View {
        GeometryReader { proxy in
            let w = proxy.size.width / CGFloat(max(titles.count, 1))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SakugaInk.cherry)
                .strokeBorder(SakugaInk.ink, lineWidth: 3)
                .background(alignment: .top) {
                    EarsShape().fill(SakugaInk.cherry).stroke(SakugaInk.ink, lineWidth: 3).frame(width: 54, height: 17).offset(y: -13)
                }
                .frame(width: w, height: proxy.size.height + 10)
                .scaleEffect(y: lift, anchor: .bottom)
                .offset(x: w * CGFloat(selection), y: -5)
        }
    }

    struct EarsShape: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + 4, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + 19, y: r.maxY))
            p.move(to: CGPoint(x: r.maxX - 19, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX - 4, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            return p
        }
    }
}

// MARK: - Progress

/// A storm cloud with ears rides the leading edge; wisps tear off it, and
/// at the end a burst goes off.
struct SakugaProgress: View {
    /// 0…1.
    let value: Double
    @State private var shown: Double = 0
    @State private var frame: CGRect = .zero
    @State private var said = false
    @State private var isDone = false
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let lobes: [(x: Double, y: Double, r: Double)] = [
        (0, -0.95, 1), (0.78, -0.55, 0.74), (-0.72, -0.78, 0.72), (0.36, -1.7, 0.7), (-0.4, -1.62, 0.62), (1.1, -1.32, 0.52),
        (-1.18, -0.28, 0.52), (0.62, 0.3, 0.5), (-0.86, 0.5, 0.52), (-1.5, 0.82, 0.38), (-2.05, 1.0, 0.24), (0.16, 0.72, 0.4),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule().fill(SakugaInk.fill)
                .overlay(alignment: .leading) {
                    Capsule().fill(SakugaInk.cherry).frame(width: max(20, (frame.width) * shown))
                }
                .clipShape(.capsule)
                .overlay(Capsule().strokeBorder(SakugaInk.ink, lineWidth: 3))
                .frame(height: 22)
                .tracksFrame($frame)
                .overlay {
                    TimelineView(.animation(paused: reduceMotion || shown < 0.02 || isDone)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        Canvas { g, size in
                            guard shown > 0.015, !isDone else { return }
                            let S = 9 + 22 * sqrt(shown), lead = 120 + (size.width - 240) * shown, cy = size.height / 2
                            for side in [-1.0, 1.0] {
                                var ear = Path()
                                ear.move(to: CGPoint(x: lead + side * S * 0.95, y: cy - S * 1.5))
                                ear.addLine(to: CGPoint(x: lead + side * S * 0.85, y: cy - S * 2.75))
                                ear.addLine(to: CGPoint(x: lead + side * S * 0.15, y: cy - S * 2.0))
                                ear.closeSubpath()
                                g.sakugaShape(ear, line: 1.5, off: 2)
                            }
                            g.sakugaBlob(Self.lobes.enumerated().map { i, l in
                                let boil = 1 + 0.14 * sin(t * (1.6 + Double(i % 4) * 0.25) + Double(i)), roll = 0.85 + 0.2 * sin(t * 2.6 - Double(i) * 0.9)
                                return (lead + l.x * S, cy - 3 + l.y * S, l.r * S * boil * roll)
                            }, line: 1.6, lx: 1, arcs: true, deep: 1.7)
                        }
                    }
                    .padding(-120)
                    .allowsHitTesting(false)
                }
            Text(isDone ? "All done!" : shown.formatted(.percent.precision(.fractionLength(0))))
                .font(manga(18)).italic()
                .foregroundStyle(DS.Colors.textPrimary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(value.formatted(.percent.precision(.fractionLength(0))))
        .onChange(of: value, initial: true) { old, new in
            if new < old { said = false; isDone = false }
            withAnimation(.easeOut(duration: 0.4)) { shown = new }
            guard let stage else { return }
            let lead = frame.minX + frame.width * new
            if new > 0.05, new < 1 {
                let S = 10 + 25 * sqrt(new)
                if Bool.random() { stage.puff(lead - S * .random(in: 0.9...1.6), frame.minY - S * .random(in: 0.1...0.9), n: 2, size: .random(in: 3...5.5) + new * 3, vx: -.random(in: 40...90), vy: .random(in: -12...4), life: .random(in: 0.4...0.7)) }
                stage.lines(lead - S * 1.4, frame.minY - S * .random(in: 0.2...1.3), n: 1, dir: .pi, len: 50, spread: 3, life: 0.3)
            }
            if !said, new > 0.3, new < 0.9 {
                said = true
                stage.sfx("PURRRR…", frame.cx - 30, frame.minY - 70, size: 40, rot: -0.1, life: 2.2)
            }
            if new >= 1, !isDone {
                stage.later(320) { finish() }
            }
        }
    }

    private func finish() {
        isDone = true
        feedback?.play(.celebrate)
        guard let stage else { return }
        let x = frame.maxX - 60
        stage.burst(x, frame.cy, r: 84, spikes: 15, life: 0.5, paw: true)
        stage.shards(x, frame.cy, n: 11, speed: 270, size: 7, life: 0.9, arc: 6.28)
        for i in 0..<7 {
            let a = Double(i) / 7 * 6.28
            stage.puff(x + cos(a) * 66, frame.cy + sin(a) * 32, n: 4, size: .random(in: 8...12), vx: cos(a) * 46, vy: sin(a) * 30 - 8, life: .random(in: 0.6...1))
        }
        stage.sfx("MEOW!", frame.cx - 20, frame.minY - 58, size: 58, rot: -0.12, life: 1.2)
    }
}

// MARK: - Rating

/// Paws instead of stars, lighting one after another.
struct SakugaRating: View {
    @Binding var score: Int
    @State private var frames: [Int: CGRect] = [:]
    @State private var lit = 0
    @State private var pops: [Int: CGFloat] = [:]
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { i in
                Button { score = i + 1 } label: {
                    PawShape(spread: i < lit ? 0.5 : 0)
                        .fill(i < lit ? SakugaInk.accent : SakugaInk.fill)
                        .overlay(PawShape(spread: i < lit ? 0.5 : 0).stroke(SakugaInk.ink, lineWidth: 2.6))
                        .frame(width: 42, height: 42)
                        .scaleEffect(pops[i] ?? 1)
                        .tracksFrame(Binding(get: { frames[i] ?? .zero }, set: { frames[i] = $0 }))
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(score) of 5")
        .accessibilityAdjustableAction { score = max(1, min(5, score + ($0 == .increment ? 1 : -1))) }
        .onChange(of: score) { old, n in
            guard n > lit else { withAnimation { lit = n }; return }
            for i in lit..<n {
                stage?.later((i - lit) * 70) { light(i, last: i == n - 1, all: n == 5) }
            }
            if stage == nil { lit = n }
        }
    }

    private func light(_ i: Int, last: Bool, all: Bool) {
        lit = i + 1
        pops[i] = 0.35
        withAnimation(.spring(response: 0.32, dampingFraction: 0.35)) { pops[i] = 1 }
        feedback?.play(.select(i))
        guard let stage, let c = frames[i] else { return }
        stage.puff(c.cx, c.cy + 14, n: 2, size: 5, life: 0.4)
        guard last else { return }
        stage.ticks(c.cx, c.cy, n: 9, r: 24, len: all ? 26 : 17, dir: -.pi / 2, life: 0.55, fan: 0.698)
        if all {
            stage.burst(c.cx, c.cy, r: 46, life: 0.4, paw: true)
            stage.shards(c.cx, c.cy, n: 8, size: 5, arc: 6.28)
        }
        stage.sfx(all ? "PURRFECT!" : "NICE", c.cx - (all ? 70 : 10), c.cy - 58, size: all ? 40 : 32, rot: 0.05, life: 1, style: .hollow)
        stage.later(300) { stage.kira(c.cx - 22, c.cy - 30, r: 8) }
    }
}

// MARK: - Toast

/// Streaks in as a smear and lands in dust.
struct SakugaToast: View {
    let message: String
    @Binding var isShown: Bool
    @State private var x: CGFloat = -420
    @State private var smear: CGFloat = 1.6
    @State private var shrink: CGFloat = 1
    @State private var frame: CGRect = .zero
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "pawprint.fill").foregroundStyle(SakugaInk.cherry)
            Text(message).foregroundStyle(SakugaInk.ink)
        }
        .font(manga(18))
        .padding(.horizontal, 20)
        .frame(height: 56)
        .paperCard()
        .tracksFrame($frame)
        .scaleEffect(x: smear * shrink, y: shrink / sqrt(smear), anchor: .trailing)
        .offset(x: x)
        .opacity(shrink < 0.05 ? 0 : 1)
        .onChange(of: isShown) { _, shown in shown ? enter() : leave() }
    }

    private func enter() {
        x = -420; smear = 1.7; shrink = 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) { x = 0 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.4).delay(0.2)) { smear = 1 }
        guard let stage else { return }
        let c = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
        stage.lines(c.minX + 40, c.cy, n: 6, dir: .pi, len: 90, spread: 16, life: 0.3)
        stage.later(230) {
            feedback?.play(.stamp)
            stage.lines(c.minX - 4, c.cy, n: 9, dir: .pi, len: 70, spread: 18, life: 0.4)
            for u in [-0.5, -0.36, -0.2] { stage.puff(c.cx + c.width * u, c.maxY + 4, n: 4, size: .random(in: 8...12), vx: -.random(in: 10...30), vy: -8, life: .random(in: 0.7...1)) }
            stage.pawPuff(c.maxX + 10, c.cy + 8, size: 10, rot: 0.3, vx: 20, life: 0.7)
            stage.shards(c.minX, c.cy + 12, n: 4, size: 4, dir: .pi + 0.5, arc: 1.6)
            stage.sfx("SKRRT!", c.cx - 34, c.minY - 34, size: 40, rot: -0.1, style: .dotted)
            stage.wob(c.maxX + 6, c.cy, dir: 1)
        }
    }

    private func leave() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { shrink = 0.01 }
        stage?.puff(frame.cx, frame.cy, n: 4, size: 9, life: 0.5)
        stage?.later(300) { x = -420 }
    }
}

// MARK: - Tooltip

struct SakugaTooltip: View {
    let hint: String
    @Binding var isOpen: Bool
    @State private var frame: CGRect = .zero
    @State private var tip: CGRect = .zero
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback

    var body: some View {
        Button { isOpen.toggle() } label: {
            Text("?").font(manga(22)).foregroundStyle(SakugaInk.fill)
                .frame(width: 46, height: 46)
                .paperCard(radius: 23, fill: SakugaInk.cherry, drop: CGSize(width: 3, height: 4))
                .tracksFrame($frame)
        }
        .buttonStyle(SquishStyle(scale: 0.78))
        .accessibilityLabel("Help")
        .accessibilityHint(hint)
        .overlay(alignment: .top) {
            Text(hint)
                .font(manga(16, .semibold)).foregroundStyle(SakugaInk.ink)
                .fixedSize()
                .padding(.horizontal, 18).frame(height: 48)
                .paperCard(radius: 24)
                .tracksFrame($tip)
                .scaleEffect(isOpen ? 1 : 0.01, anchor: .bottom)
                .offset(y: -64)
                .animation(.spring(response: 0.34, dampingFraction: 0.45), value: isOpen)
                .allowsHitTesting(false)
        }
        .onChange(of: isOpen) { _, open in
            guard open, let stage else { return }
            feedback?.play(.tap)
            stage.later(120) {
                let c = tip
                stage.puff(c.minX - 8, c.cy - 12, n: 4, size: 8, vx: -14, vy: -10)
                stage.pawPuff(c.maxX + 12, c.cy + 8, size: 10, rot: 0.3, vx: 14, vy: -6)
                stage.ticks(c.maxX - 2, c.minY - 6, n: 3, r: 5, len: 16, dir: -1, life: 0.5, fan: 0.36)
                stage.ring(frame.cx, frame.minY - 3, rx: 22, ry: 5, life: 0.5, w: 3)
                stage.sfx("PSST!", c.cx + 6, c.minY - 26, size: 34, rot: -0.08, life: 0.85, style: .hollow)
            }
        }
    }
}
