//
//  PurrStillStudio.swift
//  RentalApp (Purrperty)
//
//  Diagnostics — Renders one of Purr's moods as a still, for the logo,
//  the app icon, toasts and the motion studies. DEBUG builds only.
//
//      -PurrpertyStill welcome [-PurrpertyStillStyle classic]
//
//  Purr fills the screen width, settles into the mood and freezes. The
//  background is white for the first three seconds, then black, so two
//  screenshots of the same frozen frame give exact transparency
//  (tools/mascot/purr_stills.py does the capture and the matting).
//

#if DEBUG
import Combine
import RiveRuntime
import SwiftUI

struct PurrStillStudio: View {

    struct Request {
        let mood: PurrMood
        let style: PurrStyle
    }

    /// The still this launch should render, if asked for.
    static var request: Request? {
        let defaults = UserDefaults.standard
        guard let name = defaults.string(forKey: "PurrpertyStill"),
              let mood = PurrMood(rawValue: name) else { return nil }
        let style = defaults.string(forKey: "PurrpertyStillStyle").flatMap(PurrStyle.init(rawValue:)) ?? .classic
        return Request(mood: mood, style: style)
    }

    let request: Request

    @StateObject private var controller: PurrController
    @State private var isDark = false

    init(request: Request) {
        self.request = request
        _controller = StateObject(wrappedValue: PurrController(mood: request.mood, style: request.style))
    }

    var body: some View {
        GeometryReader { proxy in
            controller.riveViewModel.view()
                .frame(width: proxy.size.width, height: proxy.size.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(isDark ? Color.black : Color.white)
        .ignoresSafeArea()
        .statusBarHidden()
        .task {
            controller.set(request.mood)
            try? await Task.sleep(for: .seconds(1.6))
            controller.riveViewModel.pause()
            try? await Task.sleep(for: .seconds(1.4))
            isDark = true
        }
    }
}
#endif
