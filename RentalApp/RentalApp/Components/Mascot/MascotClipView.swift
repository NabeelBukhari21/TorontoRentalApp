//
//  MascotClipView.swift
//  RentalApp (Purrperty)
//
//  Mascot — Purr's hand-animated clips, shown on a white "sticker" card.
//
//  Clips are rendered video, so unlike `MascotView` they can't be posed
//  live. The card is part of the design, not a workaround: clips are
//  delivered on white, and a white card with a soft shadow presents them
//  cleanly on any background, in light and dark mode alike.
//
//  Behaviour, Duolingo-style:
//  • Plays once when it becomes active, then holds its final pose with a
//    gentle breathing motion so it never looks frozen.
//  • Tap to replay (with a light haptic).
//  • Rewinds when it becomes inactive, so it greets again next time.
//  • Reduce Motion: shows the final pose, no playback.
//  • Missing resource: falls back to the live `MascotView`.
//

import AVFoundation
import Combine
import SwiftUI

// MARK: - Clip

enum MascotClip: String, CaseIterable, Sendable {
    /// Sits, then throws both paws up to say hi.
    case hello

    var resourceName: String {
        switch self {
        case .hello: "PurrHello"
        }
    }

    /// The pose the clip ends on — shown under Reduce Motion.
    var finalFrameTime: CMTime {
        switch self {
        case .hello: CMTime(value: 96, timescale: 24)
        }
    }

    /// The live mascot to show if the clip can't be loaded.
    var fallbackMood: MascotMood {
        switch self {
        case .hello: .cheer
        }
    }

    /// Fixed white: the clips are rendered on white, so the card must match
    /// exactly in both colour schemes.
    static let canvas = Color.white
}

// MARK: - View

struct MascotClipView: View {

    let clip: MascotClip
    var size: CGFloat = 200
    /// Plays when this becomes true; rewinds when it becomes false.
    var isActive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Created on first appearance, not in `init`: SwiftUI re-runs a view's
    /// initialiser on every parent update, and each run would build (and
    /// throw away) an AVPlayer.
    @State private var player: VideoClipPlayer?
    @State private var replays = 0
    @State private var breathe = false

    var body: some View {
        Group {
            if let player, !player.isAvailable {
                MascotView(mood: clip.fallbackMood, size: size)
            } else if let player {
                card(player)
            } else {
                // First frame, before the player exists: the empty card.
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(MascotClip.canvas)
                    .frame(width: size, height: size)
                    .dsShadow(DS.Shadows.card)
            }
        }
        .onAppear {
            if player == nil {
                player = VideoClipPlayer(resource: clip.resourceName)
            }
            sync(active: isActive)
        }
        .onChange(of: isActive) { _, active in sync(active: active) }
        .onDisappear { player?.reset() }
        .accessibilityHidden(true)
    }

    private func card(_ player: VideoClipPlayer) -> some View {
        VideoClipSurface(player: player.player)
            .frame(width: size, height: size)
            .background(MascotClip.canvas)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .strokeBorder(DS.Colors.outline, lineWidth: 1)
            )
            .dsShadow(DS.Shadows.card)
            // Idle "breathing" once the clip has landed on its final pose.
            .scaleEffect(breathe ? 1.015 : 1.0, anchor: .bottom)
            .animation(
                breathe ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .default,
                value: breathe
            )
            .contentShape(Rectangle())
            .onTapGesture { replay() }
            .sensoryFeedback(.impact(weight: .light), trigger: replays)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: AVPlayerItem.didPlayToEndTimeNotification,
                    object: player.item
                )
            ) { _ in
                player.didPlayToEnd()
                breathe = !reduceMotion
            }
    }

    // MARK: Actions

    private func sync(active: Bool) {
        guard let player, player.isAvailable else { return }
        breathe = false
        if !active {
            player.reset()
        } else if reduceMotion {
            player.hold(at: clip.finalFrameTime)
        } else {
            player.playFromStart()
        }
    }

    private func replay() {
        guard let player, player.isAvailable, !reduceMotion else { return }
        replays += 1
        breathe = false
        player.playFromStart()
    }
}

// MARK: - Previews

#Preview("Hello clip") {
    ZStack {
        SplashBackground()
        MascotClipView(clip: .hello, size: 220)
    }
}
