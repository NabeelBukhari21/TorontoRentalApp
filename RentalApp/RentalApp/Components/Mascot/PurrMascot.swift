//
//  PurrMascot.swift
//  RentalApp (Purrperty)
//
//  Components/Mascot — Purr, as every screen uses him.
//
//  Purr is a Rive rig (`Resources/Mascot/purr*.riv`, made in
//  /Users/admin/Projects/Rive/rentos-mascot). A `PurrMood` picks a pose,
//  face, prop and effect; changing it blends Purr into the new moment.
//  `PurrController` and `PurrMood` in `Purr/` are the generated vendor
//  files; this view adds what the app needs on top:
//
//  • the look the user picked (Settings ▸ Appearance), from the environment
//  • Reduce Motion: the pose blends in, then Purr holds still
//  • a tap: a haptic and a little reaction (or, where a screen asks for a
//    surprise, one of the 57 signature moves), then back to the mood
//  • VoiceOver: decorative; the words on screen carry the meaning
//

import Combine
import RiveRuntime
import SwiftUI

// MARK: - Look

extension EnvironmentValues {
    /// Purr's look, chosen in Settings ▸ Appearance.
    @Entry var purrStyle: PurrStyle = .classic
}

extension PurrStyle {
    var title: String {
        switch self {
        case .classic: "Classic"
        case .original: "Original"
        case .mochi: "Mochi"
        case .puff: "Puff"
        }
    }
}

extension PurrMood {
    /// The 57 big moves: rocket rides, skateboards, backflips and the rest.
    static let signatureMoves: [PurrMood] = allCases.filter { $0.section == "Signature" }
}

// MARK: - View

struct PurrMascot: View {

    var mood: PurrMood
    var size: CGFloat = 140
    /// Tapping makes Purr react. Off where he's part of something tappable.
    var isInteractive: Bool = true
    /// A tap plays a random signature move instead of the usual reaction.
    var surprisesOnTap: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(\.purrStyle) private var style

    var body: some View {
        // A new look is a new .riv file, so it needs a fresh controller.
        PurrCanvas(mood: mood, style: style, isInteractive: isInteractive, surprisesOnTap: surprisesOnTap, onTap: onTap)
            .id(style)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// One Rive view and its controller, for one look.
private struct PurrCanvas: View {

    let mood: PurrMood
    let isInteractive: Bool
    let surprisesOnTap: Bool
    let onTap: (() -> Void)?

    @StateObject private var controller: PurrController
    @State private var reaction: PurrMood?
    @State private var taps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mood: PurrMood, style: PurrStyle, isInteractive: Bool, surprisesOnTap: Bool, onTap: (() -> Void)?) {
        self.mood = mood
        self.isInteractive = isInteractive
        self.surprisesOnTap = surprisesOnTap
        self.onTap = onTap
        _controller = StateObject(wrappedValue: PurrController(mood: mood, style: style))
    }

    /// What Purr is doing right now: a reaction if one is playing.
    private var current: PurrMood { reaction ?? mood }

    var body: some View {
        controller.riveViewModel.view()
            .contentShape(.rect)
            .onTapGesture {
                guard isInteractive else { return }
                taps += 1
                react()
                onTap?()
            }
            .sensoryFeedback(.impact(weight: .light), trigger: taps)
            // Blend into the new moment; under Reduce Motion, settle and hold.
            .task(id: current) {
                controller.set(current)
                guard reduceMotion else {
                    controller.riveViewModel.play()
                    return
                }
                controller.riveViewModel.play()
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                controller.riveViewModel.pause()
            }
    }

    private func react() {
        let move = surprisesOnTap ? (PurrMood.signatureMoves.randomElement() ?? .tapReaction) : .tapReaction
        reaction = move
        Task {
            // Signature moves are longer; give them time to land.
            try? await Task.sleep(for: .seconds(surprisesOnTap ? 3.2 : 1.6))
            if reaction == move { reaction = nil }
        }
    }
}

// MARK: - Previews

#Preview("Moods") {
    HStack {
        PurrMascot(mood: .welcome, size: 120)
        PurrMascot(mood: .celebrate, size: 120)
        PurrMascot(mood: .error, size: 120)
    }
}
