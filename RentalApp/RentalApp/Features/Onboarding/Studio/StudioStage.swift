//
//  StudioStage.swift
//  RentalApp (Purrperty)
//
//  Onboarding studio, direction A — "Paw stage". Purr stands full length
//  on a liquid puddle of the step's colour, props drifting behind and in
//  front of him; a counter of answer cards overlaps his feet.
//

#if DEBUG
import SwiftUI

struct StudioStage: View {
    let viewModel: OnboardingFlowViewModel

    private var accent: DSAccent { viewModel.studioAccent }
    private var isForm: Bool { viewModel.step == .signUp }
    private var purrSize: CGFloat {
        switch viewModel.step {
        case .signUp: 400
        case .headaches, .unlocked: 400
        case .building: 460
        default: 440
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            backdrop
            if viewModel.step == .unlocked { SunRays(color: DSAccent.gold.fill).transition(.opacity) }
            VStack(spacing: 0) {
                StudioTopBar(viewModel: viewModel)
                title.padding(.top, 8)
                stage
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                Spacer()
                front.id(viewModel.step).transition(.move(edge: .bottom).combined(with: .opacity))
                    .overlay(alignment: .topTrailing) {
                        // Sits on the counter's edge, nearest to us.
                        ClayToken(symbol: viewModel.studioProps[2], accent: .sky, size: 62)
                            .shadow(color: DS.Colors.groundShadow, radius: 8, y: 10)
                            .floating(depth: 1.2, phase: 5, bob: 0.6)
                            .offset(x: -22, y: -44)
                            .id(viewModel.step).transition(.scale.combined(with: .opacity))
                    }
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            DS.Colors.background
            LinearGradient(colors: [accent.fill.opacity(0.42), accent.fill.opacity(0.12)], startPoint: .top, endPoint: .bottom)
            LiquidBlobs(color: accent.fill.opacity(0.55), blobs: [
                .init(x: 0.5, y: 0.5, r: 0.44, phase: 0), .init(x: 0.1, y: 0.36, r: 0.17, phase: 2),
                .init(x: 0.93, y: 0.45, r: 0.2, phase: 4), .init(x: 0.78, y: 0.28, r: 0.1, phase: 5),
            ])
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: viewModel.step)
    }

    private var title: some View {
        VStack(spacing: 4) {
            Text(viewModel.studioTitle)
                .font(DS.Typography.brand(36, weight: .bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.studioLine)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(DS.Colors.textPrimary.opacity(0.8))
                .contentTransition(.opacity)
        }
        .multilineTextAlignment(.center)
        .frame(height: 100, alignment: .top)
        .padding(.horizontal, 24)
        .id(viewModel.step)
        .transition(.push(from: .bottom))
    }

    private var stage: some View {
        let props = viewModel.studioProps
        return ZStack {
            Group {
                ClayToken(symbol: props[1], accent: .blush, size: 66)
                    .shadow(color: DS.Colors.groundShadow, radius: 8, y: 8)
                    .blur(radius: 1.2)
                    .floating(depth: -0.5, phase: 1).offset(x: -158, y: -60)
                ClayToken(symbol: props[0], accent: .gold, size: 82)
                    .shadow(color: DS.Colors.groundShadow, radius: 10, y: 10)
                    .floating(depth: -0.3, phase: 3).offset(x: 152, y: -100)
            }
            .id(viewModel.step).transition(.scale.combined(with: .opacity))
            LitPurr(mood: viewModel.studioMood, size: purrSize)
        }
        // Purr is wider than the screen; don't let him widen the layout.
        .frame(maxWidth: 0)
        .frame(height: 330)
        .offset(y: isForm ? -36 : viewModel.step == .personalize ? 22 : -6)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.step)
    }

    // MARK: Front

    @ViewBuilder private var front: some View {
        switch viewModel.step {
        case .building: counter { buildList }
        case .unlocked: counter { unlocks; StudioNextButton(viewModel: viewModel, background: DS.Colors.textPrimary, edge: .black, ink: DS.Colors.background) }
        case .signUp:
            counter {
                StudioSignUpFields(auth: viewModel.auth)
                StudioNextButton(viewModel: viewModel, title: "Create account", background: DS.Colors.textPrimary, edge: .black, ink: DS.Colors.background)
                StudioSocialButtons()
            }
        default:
            counter {
                answers
                StudioNextButton(viewModel: viewModel, background: DS.Colors.textPrimary, edge: .black, ink: DS.Colors.background)
            }
        }
    }

    /// The counter Purr stands behind.
    private func counter(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 14, content: content)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38, style: .continuous)
                    .fill(DS.Colors.background.shadow(.inner(color: .white, radius: 3, y: 3)))
                    .shadow(color: DS.Colors.groundShadow, radius: 22, y: -10)
                    .ignoresSafeArea()
            }
    }

    @ViewBuilder private var answers: some View {
        let choices = viewModel.studioChoices
        if choices.count > 3 {
            VStack(spacing: 12) {
                ForEach(choices.rows(of: 2), id: \.first?.id) { row in
                    HStack(spacing: 12) { ForEach(row) { StageCard(choice: $0, isCompact: true) } }
                }
            }
        } else if viewModel.step == .personalize {
            HStack(spacing: 12) { ForEach(choices) { StageTile(choice: $0) } }
        } else {
            VStack(spacing: 10) { ForEach(choices) { StageCard(choice: $0) } }
        }
    }

    private var buildList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.buildTasks) { task in
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(.clay(task.state == .done ? DSAccent.mint.fill : DS.Colors.surfaceSecondary, shade: DSAccent.mint.ink, size: 40))
                        if task.state == .running { ProgressView() }
                        else if task.state == .done { Image(systemName: "checkmark").font(.headline.bold()).foregroundStyle(DS.Colors.textOnAccent) }
                    }
                    .frame(width: 40, height: 40)
                    Text(task.title).font(DS.Typography.brand(19, weight: .medium, relativeTo: .body))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DS.Colors.surface))
                .scaleEffect(task.state == .running ? 1.03 : 1)
            }
        }
        .padding(.bottom, 24)
    }

    private var unlocks: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(Array(viewModel.profile.unlocks.enumerated()), id: \.element.id) { index, unlock in
                    HStack(spacing: 14) {
                        ClayToken(symbol: unlock.icon, accent: DSAccent.allCases[(index + 2) % 5], size: 50)
                            .shadow(color: DS.Colors.groundShadow, radius: 5, y: 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(unlock.title).font(DS.Typography.brand(18, weight: .semibold, relativeTo: .headline)).foregroundStyle(DS.Colors.textPrimary)
                            Text(unlock.detail).font(.footnote).foregroundStyle(DS.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(DS.Colors.surface))
                }
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .frame(height: 260)
    }
}

/// A white answer card with a clay icon; picked, it lifts and turns to
/// its own colour.
private struct StageCard: View {
    let choice: StudioChoice
    var isCompact = false

    var body: some View {
        Button(action: choice.select) {
            HStack(spacing: 12) {
                ClayToken(symbol: choice.symbol, accent: choice.accent, size: isCompact ? 42 : 48)
                    .shadow(color: DS.Colors.groundShadow, radius: 4, y: 4)
                    .rotationEffect(.degrees(choice.isSelected ? -10 : 0))
                    .scaleEffect(choice.isSelected ? 1.15 : 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(choice.title)
                        .font(DS.Typography.brand(isCompact ? 17 : 20, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .minimumScaleFactor(0.8).lineLimit(isCompact && choice.subtitle.isEmpty ? 2 : 1)
                    if !choice.subtitle.isEmpty {
                        Text(choice.subtitle).font(.footnote).foregroundStyle(DS.Colors.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
                if !isCompact {
                    Image(systemName: choice.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(choice.isSelected ? AnyShapeStyle(choice.accent.ink) : AnyShapeStyle(DS.Colors.track))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: isCompact ? 66 : 72)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(choice.isSelected ? choice.accent.fill.mix(with: DS.Colors.background, by: 0.78) : DS.Colors.surface)
                    .strokeBorder(choice.isSelected ? choice.accent.fill : .clear, lineWidth: 3)
            }
            .overlay(alignment: .topTrailing) {
                if isCompact && choice.isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.title3)
                        .foregroundStyle(DS.Colors.background, choice.accent.ink)
                        .offset(x: 4, y: -6).transition(.scale)
                }
            }
        }
        .buttonStyle(PressableDepthStyle(edge: choice.isSelected ? choice.accent.fill : DS.Colors.track, depth: 4, shape: .init(cornerRadius: 24, style: .continuous)))
        .accessibilityAddTraits(choice.isSelected ? .isSelected : [])
    }
}

private struct StageTile: View {
    let choice: StudioChoice

    var body: some View {
        Button(action: choice.select) {
            VStack(spacing: 8) {
                ClayToken(symbol: choice.symbol, accent: choice.accent, size: 60)
                    .shadow(color: DS.Colors.groundShadow, radius: 5, y: 5)
                    .scaleEffect(choice.isSelected ? 1.15 : 1)
                Text(choice.title).font(DS.Typography.brand(17, weight: .semibold, relativeTo: .headline)).foregroundStyle(DS.Colors.textPrimary)
                Text(choice.subtitle).font(.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity).frame(height: 148)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(choice.isSelected ? choice.accent.fill.mix(with: DS.Colors.background, by: 0.78) : DS.Colors.surface)
                    .strokeBorder(choice.isSelected ? choice.accent.fill : .clear, lineWidth: 3)
            }
        }
        .buttonStyle(PressableDepthStyle(edge: choice.isSelected ? choice.accent.fill : DS.Colors.track, depth: 4, shape: .init(cornerRadius: 28, style: .continuous)))
    }
}

/// Slowly turning rays behind a celebrating Purr.
struct SunRays: View {
    let color: Color
    var center = UnitPoint(x: 0.5, y: 0.4)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 0.15
            Canvas { canvas, size in
                let c = CGPoint(x: size.width * center.x, y: size.height * center.y)
                for i in 0..<14 {
                    let a = Double(i) / 14 * .pi * 2 + t
                    var ray = Path()
                    ray.move(to: c)
                    ray.addLine(to: CGPoint(x: c.x + cos(a - 0.11) * 800, y: c.y + sin(a - 0.11) * 800))
                    ray.addLine(to: CGPoint(x: c.x + cos(a + 0.11) * 800, y: c.y + sin(a + 0.11) * 800))
                    canvas.fill(ray, with: .radialGradient(Gradient(colors: [color.opacity(0.7), color.opacity(0)]), center: c, startRadius: 40, endRadius: 460))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
