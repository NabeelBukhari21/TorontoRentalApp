//
//  TapAwayKeyboard.swift
//  RentalApp (Purrperty)
//
//  Keyboard — A tap anywhere outside the field being typed in puts the
//  keyboard away, on every screen and sheet. One recognizer per window,
//  which never takes the touch, so buttons and lists still get it.
//

import UIKit

@MainActor
enum TapAwayKeyboard {

    private static let recognizer = Recognizer()

    /// Call once at launch; windows are picked up as they become key.
    static func install() {
        NotificationCenter.default.addObserver(
            recognizer, selector: #selector(Recognizer.windowBecameKey),
            name: UIWindow.didBecomeKeyNotification, object: nil
        )
    }

    /// Puts the keyboard away.
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @MainActor
    private final class Recognizer: NSObject, UIGestureRecognizerDelegate {

        private let windows = NSHashTable<UIWindow>.weakObjects()

        @objc func windowBecameKey(_ note: Notification) {
            guard let window = note.object as? UIWindow, !windows.contains(window) else { return }
            windows.add(window)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
        }

        @objc private func tapped(_ tap: UITapGestureRecognizer) {
            guard let window = tap.view as? UIWindow, let field = window.firstResponder else { return }
            // The touch may have moved to another field; if so, leave it.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                if window.firstResponder === field { window.endEditing(true) }
            }
        }

        func gestureRecognizer(_ gesture: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let window = gesture.view as? UIWindow, let field = window.firstResponder, field is UITextInput else { return false }
            // Its own icons and buttons (clear, show password, send) count
            // as the field.
            if field.convert(field.bounds, to: window).insetBy(dx: -64, dy: -16).contains(touch.location(in: window)) { return false }
            var view = touch.view
            while let current = view {
                if current is UITextInput { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool { true }
    }
}

private extension UIView {
    var firstResponder: UIView? {
        if isFirstResponder { return self }
        for view in subviews {
            if let found = view.firstResponder { return found }
        }
        return nil
    }
}
