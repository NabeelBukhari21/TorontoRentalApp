//
//  StudioBust.swift
//  RentalApp (Purrperty)
//
//  Onboarding studio, direction B — "Big Purr". The whole screen is the
//  step's colour. Answers are chunky 3D keys up top; a giant Purr rises
//  from the bottom, his ears over the keys, the button on his tummy.
//

#if DEBUG
import SwiftUI

struct StudioBust: View {
    let viewModel: OnboardingFlowViewModel

    private var accent: DSAccent { viewModel.studioAccent }
    private var ink: Color { DS.Colors.textOnAccent }

    private var purr: (size: CGFloat, y: CGFloat) {
        switch viewModel.step {
        case .building: (640, 70)
        case .unlocked: (520, 76)
        case .signUp: (540, 30)
        default: (640, 130)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                backdrop
                VStack(spacing: 0) {
                    StudioTopBar(viewModel: viewModel, ink: ink, fill: ink, track: .white.opacity(0.55))
                    title.padding(.top, 10)
                    top.id(viewModel.step).padding(.top, 14)
                    Spacer(minLength: 0)
                }
                floaters(proxy.size)
                LitPurr(mood: viewModel.studioMood, size: purr.size, showsFloor: false, shadow: Color.black.opacity(0.28))
                    .position(x: proxy.size.width / 2, y: proxy.size.height - purr.size / 2 + purr.y)
                    .animation(.spring(response: 0.7, dampingFraction: 0.62), value: viewModel.step)
                    .allowsHitTesting(viewModel.step != .signUp)
                VStack(spacing: 12) {
                    Spacer()
                    tummy
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [accent.fill.mix(with: .white, by: 0.25), accent.fill], startPoint: .top, endPoint: .bottom)
            LiquidBlobs(color: .white.opacity(0.28), blobs: [
                .init(x: 0.1, y: 0.12, r: 0.3, phase: 0), .init(x: 0.95, y: 0.3, r: 0.25, phase: 3),
                .init(x: 0.5, y: 0.95, r: 0.62, phase: 1), .init(x: 0.12, y: 0.62, r: 0.16, phase: 2),
            ])
            if viewModel.step == .building {
                TimelineView(.animation) { context in
                    Wave(level: buildLevel, phase: context.date.timeIntervalSinceReferenceDate * 3)
                        .fill(LinearGradient(colors: [DS.Colors.brand.opacity(0.75), DS.Colors.brandDeep], startPoint: .top, endPoint: .bottom))
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: buildLevel)
            }
            if viewModel.step == .unlocked { SunRays(color: .white, center: UnitPoint(x: 0.5, y: 0.72)) }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: viewModel.step)
    }

    private var buildLevel: CGFloat {
        let done = viewModel.buildTasks.count { $0.state == .done }
        return 0.1 + 0.5 * CGFloat(done) / CGFloat(max(viewModel.buildTasks.count, 1))
    }

    private var title: some View {
        VStack(spacing: 4) {
            Text(viewModel.studioTitle)
                .font(DS.Typography.brand(38, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.studioLine)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
        .foregroundStyle(ink)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22)
        .id(viewModel.step)
        .transition(.push(from: .bottom))
    }

    @ViewBuilder private var top: some View {
        switch viewModel.step {
        case .building:
            VStack(spacing: 10) {
                ForEach(Array(viewModel.buildTasks.enumerated()), id: \.element.id) { index, task in
                    HStack(spacing: 8) {
                        if task.state == .done { Image(systemName: "checkmark.circle.fill").foregroundStyle(DSAccent.mint.ink) }
                        else if task.state == .running { ProgressView() }
                        Text(task.title)
                    }
                    .font(DS.Typography.brand(18, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, 18).frame(height: 46)
                    .background(Capsule().fill(.clay(DS.Colors.surfaceRaised, shade: accent.ink, size: 46)))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 8)
                    .opacity(task.state == .pending ? 0.5 : 1)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -3 : 3))
                    .offset(x: index.isMultiple(of: 2) ? -18 : 18)
                }
            }
        case .unlocked: deck
        case .signUp:
            VStack(spacing: 12) {
                StudioSignUpFields(auth: viewModel.auth)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(.clay(DS.Colors.surfaceRaised, shade: accent.ink, size: 70)))
            .shadow(color: .black.opacity(0.2), radius: 18, y: 14)
            .padding(.horizontal, 16)
        default: keys
        }
    }

    private var keys: some View {
        let choices = viewModel.studioChoices
        return VStack(spacing: 18) {
            ForEach(choices.rows(of: choices.count == 4 ? 2 : 3), id: \.first?.id) { row in
                HStack(spacing: 12) {
                    ForEach(row) { BustKey(choice: $0, tall: choices.count == 3).transition(.popIn(row.count)) }
                }
                .padding(.horizontal, row.count < 3 && choices.count == 5 ? 56 : 0)
            }
        }
        .padding(.horizontal, 16)
    }

    private var deck: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(Array(viewModel.profile.unlocks.enumerated()), id: \.element.id) { index, unlock in
                    VStack(alignment: .leading, spacing: 8) {
                        ClayToken(symbol: unlock.icon, accent: DSAccent.allCases[(index + 3) % 5], size: 62)
                            .shadow(color: .black.opacity(0.2), radius: 6, y: 5)
                        Spacer(minLength: 0)
                        Text(unlock.title).font(DS.Typography.brand(20, weight: .semibold, relativeTo: .headline)).foregroundStyle(DS.Colors.textPrimary)
                        Text(unlock.detail).font(.footnote).foregroundStyle(DS.Colors.textSecondary)
                    }
                    .padding(18)
                    .frame(width: 220, height: 206, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(.clay(DS.Colors.surfaceRaised, shade: accent.ink, size: 90)))
                    .shadow(color: .black.opacity(0.22), radius: 14, y: 12)
                    .scrollTransition { content, phase in
                        content
                            .rotation3DEffect(.degrees(phase.value * -35), axis: (0, 1, 0), perspective: 0.6)
                            .scaleEffect(1 - abs(phase.value) * 0.14)
                            .offset(y: abs(phase.value) * 26)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 26)
        }
        .contentMargins(.horizontal, 91, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }

    private func floaters(_ size: CGSize) -> some View {
        let props = viewModel.studioProps
        return ZStack {
            ClayToken(symbol: props[0], accent: .cherry, size: 74)
                .shadow(color: .black.opacity(0.22), radius: 10, y: 10)
                .floating(depth: -0.4, phase: 1).position(x: 48, y: size.height * 0.64)
            ClayToken(symbol: props[1], accent: .gold, size: 60)
                .shadow(color: .black.opacity(0.22), radius: 10, y: 10)
                .floating(depth: -0.6, phase: 3).position(x: size.width - 40, y: size.height * 0.58)
        }
        .opacity(viewModel.step == .signUp ? 0 : 1)
        .id(viewModel.step)
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder private var tummy: some View {
        switch viewModel.step {
        case .building: EmptyView()
        case .signUp:
            VStack(spacing: 14) {
                StudioNextButton(viewModel: viewModel, title: "Create account")
                StudioSocialButtons()
            }
            .offset(y: 8)
        default: StudioNextButton(viewModel: viewModel, background: DS.Colors.surfaceRaised, edge: DSAccent.gold.ink, ink: DS.Colors.textPrimary)
        }
    }
}

/// A big soft key. Picked, it stays pressed in and glows its colour.
private struct BustKey: View {
    let choice: StudioChoice
    let tall: Bool

    var body: some View {
        Button(action: choice.select) {
            VStack(spacing: 6) {
                Image(systemName: choice.symbol)
                    .font(.system(size: tall ? 34 : 26, weight: .bold))
                    .foregroundStyle(choice.isSelected ? choice.accent.onFill : choice.accent.ink)
                    .symbolEffect(.bounce, value: choice.isSelected)
                Text(choice.title)
                    .font(DS.Typography.brand(17, weight: .semibold, relativeTo: .headline))
                    .multilineTextAlignment(.center).minimumScaleFactor(0.75).lineLimit(2)
                if !choice.subtitle.isEmpty && !tall {
                    Text(choice.subtitle).font(.system(.caption, design: .rounded, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(choice.isSelected ? choice.accent.onFill : DS.Colors.textPrimary)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity).frame(height: tall ? 150 : 92)
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.clay(choice.isSelected ? choice.accent.fill : DS.Colors.surfaceRaised, shade: choice.accent.ink, size: 80)))
            .offset(y: choice.isSelected ? 6 : 0)
        }
        .buttonStyle(PressableDepthStyle(edge: choice.accent.ink, depth: 9))
        .shadow(color: .black.opacity(0.16), radius: 10, y: 12)
        .accessibilityAddTraits(choice.isSelected ? .isSelected : [])
    }
}

private struct Wave: Shape {
    var level: CGFloat
    var phase: Double
    var animatableData: CGFloat { get { level } set { level = newValue } }

    func path(in rect: CGRect) -> Path {
        let top = rect.height * (1 - level)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        for i in 0...60 {
            let x = rect.width * CGFloat(i) / 60
            path.addLine(to: CGPoint(x: x, y: top + sin(Double(i) / 9 + phase) * 9 + sin(Double(i) / 5 - phase * 0.7) * 4))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
#endif
