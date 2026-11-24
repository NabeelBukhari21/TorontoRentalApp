//
//  PurrRig.swift
//  RentalApp (Purrperty)
//
//  Components/Mascot — Purr's Rive rig: the four looks, the controller
//  that drives one cat, and the view that draws him.
//
//  Adapted from `PurrView.swift` in the rentos-mascot project to Rive's
//  concurrency runtime (that file uses the deprecated `RiveViewModel`).
//  Every Purr shares one worker and one loaded file per look, so a second
//  cat on screen costs an artboard, not another 2 MB file.
//
//  This is the only file that imports RiveRuntime: the module exports
//  its own `Image`, `Color` and `File`, which would clash elsewhere.
//

import OSLog
import Observation
import RiveRuntime
import SwiftUI

/// Which look of Purr to show. Each one is its own .riv file with the
/// same rig, so every mood works on every look.
enum PurrStyle: String, CaseIterable, Identifiable, Sendable {
    case classic, original, mochi, puff

    var id: String { rawValue }
    var fileName: String { self == .classic ? "purr" : "purr_\(rawValue)" }
}

// MARK: - Files

/// Loads each look once.
@MainActor
private enum PurrFiles {

    private static var loads: [PurrStyle: Task<RiveRuntime.File, Error>] = [:]
    private static let worker = Task { @MainActor in try await RiveRuntime.Worker() }

    static func file(for style: PurrStyle) async throws -> RiveRuntime.File {
        if let load = loads[style] { return try await load.value }
        let load = Task { @MainActor in
            try await RiveRuntime.File(source: .local(style.fileName, .main), worker: worker.value)
        }
        loads[style] = load
        do {
            return try await load.value
        } catch {
            // Let the next Purr try again.
            loads[style] = nil
            throw error
        }
    }
}

// MARK: - Controller

/// One cat: his artboard, state machine, and the four numbers (pose, face,
/// prop, effect) that a mood sets.
@MainActor
@Observable
final class PurrController {

    let style: PurrStyle
    private(set) var mood: PurrMood
    var isPaused = false

    fileprivate private(set) var rive: Rive?
    @ObservationIgnored private var instance: ViewModelInstance?
    @ObservationIgnored private var loading: Task<Void, Never>?

    init(mood: PurrMood, style: PurrStyle) {
        self.mood = mood
        self.style = style
    }

    /// Safe to call from several places: the first call does the work and
    /// the rest wait for it.
    func load() async {
        if loading == nil { loading = Task { await performLoad() } }
        await loading?.value
    }

    private func performLoad() async {
        do {
            let file = try await PurrFiles.file(for: style)
            let artboard = try await file.createArtboard()
            let stateMachine = try await artboard.createStateMachine("Mascot")
            let instance = try await file.createViewModelInstance(.viewModelDefault(from: .artboardDefault(artboard)))
            self.instance = instance
            // Set before binding, so Purr appears already in the mood.
            apply(mood)
            try await stateMachine.bindViewModelInstances(main: instance)
            rive = try await Rive(file: file, artboard: artboard, stateMachine: stateMachine)
        } catch {
            loading = nil
            AppLog.app.error("Purr failed to load: \(error.localizedDescription, privacy: .public)")
        }
    }

    func set(_ mood: PurrMood) {
        guard mood != self.mood else { return }
        self.mood = mood
        apply(mood)
    }

    private func apply(_ mood: PurrMood) {
        guard let instance else { return }
        let parts = mood.parts
        instance.setValue(of: NumberProperty(path: "pose"), to: Float(parts.pose))
        instance.setValue(of: NumberProperty(path: "face"), to: Float(parts.face))
        instance.setValue(of: NumberProperty(path: "prop"), to: Float(parts.prop))
        instance.setValue(of: NumberProperty(path: "fx"), to: Float(parts.fx))
    }
}

// MARK: - View

/// Draws a controller's cat. Screens use `PurrMascot` instead.
struct PurrRigView: View {

    let controller: PurrController

    var body: some View {
        RiveUIViewRepresentable(rive: controller.rive)
            .paused(controller.isPaused)
            // Purr takes taps in SwiftUI; the Rive view must not eat them.
            .allowsHitTesting(false)
            .task { await controller.load() }
    }
}
