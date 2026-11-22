// PurrView.swift — drop-in SwiftUI view for Purr, the RentOS mascot.
//
// Setup
//   1. Xcode ▸ File ▸ Add Package Dependencies… ▸ https://github.com/rive-app/rive-ios
//      (product: RiveRuntime).
//   2. Add the look(s) you want from export/ (purr.riv, purr_original.riv, purr_mochi.riv,
//      purr_puff.riv)
//      and PurrMood.swift (from swift/) to the app target.
//
// Usage
//   PurrView(mood: .paymentSuccess)                  // default look
//   PurrView(mood: .paymentSuccess, style: .original) // the first design
//   PurrView(mood: .paymentSuccess, style: .mochi)   // chubby bun, pom-pom tail
//   PurrView(mood: .paymentSuccess, style: .puff)    // fluffy longhair, plume tail
//       .frame(width: 180, height: 180)
//
//   Change `mood` whenever the screen state changes; Purr blends into the new
//   pose and swaps face, prop and effect. All three looks share the same rig,
//   so every mood works on every look. Views that share one cat (for example
//   a dashboard header) can hold a PurrController in @StateObject and call
//   `controller.set(.allCaughtUp)` directly.

import Combine // Purrperty: MemberImportVisibility needs it for ObservableObject.
import SwiftUI
import RiveRuntime

/// Which look of Purr to show. Each one is its own .riv file with the same moods.
enum PurrStyle: String, CaseIterable, Identifiable {
    case classic, original, mochi, puff
    var id: String { rawValue }
    var fileName: String { self == .classic ? "purr" : "purr_\(rawValue)" }
}

@MainActor
final class PurrController: ObservableObject {
    let riveViewModel: RiveViewModel
    private var instance: RiveDataBindingViewModel.Instance?
    private(set) var mood: PurrMood

    init(mood: PurrMood = .dashboard, style: PurrStyle = .classic) {
        self.mood = mood
        riveViewModel = RiveViewModel(
            fileName: style.fileName,
            stateMachineName: "Mascot",
            fit: .contain,
            alignment: .center
        )
        // Bind the file's default "Mascot" view model instance, then push the
        // starting mood into it. The closure can fire again if the artboard or
        // state machine changes, so always keep the latest instance.
        riveViewModel.riveModel?.enableAutoBind { [weak self] instance in
            Task { @MainActor in
                guard let self else { return }
                self.instance = instance
                self.apply(self.mood)
            }
        }
    }

    func set(_ mood: PurrMood) {
        guard mood != self.mood || instance == nil else { return }
        self.mood = mood
        apply(mood)
    }

    private func apply(_ mood: PurrMood) {
        guard let instance else { return }
        let p = mood.parts
        instance.numberProperty(fromPath: "pose")?.value = Float(p.pose)
        instance.numberProperty(fromPath: "face")?.value = Float(p.face)
        instance.numberProperty(fromPath: "prop")?.value = Float(p.prop)
        instance.numberProperty(fromPath: "fx")?.value = Float(p.fx)
    }
}

struct PurrView: View {
    var mood: PurrMood
    @StateObject private var controller: PurrController

    init(mood: PurrMood, style: PurrStyle = .classic) {
        self.mood = mood
        _controller = StateObject(wrappedValue: PurrController(mood: mood, style: style))
    }

    var body: some View {
        controller.riveViewModel.view()
            .onChange(of: mood) { _, newMood in controller.set(newMood) }
            .accessibilityHidden(true) // decorative; pair it with real text on screen
    }
}

#if DEBUG
/// Every preset and look in one screen, for checking moods on device.
struct PurrGallery: View {
    @State private var selected: PurrMood = .splash
    @State private var style: PurrStyle = .classic

    var body: some View {
        VStack(spacing: 12) {
            Picker("Look", selection: $style) {
                ForEach(PurrStyle.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            PurrView(mood: selected, style: style)
                .id(style) // a new look loads a new file
                .frame(height: 260)
            Text(selected.rawValue).font(.headline)
            Text(selected.section).font(.caption).foregroundStyle(.secondary)
            List(PurrMood.allCases) { mood in
                Button(mood.rawValue) { selected = mood }
            }
        }
        .padding(.horizontal)
    }
}

#Preview { PurrGallery() }
#endif
