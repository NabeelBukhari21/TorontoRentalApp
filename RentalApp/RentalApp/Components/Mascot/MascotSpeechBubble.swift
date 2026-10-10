//
//  MascotSpeechBubble.swift
//  RentalApp
//
//  Mascot — What the cat says, and the cat-plus-bubble "guide" layout.
//
//  The bubble types its message out, Duolingo-style. Two details make
//  that feel polished rather than jittery:
//
//  • The bubble is sized by the FULL text from the first frame (an
//    invisible copy underneath does the layout), so it never grows or
//    reflows while the letters appear.
//  • VoiceOver reads the whole message at once, not character by character,
//    and Reduce Motion shows it immediately.
//

import SwiftUI

// MARK: - Bubble

struct MascotSpeechBubble: View {

    enum Tail {
        /// Points left, at a cat standing to the bubble's left.
        case leading
        /// Points down, at a cat below.
        case bottom
        /// Points up, at a cat (or clip) above.
        case top
    }

    /// Optional bold first line — a question or a headline.
    var title: String? = nil
    let message: String
    var tail: Tail = .leading
    var typesOut: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0

    private static let tailWidth: CGFloat = 12
    private static let tailHeight: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if let title {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack(alignment: .topLeading) {
                // Layout copy: reserves the final size so nothing reflows.
                Text(message).opacity(0)
                Text(String(Array(message).prefix(revealed)))
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(title == nil ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .padding(tailEdge, tail == .leading ? Self.tailWidth : Self.tailHeight * 0.7)
        .background {
            MascotBubbleShape(tail: tail, tailWidth: Self.tailWidth, tailHeight: Self.tailHeight)
                .fill(DS.Colors.surfaceRaised)
                .dsShadow(DS.Shadows.soft)
        }
        .overlay {
            MascotBubbleShape(tail: tail, tailWidth: Self.tailWidth, tailHeight: Self.tailHeight)
                .stroke(DS.Colors.outline, lineWidth: 1.5)
        }
        .task(id: message) { await typeOut() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, message].compactMap { $0 }.joined(separator: ". "))
    }

    /// The side the tail occupies, reserved so text never sits under it.
    private var tailEdge: Edge.Set {
        switch tail {
        case .leading: .leading
        case .bottom:  .bottom
        case .top:     .top
        }
    }

    private func typeOut() async {
        let count = message.count
        guard typesOut, !reduceMotion, count > 0 else {
            revealed = count
            return
        }
        revealed = 0
        // Faster for long lines, so every message lands in about a second.
        let step = max(12, min(28, 1100 / count))
        for index in 1...count {
            try? await Task.sleep(for: .milliseconds(step))
            if Task.isCancelled { return }
            revealed = index
        }
    }
}

// MARK: - Shape

/// A rounded rectangle with one continuous outline, tail included — so the
/// stroke has no seam where the tail joins the body.
struct MascotBubbleShape: Shape {

    var tail: MascotSpeechBubble.Tail
    var tailWidth: CGFloat
    var tailHeight: CGFloat
    var cornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var body = rect
        switch tail {
        case .leading: body.origin.x += tailWidth; body.size.width -= tailWidth
        case .bottom:  body.size.height -= tailHeight * 0.7
        case .top:     body.origin.y += tailHeight * 0.7; body.size.height -= tailHeight * 0.7
        }
        let r = min(cornerRadius, body.height / 2, body.width / 2)
        var p = Path()

        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        if tail == .top {
            // Tail centred, pointing up at whatever sits above the bubble.
            let tx = body.midX
            p.addLine(to: CGPoint(x: tx - tailWidth * 0.7, y: body.minY))
            p.addLine(to: CGPoint(x: tx, y: rect.minY))
            p.addLine(to: CGPoint(x: tx + tailWidth * 0.7, y: body.minY))
        }
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY),
                 tangent2End: CGPoint(x: body.maxX, y: body.minY + r), radius: r)
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY),
                 tangent2End: CGPoint(x: body.maxX - r, y: body.maxY), radius: r)

        if tail == .bottom {
            // Tail sits a third of the way in from the left, pointing down.
            let tx = body.minX + max(r + tailWidth, body.width * 0.28)
            p.addLine(to: CGPoint(x: tx + tailWidth * 0.8, y: body.maxY))
            p.addLine(to: CGPoint(x: tx - tailWidth * 0.2, y: rect.maxY))
            p.addLine(to: CGPoint(x: tx - tailWidth * 0.6, y: body.maxY))
        }

        p.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY),
                 tangent2End: CGPoint(x: body.minX, y: body.maxY - r), radius: r)

        if tail == .leading {
            // Tail near the bottom, pointing at the cat's head height when
            // the bubble sits beside it.
            let ty = body.maxY - max(r + tailHeight * 0.5, body.height * 0.32)
            p.addLine(to: CGPoint(x: body.minX, y: ty + tailHeight * 0.5))
            p.addLine(to: CGPoint(x: rect.minX, y: ty + tailHeight * 0.15))
            p.addLine(to: CGPoint(x: body.minX, y: ty - tailHeight * 0.5))
        }

        p.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY),
                 tangent2End: CGPoint(x: body.minX + r, y: body.minY), radius: r)
        p.closeSubpath()
        return p
    }
}

// MARK: - Guide

/// The cat with something to say: mascot on the left, bubble on the right.
/// The building block for onboarding, setup questions, the home greeting
/// and empty states.
struct MascotGuide: View {

    var mood: MascotMood = .happy
    var title: String? = nil
    let message: String
    var mascotSize: CGFloat = 104
    /// When false the cat steps out and the bubble points up instead — for
    /// screens where Purr is already on stage above (e.g. an animated clip).
    var showsMascot: Bool = true
    var onTapMascot: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
            if showsMascot {
                MascotView(mood: mood, size: mascotSize, onTap: onTapMascot)
                    // The canvas has headroom for raised arms; pull the bubble
                    // in so it sits beside the cat, not beside empty space.
                    .padding(.trailing, -mascotSize * 0.08)
                    .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
            }

            MascotSpeechBubble(title: title, message: message, tail: showsMascot ? .leading : .top)
                .padding(.bottom, showsMascot ? mascotSize * 0.22 : 0)
        }
        // Keep the guide's height steady while the cat comes and goes, so
        // the layout above and below doesn't jump.
        .frame(minHeight: mascotSize * 0.9, alignment: .bottom)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: showsMascot)
    }
}

#Preview("Guide") {
    VStack(spacing: DS.Spacing.xxl) {
        MascotGuide(mood: .happy, message: "Hi! I'll help you run your rentals — properties, tenants and repairs, all in one place.")
        MascotGuide(mood: .thinking, title: "What do you manage?", message: "I'll tailor your dashboard to your portfolio.")
        MascotSpeechBubble(message: "Bubble with a bottom tail.", tail: .bottom)
    }
    .padding()
    .background(DS.Colors.background)
}
