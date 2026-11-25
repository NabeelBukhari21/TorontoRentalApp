//
//  PawHome.swift — E: The paw. Five numbers as one giant paw of liquid
//  glass: the pad is rent, the toes are homes, repairs, tasks and the
//  streak. Touch one and it swells and tells you more.
//

#if DEBUG
import SwiftUI

struct PawHome: View {
    let model: HomeStudioModel

    enum Pad: Int, CaseIterable, Identifiable { case homes, repairs, tasks, streak, rent; var id: Int { rawValue } }

    @State private var picked: Pad = .rent
    @State private var fill = 0.0
    @Environment(AppRouter.self) private var router
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HomeBar(model: model)
                paw.frame(height: 430)
                panel
                tasks
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background { LiquidBackdrop(look: OnboardingLook(accent: accent(picked), finish: .glow), origin: UnitPoint(x: 0.5, y: 0.4)).ignoresSafeArea() }
        .task(id: model.dashboard.isLoading) {
            guard !model.dashboard.isLoading else { return }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(response: 1.4, dampingFraction: 0.75)) { fill = 1 }
        }
    }

    // MARK: Values

    private func level(_ pad: Pad) -> Double {
        switch pad {
        case .rent: model.rentRate
        case .homes: model.occupancy
        case .repairs: model.resolvedRate
        case .tasks: model.taskRate
        case .streak: min(1, Double(model.dashboard.streak.count) / 6)
        }
    }

    private func accent(_ pad: Pad) -> DSAccent {
        switch pad {
        case .rent: .cherry
        case .homes: .gold
        case .repairs: .sky
        case .tasks: .mint
        case .streak: .blush
        }
    }

    private func value(_ pad: Pad) -> String {
        switch pad {
        case .rent: "\(Int((model.rentRate * 100).rounded()))%"
        case .homes: "\(Int((model.occupancy * 100).rounded()))%"
        case .repairs: "\(model.requests)"
        case .tasks: "\(model.openTasks.count)"
        case .streak: "\(model.dashboard.streak.count)"
        }
    }

    private func name(_ pad: Pad) -> String {
        switch pad {
        case .rent: "Rent in"
        case .homes: "Rented"
        case .repairs: "Repairs"
        case .tasks: "To do"
        case .streak: "Streak"
        }
    }

    private func symbol(_ pad: Pad) -> String {
        switch pad {
        case .rent: "dollarsign"
        case .homes: "key.fill"
        case .repairs: "wrench.fill"
        case .tasks: "checklist"
        case .streak: "flame.fill"
        }
    }

    // MARK: Paw

    private var paw: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                toe(.homes, w: 92, h: 112, tilt: -24).position(x: w * 0.13, y: h * 0.34)
                toe(.repairs, w: 100, h: 122, tilt: -8).position(x: w * 0.37, y: h * 0.16)
                toe(.tasks, w: 100, h: 122, tilt: 8).position(x: w * 0.63, y: h * 0.16)
                toe(.streak, w: 92, h: 112, tilt: 24).position(x: w * 0.87, y: h * 0.34)
                pad.frame(width: w * 0.72, height: h * 0.62).position(x: w * 0.5, y: h * 0.66)
            }
        }
    }

    private func glass(_ pad: Pad, _ shape: some Shape) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 1.5 + Double(pad.rawValue)
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(DS.Colors.surfaceRaised.opacity(0.4))
                LiquidWave(level: max(0.08, level(pad) * fill * 0.94), phase: phase)
                    .fill(LinearGradient(colors: [accent(pad).fill.mix(with: .white, by: 0.2), accent(pad).fill], startPoint: .top, endPoint: .bottom))
                    .clipShape(shape)
                shape.fill(LinearGradient(colors: [.white.opacity(0.5), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.stroke(LinearGradient(colors: [.white, .white.opacity(0.25)], startPoint: .top, endPoint: .bottom), lineWidth: 3)
            }
        }
        .shadow(color: accent(pad).fill.opacity(picked == pad ? 0.6 : 0.25), radius: picked == pad ? 24 : 12, y: 10)
    }

    private func toe(_ toe: Pad, w: CGFloat, h: CGFloat, tilt: Double) -> some View {
        Button { pick(toe) } label: {
            glass(toe, Ellipse())
                .rotationEffect(.degrees(tilt))
                .overlay {
                    VStack(spacing: 0) {
                        Image(systemName: symbol(toe)).font(.system(size: 15, weight: .bold))
                        Text(value(toe)).font(DS.Typography.brandFixed(26)).contentTransition(.numericText())
                        Text(name(toe)).font(DS.Typography.brandFixed(13))
                    }
                    .foregroundStyle(DS.Colors.textPrimary)
                }
                .frame(width: w, height: h)
        }
        .buttonStyle(SquishStyle(scale: 0.88))
        .scaleEffect(picked == toe ? 1.14 : 1)
        .zIndex(picked == toe ? 2 : 1)
        .animation(DS.Motion.bouncy, value: picked)
        .accessibilityLabel("\(name(toe)): \(value(toe))")
    }

    private var pad: some View {
        Button { pick(.rent) } label: {
            glass(.rent, PawPad())
                .overlay {
                    VStack(spacing: -4) {
                        Text(value(.rent)).font(DS.Typography.brandFixed(64))
                        Text("rent in").font(DS.Typography.brandFixed(20))
                        Text(model.dollars(model.roll.collected)).font(DS.Typography.brandFixed(17)).padding(.top, 8)
                    }
                    .foregroundStyle(level(.rent) > 0.55 ? DS.Colors.textOnBrand : DS.Colors.textPrimary)
                    .shadow(color: level(.rent) > 0.55 ? DS.Colors.brandDeep.opacity(0.7) : .clear, radius: 5)
                    .offset(y: 14)
                }
        }
        .buttonStyle(SquishStyle(scale: 0.95))
        .scaleEffect(picked == .rent ? 1.04 : 1)
        .animation(DS.Motion.bouncy, value: picked)
        .accessibilityLabel("Rent in: \(value(.rent))")
    }

    private func pick(_ pad: Pad) {
        feedback?.play(.select(pad.rawValue))
        withAnimation(DS.Motion.bouncy) { picked = pad }
    }

    // MARK: Panel

    private var panel: some View {
        HStack(spacing: 14) {
            PurrMascot(mood: mood, size: 112, isInteractive: false).padding(-6)
            VStack(alignment: .leading, spacing: 8) {
                Text(detail).font(DS.Typography.brand(.headline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary).fixedSize(horizontal: false, vertical: true).contentTransition(.opacity)
                SakugaButton(title: "Open", kind: .dark, impact: .light, symbol: "chevron.forward", action: go)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 32))
    }

    private var mood: PurrMood {
        switch picked {
        case .rent: .moneyDance
        case .homes: .keysReady
        case .repairs: .builder
        case .tasks: model.urgentTasks > 0 ? .urgentIssue : .tasksWaiting
        case .streak: .streak
        }
    }

    private var detail: String {
        switch picked {
        case .rent: model.rentLine
        case .homes: "\(model.dashboard.occupiedUnits) of \(model.dashboard.unitCount) rented. \(model.dashboard.vacantUnits) empty."
        case .repairs: "\(model.requests) open. I've sorted them by urgency."
        case .tasks: model.urgentTasks > 0 ? "\(model.urgentTasks) urgent today. Let's go!" : "\(model.openTasks.count) things lined up."
        case .streak: "\(model.dashboard.streak.count) months of rent on time."
        }
    }

    private func go() {
        switch picked {
        case .rent, .streak: router.push(.rentCollection)
        case .homes: router.select(.properties)
        case .repairs: router.select(.maintenance)
        case .tasks: router.push(.notifications)
        }
    }

    private var tasks: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today").font(DS.Typography.brand(.title3, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
            ForEach(model.dashboard.tasks) { task in
                Button { Task { await model.dashboard.toggleTask(task) } } label: {
                    HStack(spacing: 12) {
                        SakugaCheckMark(isOn: task.isDone)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(task.title).font(DS.Typography.brand(.body, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary).strikethrough(task.isDone)
                            Text(task.due).font(DS.Typography.brand(.footnote)).foregroundStyle(task.isUrgent ? DS.Colors.brandInk : DS.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 56)
                    .contentShape(.rect)
                }
                .buttonStyle(SquishStyle(scale: 0.98))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(DS.Colors.surfaceRaised.opacity(0.9)))
    }
}
#endif
