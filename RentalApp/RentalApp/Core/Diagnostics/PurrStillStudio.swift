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

    @State private var controller: PurrController
    @State private var isDark = false

    init(request: Request) {
        self.request = request
        _controller = State(initialValue: PurrController(mood: request.mood, style: request.style))
    }

    var body: some View {
        GeometryReader { proxy in
            PurrRigView(controller: controller)
                .frame(width: proxy.size.width, height: proxy.size.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(isDark ? Color.black : Color.white)
        .ignoresSafeArea()
        .statusBarHidden()
        .task {
            await controller.load()
            try? await Task.sleep(for: .seconds(1.6))
            controller.isPaused = true
            try? await Task.sleep(for: .seconds(1.4))
            isDark = true
        }
    }
}
#endif
