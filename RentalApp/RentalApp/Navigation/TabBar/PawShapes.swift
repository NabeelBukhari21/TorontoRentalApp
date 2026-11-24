//
//  PawShapes.swift
//  RentalApp (Purrperty)
//
//  Navigation — A cat's paw: the pad, and four toe beans over it.
//

import SwiftUI

/// The soft triangular pad.
struct PawPad: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        var path = Path()
        path.move(to: p(0.5, 0))
        path.addCurve(to: p(0.98, 0.62), control1: p(0.78, 0), control2: p(0.88, 0.34))
        path.addCurve(to: p(0.72, 1), control1: p(1.06, 0.86), control2: p(0.92, 1.02))
        path.addCurve(to: p(0.28, 1), control1: p(0.6, 0.97), control2: p(0.4, 0.97))
        path.addCurve(to: p(0.02, 0.62), control1: p(0.08, 1.02), control2: p(-0.06, 0.86))
        path.addCurve(to: p(0.5, 0), control1: p(0.12, 0.34), control2: p(0.22, 0))
        path.closeSubpath()
        return path
    }
}

/// The whole paw. `spread` pushes the toes out, 0…1.
struct PawShape: Shape {
    var spread: CGFloat = 0
    var animatableData: CGFloat {
        get { spread }
        set { spread = newValue }
    }

    /// Centre, size and tilt of each bean, in a unit square.
    static let beans: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, tilt: Double)] = [
        (0.13, 0.42, 0.21, 0.30, -24), (0.36, 0.18, 0.22, 0.33, -8), (0.64, 0.18, 0.22, 0.33, 8), (0.87, 0.42, 0.21, 0.30, 24),
    ]

    func path(in r: CGRect) -> Path {
        var path = PawPad().path(in: CGRect(x: r.minX + r.width * 0.19, y: r.minY + r.height * 0.44, width: r.width * 0.62, height: r.height * 0.54))
        for bean in Self.beans {
            let out = 1 + spread * 0.16
            let center = CGPoint(x: r.midX + (bean.x - 0.5) * r.width * out, y: r.midY + (bean.y - 0.5) * r.height * out)
            let size = CGSize(width: r.width * bean.w, height: r.height * bean.h)
            path.addPath(
                Path(ellipseIn: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
                    .applying(CGAffineTransform(rotationAngle: bean.tilt * .pi / 180))
                    .applying(CGAffineTransform(translationX: center.x, y: center.y))
            )
        }
        return path
    }
}

/// A bar with a dip in its top edge for something to sit in.
struct NotchedBar: Shape {
    var dip: CGFloat
    var radius: CGFloat = 34
    var animatableData: CGFloat {
        get { dip }
        set { dip = newValue }
    }

    func path(in r: CGRect) -> Path {
        let c = r.midX, half: CGFloat = 58
        var path = Path()
        path.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        path.addLine(to: CGPoint(x: c - half, y: r.minY))
        path.addCurve(to: CGPoint(x: c, y: r.minY + dip), control1: CGPoint(x: c - half * 0.5, y: r.minY), control2: CGPoint(x: c - half * 0.62, y: r.minY + dip))
        path.addCurve(to: CGPoint(x: c + half, y: r.minY), control1: CGPoint(x: c + half * 0.62, y: r.minY + dip), control2: CGPoint(x: c + half * 0.5, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        path.addArc(center: CGPoint(x: r.maxX - radius, y: r.minY + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        path.addArc(center: CGPoint(x: r.maxX - radius, y: r.maxY - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        path.addArc(center: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        path.addArc(center: CGPoint(x: r.minX + radius, y: r.minY + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
