//
//  SlideToFinish.swift
//  RentalApp (Purrperty)
//
//  Components/Core — Drag the paw across to finish something that matters,
//  and the paw stamp that lands on it. VoiceOver gets a plain button.
//

import SwiftUI

struct SlideToFinish: View {

    let title: String
    let action: () async -> Void

    @State private var drag: CGFloat = 0
    @State private var isWorking = false
    @State private var isPastEnd = false
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let knob: CGFloat = 56
    private static let inset: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let reach = max(1, proxy.size.width - Self.knob - Self.inset * 2)
            let progress = min(1, max(0, drag / reach))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.Colors.surfaceRaised.shadow(.inner(color: DS.Colors.groundShadow, radius: 5, y: 3)))
                // Liquid follows the paw.
                Capsule()
                    .fill(LinearGradient(colors: [DS.Colors.accentMint.opacity(0.35), DS.Colors.accentMint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: drag + Self.knob + Self.inset * 2)
                Text(title)
                    .font(DS.Typography.brand(18, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - progress * 1.4)
                    .padding(.leading, Self.knob)

                ZStack {
                    Circle().fill(.clay(DSAccent.mint.fill, shade: DSAccent.mint.ink, size: Self.knob))
                    if isWorking {
                        ProgressView().tint(DS.Colors.textOnAccent)
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(DS.Colors.textOnAccent)
                            .rotationEffect(.degrees(progress * 90))
                    }
                }
                .frame(width: Self.knob, height: Self.knob)
                .shadow(color: DS.Colors.groundShadow, radius: 6, y: 4)
                .scaleEffect(isPastEnd ? 1.12 : 1)
                .offset(x: drag + Self.inset)
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            guard !isWorking else { return }
                            drag = min(reach, max(0, value.translation.width))
                            let past = drag > reach * 0.92
                            if past != isPastEnd {
                                isPastEnd = past
                                if past { feedback?.play(.stretch) }
                            }
                        }
                        .onEnded { _ in release(reach) }
                )
            }
            .animation(.interactiveSpring, value: drag)
        }
        .frame(height: Self.knob + Self.inset * 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finish() }
    }

    private func release(_ reach: CGFloat) {
        guard !isWorking else { return }
        guard isPastEnd else {
            withAnimation(DS.Motion.bouncy) { drag = 0 }
            return
        }
        withAnimation(DS.Motion.snappy) { drag = reach }
        finish()
    }

    private func finish() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await action()
            isWorking = false
            isPastEnd = false
            withAnimation(DS.Motion.bouncy) { drag = 0 }
        }
    }
}

// MARK: - Paw Stamp

/// "DONE", stamped with a paw.
struct PawStamp: View {

    var text = "DONE"
    @State private var hasLanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "pawprint.fill").font(.system(size: 46, weight: .black))
            Text(text).font(DS.Typography.brandFixed(20))
        }
        .foregroundStyle(DSAccent.mint.ink)
        .padding(16)
        .background(Circle().strokeBorder(DSAccent.mint.ink, style: StrokeStyle(lineWidth: 5, dash: [14, 5])).aspectRatio(1, contentMode: .fill))
        .rotationEffect(.degrees(-14))
        .scaleEffect(hasLanded || reduceMotion ? 1 : 3.4)
        .opacity(hasLanded ? 0.92 : 0)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.26, dampingFraction: 0.55)) { hasLanded = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
