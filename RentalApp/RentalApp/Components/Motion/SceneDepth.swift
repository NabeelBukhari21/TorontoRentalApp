//
//  SceneDepth.swift
//  RentalApp (Purrperty)
//
//  Components/Motion — Parallax for illustrated scenes: layers bob on
//  their own and shift with the scene's tilt, near ones most.
//

import SwiftUI

// MARK: - Depth

extension EnvironmentValues {
    /// How far the scene is tilted, in points. Front layers move most.
    @Entry var sceneTilt: CGSize = .zero
}

/// Floats a layer: it bobs on its own and shifts with the scene's tilt.
/// Negative depths sit behind Purr and move against it.
private struct FloatInDepth: ViewModifier {
    let depth: Double
    let phase: Double
    let bob: Double
    @Environment(\.sceneTilt) private var tilt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            content
                .rotationEffect(.degrees(sin(t * 0.9 + phase) * 4 * bob))
                .offset(
                    x: tilt.width * depth + (reduceMotion ? 0 : sin(t * 0.7 + phase) * 5 * bob),
                    y: tilt.height * depth + (reduceMotion ? 0 : cos(t * 1.1 + phase) * 7 * bob)
                )
        }
    }
}

extension View {
    func floating(depth: Double, phase: Double = 0, bob: Double = 1) -> some View {
        modifier(FloatInDepth(depth: depth, phase: phase, bob: bob))
    }
}

/// Dragging anywhere tilts the scene; letting go springs it back.
struct TiltScene<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var tilt: CGSize = .zero

    var body: some View {
        content
            .environment(\.sceneTilt, tilt)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        tilt = CGSize(width: max(-30, min(30, value.translation.width / 5)),
                                      height: max(-20, min(20, value.translation.height / 8)))
                    }
                    .onEnded { _ in withAnimation(.spring(response: 0.6, dampingFraction: 0.45)) { tilt = .zero } }
            )
    }
}
