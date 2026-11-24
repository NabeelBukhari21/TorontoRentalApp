//
//  RentJarView.swift
//  RentalApp (Purrperty)
//
//  Payments — After a payment is recorded: coins drop into the month's
//  jar. The jar's level is the month's real collection, before and after;
//  when all of it is in, Purr takes a victory lap.
//

import SwiftUI

/// What was just recorded, and where the month stands.
struct RentReceipt: Equatable, Sendable {
    let amount: Int
    let from: String
    let monthTitle: String
    /// Collection rate before and after, 0…1.
    let before: Double
    let after: Double
    let collected: Int
    let expected: Int

    var isFull: Bool { collected >= expected }
}

struct RentJarView: View {

    let receipt: RentReceipt
    let onDone: () -> Void

    @State private var start: Date?
    @State private var landed = 0
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Coins a full jar holds.
    private static let capacity = 30
    private static let columns = 5
    private static let dropEvery = 0.16
    private static let fallTime = 0.42

    private var coinsBefore: Int { min(Self.capacity - 1, Int((receipt.before * Double(Self.capacity)).rounded(.down))) }
    /// At least one drops, however small the payment.
    private var coinsAfter: Int {
        receipt.isFull ? Self.capacity : min(Self.capacity - 1, max(coinsBefore + 1, Int((receipt.after * Double(Self.capacity)).rounded())))
    }
    private var dropping: Int { coinsAfter - coinsBefore }
    private var isSettled: Bool { landed >= dropping }
    private var celebrates: Bool { isSettled && receipt.isFull }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(receipt.amount, format: .cad)
                    .font(DS.Typography.brand(48))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("from \(receipt.from), for \(receipt.monthTitle)")
                    .font(DS.Typography.brand(.subheadline))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(.top, 8)

            ZStack(alignment: .bottom) {
                jar.offset(x: -58)
                LivingPurr(mood: celebrates ? .victoryLap : isSettled ? .paymentSuccess : .moneyDance, size: 250, beat: isSettled)
                    .offset(x: 88, y: 12)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 14) {
                Text(celebrates ? "All of \(receipt.monthTitle)'s rent is in!" : "\(receipt.collected.formatted(.cad)) of \(receipt.expected.formatted(.cad)) collected")
                    .font(DS.Typography.brand(.title3, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                StageButton(title: "Done", isProminent: true, action: onDone)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                DS.Colors.background
                LinearGradient(colors: [DS.Colors.accentGold.opacity(0.4), DS.Colors.accentGold.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                if celebrates { SunRays(color: DSAccent.gold.fill, center: UnitPoint(x: 0.5, y: 0.5)).transition(.opacity) }
            }
            .ignoresSafeArea()
        }
        .overlay { if celebrates { OrgConfettiBurst().allowsHitTesting(false).accessibilityHidden(true) } }
        .animation(DS.Motion.smooth, value: isSettled)
        .task { await drop() }
    }

    private func drop() async {
        guard !reduceMotion else {
            landed = dropping
            feedback?.play(receipt.isFull ? .celebrate : .coin(0))
            return
        }
        try? await Task.sleep(for: .milliseconds(350))
        start = .now
        for i in 0..<dropping {
            try? await Task.sleep(for: .seconds(i == 0 ? Self.fallTime : Self.dropEvery))
            guard !Task.isCancelled else { return }
            landed = i + 1
            feedback?.play(.coin(i))
        }
        try? await Task.sleep(for: .milliseconds(250))
        if receipt.isFull, !Task.isCancelled { feedback?.play(.celebrate) }
    }

    // MARK: Jar

    private static let jarSize = CGSize(width: 176, height: 224)

    private var jar: some View {
        TimelineView(.animation(paused: start == nil || isSettled)) { context in
            let t = start.map { context.date.timeIntervalSince($0) } ?? 0
            ZStack {
                glass(back: true)
                ForEach(0..<coinsAfter, id: \.self) { i in
                    if let y = height(of: i, at: t) {
                        Coin()
                            .rotationEffect(.degrees(Double((i * 37) % 24) - 12))
                            .position(x: x(of: i), y: y)
                    }
                }
                glass(back: false)
            }
        }
        .frame(width: Self.jarSize.width, height: Self.jarSize.height)
        // Coins fall in from above the rim.
        .padding(.top, 60)
        .accessibilityElement()
        .accessibilityLabel("Rent jar")
        .accessibilityValue(receipt.after.formatted(.percent.precision(.fractionLength(0))))
    }

    private func x(of i: Int) -> CGFloat {
        let row = i / Self.columns
        let column = CGFloat((i * 3 + row) % Self.columns)
        return 34 + column * 27 + (row.isMultiple(of: 2) ? 0 : 6) - CGFloat((i * 13) % 5)
    }

    private func restingY(of i: Int) -> CGFloat {
        Self.jarSize.height - 24 - CGFloat(i / Self.columns) * 25 - CGFloat((i * 7) % 5)
    }

    /// Where a coin is; nil before it's in the air.
    private func height(of i: Int, at t: Double) -> CGFloat? {
        let rest = restingY(of: i)
        guard i >= coinsBefore, !reduceMotion else { return rest }
        guard start != nil else { return nil }
        let age = t - Double(i - coinsBefore) * Self.dropEvery
        guard age > 0 else { return nil }
        let top: CGFloat = -60
        if age < Self.fallTime {
            let p = age / Self.fallTime
            return top + (rest - top) * p * p
        }
        // One small bounce.
        let b = (age - Self.fallTime) / 0.22
        return b < 1 ? rest - 14 * 4 * b * (1 - b) : rest
    }

    private func glass(back: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 44, style: .continuous)
        return ZStack {
            if back {
                shape.fill(DS.Colors.surfaceRaised.opacity(0.55))
            } else {
                shape.strokeBorder(DS.Colors.textPrimary.opacity(0.75), lineWidth: 5)
                // Light down one side.
                Capsule().fill(.white.opacity(0.55))
                    .frame(width: 12, height: 120)
                    .position(x: 24, y: 96)
                Capsule().fill(DS.Colors.brand)
                    .overlay(Capsule().strokeBorder(DS.Colors.textPrimary.opacity(0.75), lineWidth: 5))
                    .frame(width: 150, height: 22)
                    .position(x: Self.jarSize.width / 2, y: 2)
                    .opacity(isSettled ? 1 : 0)
                    .offset(y: isSettled ? 0 : -40)
                Text("RENT")
                    .font(DS.Typography.brandFixed(17))
                    .foregroundStyle(DS.Colors.textOnBrand)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(DS.Colors.brand, in: .capsule)
                    .rotationEffect(.degrees(-4))
                    .position(x: Self.jarSize.width / 2 + 10, y: 130)
            }
        }
    }
}

private struct Coin: View {
    var body: some View {
        Circle()
            .fill(.clay(DS.Colors.accentGold, shade: DSAccent.gold.ink, size: 38))
            .overlay {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DSAccent.gold.ink)
            }
            .overlay(Circle().strokeBorder(DSAccent.gold.ink.opacity(0.7), lineWidth: 2))
            .frame(width: 38, height: 38)
    }
}

#Preview("Jar") {
    RentJarView(receipt: RentReceipt(amount: 2150, from: "Maya", monthTitle: "November 2026", before: 0.6, after: 1, collected: 20000, expected: 20000)) {}
}
