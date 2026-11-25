//
//  DeckHome.swift — D: The deck. One thing at a time: the day dealt as big
//  cards. Throw one right to deal with it, left to leave it for later, and
//  when the deck is empty you're done.
//

#if DEBUG
import SwiftUI

struct DeckHome: View {
    let model: HomeStudioModel

    struct Card: Identifiable {
        let id: String
        let accent: DSAccent
        let symbol, kicker, value, line, action: String
        let mood: PurrMood
        let run: () -> Void
    }

    @State private var gone: Set<String> = []
    @State private var drag: CGSize = .zero
    @Environment(AppRouter.self) private var router
    @Environment(\.feedback) private var feedback

    private var cards: [Card] {
        guard !model.dashboard.isLoading else { return [] }
        var all = model.openTasks.sorted { $0.isUrgent && !$1.isUrgent }.prefix(3).map { task in
            Card(id: "task\(task.title)", accent: task.isUrgent ? .cherry : .sky, symbol: task.icon, kicker: task.isUrgent ? "Urgent" : "To do",
                 value: task.title, line: task.due, action: "Done", mood: task.isUrgent ? .urgentIssue : .tasksWaiting) { Task { await model.dashboard.toggleTask(task) } }
        }
        all.insert(Card(id: "rent", accent: .mint, symbol: "dollarsign", kicker: "Rent this month", value: model.dollars(model.roll.collected),
                        line: "of \(model.dollars(model.roll.expected)). \(model.roll.owingCount) still to pay.", action: "Open rent", mood: .moneyDance) { router.push(.rentCollection) }, at: min(1, all.count))
        all.append(Card(id: "repairs", accent: .blush, symbol: "wrench.and.screwdriver.fill", kicker: "Repairs", value: "\(model.requests) open",
                        line: "Sorted by urgency, vendors and all.", action: "See repairs", mood: .builder) { router.select(.maintenance) })
        all.append(Card(id: "homes", accent: .gold, symbol: "key.fill", kicker: "Homes", value: "\(model.dashboard.occupiedUnits) of \(model.dashboard.unitCount)",
                        line: "rented. \(model.dashboard.vacantUnits) empty right now.", action: "See homes", mood: .keysReady) { router.select(.properties) })
        return all
    }

    private var left: [Card] { cards.filter { !gone.contains($0.id) } }
    private var top: Card? { left.first }

    var body: some View {
        GeometryReader { proxy in
            TiltlessStack {
                VStack(spacing: 14) {
                    HomeBar(model: model)
                    progress
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16).padding(.top, 4)

                LivingPurr(mood: mood, size: proxy.size.width * 0.9, showsFloor: false, beat: gone.count)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.325)
                    .allowsHitTesting(false)

                deck(proxy.size)
            }
        }
        .background {
            LiquidBackdrop(look: OnboardingLook(accent: top?.accent ?? .mint, finish: .stage), origin: UnitPoint(x: drag.width < 0 ? 0.1 : 0.9, y: 0.6)).ignoresSafeArea()
        }
    }

    private var mood: PurrMood {
        guard !model.dashboard.isLoading else { return .loading }
        guard let top else { return .meditate }
        return drag.width > 60 ? .clapping : drag.width < -60 ? .idleTimeout : top.mood
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(cards) { card in
                Capsule().fill(gone.contains(card.id) ? DS.Colors.brand : DS.Colors.surfaceRaised.opacity(0.85)).frame(height: 8)
            }
        }
        .animation(DS.Motion.bouncy, value: gone)
        .accessibilityLabel("\(left.count) left today")
    }

    private func deck(_ size: CGSize) -> some View {
        let w = size.width - 44, h = size.height * 0.46
        return ZStack {
            if left.isEmpty, !model.dashboard.isLoading { caughtUp }
            ForEach(Array(left.prefix(4).enumerated()).reversed(), id: \.element.id) { depth, card in
                face(card, isTop: depth == 0)
                    .frame(width: w, height: h)
                    .scaleEffect(1 - CGFloat(depth) * 0.055)
                    .offset(y: CGFloat(depth) * 17)
                    .rotationEffect(.degrees(depth == 0 ? Double(drag.width / 18) : depth.isMultiple(of: 2) ? -2.5 : 2.5))
                    .offset(depth == 0 ? drag : .zero)
                    .zIndex(Double(10 - depth))
                    .gesture(depth == 0 ? throwing(card) : nil)
                    .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .identity))
            }
        }
        .position(x: size.width / 2, y: size.height * 0.70)
    }

    private func throwing(_ card: Card) -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                let far = abs(value.predictedEndTranslation.width) > 170
                guard far else { return withAnimation(DS.Motion.bouncy) { drag = .zero } }
                fling(card, right: value.predictedEndTranslation.width > 0)
            }
    }

    private func fling(_ card: Card, right: Bool) {
        feedback?.play(right ? .stamp : .deselect)
        withAnimation(.easeIn(duration: 0.22)) { drag = CGSize(width: right ? 620 : -620, height: 40) }
        Task {
            try? await Task.sleep(for: .milliseconds(210))
            var jump = Transaction(animation: nil)
            jump.disablesAnimations = true
            withTransaction(jump) { drag = .zero }
            withAnimation(DS.Motion.bouncy) { _ = gone.insert(card.id) }
            if right, card.id.hasPrefix("task") { card.run() }
        }
    }

    private func face(_ card: Card, isTop: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 40, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                ClayToken(symbol: card.symbol, accent: card.accent, size: 64).shadow(color: DS.Colors.groundShadow, radius: 7, y: 6)
                Spacer()
                Text(card.kicker).font(DS.Typography.brand(.subheadline, weight: .semibold)).foregroundStyle(card.accent.ink)
                    .padding(.horizontal, 14).frame(height: 34).background(Capsule().fill(card.accent.tint))
            }
            Spacer(minLength: 0)
            Text(card.value).font(DS.Typography.brand(34, weight: .bold)).foregroundStyle(DS.Colors.textPrimary).lineLimit(2).minimumScaleFactor(0.6)
            Text(card.line).font(DS.Typography.brand(.body)).foregroundStyle(DS.Colors.textSecondary).lineLimit(2)
            HStack {
                SakugaButton(title: card.action, kind: .dark, impact: .light, symbol: card.id.hasPrefix("task") ? "checkmark" : "chevron.forward", isFullWidth: true) {
                    if card.id.hasPrefix("task") { fling(card, right: true) } else { card.run() }
                }
                Button { fling(card, right: false) } label: {
                    Text("Later").font(DS.Typography.brand(.headline, weight: .semibold)).foregroundStyle(DS.Colors.textSecondary).frame(width: 84, height: 54)
                }
                .buttonStyle(SquishStyle(scale: 0.93))
            }
            .disabled(!isTop)
        }
        .padding(22)
        .background { shape.fill(.clay(DS.Colors.surfaceRaised, shade: card.accent.ink, size: 70)) }
        .overlay(shape.strokeBorder(card.accent.fill.opacity(0.5), lineWidth: 2))
        .overlay {
            if isTop {
                stamp("DONE", .mint, angle: -14).opacity(Double(drag.width / 110))
                stamp("LATER", .sky, angle: 14).opacity(Double(-drag.width / 110))
            }
        }
        .shadow(color: DS.Colors.groundShadow, radius: 18, y: 12)
        .accessibilityElement(children: .contain)
    }

    private func stamp(_ text: String, _ accent: DSAccent, angle: Double) -> some View {
        Text(text).font(DS.Typography.brandFixed(46)).foregroundStyle(accent.ink)
            .padding(.horizontal, 18).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 18).fill(accent.tint))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(accent.ink, lineWidth: 5))
            .rotationEffect(.degrees(angle))
    }

    private var caughtUp: some View {
        VStack(spacing: 12) {
            Text("All caught up").font(DS.Typography.brand(36, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
            Text("Nothing needs you. Go and enjoy your day.").font(DS.Typography.brand(.body)).foregroundStyle(DS.Colors.textSecondary)
            SakugaButton(title: "Deal again", kind: .plain, impact: .light, symbol: "arrow.counterclockwise") { withAnimation(DS.Motion.bouncy) { gone = [] } }
        }
        .multilineTextAlignment(.center)
    }
}

/// A plain layer stack; dragging here throws cards, it doesn't tilt.
private struct TiltlessStack<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { ZStack(alignment: .top) { content } }
}
#endif
