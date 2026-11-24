//
//  TabBarModel.swift
//  RentalApp (Purrperty)
//
//  Navigation — What the paw tab bar knows: which tab a finger is over,
//  and how the screen underneath is scrolling. Scrolling also ticks, like
//  a dial, with a firmer stop at each end.
//

import Observation
import SwiftUI

extension AppTab {
    /// Properties in the middle.
    static let pawOrder: [AppTab] = [.dashboard, .maintenance, .properties, .messages, .search]
}

@MainActor
@Observable
final class TabBarModel {

    /// The tab under a finger that's down on the bar.
    var hovered: AppTab?
    /// Scrolled down: the bar gets out of the way.
    private(set) var isCollapsed = false
    /// -1…1, how fast and which way the screen is scrolling.
    private(set) var energy: CGFloat = 0

    @ObservationIgnored var feedback: FeedbackPlayer?
    @ObservationIgnored private var lastOffset: CGFloat?
    @ObservationIgnored private var travel: CGFloat = 0
    @ObservationIgnored private var sinceTick: CGFloat = 0
    @ObservationIgnored private var lastTick = Date.distantPast
    @ObservationIgnored private var wasAtEnd = false
    @ObservationIgnored private var settle: Task<Void, Never>?

    /// Points of scrolling between ticks.
    private static let tickEvery: CGFloat = 92

    func scrolled(to offset: CGFloat, end: CGFloat) {
        defer { lastOffset = offset }
        guard let last = lastOffset else { return }
        let delta = offset - last
        // A jump is another screen, not a scroll.
        guard abs(delta) > 0.1, abs(delta) < 400 else { return }

        // Out of the way going down, back going up or near the top.
        travel = (travel > 0) == (delta > 0) ? travel + delta : delta
        let collapsed = offset < 20 ? false : travel > 36 ? true : travel < -24 ? false : isCollapsed
        if collapsed != isCollapsed { withAnimation(DS.Motion.bouncy) { isCollapsed = collapsed } }

        let target = max(-1, min(1, delta / 26))
        if abs(target - energy) > 0.08 { withAnimation(.interactiveSpring) { energy = target } }
        settle?.cancel()
        settle = Task {
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) { energy = 0 }
        }

        // Ticks, no faster than a hand can feel.
        sinceTick += abs(delta)
        let atEnd = offset <= 0 || offset >= end
        if atEnd, !wasAtEnd {
            feedback?.play(.scrollEnd)
        } else if !atEnd, sinceTick >= Self.tickEvery, Date.now.timeIntervalSince(lastTick) > 0.045 {
            sinceTick = 0
            lastTick = .now
            feedback?.play(.scrollTick(Float(min(1, abs(delta) / 30))))
        }
        wasAtEnd = atEnd
    }

    /// A different screen: its first report is a starting point.
    func reset() {
        lastOffset = nil
        travel = 0
        wasAtEnd = false
        withAnimation(DS.Motion.bouncy) { isCollapsed = false }
    }
}

// MARK: - Reporting

private struct ReportsScroll: ViewModifier {
    let model: TabBarModel?

    private struct Position: Equatable { let offset: CGFloat, end: CGFloat }

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: Position.self) { geometry in
            Position(offset: geometry.contentOffset.y + geometry.contentInsets.top,
                     end: max(1, geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom - geometry.containerSize.height))
        } action: { _, new in
            model?.scrolled(to: new.offset, end: new.end)
        }
    }
}

extension View {
    /// Tells the tab bar how this screen scrolls.
    func reportsScroll(to model: TabBarModel?) -> some View { modifier(ReportsScroll(model: model)) }
}
