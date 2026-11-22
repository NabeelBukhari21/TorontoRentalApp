//
//  LiquidMotion.swift
//  RentalApp (Purrperty)
//
//  Components/Motion — The "liquid morph" toolkit: time-based springs and
//  easing, a rippling blob path, and a gooey drawing layer.
//
//  The launch and welcome motion was designed in Remotion
//  (tools/motion). These helpers use the same maths, so a timeline can
//  be ported second for second: `LiquidMotion.spring` is the same
//  mass–spring–damper Remotion's `spring()` solves, and `liquidLayer` is
//  the SVG blur + alpha-contrast filter as a Canvas layer.
//

import SwiftUI

// MARK: - Timing

enum LiquidMotion {

    /// A spring's position at `t` seconds after it starts, settling at 1.
    /// Zero before it starts. Parameters match Remotion's `spring()`.
    static func spring(_ t: Double, damping: Double = 10, stiffness: Double = 100, mass: Double = 1) -> Double {
        guard t > 0 else { return 0 }
        let natural = (stiffness / mass).squareRoot()
        let ratio = damping / (2 * (stiffness * mass).squareRoot())
        if ratio < 1 {
            let damped = natural * (1 - ratio * ratio).squareRoot()
            let envelope = exp(-ratio * natural * t)
            return 1 - envelope * (cos(damped * t) + ratio * natural / damped * sin(damped * t))
        }
        // Critically damped or slower: no overshoot.
        return 1 - exp(-natural * t) * (1 + natural * t)
    }

    /// Linear 0…1 progress of `t` through `range`, clamped.
    static func progress(_ t: Double, from start: Double, to end: Double) -> Double {
        guard end > start else { return t >= end ? 1 : 0 }
        return min(1, max(0, (t - start) / (end - start)))
    }

    static func easeInCubic(_ p: Double) -> Double { p * p * p }

    static func easeOutCubic(_ p: Double) -> Double { 1 - pow(1 - p, 3) }

    /// Overshoots past 1 and settles back: a liquid "plop".
    static func easeOutBack(_ p: Double, overshoot s: Double = 1.7) -> Double {
        let q = p - 1
        return 1 + (s + 1) * q * q * q + s * q * q
    }

    static func mix(_ a: Double, _ b: Double, _ p: Double) -> Double { a + (b - a) * p }
}

// MARK: - Shapes

extension Path {

    /// A circle whose edge ripples with a few slow harmonics, so it reads
    /// as liquid rather than geometry. `time` drives the ripple.
    static func wobblyCircle(center: CGPoint, radius: CGFloat, time: Double, amount: Double = 0.04, points: Int = 72) -> Path {
        var path = Path()
        for i in 0...points {
            let a = Double(i) / Double(points) * .pi * 2
            let ripple = sin(a * 3 + time * 2.1) * 0.5 + sin(a * 5 - time * 1.7) * 0.3 + sin(a * 2 + time * 1.3) * 0.2
            let r = radius * (1 + amount * ripple)
            let point = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Gooey Layer

extension GraphicsContext {

    /// Draws into a layer that blurs everything, then keeps only what's
    /// above half opacity, in one colour. Shapes that touch fuse into one
    /// smooth blob and pull apart like liquid.
    func liquidLayer(color: Color, blur: CGFloat = 9, _ draw: (inout GraphicsContext) -> Void) {
        drawLayer { layer in
            layer.addFilter(.alphaThreshold(min: 0.5, color: color))
            layer.addFilter(.blur(radius: blur))
            draw(&layer)
        }
    }
}
