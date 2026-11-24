//
//  ButtonMotion.swift
//  RentalApp (Purrperty)
//
//  Components/Motion — How controls move: the press styles (each with its
//  cue), the jelly wobble and droplet burst of a picked answer, the sheen
//  that crosses a ready button, and the shake of a refused one. All of it
//  holds still under Reduce Motion.
//

import SwiftUI

// MARK: - Press Styles

/// A key-like button: a face on a darker edge that sinks when pressed,
/// squashing a little, and springs back past where it started.
struct PressableDepthStyle: ButtonStyle {
    var edge: Color
    var depth: CGFloat = 6
    var shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
    var cue: FeedbackCue = .press

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, edge: edge, depth: depth, shape: shape, cue: cue)
    }

    private struct Face: View {
        let configuration: Configuration
        let edge: Color
        let depth: CGFloat
        let shape: RoundedRectangle
        let cue: FeedbackCue

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let isDown = configuration.isPressed
            configuration.label
                .offset(y: isDown ? depth : 0)
                .background(shape.fill(edge).offset(y: depth))
                .contentShape(shape)
                .scaleEffect(x: isDown && !reduceMotion ? 1.025 : 1, y: isDown && !reduceMotion ? 0.965 : 1, anchor: .bottom)
                .animation(isDown ? .spring(response: 0.14, dampingFraction: 0.8) : .spring(response: 0.38, dampingFraction: 0.42), value: isDown)
                .cue(cue, whenPressed: isDown)
        }
    }
}

/// A floating thing that gives under the finger and bounces back.
struct SquishStyle: ButtonStyle {
    var scale: CGFloat = 0.9
    var cue: FeedbackCue = .tap

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, scale: scale, cue: cue)
    }

    private struct Face: View {
        let configuration: Configuration
        let scale: CGFloat
        let cue: FeedbackCue
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let isDown = configuration.isPressed
            configuration.label
                .scaleEffect(isDown && !reduceMotion ? scale : 1)
                .opacity(isDown && reduceMotion ? 0.7 : 1)
                .animation(isDown ? .spring(response: 0.16, dampingFraction: 0.8) : .spring(response: 0.42, dampingFraction: 0.4), value: isDown)
                .cue(cue, whenPressed: isDown)
        }
    }
}

private struct PressCue: ViewModifier {
    let cue: FeedbackCue
    let isPressed: Bool
    @Environment(\.feedback) private var feedback

    func body(content: Content) -> some View {
        content.onChange(of: isPressed) { _, pressed in
            if pressed { feedback?.play(cue) }
        }
    }
}

extension View {
    func cue(_ cue: FeedbackCue, whenPressed isPressed: Bool) -> some View {
        modifier(PressCue(cue: cue, isPressed: isPressed))
    }
}

// MARK: - Jelly

private struct Jelly<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    /// Wide things need less, or they spill out of their row.
    let strength: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { [reduceMotion, strength] view, amount in
            let wobble = amount * strength
            view.scaleEffect(x: reduceMotion ? 1 : 1 + wobble, y: reduceMotion ? 1 : 1 - wobble / max(strength, 0.1))
        } keyframes: { _ in
            CubicKeyframe(0.07, duration: 0.09)
            CubicKeyframe(-0.055, duration: 0.12)
            CubicKeyframe(0.03, duration: 0.12)
            SpringKeyframe(0, duration: 0.3, spring: .bouncy)
        }
    }
}

// MARK: - Shake

private struct Shake: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(0), trigger: trigger) { [reduceMotion] view, x in
            view.offset(x: reduceMotion ? 0 : x)
        } keyframes: { _ in
            for x in [-10.0, 9, -7, 5, -2, 0] {
                CubicKeyframe(CGFloat(x), duration: 0.07)
            }
        }
    }
}

extension View {
    /// Wobbles like jelly each time `trigger` changes.
    func jelly(on trigger: some Equatable, strength: Double = 1) -> some View {
        modifier(Jelly(trigger: trigger, strength: strength))
    }

    /// Shakes its head each time `trigger` changes.
    func shake(on trigger: Int) -> some View { modifier(Shake(trigger: trigger)) }
}

// MARK: - Droplet Burst

/// Drops of liquid thrown out when something is picked.
struct DropletBurst: View {
    let isOn: Bool
    let color: Color
    let radius: CGFloat

    @State private var bursts = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let count = 10

    var body: some View {
        ZStack {
            ForEach(0..<Self.count, id: \.self) { i in
                let angle = Double(i) / Double(Self.count) * 2 * .pi + 0.3
                // Alternate near and far, so it reads as a splash, not a ring.
                let reach = radius * (i.isMultiple(of: 2) ? 1 : 0.76)
                Circle()
                    .fill(color)
                    .frame(width: i.isMultiple(of: 2) ? 9 : 6)
                    .keyframeAnimator(initialValue: 1.0, trigger: bursts) { drop, p in
                        drop
                            .scaleEffect(1 - p)
                            .offset(x: cos(angle) * reach * (0.35 + 0.65 * p), y: sin(angle) * reach * (0.35 + 0.65 * p) + 14 * p * p)
                    } keyframes: { _ in
                        MoveKeyframe(0)
                        CubicKeyframe(0.75, duration: 0.26)
                        CubicKeyframe(1, duration: 0.3)
                    }
            }
        }
        .opacity(reduceMotion ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isOn) { _, on in if on { bursts += 1 } }
    }
}

// MARK: - Sheen

private struct Sheen: ViewModifier {
    let isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds between sweeps, and how long one takes.
    private static let period = 3.6, sweep = 0.9

    func body(content: Content) -> some View {
        content.overlay {
            if isOn, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 60)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.sweep
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 54)
                            .rotationEffect(.degrees(18))
                            .scaleEffect(y: 1.8)
                            .offset(x: -80 + (proxy.size.width + 140) * min(t, 1.2))
                    }
                }
                .clipShape(.capsule)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    /// Light crossing a capsule button now and then: "I'm ready".
    func sheen(isOn: Bool) -> some View { modifier(Sheen(isOn: isOn)) }
}
