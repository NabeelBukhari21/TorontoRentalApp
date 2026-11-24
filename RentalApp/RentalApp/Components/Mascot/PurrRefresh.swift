//
//  PurrRefresh.swift
//  RentalApp (Purrperty)
//
//  Components/Mascot — Pull to refresh, with Purr: he stretches as you
//  pull, and pounces when you let go. VoiceOver gets a "Refresh" action.
//  Under Reduce Motion it's the system's own control.
//

import SwiftUI

private struct PurrRefresh: ViewModifier {

    let action: () async -> Void

    @State private var pull: CGFloat = 0
    @State private var isRefreshing = false
    @State private var isArmed = false
    @State private var isTouching = false
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far to pull, and the room Purr gets while it works.
    private static let threshold: CGFloat = 104
    private static let room: CGFloat = 92

    private var progress: CGFloat { min(1, max(0, pull / Self.threshold)) }

    func body(content: Content) -> some View {
        if reduceMotion {
            content.refreshable { await action() }
        } else {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: isRefreshing ? Self.room : 0)
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
                } action: { _, distance in
                    pull = distance
                    guard isTouching, !isRefreshing else { return }
                    let armed = distance > Self.threshold
                    if armed != isArmed {
                        isArmed = armed
                        if armed { feedback?.play(.stretch) }
                    }
                }
                .onScrollPhaseChange { _, phase in
                    isTouching = phase == .interacting || phase == .tracking
                    if !isTouching, isArmed { refresh() }
                }
                .overlay(alignment: .top) { purr }
                .accessibilityAction(named: "Refresh") { refresh() }
        }
    }

    @ViewBuilder private var purr: some View {
        if isRefreshing || pull > 8 {
            PurrMascot(mood: isRefreshing ? .zoomies : isArmed ? .pancake : .yogaStretch, size: 104, isInteractive: false)
                // Long and thin as he's pulled.
                .scaleEffect(
                    x: isRefreshing ? 1 : 1 - 0.12 * progress,
                    y: isRefreshing ? 1 : 0.7 + 0.45 * progress, anchor: .top
                )
                .opacity(isRefreshing ? 1 : Double(progress))
                .offset(y: isRefreshing ? -6 : min(pull, Self.threshold * 1.3) * 0.5 - 52)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isArmed = false
        feedback?.play(.pounce)
        withAnimation(DS.Motion.bouncy) { isRefreshing = true }
        Task {
            let began = ContinuousClock.now
            await action()
            // Long enough to see him run.
            let left = Duration.milliseconds(900) - (ContinuousClock.now - began)
            if left > .zero { try? await Task.sleep(for: left) }
            withAnimation(DS.Motion.smooth) { isRefreshing = false }
        }
    }
}

extension View {
    /// Pull to refresh with Purr, on a scroll view.
    func purrRefreshable(_ action: @escaping () async -> Void) -> some View {
        modifier(PurrRefresh(action: action))
    }
}
