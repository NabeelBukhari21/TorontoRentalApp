//
//  DSMotion.swift
//  RentalApp
//
//  Design System — Motion tokens & reusable animation modifiers.
//  Every animation in the app should use these tokens for a consistent feel.
//

import SwiftUI

extension DS {

    enum Motion {

        /// Quick feedback — button presses, toggles.
        static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.82)

        /// Default UI transitions.
        static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.86)

        /// Playful emphasis — badges appearing, success states.
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.65)

        /// Content entrances — cards sliding in.
        static let entrance = Animation.spring(response: 0.55, dampingFraction: 0.8)

        /// Non-spring fallback for opacity/color changes.
        static let gentle = Animation.easeInOut(duration: 0.3)

        /// Stagger interval between sibling card entrances.
        static let staggerStep: Double = 0.06
    }
}

// MARK: - Press Scale (buttons, tappable cards)

/// Scales content down slightly while pressed. The standard press feedback.
struct DSPressStyle: ButtonStyle {

    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(DS.Motion.snappy, value: configuration.isPressed)
    }
}

// MARK: - Entrance

/// Fades + slides content in on first appearance. Use `index` to stagger siblings.
struct DSEntranceModifier: ViewModifier {

    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 18)
            .onAppear {
                withAnimation(DS.Motion.entrance.delay(Double(index) * DS.Motion.staggerStep)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Floating

/// Gentle perpetual vertical drift for hero elements. Use sparingly.
struct DSFloatingModifier: ViewModifier {

    var amplitude: CGFloat = 6
    var duration: Double = 3.2
    @State private var isFloating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -amplitude : amplitude)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }
    }
}

// MARK: - View Extensions

extension View {

    /// Staggered fade-and-rise entrance. Pass the item's position for a cascade.
    func dsEntrance(index: Int = 0) -> some View {
        modifier(DSEntranceModifier(index: index))
    }

    /// Gentle perpetual floating motion for hero elements.
    func dsFloating(amplitude: CGFloat = 6, duration: Double = 3.2) -> some View {
        modifier(DSFloatingModifier(amplitude: amplitude, duration: duration))
    }
}
