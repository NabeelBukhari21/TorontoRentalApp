//
//  StudioBubbles.swift
//  RentalApp (Purrperty)
//
//  Onboarding studio, direction C — "Liquid orbit". Purr sits in the
//  middle of the screen; the answers are bubbles floating around him in
//  depth, some behind, some in front. A picked bubble fills with colour
//  and a strand of liquid joins it to the pool he stands in.
//

#if DEBUG
import SwiftUI

struct StudioBubbles: View {
    let viewModel: OnboardingFlowViewModel

    private var accent: DSAccent { viewModel.studioAccent }
    private var purrSize: CGFloat { viewModel.step == .signUp ? 400 : 440 }
    private var purrY: CGFloat { viewModel.step == .signUp ? 245 : 425 }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .top) {
                backdrop
                LiquidPool(accent: accent, feet: CGPoint(x: size.width / 2, y: purrY + purrSize * 0.455), targets: selectedPoints(size))
                    .animation(.spring(response: 0.7, dampingFraction: 0.6), value: viewModel.step)
                bubbles(size, inFront: false)
                LitPurr(mood: viewModel.studioMood, size: purrSize)
                    .position(x: size.width / 2, y: purrY)
                    .animation(.spring(response: 0.7, dampingFraction: 0.62), value: viewModel.step)
                bubbles(size, inFront: true)
                VStack(spacing: 0) {
                    StudioTopBar(viewModel: viewModel)
                    title.padding(.top, 8)
                    Spacer()
                    bottom.id(viewModel.step)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            DS.Colors.background
            RadialGradient(colors: [accent.fill.opacity(0.5), accent.fill.opacity(0.08)], center: UnitPoint(x: 0.5, y: 0.52), startRadius: 30, endRadius: 420)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: viewModel.step)
    }

    private var title: some View {
        VStack(spacing: 8) {
            Text(viewModel.studioTitle)
                .font(DS.Typography.brand(36, weight: .bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if viewModel.step != .signUp {
                Text(viewModel.studioLine)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .id(viewModel.step)
        .transition(.push(from: .bottom))
    }

    // MARK: Bubbles

    struct Spot { let x: Double, y: Double, d: CGFloat, front: Bool }

    private var spots: [Spot] {
        switch viewModel.step {
        case .units:
            [.init(x: 0.16, y: 0.32, d: 104, front: false), .init(x: 0.84, y: 0.34, d: 116, front: false),
             .init(x: 0.19, y: 0.67, d: 126, front: true), .init(x: 0.80, y: 0.71, d: 136, front: true)]
        case .headaches:
            [.init(x: 0.17, y: 0.34, d: 104, front: false), .init(x: 0.83, y: 0.35, d: 104, front: false),
             .init(x: 0.14, y: 0.56, d: 112, front: true), .init(x: 0.85, y: 0.58, d: 116, front: true),
             .init(x: 0.5, y: 0.76, d: 124, front: true)]
        default:
            [.init(x: 0.16, y: 0.29, d: 116, front: false), .init(x: 0.83, y: 0.47, d: 128, front: true), .init(x: 0.27, y: 0.72, d: 144, front: true)]
        }
    }

    private func point(_ i: Int, _ size: CGSize) -> CGPoint {
        CGPoint(x: spots[i].x * size.width, y: spots[i].y * size.height)
    }

    private func selectedPoints(_ size: CGSize) -> [LiquidPool.Target] {
        viewModel.studioChoices.enumerated().compactMap { i, choice in
            choice.isSelected ? .init(point: point(i, size), radius: spots[i].d / 2, color: choice.accent.fill) : nil
        }
    }

    private func bubbles(_ size: CGSize, inFront: Bool) -> some View {
        ZStack {
            ForEach(Array(viewModel.studioChoices.enumerated()), id: \.element.id) { i, choice in
                if spots[i].front == inFront {
                    AnswerBubble(choice: choice, diameter: spots[i].d)
                        .floating(depth: inFront ? 1 : -0.4, phase: Double(i) * 1.7, bob: inFront ? 1 : 0.7)
                        .position(point(i, size))
                        .transition(.popIn(i))
                }
            }
            if viewModel.step == .unlocked { unlockBubbles(size, inFront: inFront) }
            if viewModel.step == .building, inFront { buildBubbles(size) }
            if viewModel.step == .signUp || viewModel.step == .building, !inFront {
                ForEach(0..<7, id: \.self) { i in
                    EmptyBubble(diameter: [34, 60, 22, 46, 28, 70, 40][i])
                        .floating(depth: -0.5, phase: Double(i))
                        .position(x: size.width * [0.1, 0.9, 0.3, 0.06, 0.78, 0.2, 0.94][i], y: size.height * [0.24, 0.3, 0.22, 0.46, 0.2, 0.6, 0.5][i])
                }
            }
        }
    }

    private func buildBubbles(_ size: CGSize) -> some View {
        ForEach(Array(viewModel.buildTasks.enumerated()), id: \.element.id) { i, task in
            let home = CGPoint(x: size.width * [0.2, 0.8, 0.5][i], y: size.height * [0.64, 0.66, 0.8][i])
            ZStack {
                BubbleShape(color: task.state == .done ? DSAccent.mint.fill : DS.Colors.surfaceRaised, shade: DSAccent.mint.ink, diameter: 126)
                VStack(spacing: 6) {
                    if task.state == .done { Image(systemName: "checkmark").font(.title.bold()) }
                    else if task.state == .running { ProgressView().controlSize(.large) }
                    else { Image(systemName: "ellipsis").font(.title.bold()) }
                    Text(task.title).font(DS.Typography.brand(14, weight: .semibold, relativeTo: .caption)).multilineTextAlignment(.center)
                }
                .foregroundStyle(task.state == .done ? DS.Colors.textOnAccent : DS.Colors.textPrimary)
                .padding(14)
            }
            .frame(width: 126, height: 126)
            .scaleEffect(task.state == .running ? 1.1 : 1)
            .floating(depth: 1, phase: Double(i) * 2)
            .position(home)
        }
    }

    private func unlockBubbles(_ size: CGSize, inFront: Bool) -> some View {
        ForEach(Array(viewModel.profile.unlocks.prefix(5).enumerated()), id: \.element.id) { i, unlock in
            let spot = [Spot(x: 0.16, y: 0.33, d: 112, front: false), Spot(x: 0.84, y: 0.32, d: 108, front: false),
                        Spot(x: 0.17, y: 0.58, d: 124, front: true), Spot(x: 0.83, y: 0.57, d: 120, front: true),
                        Spot(x: 0.5, y: 0.76, d: 140, front: true)][i]
            if spot.front == inFront {
                let tint = DSAccent.allCases[(i + 1) % 5]
                ZStack {
                    BubbleShape(color: tint.fill, shade: tint.ink, diameter: spot.d)
                    VStack(spacing: 4) {
                        Image(systemName: unlock.icon).font(.system(size: 24, weight: .bold))
                        Text(unlock.title).font(DS.Typography.brand(13, weight: .semibold, relativeTo: .caption))
                            .multilineTextAlignment(.center).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(tint.onFill)
                    .padding(12)
                }
                .frame(width: spot.d, height: spot.d)
                .floating(depth: inFront ? 1 : -0.4, phase: Double(i) * 1.7)
                .position(x: size.width * spot.x, y: size.height * spot.y)
                .transition(.popIn(i))
                .accessibilityElement(children: .combine)
                .accessibilityHint(unlock.detail)
            }
        }
    }

    @ViewBuilder private var bottom: some View {
        switch viewModel.step {
        case .building: EmptyView()
        case .signUp:
            VStack(spacing: 14) {
                StudioSignUpFields(auth: viewModel.auth, background: DS.Colors.background.opacity(0.7))
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 34))
                    .shadow(color: DS.Colors.groundShadow, radius: 20, y: 10)
                StudioNextButton(viewModel: viewModel, title: "Create account")
                StudioSocialButtons()
            }
            .padding(.horizontal, 16)
        default: StudioNextButton(viewModel: viewModel)
        }
    }
}

// MARK: - Bubble

private struct BubbleShape: View {
    let color: Color
    let shade: Color
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(.clay(color, shade: shade, size: diameter * 0.9))
            .overlay(alignment: .topLeading) {
                Ellipse().fill(.white.opacity(0.85))
                    .frame(width: diameter * 0.24, height: diameter * 0.13)
                    .rotationEffect(.degrees(-34))
                    .blur(radius: 1.5)
                    .offset(x: diameter * 0.15, y: diameter * 0.12)
            }
            .frame(width: diameter, height: diameter)
            .shadow(color: DS.Colors.groundShadow, radius: diameter * 0.12, y: diameter * 0.12)
    }
}

private struct EmptyBubble: View {
    let diameter: CGFloat
    var body: some View {
        Circle().fill(.clear).frame(width: diameter, height: diameter).glassEffect(.clear, in: .circle)
    }
}

private struct AnswerBubble: View {
    let choice: StudioChoice
    let diameter: CGFloat

    var body: some View {
        Button(action: choice.select) {
            ZStack {
                BubbleShape(color: choice.isSelected ? choice.accent.fill : DS.Colors.surfaceRaised, shade: choice.accent.ink, diameter: diameter)
                VStack(spacing: 4) {
                    Image(systemName: choice.symbol)
                        .font(.system(size: diameter * 0.24, weight: .bold))
                        .foregroundStyle(choice.isSelected ? choice.accent.onFill : choice.accent.ink)
                        .symbolEffect(.bounce, value: choice.isSelected)
                    Text(choice.title)
                        .font(DS.Typography.brand(15, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(choice.isSelected ? choice.accent.onFill : DS.Colors.textPrimary)
                        .multilineTextAlignment(.center).minimumScaleFactor(0.8).lineLimit(2)
                }
                .padding(diameter * 0.12)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(choice.isSelected ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .contentShape(.circle)
        .sensoryFeedback(.impact(weight: .medium), trigger: choice.isSelected)
        .accessibilityHint(choice.subtitle)
        .accessibilityAddTraits(choice.isSelected ? .isSelected : [])
    }
}

// MARK: - Pool

/// The pool under Purr, with a strand of liquid out to each picked bubble.
private struct LiquidPool: View {
    struct Target { let point: CGPoint, radius: CGFloat, color: Color }
    let accent: DSAccent
    let feet: CGPoint
    let targets: [Target]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, _ in
                let color = targets.last?.color ?? accent.fill
                canvas.liquidLayer(color: color, blur: 10) { layer in
                    var pool = Path()
                    for i in 0...80 {
                        let a = Double(i) / 80 * .pi * 2
                        let r = 1 + 0.06 * sin(a * 3 + t * 1.6) + 0.04 * sin(a * 5 - t)
                        let p = CGPoint(x: feet.x + cos(a) * 165 * r, y: feet.y + sin(a) * 40 * r)
                        if i == 0 { pool.move(to: p) } else { pool.addLine(to: p) }
                    }
                    layer.fill(pool, with: .color(.black))
                    for target in targets {
                        layer.fill(.wobblyCircle(center: target.point, radius: target.radius * 1.2, time: t, amount: 0.07), with: .color(.black))
                        var strand = Path()
                        strand.move(to: feet)
                        let mid = CGPoint(x: target.point.x + (target.point.x - feet.x) * 0.15 + sin(t * 1.4) * 10, y: (feet.y + target.point.y) / 2 + 20)
                        strand.addQuadCurve(to: target.point, control: mid)
                        layer.stroke(strand, with: .color(.black), style: StrokeStyle(lineWidth: 34 + sin(t * 2) * 5, lineCap: .round))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
