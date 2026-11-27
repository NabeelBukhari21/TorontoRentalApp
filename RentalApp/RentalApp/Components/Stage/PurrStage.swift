//
//  PurrStage.swift
//  RentalApp (Purrperty)
//
//  Components/Stage — Purr standing behind a counter, for any flow of
//  steps: workspace setup, the first property, the trial. The same scene
//  as onboarding: Purr and the counter stay, the next colour spreads as a
//  drop of liquid, and only the words and the counter's content change.
//
//  At accessibility text sizes and in landscape it's a plain page.
//

import SwiftUI

struct PurrStage<Step: Hashable, Content: View, Actions: View>: View {

    let step: Step
    let accent: DSAccent
    let mood: PurrMood
    let title: String
    var line: String = ""
    var movesForward = true
    /// 0…1, or nil for no progress tube.
    var progress: Double? = nil
    var progressLabel = ""
    var props: [String] = []
    /// Plays the reward instead of a step sound, and turns on the rays.
    var celebrates = false
    var onBack: (() -> Void)? = nil
    /// A close button, top right.
    var onClose: (() -> Void)? = nil
    var closeLabel = "Close"
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.feedback) private var feedback

    @State private var topHeights: [Step: CGFloat] = [:]
    @State private var contentHeights: [Step: CGFloat] = [:]
    @State private var actionsHeight: CGFloat = 80
    @State private var sceneHeight: CGFloat = 800
    @State private var hasEntered = false
    @State private var reaction: PurrMood?
    @AccessibilityFocusState private var titleIsFocused: Bool

    private static var barHeight: CGFloat { 44 }
    /// The keyboard has taken most of the room.
    private var isCramped: Bool { sceneHeight < 560 }
    private var usesPlainPage: Bool { typeSize.isAccessibilitySize || (verticalSizeClass == .compact) }

    var body: some View {
        Group {
            if usesPlainPage {
                plainPage
            } else {
                TiltScene {
                    GeometryReader { proxy in scene(proxy.size) }
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { sceneHeight = $0 }
                }
                .background {
                    ZStack {
                        LiquidBackdrop(look: OnboardingLook(accent: accent, finish: .stage),
                                       origin: movesForward ? UnitPoint(x: 0.5, y: 0.92) : UnitPoint(x: 0.1, y: 0.1))
                        if celebrates {
                            SunRays(color: accent.fill, center: UnitPoint(x: 0.5, y: 0.36)).transition(.opacity)
                        }
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .onChange(of: step) { _, _ in
            reaction = nil
            feedback?.play(celebrates ? .celebrate : movesForward ? .advance : .back)
        }
        .task(id: step) { titleIsFocused = true }
        .onAppear { withAnimation(DS.Motion.scene) { hasEntered = true } }
    }

    // MARK: Scene

    private struct Placement: Equatable {
        let size: CGFloat
        let center: CGPoint
    }

    private func scene(_ size: CGSize) -> some View {
        let top = Self.barHeight + 8 + (topHeights[step] ?? 90)
        let room = size.height - top
        // Leave Purr at least his face.
        let contentMax = max(120, room - actionsHeight - (isCramped ? 110 : 190) - 40)
        let contentHeight = min(contentHeights[step] ?? 240, contentMax)
        let edge = size.height - (contentHeight + actionsHeight + 40)
        let purr = placement(in: size, top: top, edge: edge)

        return ZStack(alignment: .top) {
            VStack(spacing: 8) {
                topBar
                ZStack(alignment: .top) {
                    words
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { [step] in topHeights[step] = $0 }
                        .id(step)
                        .transition(.drift)
                }
                .frame(maxWidth: 520)
            }

            if props.count > 1, hasEntered, !isCramped { floaters(size, purr) }

            LivingPurr(mood: reaction ?? mood, size: purr.size, beat: step)
                .position(x: purr.center.x, y: hasEntered ? purr.center.y : size.height + purr.size)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : DS.Motion.scene, value: purr)
            Circle().fill(.clear)
                .frame(width: purr.size * 0.36)
                .contentShape(.circle)
                .onTapGesture(perform: tickle)
                .position(purr.center)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if hasEntered { counter(contentHeight: contentHeight) }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// In the rig's canvas his ears start 19% down and his feet are at 97%.
    private func placement(in size: CGSize, top: CGFloat, edge: CGFloat) -> Placement {
        let width = min(size.width, 480)
        let side: CGFloat
        let y: CGFloat
        if isCramped {
            side = min(max((edge - top) / 0.36, 160), 280)
            y = edge - side * 0.55
        } else {
            side = min(max((edge - top - 14) / 0.61, 170), width * 1.05)
            y = max(top + 14 - side * 0.19, edge - side * 0.9)
        }
        return Placement(size: side, center: CGPoint(x: size.width / 2, y: y + side / 2))
    }

    private func floaters(_ size: CGSize, _ purr: Placement) -> some View {
        let spread = min(size.width, 480) / 2
        let scale = min(1, purr.size / 340)
        return ZStack {
            ClayToken(symbol: props[1], accent: .blush, size: 64 * scale)
                .shadow(color: DS.Colors.groundShadow, radius: 9, y: 9)
                .blur(radius: 1.2)
                .floating(depth: -0.5, phase: 1)
                .position(x: size.width / 2 - spread + 40, y: purr.center.y - purr.size * 0.14)
            ClayToken(symbol: props[0], accent: .gold, size: 76 * scale)
                .shadow(color: DS.Colors.groundShadow, radius: 9, y: 9)
                .floating(depth: -0.3, phase: 3)
                .position(x: size.width / 2 + spread - 44, y: purr.center.y - purr.size * 0.22)
        }
        .frame(width: size.width, height: size.height)
        .id(step)
        .transition(.bubble(0))
    }

    private func tickle() {
        feedback?.play(.purr)
        guard reaction == nil, let move = PurrMood.signatureMoves.randomElement() else { return }
        reaction = move
        Task {
            try? await Task.sleep(for: .seconds(3))
            if reaction == move { reaction = nil }
        }
    }

    // MARK: Top

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { onBack?() } label: {
                Image(systemName: "chevron.backward").stageBarIcon()
            }
            .buttonStyle(SquishStyle(scale: 0.86))
            .opacity(onBack == nil ? 0 : 1)
            .disabled(onBack == nil)
            .accessibilityLabel("Back")

            if let progress {
                OnboardingProgressTube(progress: progress, label: progressLabel, fill: DS.Colors.brand, track: DS.Colors.track)
            } else {
                Spacer()
            }

            Button { onClose?() } label: {
                Image(systemName: "xmark").stageBarIcon()
            }
            .buttonStyle(SquishStyle(scale: 0.86))
            .opacity(onClose == nil ? 0 : 1)
            .disabled(onClose == nil)
            .accessibilityHidden(onClose == nil)
            .accessibilityLabel(closeLabel)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 560)
        .frame(height: Self.barHeight)
    }

    @ViewBuilder private var words: some View {
        if isCramped {
            Color.clear.frame(height: 1)
        } else {
            VStack(spacing: 4) {
                Text(title)
                    .font(DS.Typography.brand(34, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleIsFocused)
                if !line.isEmpty {
                    Text(line)
                        .font(DS.Typography.brand(.subheadline))
                        .contentTransition(.opacity)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(DS.Colors.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
        }
    }

    // MARK: Counter

    private func counter(contentHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            ScrollView {
                ZStack(alignment: .top) {
                    content
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { [step] in contentHeights[step] = $0 }
                        .id(step)
                        .transition(.drift)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .scrollClipDisabled(contentHeight >= (contentHeights[step] ?? 0))
            .frame(height: contentHeight)

            VStack(spacing: 8) { actions }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { actionsHeight = $0 }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38, style: .continuous)
                .fill(DS.Colors.background)
                .shadow(color: DS.Colors.groundShadow, radius: 22, y: -10)
                .ignoresSafeArea()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Plain Page

    private var plainPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                topBar.padding(.horizontal, -16)
                PurrMascot(mood: mood, size: 150)
                Text(title).font(DS.Typography.brand(34)).accessibilityAddTraits(.isHeader)
                if !line.isEmpty {
                    Text(line).font(DS.Typography.brand(.body, weight: .regular)).foregroundStyle(DS.Colors.textSecondary)
                }
                content.multilineTextAlignment(.leading)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .id(step)
        }
        .background(DS.Colors.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) { actions }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(DS.Colors.background)
        }
    }
}

private extension View {
    func stageBarIcon() -> some View {
        font(.system(size: 17, weight: .bold))
            .foregroundStyle(DS.Colors.textPrimary)
            .frame(width: 44, height: 44)
            .dsGlass(.regular.interactive(), in: .circle)
    }
}
