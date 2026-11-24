//
//  FeedbackPlayer.swift
//  RentalApp (Purrperty)
//
//  Feedback — Plays a cue's haptic and sound together.
//
//  Sounds use the ambient session: they follow the Ring/Silent switch and
//  never interrupt the user's music. They also stay quiet while VoiceOver
//  is talking. Both halves can be turned off in Settings ▸ Appearance.
//  Haptics follow the system setting by themselves.
//
//  Views reach it through `\.feedback`; nothing plays in previews.
//

import AVFoundation
import CoreHaptics
import OSLog
import SwiftUI

@MainActor
final class FeedbackPlayer {

    private let preferences: PreferencesRepositoryProtocol
    private var sounds: [String: AVAudioPlayer] = [:]
    private var engine: CHHapticEngine?
    private var music: AVAudioPlayer?
    private var isPrepared = false

    init(preferences: PreferencesRepositoryProtocol) {
        self.preferences = preferences
    }

    /// Loads the sounds and starts the haptic engine, so the first cue is
    /// as quick as the rest. Safe to call more than once.
    func prepare() async {
        guard !isPrepared else { return }
        isPrepared = true

        // File reads and the audio session stay off the main thread.
        let data = await Task.detached(priority: .utility) {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            return FeedbackCue.allSounds.reduce(into: [String: Data]()) { result, name in
                result[name] = Bundle.main.url(forResource: name, withExtension: "wav").flatMap { try? Data(contentsOf: $0) }
            }
        }.value

        for (name, bytes) in data {
            guard let player = try? AVAudioPlayer(data: bytes) else { continue }
            player.prepareToPlay()
            sounds[name] = player
            // A little at a time: the launch is animating.
            await Task.yield()
        }
        if sounds.count != FeedbackCue.allSounds.count {
            AppLog.app.error("Feedback: \(FeedbackCue.allSounds.count - self.sounds.count, privacy: .public) sounds failed to load")
        }
        startEngine()
    }

    func play(_ cue: FeedbackCue) {
        if preferences.hapticsEnabled { playHaptic(cue) }
        if preferences.soundEffectsEnabled, !UIAccessibility.isVoiceOverRunning { playSound(cue) }
    }

    // MARK: Sound

    private func playSound(_ cue: FeedbackCue) {
        guard let name = cue.sound, let player = sounds[name] else { return }
        // Again before it's finished: start over, rather than miss one.
        player.currentTime = 0
        let started = player.play()
        AppLog.app.debug("Feedback: \(name, privacy: .public) \(started ? "played" : "refused", privacy: .public)")
    }

    // MARK: Music

    /// Starts a score from the top, if sounds are on.
    func startMusic(_ name: String) {
        guard preferences.soundEffectsEnabled, !UIAccessibility.isVoiceOverRunning,
              let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.8
        player.play()
        music = player
    }

    /// Fades the score out.
    func stopMusic() {
        guard let player = music else { return }
        music = nil
        player.setVolume(0, fadeDuration: 0.35)
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            player.stop()
        }
    }

    // MARK: Haptics

    private func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            try engine.start()
            self.engine = engine
        } catch {
            AppLog.app.error("Feedback: haptic engine failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func playHaptic(_ cue: FeedbackCue) {
        guard let engine else { return }
        do {
            // It shuts down when idle or interrupted; starting it again when
            // it's running costs nothing.
            try engine.start()
            var events: [CHHapticEvent] = []
            var curves: [CHHapticParameterCurve] = []
            for beat in cue.haptic {
                let parameters = [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: beat.endIntensity == nil ? beat.intensity : 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: beat.sharpness)
                ]
                if beat.duration > 0 {
                    events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: parameters, relativeTime: beat.time, duration: beat.duration))
                    if let end = beat.endIntensity {
                        curves.append(CHHapticParameterCurve(
                            parameterID: .hapticIntensityControl,
                            controlPoints: [.init(relativeTime: 0, value: beat.intensity), .init(relativeTime: beat.duration, value: end)],
                            relativeTime: beat.time
                        ))
                        // Back to full strength for the beats after it.
                        curves.append(CHHapticParameterCurve(
                            parameterID: .hapticIntensityControl,
                            controlPoints: [.init(relativeTime: 0, value: 1)],
                            relativeTime: beat.time + beat.duration
                        ))
                    }
                } else {
                    events.append(CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: beat.time))
                }
            }
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            AppLog.app.error("Feedback: haptic failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension EnvironmentValues {
    /// Plays haptics and sounds. Nil in previews.
    @Entry var feedback: FeedbackPlayer? = nil
}
