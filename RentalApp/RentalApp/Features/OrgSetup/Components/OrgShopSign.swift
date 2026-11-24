//
//  OrgShopSign.swift
//  RentalApp (Purrperty)
//
//  Org Setup — A clay shop sign hung from the counter, with the name going
//  up on it letter by letter. It swings as it's typed on.
//

import SwiftUI

struct OrgShopSign: View {

    let name: String
    let monogram: String
    let colors: [Color]
    var height: CGFloat = 92

    @State private var swing = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let rope: CGFloat = 24
    private var isBlank: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ropeView
                Spacer()
                ropeView
            }
            .padding(.horizontal, 54)
            board
        }
        .rotationEffect(.degrees(swing), anchor: .top)
        .onChange(of: name) { old, new in
            guard !reduceMotion else { return }
            // A push from the new letter, then it settles.
            var jump = Transaction(animation: nil)
            jump.disablesAnimations = true
            withTransaction(jump) { swing = new.count >= old.count ? 2.4 : -2.4 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.28)) { swing = 0 }
        }
        .accessibilityElement()
        .accessibilityLabel(isBlank ? "Sign preview, no name yet" : "Sign preview: \(name)")
    }

    private var ropeView: some View {
        Capsule()
            .fill(DSAccent.gold.ink)
            .frame(width: 5, height: Self.rope + 34)
            .padding(.top, -34)
    }

    private var board: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(.clay(DS.Colors.accentGold, shade: DSAccent.gold.ink, size: 56))
                if isBlank {
                    Image(systemName: "pawprint.fill").font(.system(size: 24, weight: .bold))
                } else {
                    Text(monogram).font(DS.Typography.brandFixed(22))
                        .contentTransition(.interpolate)
                }
            }
            .foregroundStyle(DSAccent.gold.onFill)
            .frame(width: 56, height: 56)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
            .jelly(on: monogram)

            VStack(alignment: .leading, spacing: 1) {
                Text(isBlank ? "Your name here" : name)
                    .font(DS.Typography.brandFixed(26))
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .opacity(isBlank ? 0.75 : 1)
                Text("Rentals, well looked after")
                    .font(DS.Typography.brandFixed(13))
                    .opacity(0.92)
            }
            .foregroundStyle(DS.Colors.onFixedColor)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: height)
        .background {
            shape.fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .shadow(.inner(color: .white.opacity(0.4), radius: 3, x: 1, y: 3))
                .shadow(.inner(color: .black.opacity(0.28), radius: 6, x: -2, y: -5)))
            shape.inset(by: 7).strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
        }
        .overlay(alignment: .topLeading) { screw.offset(x: 51, y: 6) }
        .overlay(alignment: .topTrailing) { screw.offset(x: -51, y: 6) }
        .shadow(color: DS.Colors.groundShadow, radius: 12, y: 10)
        .animation(DS.Motion.bouncy, value: colors)
    }

    private var screw: some View {
        Circle()
            .fill(.clay(DS.Colors.accentGold, shade: DSAccent.gold.ink, size: 12))
            .frame(width: 11, height: 11)
    }
}

#Preview {
    OrgShopSign(name: "Maple Rentals", monogram: "MR", colors: DS.Gradients.monogramStops[0]).padding()
}
