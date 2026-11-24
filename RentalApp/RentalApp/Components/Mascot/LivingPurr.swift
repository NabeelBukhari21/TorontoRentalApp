//
//  LivingPurr.swift
//  RentalApp (Purrperty)
//
//  Components/Mascot — Purr, big and lit, for illustrated scenes: a
//  contact shadow under his feet, a soft one thrown behind him, a slight
//  turn with the scene's tilt, and a little hop whenever `beat` changes.
//

import SwiftUI

struct LivingPurr<Beat: Equatable>: View {

    let mood: PurrMood
    let size: CGFloat
    var showsFloor = true
    /// Changes when the scene moves on.
    let beat: Beat

    /// Purr is always drawn at this size and scaled to `size`: resizing
    /// the Rive canvas on every frame of a glide would drop frames.
    private static var canvas: CGFloat { 480 }

    @Environment(\.sceneTilt) private var tilt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            floor.opacity(showsFloor ? 1 : 0)
            PurrMascot(mood: mood, size: Self.canvas, isInteractive: false)
                .shadow(color: DS.Colors.groundShadow, radius: Self.canvas * 0.03, x: Self.canvas * 0.035, y: Self.canvas * 0.045)
                .keyframeAnimator(initialValue: 1.0, trigger: beat) { [reduceMotion] content, stretch in
                    content.scaleEffect(x: reduceMotion ? 1 : 2 - stretch, y: reduceMotion ? 1 : stretch, anchor: .bottom)
                } keyframes: { _ in
                    CubicKeyframe(0.93, duration: 0.14)
                    CubicKeyframe(1.06, duration: 0.2)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
                .rotation3DEffect(.degrees(tilt.width * 0.5), axis: (0, 1, 0))
                .offset(x: tilt.width * 0.35, y: tilt.height * 0.2)
        }
        .frame(width: Self.canvas, height: Self.canvas)
        .scaleEffect(size / Self.canvas)
        .allowsHitTesting(false)
    }

    private var floor: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let breath = reduceMotion ? 0 : sin(context.date.timeIntervalSinceReferenceDate * 2.2) * 0.04
            ZStack {
                Ellipse().fill(DS.Colors.groundShadow.opacity(0.75))
                    .frame(width: Self.canvas * 0.66, height: Self.canvas * 0.12)
                    .blur(radius: Self.canvas * 0.035)
                    .offset(x: Self.canvas * 0.06, y: Self.canvas * 0.47)
                Ellipse().fill(DS.Colors.groundShadow)
                    .frame(width: Self.canvas * 0.42 * (1 - breath), height: Self.canvas * 0.055)
                    .blur(radius: Self.canvas * 0.012)
                    .offset(y: Self.canvas * 0.465)
            }
        }
        .accessibilityHidden(true)
    }
}
