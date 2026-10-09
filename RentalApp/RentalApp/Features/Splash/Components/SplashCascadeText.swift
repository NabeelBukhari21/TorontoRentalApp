//
//  SplashCascadeText.swift
//  RentalApp
//
//  Splash — Text whose characters cascade in one by one with a
//  blur-and-rise reveal. Used for the tagline; reusable anywhere
//  a premium text entrance is needed.
//

import SwiftUI

struct SplashCascadeText: View {

    let text: String
    var isVisible: Bool = false
    var font: Font = DS.Typography.callout
    /// `textSecondary`: 4.90 on white. Was translucent white for the dark
    /// splash, which would be invisible on the bright one.
    var color: Color = DS.Colors.textSecondary
    var characterDelay: Double = 0.022
    var startDelay: Double = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(font)
                    .foregroundStyle(color)
                    .opacity(isVisible ? 1 : 0)
                    .blur(radius: isVisible ? 0 : 5)
                    .offset(y: isVisible ? 0 : 10)
                    .animation(
                        DS.Motion.smooth.delay(startDelay + Double(index) * characterDelay),
                        value: isVisible
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

#Preview("Cascade Text") {
    struct Demo: View {
        @State private var visible = false

        var body: some View {
            ZStack {
                SplashBackground()
                SplashCascadeText(
                    text: "Property management, reimagined.",
                    isVisible: visible
                )
            }
            .onAppear { visible = true }
        }
    }
    return Demo()
}
