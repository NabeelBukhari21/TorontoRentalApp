//
//  MascotView.swift
//  RentalApp
//
//  Mascot — The animated cat.
//
//  ─────────────────────────────────────────────────────────────────
//  HOW IT MOVES
//  ─────────────────────────────────────────────────────────────────
//  The cat is two illustrated poses (sitting, cheering) brought to life
//  with layered motion, the way a 2D mascot is animated without a rig:
//
//  • Always on    — a slow breath (vertical stretch from the feet) and a
//                   gentle sway, out of phase so it never looks mechanical.
//  • Reactions    — keyframed hops with real squash-and-stretch:
//                   anticipation squash → stretched take-off → landing
//                   squash → springy settle. The ground shadow shrinks and
//                   fades as the cat leaves the floor, because the shadow
//                   stays on the ground — which is why the shadow baked into
//                   the original art had to be removed.
//  • Idle life    — every few seconds a small unprompted action (a hop, a
//                   wiggle), so a screen with the cat on it never feels
//                   frozen.
//  • Moods        — cheering swaps to the arms-up pose with a sparkle burst;
//                   thinking tilts and shows a thought bubble; concerned
//                   wiggles and shows an alert badge.
//  • Touch        — tap the cat and it hops, with a light haptic.
//
//  Everything respects Reduce Motion: no ambient motion, no hops, pose
//  changes crossfade. The cat is decorative, so it is hidden from
//  VoiceOver; anything it "says" goes through `MascotSpeechBubble`, which
//  is read normally.
//
//  ─────────────────────────────────────────────────────────────────
//  ADDING POSES
//  ─────────────────────────────────────────────────────────────────
//  New art drops in as a case on `MascotPose` plus an image set named in
//  `assetName`. Every pose must be exported on the same 1024² canvas with
//  the floor line at 94% and the eyes centred horizontally (that is what
//  the cut-out pipeline produced), so poses can be swapped without the
//  cat jumping. A rigged Rive/Lottie version can later replace the body of
//  this view without touching any screen that uses it.
//

import SwiftUI

// MARK: - Pose

/// An illustrated pose. All poses share one canvas geometry: the floor
/// line at 94% and the cat sized so heads match across poses.
enum MascotPose: String, CaseIterable, Sendable {
    case sit
    case cheer
    /// Sunglasses — calm confidence, "all clear".
    case cool
    /// At the laptop — busy, loading, syncing.
    case work
    /// Curled up asleep — quiet hours, nothing happening.
    case sleep
    /// Mid-leap — "let's go!". Airborne: its paws sit above the floor line,
    /// so the ground shadow reads as being below it.
    case leap

    var assetName: String {
        switch self {
        case .sit:   "MascotSit"
        case .cheer: "MascotCheer"
        case .cool:  "MascotCool"
        case .work:  "MascotWork"
        case .sleep: "MascotSleep"
        case .leap:  "MascotLeap"
        }
    }

    /// Floor line (where the paws meet the ground), as a fraction of the
    /// canvas height. Identical for every grounded pose by construction.
    static let floorY: CGFloat = 0.94

    /// Pixel side of the pose's canvas. The extra poses were cut from the
    /// character sheets at their native size — never upscaled — so they
    /// are smaller than the two hero poses. See `renderable(atPoints:scale:)`.
    var nativePixels: CGFloat {
        switch self {
        case .sit, .cheer: 1024
        case .cool:  299
        case .work:  287
        case .sleep: 336
        case .leap:  477
        }
    }

    /// The high-resolution pose to show instead when this one would be
    /// visibly upscaled.
    var hiResFallback: MascotPose {
        switch self {
        case .sit, .cheer:  self
        case .cool, .work, .sleep: .sit
        case .leap: .cheer
        }
    }

    /// The pose actually drawn at a given size: this one if its pixels hold
    /// up (allowing a mild 1.3× stretch, invisible on a soft illustration),
    /// otherwise the hi-res fallback. When high-resolution exports of the
    /// newer poses arrive, raising `nativePixels` is all it takes.
    func renderable(atPoints points: CGFloat, scale: CGFloat) -> MascotPose {
        points * scale <= nativePixels * 1.3 ? self : hiResFallback
    }

    /// Whether the paws touch the floor.
    var isGrounded: Bool { self != .leap }

    /// Vertical centre of the eyes, as a fraction of the canvas — where
    /// sparkles and badges are placed around the head. Measured from the art.
    var eyeY: CGFloat {
        switch self {
        case .sit:   0.351
        case .cheer: 0.315
        case .cool:  0.278
        case .work:  0.456
        case .sleep: 0.646
        case .leap:  0.428
        }
    }

    /// Top of the ears, as a fraction of the canvas.
    var headTopY: CGFloat {
        switch self {
        case .sit:   0.058
        case .cheer: 0.040
        case .cool:  0.100
        case .work:  0.101
        case .sleep: 0.360
        case .leap:  0.080
        }
    }
}

// MARK: - Mood

/// How the cat feels — picks the pose and the motion.
enum MascotMood: Hashable, Sendable {
    /// Calm: breathing, sway, the odd hop.
    case idle
    /// Pleased: livelier, hops more often. The default "hello".
    case happy
    /// Celebrating: arms up, sparkles, double hop.
    case cheer
    /// Working something out: slow tilt and a thought bubble.
    case thinking
    /// Something needs attention: a wiggle and an alert badge.
    case concerned
    /// All clear: sunglasses on, the occasional glint.
    case cool
    /// Busy at the laptop: loading, syncing, the AI at work.
    case working
    /// Asleep: slow breathing and drifting Zs. Nothing needs you.
    case sleeping
    /// Mid-leap: bobbing in the air. "Let's go!"
    case excited

    var pose: MascotPose {
        switch self {
        case .cheer:    .cheer
        case .cool:     .cool
        case .working:  .work
        case .sleeping: .sleep
        case .excited:  .leap
        case .idle, .happy, .thinking, .concerned: .sit
        }
    }

    /// Seconds between unprompted idle actions.
    fileprivate var idleInterval: ClosedRange<Double> {
        switch self {
        case .idle:      5.5...9
        case .happy:     3.2...5.5
        case .cheer:     2.2...3.6
        case .thinking:  7...11
        case .concerned: 4...6
        case .cool:      4.5...7.5
        case .working:   2.5...4
        case .sleeping:  60...90      // practically never — it's asleep
        case .excited:   2.4...3.6
        }
    }

    /// Whether the cat sways side to side. Not while typing or asleep.
    fileprivate var sways: Bool {
        switch self {
        case .working, .sleeping, .excited: false
        default: true
        }
    }
}

// MARK: - Motion

/// The animatable state of one reaction.
private struct MascotMotion {
    /// Height off the ground, in points.
    var lift: CGFloat = 0
    /// Vertical stretch about the floor line; < 1 squashes, > 1 stretches.
    var stretch: CGFloat = 1
    /// Rotation about the floor line, in degrees.
    var tilt: Double = 0
}

/// Amplitudes for a reaction. The keyframe structure is fixed; only these
/// numbers change, which keeps every reaction physically consistent.
private struct MascotReaction: Equatable {
    var firstHop: CGFloat = 0      // fraction of mascot size
    var secondHop: CGFloat = 0     // 0 = single hop
    var squash: CGFloat = 0        // 0…1
    var wiggle: Double = 0         // degrees

    static let hop       = MascotReaction(firstHop: 0.16, squash: 1)
    static let littleHop = MascotReaction(firstHop: 0.07, squash: 0.6)
    static let doubleHop = MascotReaction(firstHop: 0.18, secondHop: 0.12, squash: 1)
    static let wiggle    = MascotReaction(squash: 0.3, wiggle: 7)
    static let nudge     = MascotReaction(squash: 0.45)
}

// MARK: - View

struct MascotView: View {

    var mood: MascotMood = .idle
    /// Side of the square canvas. The visible cat is a little smaller —
    /// the canvas includes headroom for the cheering arms.
    var size: CGFloat = 140
    /// Tap to hop. Off for logos and other decorative uses.
    var isInteractive: Bool = true
    /// Ambient motion and idle actions. Off for very small, static uses.
    var isAnimated: Bool = true
    /// Hop hello when the cat first appears.
    var greetsOnAppear: Bool = true
    /// Called after the cat reacts to a tap — e.g. to cycle a tip.
    var onTap: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    @State private var reaction = MascotReaction.hop
    @State private var reactionTrigger = 0
    @State private var sparkleTrigger = 0
    @State private var tapCount = 0
    @State private var breathe = false
    @State private var sway = false

    private var moves: Bool { isAnimated && !reduceMotion }

    /// The pose actually drawn — the mood's pose, unless it would look soft
    /// at this size (see `MascotPose.renderable`).
    private var pose: MascotPose {
        mood.pose.renderable(atPoints: size, scale: displayScale)
    }
    private var floorAnchor: UnitPoint { UnitPoint(x: 0.5, y: MascotPose.floorY) }

    var body: some View {
        KeyframeAnimator(initialValue: MascotMotion(), trigger: reactionTrigger) { motion in
            ZStack {
                groundShadow(lift: motion.lift)

                ZStack {
                    Image(pose.assetName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .id(pose)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.92, anchor: floorAnchor).combined(with: .opacity)
                        )
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: pose)
                // Breath and sway: always-on, deliberately out of phase.
                .scaleEffect(x: 1, y: breathe ? 1.022 : 1, anchor: floorAnchor)
                .rotationEffect(.degrees(swayAngle), anchor: floorAnchor)
                // Airborne poses bob instead of sway.
                .offset(y: airBob)
                // The reaction on top.
                .scaleEffect(
                    x: 1 / max(motion.stretch, 0.5),
                    y: motion.stretch,
                    anchor: floorAnchor
                )
                .rotationEffect(.degrees(motion.tilt), anchor: floorAnchor)
                .offset(y: -motion.lift)
                .overlay { moodAccessory.offset(y: -motion.lift) }
                .overlay {
                    MascotSparkles(trigger: sparkleTrigger, center: UnitPoint(x: 0.5, y: pose.eyeY))
                        .offset(y: -motion.lift)
                }
            }
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                LinearKeyframe(0, duration: 0.07)
                SpringKeyframe(size * reaction.firstHop, duration: 0.2, spring: .snappy)
                SpringKeyframe(0, duration: 0.22, spring: Spring(duration: 0.28, bounce: 0.15))
                SpringKeyframe(size * reaction.secondHop, duration: 0.18, spring: .snappy)
                SpringKeyframe(0, duration: 0.24, spring: Spring(duration: 0.3, bounce: 0.2))
            }
            KeyframeTrack(\.stretch) {
                CubicKeyframe(1 - 0.10 * reaction.squash, duration: 0.07)   // anticipation
                CubicKeyframe(1 + 0.09 * reaction.squash, duration: 0.12)   // take-off stretch
                CubicKeyframe(1, duration: 0.12)
                CubicKeyframe(1 - 0.09 * reaction.squash, duration: 0.08)   // landing squash
                CubicKeyframe(1 + 0.04 * reaction.squash, duration: 0.10)
                SpringKeyframe(1, duration: 0.3, spring: .bouncy)
            }
            KeyframeTrack(\.tilt) {
                CubicKeyframe(-reaction.wiggle, duration: 0.09)
                CubicKeyframe(reaction.wiggle, duration: 0.12)
                CubicKeyframe(-reaction.wiggle * 0.6, duration: 0.11)
                CubicKeyframe(reaction.wiggle * 0.3, duration: 0.11)
                CubicKeyframe(0, duration: 0.14)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { if isInteractive { handleTap() } }
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .onAppear(perform: startAmbient)
        .onChange(of: mood) { _, newMood in react(to: newMood) }
        .task(id: TaskKey(mood: mood, active: moves && scenePhase == .active)) {
            await idleLoop()
        }
        .accessibilityHidden(true)
    }

    // MARK: Pieces

    private var swayAngle: Double {
        guard moves, mood.sways else { return 0 }
        let amplitude = mood == .thinking ? 4.5 : 1.8
        return sway ? amplitude : -amplitude
    }

    private var airBob: CGFloat {
        guard moves, !pose.isGrounded else { return 0 }
        return breathe ? -size * 0.035 : size * 0.01
    }

    /// The contact shadow. It belongs to the floor, so it stays put while
    /// the cat hops — shrinking and fading as the cat gets further away.
    private func groundShadow(lift: CGFloat) -> some View {
        let height = max(size * 0.18, 1)
        // An airborne pose starts "away" from the floor already.
        let base: CGFloat = pose.isGrounded ? 0 : 0.6
        let away = min(base + lift / height, 1)
        return Ellipse()
            .fill(DS.Colors.groundShadow)
            .frame(width: size * 0.52 * (1 - away * 0.35), height: size * 0.065 * (1 - away * 0.3))
            .opacity(1 - away * 0.55)
            .blur(radius: size * 0.012)
            .position(x: size / 2, y: size * MascotPose.floorY)
    }

    @ViewBuilder
    private var moodAccessory: some View {
        switch mood {
        case .thinking:
            MascotThoughtDots(size: size * 0.20, animates: moves)
                .position(x: size * 0.80, y: size * max(pose.headTopY + 0.05, 0.08))
        case .concerned:
            MascotAlertBadge(size: size * 0.17, animates: moves)
                .position(x: size * 0.79, y: size * (pose.headTopY + 0.08))
        case .sleeping:
            MascotSleepZs(size: size * 0.24, animates: moves)
                .position(x: size * 0.72, y: size * max(pose.headTopY - 0.02, 0.12))
        case .idle, .happy, .cheer, .cool, .working, .excited:
            EmptyView()
        }
    }

    // MARK: Behaviour

    private func startAmbient() {
        guard moves else { return }
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            breathe = true
        }
        withAnimation(.easeInOut(duration: 2.9).repeatForever(autoreverses: true)) {
            sway = true
        }
        if greetsOnAppear {
            play(mood == .cheer ? .doubleHop : .hop, sparkles: mood == .cheer)
        }
    }

    private func react(to newMood: MascotMood) {
        switch newMood {
        case .cheer:     play(.doubleHop, sparkles: true)
        case .happy:     play(.hop)
        case .concerned: play(.wiggle)
        case .thinking:  play(.nudge)
        case .idle:      play(.littleHop)
        case .cool:      play(.littleHop, sparkles: true)
        case .working:   play(.nudge)
        case .sleeping:  break                      // don't wake it
        case .excited:   play(.hop, sparkles: true)
        }
    }

    private func handleTap() {
        tapCount += 1
        play(mood == .cheer ? .doubleHop : .hop, sparkles: true)
        onTap?()
    }

    private func play(_ next: MascotReaction, sparkles: Bool = false) {
        guard moves else { return }
        reaction = next
        reactionTrigger += 1
        if sparkles { sparkleTrigger += 1 }
    }

    /// Small unprompted actions so the cat never looks frozen. Restarts
    /// when the mood changes; stops when the app is backgrounded, the view
    /// goes away, or Reduce Motion is on.
    private func idleLoop() async {
        guard moves, scenePhase == .active else { return }
        while !Task.isCancelled {
            let wait = Double.random(in: mood.idleInterval)
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            switch mood {
            case .cheer:     play(.hop, sparkles: Bool.random())
            case .happy:     play(Bool.random() ? .littleHop : .hop)
            case .concerned: play(.wiggle)
            case .thinking:  play(.nudge)
            case .idle:      play(Bool.random() ? .littleHop : .nudge)
            case .cool:      play(.nudge, sparkles: true)    // a glint off the shades
            case .working:   play(.nudge)                     // typing bob
            case .sleeping:  break
            case .excited:   play(.littleHop, sparkles: Bool.random())
            }
        }
    }

    /// Restarts the idle loop whenever its inputs change.
    private struct TaskKey: Equatable {
        let mood: MascotMood
        let active: Bool
    }
}

// MARK: - Sparkles

/// The coloured dashes from the original art, now as a burst that radiates
/// out from the head and fades. Plays once per `trigger` change.
struct MascotSparkles: View {

    var trigger: Int
    /// Burst centre, as a fraction of the view.
    var center: UnitPoint = UnitPoint(x: 0.5, y: 0.35)

    private static let colors: [Color] = [
        DS.Colors.accentCoral, DS.Colors.accentSunny, DS.Colors.accentMint, DS.Colors.accentSky
    ]
    /// Angles in degrees (0 = right, clockwise): three either side of the
    /// head, matching the art.
    private static let angles: [Double] = [-160, -195, -225, -20, 15, 45]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            KeyframeAnimator(initialValue: 0.0, trigger: trigger) { progress in
                ZStack {
                    ForEach(Self.angles.indices, id: \.self) { index in
                        dash(index: index, progress: progress, side: side)
                    }
                }
                .position(x: proxy.size.width * center.x, y: proxy.size.height * center.y)
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(0)
                    CubicKeyframe(1, duration: 0.75)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func dash(index: Int, progress: Double, side: CGFloat) -> some View {
        let radians = Self.angles[index] * .pi / 180
        let radius = side * (0.30 + 0.16 * progress)
        let fadeIn = min(progress / 0.15, 1)
        let fadeOut = 1 - max((progress - 0.45) / 0.55, 0)
        let visible = progress > 0 && progress < 1
        return Capsule()
            .fill(Self.colors[index % Self.colors.count])
            .frame(width: side * 0.075, height: side * 0.022)
            .rotationEffect(.radians(radians))
            .scaleEffect(0.6 + 0.4 * progress)
            .offset(x: cos(radians) * radius, y: sin(radians) * radius)
            .opacity(visible ? fadeIn * fadeOut : 0)
    }
}

// MARK: - Mood Accessories

/// "…" thought bubble for `.thinking`.
private struct MascotThoughtDots: View {

    let size: CGFloat
    let animates: Bool

    var body: some View {
        HStack(spacing: size * 0.08) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(DS.Colors.brandInk)
                    .frame(width: size * 0.15, height: size * 0.15)
                    .phaseAnimator(animates ? [0.0, 1.0] : [0.0]) { dot, phase in
                        dot.offset(y: -size * 0.08 * phase)
                    } animation: { _ in
                        .easeInOut(duration: 0.45).delay(Double(index) * 0.15)
                    }
            }
        }
        .padding(.horizontal, size * 0.18)
        .padding(.vertical, size * 0.14)
        .background(DS.Colors.surfaceRaised, in: Capsule())
        .overlay(Capsule().strokeBorder(DS.Colors.outline, lineWidth: 1))
        .dsShadow(DS.Shadows.soft)
    }
}

/// Drifting "z z z" for `.sleeping`.
private struct MascotSleepZs: View {

    let size: CGFloat
    let animates: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(0..<3, id: \.self) { index in
                Text("z")
                    .font(.system(size: size * (0.32 + 0.12 * CGFloat(index)), weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.brandInk)
                    .phaseAnimator(animates ? [CGFloat(0), 1] : [CGFloat(0.5)]) { z, phase in
                        z.offset(x: size * (0.18 * CGFloat(index) + 0.10 * phase),
                                 y: -size * (0.28 * CGFloat(index) + 0.22 * phase))
                            .opacity(animates ? Double(1 - 0.7 * phase) : 1)
                    } animation: { _ in
                        .easeInOut(duration: 1.6).delay(Double(index) * 0.35)
                    }
            }
        }
        .frame(width: size, height: size, alignment: .bottomLeading)
        .allowsHitTesting(false)
    }
}

/// "!" badge for `.concerned`.
private struct MascotAlertBadge: View {

    let size: CGFloat
    let animates: Bool

    var body: some View {
        Text("!")
            .font(.system(size: size * 0.62, weight: .heavy, design: .rounded))
            .foregroundStyle(DS.Colors.textOnAccent)
            .frame(width: size, height: size)
            .background(DS.Colors.accentSunny, in: Circle())
            .overlay(Circle().strokeBorder(DS.Colors.surfaceRaised, lineWidth: max(size * 0.07, 1)))
            .dsShadow(DS.Shadows.glow(DS.Colors.accentSunny, intensity: 0.4))
            .phaseAnimator(animates ? [0.0, 1.0] : [0.0]) { badge, phase in
                badge.rotationEffect(.degrees(-10 + 20 * phase))
            } animation: { _ in
                .easeInOut(duration: 0.5)
            }
    }
}

// MARK: - Previews

#Preview("Moods") {
    struct Demo: View {
        @State private var mood: MascotMood = .happy
        var body: some View {
            VStack(spacing: DS.Spacing.xl) {
                MascotView(mood: mood, size: 220)
                Picker("Mood", selection: $mood) {
                    Text("Idle").tag(MascotMood.idle)
                    Text("Happy").tag(MascotMood.happy)
                    Text("Cheer").tag(MascotMood.cheer)
                    Text("Think").tag(MascotMood.thinking)
                    Text("Alert").tag(MascotMood.concerned)
                }
                .pickerStyle(.segmented)
                Picker("More", selection: $mood) {
                    Text("Cool").tag(MascotMood.cool)
                    Text("Work").tag(MascotMood.working)
                    Text("Sleep").tag(MascotMood.sleeping)
                    Text("Leap").tag(MascotMood.excited)
                }
                .pickerStyle(.segmented)
                .padding()
            }
            .background(DS.Colors.background)
        }
    }
    return Demo()
}
