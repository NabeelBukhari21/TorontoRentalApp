//
//  PawGauge.swift
//  RentalApp (Purrperty)
//
//  Dashboard — Five numbers as one paw of liquid glass: the pad is rent
//  collected, the toes are homes rented, repairs closed, tasks done and
//  the rent streak. Touch one to pick it.
//

#if DEBUG
import SwiftUI

enum PawToe: Int, CaseIterable, Identifiable {
    case homes, repairs, tasks, streak, rent
    var id: Int { rawValue }

    var accent: DSAccent {
        switch self {
        case .rent: .cherry
        case .homes: .gold
        case .repairs: .sky
        case .tasks: .mint
        case .streak: .blush
        }
    }

    var name: String {
        switch self {
        case .rent: "Rent in"
        case .homes: "Rented"
        case .repairs: "Repairs"
        case .tasks: "To do"
        case .streak: "Streak"
        }
    }

    var symbol: String {
        switch self {
        case .rent: "dollarsign"
        case .homes: "key.fill"
        case .repairs: "wrench.fill"
        case .tasks: "checklist"
        case .streak: "flame.fill"
        }
    }
}

extension HomeStudioModel {

    /// How full the toe is, 0…1.
    func level(_ toe: PawToe) -> Double {
        switch toe {
        case .rent: rentRate
        case .homes: occupancy
        case .repairs: resolvedRate
        case .tasks: taskRate
        case .streak: min(1, Double(dashboard.streak.count) / 6)
        }
    }

    func value(_ toe: PawToe) -> String {
        switch toe {
        case .rent: "\(Int((rentRate * 100).rounded()))%"
        case .homes: "\(Int((occupancy * 100).rounded()))%"
        case .repairs: "\(requests)"
        case .tasks: "\(openTasks.count)"
        case .streak: "\(dashboard.streak.count)"
        }
    }

    func detail(_ toe: PawToe) -> String {
        switch toe {
        case .rent: rentLine
        case .homes: "\(dashboard.occupiedUnits) of \(dashboard.unitCount) rented. \(dashboard.vacantUnits) empty."
        case .repairs: "\(requests) open. I've sorted them by urgency."
        case .tasks: urgentTasks > 0 ? "\(urgentTasks) urgent today. Let's go!" : "\(openTasks.count) things lined up."
        case .streak: "\(dashboard.streak.count) months of rent on time."
        }
    }

    func mood(_ toe: PawToe) -> PurrMood {
        switch toe {
        case .rent: .moneyDance
        case .homes: .keysReady
        case .repairs: .builder
        case .tasks: urgentTasks > 0 ? .urgentIssue : .tasksWaiting
        case .streak: .streak
        }
    }
}

struct PawGauge: View {
    let model: HomeStudioModel
    @Binding var picked: PawToe
    /// The paw's width; it's about as tall as it is wide.
    var size: CGFloat = 300

    @State private var fill = 0.0
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var k: CGFloat { size / 360 }

    var body: some View {
        ZStack {
            toe(.homes, w: 92, h: 112, tilt: -24).position(x: size * 0.13, y: size * 0.36)
            toe(.repairs, w: 100, h: 122, tilt: -8).position(x: size * 0.37, y: size * 0.17)
            toe(.tasks, w: 100, h: 122, tilt: 8).position(x: size * 0.63, y: size * 0.17)
            toe(.streak, w: 92, h: 112, tilt: 24).position(x: size * 0.87, y: size * 0.36)
            pad.frame(width: size * 0.72, height: size * 0.66).position(x: size * 0.5, y: size * 0.7)
        }
        .frame(width: size, height: size * 1.04)
        .task(id: model.dashboard.isLoading) {
            guard !model.dashboard.isLoading else { return }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(reduceMotion ? nil : .spring(response: 1.4, dampingFraction: 0.75)) { fill = 1 }
        }
    }

    private func glass(_ toe: PawToe, _ shape: some Shape) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 1.5 + Double(toe.rawValue)
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(DS.Colors.surfaceRaised.opacity(0.35))
                LiquidWave(level: max(0.08, model.level(toe) * fill * 0.94), phase: phase)
                    .fill(LinearGradient(colors: [toe.accent.fill.mix(with: .white, by: 0.2), toe.accent.fill], startPoint: .top, endPoint: .bottom))
                    .clipShape(shape)
                shape.fill(LinearGradient(colors: [.white.opacity(0.5), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.stroke(LinearGradient(colors: [.white, .white.opacity(0.25)], startPoint: .top, endPoint: .bottom), lineWidth: 2.5)
            }
        }
        .shadow(color: toe.accent.fill.opacity(picked == toe ? 0.55 : 0.22), radius: picked == toe ? 18 : 9, y: 8)
    }

    private func toe(_ toe: PawToe, w: CGFloat, h: CGFloat, tilt: Double) -> some View {
        Button { pick(toe) } label: {
            glass(toe, Ellipse())
                .rotationEffect(.degrees(tilt))
                .overlay {
                    VStack(spacing: 0) {
                        Image(systemName: toe.symbol).font(.system(size: 14 * k, weight: .bold))
                        Text(model.value(toe)).font(DS.Typography.brandFixed(25 * k)).contentTransition(.numericText())
                        Text(toe.name).font(DS.Typography.brandFixed(12 * k))
                    }
                    .foregroundStyle(DS.Colors.textPrimary)
                }
                .frame(width: w * k, height: h * k)
        }
        .buttonStyle(SquishStyle(scale: 0.88))
        .scaleEffect(picked == toe ? 1.12 : 1)
        .zIndex(picked == toe ? 2 : 1)
        .animation(DS.Motion.bouncy, value: picked)
        .accessibilityLabel("\(toe.name): \(model.value(toe))")
    }

    private var pad: some View {
        Button { pick(.rent) } label: {
            glass(.rent, PawPad())
                .overlay {
                    VStack(spacing: -4 * k) {
                        Text(model.value(.rent)).font(DS.Typography.brandFixed(60 * k))
                        Text("rent in").font(DS.Typography.brandFixed(18 * k))
                        Text(model.dollars(model.roll.collected)).font(DS.Typography.brandFixed(15 * k)).padding(.top, 6 * k)
                    }
                    .foregroundStyle(model.level(.rent) > 0.55 ? DS.Colors.textOnBrand : DS.Colors.textPrimary)
                    .shadow(color: model.level(.rent) > 0.55 ? DS.Colors.brandDeep.opacity(0.7) : .clear, radius: 5)
                    .offset(y: 12 * k)
                }
        }
        .buttonStyle(SquishStyle(scale: 0.95))
        .scaleEffect(picked == .rent ? 1.03 : 1)
        .animation(DS.Motion.bouncy, value: picked)
        .accessibilityLabel("Rent in: \(model.value(.rent))")
    }

    private func pick(_ toe: PawToe) {
        feedback?.play(.select(toe.rawValue))
        withAnimation(DS.Motion.bouncy) { picked = toe }
    }
}
#endif
