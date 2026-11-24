//
//  PurrMascot.swift
//  RentalApp (Purrperty)
//
//  Components/Mascot — Purr, as every screen uses him.
//
//  Purr is a Rive rig (`Resources/Mascot/purr*.riv`, made in
//  /Users/admin/Projects/Rive/rentos-mascot). A `PurrMood` picks a pose,
//  face, prop and effect; changing it blends Purr into the new moment.
//  `PurrMood` in `Purr/` is the generated catalogue and `PurrController`
//  drives the rig; this view adds what the app needs on top:
//
//  • the look the user picked (Settings ▸ Appearance), from the environment
//  • Reduce Motion: the pose blends in, then Purr holds still
//  • a tap: a haptic and a little reaction (or, where a screen asks for a
//    surprise, one of the 57 signature moves), then back to the mood
//  • VoiceOver: decorative; the words on screen carry the meaning
//

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

    @State private var controller: PurrController
    @State private var reaction: PurrMood?
    @State private var taps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mood: PurrMood, style: PurrStyle, isInteractive: Bool, surprisesOnTap: Bool, onTap: (() -> Void)?) {
        self.mood = mood
        self.isInteractive = isInteractive
        self.surprisesOnTap = surprisesOnTap
        self.onTap = onTap
        _controller = State(initialValue: PurrController(mood: mood, style: style))
    }

    /// What Purr is doing right now: a reaction if one is playing.
    private var current: PurrMood { reaction ?? mood }

    var body: some View {
        PurrRigView(controller: controller)
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
                controller.isPaused = false
                controller.set(current)
                guard reduceMotion else { return }
                // Loads before the timer starts, so there is a pose to hold.
                await controller.load()
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                controller.isPaused = true
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

// MARK: - Gallery

#if DEBUG
/// Every mood and look in one screen, for checking on device.
struct PurrGallery: View {

    @State private var mood: PurrMood = .splash
    @State private var style: PurrStyle = .classic

    var body: some View {
        VStack(spacing: 12) {
            Picker("Look", selection: $style) {
                ForEach(PurrStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            PurrMascot(mood: mood, size: 260)
                .environment(\.purrStyle, style)
            Text(mood.rawValue).font(.headline)
            Text(mood.section).font(.caption).foregroundStyle(.secondary)
            List(PurrMood.allCases) { option in
                Button(option.rawValue) { mood = option }
            }
        }
        .padding()
    }
}
#endif

// MARK: - Previews

#Preview("Moods") {
    HStack {
        PurrMascot(mood: .welcome, size: 120)
        PurrMascot(mood: .celebrate, size: 120)
        PurrMascot(mood: .error, size: 120)
    }
}

// MARK: - Unavailable Label

/// A `Label` whose icon is Purr acting out the moment, for the system
/// `ContentUnavailableView` (empty, error and waiting states) on the
/// native screens.
struct PurrLabel: View {

    let title: Text
    let mood: PurrMood

    init(_ titleKey: LocalizedStringKey, mood: PurrMood) {
        title = Text(titleKey)
        self.mood = mood
    }

    var body: some View {
        Label {
            title
        } icon: {
            PurrMascot(mood: mood, size: 132)
        }
    }
}

// MARK: - Note Row

/// Purr beside one line of fact, as the first row of a native list
/// ("1 month of rent is owing."). States only what the screen shows.
struct PurrNote: View {

    let mood: PurrMood
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            PurrMascot(mood: mood, size: 76)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
