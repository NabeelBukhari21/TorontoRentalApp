//
//  DSProgress.swift
//  RentalApp
//
//  Design System — Progress indicators: animated bar, ring, and counter.
//

import SwiftUI

// MARK: - Progress Bar

/// A slim gradient progress bar that animates to its value on appear.
struct DSProgressBar: View {

    /// 0...1
    let value: Double
    var gradient: LinearGradient = DS.Gradients.brand
    var height: CGFloat = 8

    @State private var animatedValue: Double = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.Colors.surfaceSecondary)

                Capsule()
                    .fill(gradient)
                    .frame(width: proxy.size.width * max(0, min(1, animatedValue)))
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(DS.Motion.entrance.delay(0.1)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(DS.Motion.smooth) {
                animatedValue = newValue
            }
        }
    }
}

// MARK: - Progress Ring

/// A circular gauge with a rounded gradient stroke and centered label.
struct DSProgressRing: View {

    /// 0...1
    let value: Double
    var lineWidth: CGFloat = 10
    var size: CGFloat = 88
    var gradient: AngularGradient = AngularGradient(
        colors: [DS.Colors.brand, DS.Colors.brandViolet, DS.Colors.brandCyan, DS.Colors.brand],
        center: .center
    )
    var label: String? = nil

    @State private var animatedValue: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.Colors.surfaceSecondary, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, animatedValue)))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(Int(animatedValue * 100))%")
                    .font(DS.Typography.statValueSmall)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .contentTransition(.numericText())

                if let label {
                    Text(label)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(DS.Motion.entrance.delay(0.15)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(DS.Motion.smooth) {
                animatedValue = newValue
            }
        }
    }
}

// MARK: - Animated Counter

/// A number that rolls smoothly between values using numeric text transitions.
struct DSAnimatedCounter: View {

    let value: Int
    var font: Font = DS.Typography.statValue
    var prefix: String = ""
    var suffix: String = ""

    var body: some View {
        Text("\(prefix)\(value)\(suffix)")
            .font(font)
            .foregroundStyle(DS.Colors.textPrimary)
            .contentTransition(.numericText())
            .animation(DS.Motion.smooth, value: value)
    }
}

// MARK: - Previews

#Preview("Progress") {
    struct Demo: View {
        @State private var count = 128

        var body: some View {
            ZStack {
                DS.Colors.background.ignoresSafeArea()

                VStack(spacing: DS.Spacing.xxxl) {
                    DSProgressBar(value: 0.72)
                        .padding(.horizontal, DS.Spacing.xxl)

                    HStack(spacing: DS.Spacing.xxl) {
                        DSProgressRing(value: 0.94, label: "Occupancy")
                        DSProgressRing(
                            value: 0.38,
                            gradient: AngularGradient(
                                colors: [DS.Colors.accentCoral, DS.Colors.accentAmber, DS.Colors.accentCoral],
                                center: .center
                            ),
                            label: "Overdue"
                        )
                    }

                    VStack(spacing: DS.Spacing.sm) {
                        DSAnimatedCounter(value: count, prefix: "$", suffix: "K")
                        DSButton(title: "Randomize", variant: .secondary, size: .small) {
                            count = Int.random(in: 80...400)
                        }
                    }
                }
                .padding(DS.Spacing.xxl)
            }
        }
    }
    return Demo()
}
