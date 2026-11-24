//
//  FeedbackCue.swift
//  RentalApp (Purrperty)
//
//  Feedback — The moments that can be felt and heard. A cue names what
//  happened; what it sounds and feels like is decided here, once.
//

import Foundation

enum FeedbackCue: Equatable, Sendable {
    /// A chunky button going down.
    case press
    /// A light control: Skip, a link, a menu.
    case tap
    /// A text field taking focus.
    case focus
    /// An answer picked; each position has its own note.
    case select(Int)
    case deselect
    /// Moving on, and going back.
    case advance, back
    /// A password rule met.
    case tick
    /// A build task finished.
    case taskDone(Int)
    /// Liquid filling the screen, and filling the paw button.
    case flood, fill
    /// The launch drop landing.
    case drop
    /// The reward.
    case celebrate
    /// An unlock card landing.
    case deal(Int)
    case error
    /// Purr being stroked.
    case purr

    /// The sound's file name.
    var sound: String {
        switch self {
        case .press: "press"
        case .tap: "tap"
        case .focus: "focus"
        case .select(let i): "select\(min(max(i, 0), 4))"
        case .deselect: "deselect"
        case .advance: "advance"
        case .back: "back"
        case .tick: "tick"
        case .taskDone(let i): "done\(min(max(i, 0), 2))"
        case .flood: "flood"
        case .fill: "fill"
        case .drop: "drop"
        case .celebrate: "celebrate"
        case .deal(let i): "deal\(min(max(i, 0), 6))"
        case .error: "error"
        case .purr: "purr"
        }
    }

    /// Every sound file, for loading ahead.
    static let allSounds: [String] = {
        let single: [FeedbackCue] = [.press, .tap, .focus, .deselect, .advance, .back, .tick, .flood, .fill, .drop, .celebrate, .error, .purr]
        let runs = (0..<5).map(FeedbackCue.select) + (0..<3).map(FeedbackCue.taskDone) + (0..<7).map(FeedbackCue.deal)
        return (single + runs).map(\.sound)
    }()

    /// One beat of a haptic: a tap, or a rumble if it has a duration.
    struct Beat: Equatable, Sendable {
        let time: Double
        var duration: Double = 0
        let intensity: Float
        let sharpness: Float
        /// Where a rumble's strength ends up.
        var endIntensity: Float? = nil
    }

    var haptic: [Beat] {
        switch self {
        case .press: [.init(time: 0, intensity: 0.65, sharpness: 0.45)]
        case .tap, .focus: [.init(time: 0, intensity: 0.4, sharpness: 0.6)]
        case .select: [.init(time: 0, intensity: 0.75, sharpness: 0.55), .init(time: 0.07, intensity: 0.35, sharpness: 0.8)]
        case .deselect: [.init(time: 0, intensity: 0.4, sharpness: 0.3)]
        case .advance: [.init(time: 0, duration: 0.18, intensity: 0.12, sharpness: 0.2, endIntensity: 0.45), .init(time: 0.2, intensity: 0.6, sharpness: 0.4)]
        case .back: [.init(time: 0, intensity: 0.5, sharpness: 0.3), .init(time: 0.02, duration: 0.14, intensity: 0.35, sharpness: 0.15, endIntensity: 0.05)]
        case .tick: [.init(time: 0, intensity: 0.45, sharpness: 0.9)]
        case .taskDone: [.init(time: 0, intensity: 0.6, sharpness: 0.5), .init(time: 0.09, intensity: 0.85, sharpness: 0.6)]
        case .flood: [.init(time: 0, duration: 0.65, intensity: 0.1, sharpness: 0.1, endIntensity: 0.8), .init(time: 0.66, intensity: 1, sharpness: 0.3)]
        case .fill: [.init(time: 0, duration: 0.36, intensity: 0.15, sharpness: 0.15, endIntensity: 0.6), .init(time: 0.38, intensity: 0.8, sharpness: 0.4)]
        case .drop: [.init(time: 0.08, intensity: 0.8, sharpness: 0.2), .init(time: 0.2, intensity: 0.45, sharpness: 0.6)]
        case .celebrate:
            (0..<4).map { .init(time: Double($0) * 0.075, intensity: 0.4 + Float($0) * 0.15, sharpness: 0.5) }
                + [.init(time: 0.34, duration: 0.35, intensity: 0.6, sharpness: 0.2, endIntensity: 0)]
        case .deal: [.init(time: 0.01, intensity: 0.4, sharpness: 0.6)]
        case .error: [.init(time: 0, intensity: 0.8, sharpness: 0.2), .init(time: 0.12, intensity: 0.8, sharpness: 0.2)]
        case .purr:
            // A motor: soft pulses, 25 a second, after the "mrrp".
            [.init(time: 0.05, intensity: 0.5, sharpness: 0.5)]
                + (0..<24).map { .init(time: 0.3 + Double($0) * 0.04, intensity: 0.5 * sin(Float($0) / 24 * .pi), sharpness: 0.05) }
        }
    }
}
