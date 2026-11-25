//
//  PlaceHome.swift — A: Purr's place. Home is a room, and everything in it
//  is a number: the jar is rent, the picture is occupancy, the toolbox is
//  repairs. Touch one to see it.
//

#if DEBUG
import SwiftUI

struct PlaceHome: View {
    let model: HomeStudioModel

    enum Thing: String, CaseIterable, Identifiable { case jar, picture, toolbox, calendar, phone; var id: String { rawValue } }

    @State private var open: Thing?
    @State private var bounce: Thing?
    @Environment(AppRouter.self) private var router
    @Environment(\.feedback) private var feedback

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            TiltScene {
                ZStack {
                    room(w, h)

                    // Wall
                    window.frame(width: w * 0.46, height: h * 0.25)
                        .position(x: w * 0.28, y: h * 0.255).floating(depth: -0.3, bob: 0)
                    thing(.picture) { picture }.frame(width: w * 0.34, height: h * 0.15)
                        .position(x: w * 0.76, y: h * 0.205).floating(depth: -0.3, bob: 0)
                    thing(.calendar) { calendar }.frame(width: 86, height: 96)
                        .position(x: w * 0.67, y: h * 0.385).floating(depth: -0.3, bob: 0)
                    shelf.frame(width: w * 0.30, height: 12).position(x: w * 0.9, y: h * 0.445)
                    thing(.phone) { phone }.frame(width: 62, height: 62)
                        .position(x: w * 0.9, y: h * 0.402)

                    // Floor
                    Ellipse().fill(DS.Colors.accentBlush.opacity(0.55))
                        .overlay(Ellipse().inset(by: 14).stroke(DS.Colors.accentGold, lineWidth: 5))
                        .frame(width: w * 1.06, height: h * 0.17)
                        .position(x: w * 0.5, y: h * 0.865)
                    thing(.jar) { jar }.frame(width: 104, height: 134)
                        .position(x: w * 0.145, y: h * 0.81).floating(depth: 0.5, bob: 0)
                    thing(.toolbox) { toolbox }.frame(width: 116, height: 94)
                        .position(x: w * 0.84, y: h * 0.83).floating(depth: 0.5, bob: 0)

                    LivingPurr(mood: mood, size: min(w * 0.86, h * 0.43), beat: open)
                        .position(x: w * 0.53, y: h * 0.71)
                        .allowsHitTesting(false)

                    bubble.frame(width: w * 0.52).position(x: w * 0.31, y: h * 0.465)
                        .opacity(open == nil ? 1 : 0)
                }
            }
            .overlay(alignment: .top) { HomeBar(model: model).padding(.horizontal, 16).padding(.top, 4) }
            .overlay(alignment: .bottom) { tray.padding(.bottom, 10) }
        }
        .background(DS.Colors.accentGold.opacity(0.16).ignoresSafeArea())
        .animation(DS.Motion.bouncy, value: open)
    }

    private var mood: PurrMood {
        switch open {
        case nil: model.brief.mood == .urgentIssue ? .tasksWaiting : model.brief.mood
        case .jar: .moneyDance
        case .picture: .properties
        case .toolbox: .builder
        case .calendar: .tasksWaiting
        case .phone: .conversation
        }
    }

    // MARK: Room

    private func room(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // Striped wallpaper.
            LinearGradient(colors: [DS.Colors.accentGold.mix(with: DS.Colors.background, by: 0.55), DS.Colors.accentGold.mix(with: DS.Colors.background, by: 0.72)], startPoint: .top, endPoint: .bottom)
            HStack(spacing: 26) {
                ForEach(0..<12, id: \.self) { _ in Rectangle().fill(DS.Colors.background.opacity(0.28)).frame(width: 26) }
            }
            VStack(spacing: 0) {
                Spacer().frame(height: h * 0.78)
                Rectangle().fill(DS.Colors.background).frame(height: 16).shadow(color: DS.Colors.groundShadow, radius: 4, y: 3)
                // Boards.
                ZStack {
                    LinearGradient(colors: [Color(hex: 0xD99A5B), Color(hex: 0xB87440)], startPoint: .top, endPoint: .bottom)
                    Path { p in
                        for i in -6...18 {
                            p.move(to: CGPoint(x: w * 0.5 + CGFloat(i - 6) * 30, y: 0))
                            p.addLine(to: CGPoint(x: w * 0.5 + CGFloat(i - 6) * 74, y: h * 0.5))
                        }
                    }.stroke(Color(hex: 0x8A4F27).opacity(0.35), lineWidth: 2)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var window: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return TorontoSky(weather: model.dashboard.weather)
            .clipShape(shape)
            .overlay { Rectangle().fill(DS.Colors.background).frame(width: 7) }
            .overlay { Rectangle().fill(DS.Colors.background).frame(height: 7) }
            .overlay(shape.strokeBorder(DS.Colors.background, lineWidth: 11))
            .overlay(alignment: .bottom) {
                Capsule().fill(.clay(DS.Colors.background, shade: DSAccent.gold.ink, size: 20)).frame(height: 18).padding(.horizontal, -12).offset(y: 10)
            }
            .overlay(alignment: .topLeading) {
                if let weather = model.dashboard.weather {
                    Text(weather.summary)
                        .font(DS.Typography.brand(.caption, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(DS.Colors.surfaceRaised))
                        .padding(18)
                }
            }
            .shadow(color: DS.Colors.groundShadow, radius: 10, y: 8)
    }

    private var shelf: some View {
        Capsule().fill(.clay(Color(hex: 0xB87440), shade: Color(hex: 0x6B3A1B), size: 14))
            .shadow(color: DS.Colors.groundShadow, radius: 5, y: 5)
    }

    // MARK: Things

    private func thing(_ thing: Thing, @ViewBuilder _ art: () -> some View) -> some View {
        Button {
            feedback?.play(.select(Thing.allCases.firstIndex(of: thing) ?? 0))
            open = open == thing ? nil : thing
        } label: {
            art().contentShape(.rect)
        }
        .buttonStyle(SquishStyle(scale: 0.9))
        .scaleEffect(open == thing ? 1.1 : 1)
        .shadow(color: open == thing ? DS.Colors.accentGold : DS.Colors.groundShadow, radius: open == thing ? 18 : 8, y: 7)
        .accessibilityLabel(label(thing))
    }

    /// Homes as windows, lit when someone lives there.
    private var picture: some View {
        let lit = Int((model.occupancy * 12).rounded())
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(colors: [DSAccent.sky.fill, DSAccent.sky.tint], startPoint: .top, endPoint: .bottom))
            .overlay {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4).fill(i < lit ? DS.Colors.accentGold : DS.Colors.textPrimary.opacity(0.25)).frame(height: 17)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(DS.Colors.brand))
                .padding(14)
            }
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hex: 0xB87440), lineWidth: 9))
            .overlay(alignment: .bottom) { tag("\(Int((model.occupancy * 100).rounded()))% full") }
    }

    private var calendar: some View {
        VStack(spacing: 0) {
            Text(Date.now, format: .dateTime.month(.abbreviated)).font(DS.Typography.brandFixed(14)).foregroundStyle(DS.Colors.textOnBrand)
                .frame(maxWidth: .infinity).frame(height: 26).background(DS.Colors.brand)
            Text(Date.now, format: .dateTime.day()).font(DS.Typography.brandFixed(36)).foregroundStyle(DS.Colors.textPrimary).frame(maxHeight: .infinity)
        }
        .background(DS.Colors.surfaceRaised)
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) { badge(model.openTasks.count) }
    }

    private var phone: some View {
        ClayToken(symbol: "phone.fill", accent: .mint, size: 62)
            .overlay(alignment: .topTrailing) { badge(model.dashboard.unreadNotifications) }
    }

    private var jar: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
            ZStack {
                shape.fill(.white.opacity(0.35))
                LiquidWave(level: max(0.06, model.rentRate * 0.92), phase: context.date.timeIntervalSinceReferenceDate * 1.6)
                    .fill(LinearGradient(colors: [DS.Colors.accentGold, Color(hex: 0xD98A1E)], startPoint: .top, endPoint: .bottom))
                    .clipShape(shape)
                Text("\(Int((model.rentRate * 100).rounded()))%").font(DS.Typography.brandFixed(30)).foregroundStyle(DS.Colors.textOnAccent)
                shape.strokeBorder(.white.opacity(0.9), lineWidth: 4)
                Capsule().fill(.white.opacity(0.7)).frame(width: 9, height: 52).offset(x: -34, y: -6)
            }
            .overlay(alignment: .top) { Capsule().fill(.clay(DS.Colors.brand, shade: DS.Colors.brandDeep, size: 24)).frame(width: 82, height: 22).offset(y: -12) }
            .overlay(alignment: .bottom) { tag("Rent") }
        }
    }

    private var toolbox: some View {
        VStack(spacing: -4) {
            Capsule().stroke(DS.Colors.textPrimary, lineWidth: 8).frame(width: 46, height: 30)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clay(DS.Colors.brand, shade: DS.Colors.brandDeep, size: 70))
                .overlay { Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(DS.Colors.textOnBrand) }
                .overlay(alignment: .top) { Rectangle().fill(DS.Colors.accentGold).frame(height: 8).offset(y: 14).opacity(0.9) }
        }
        .overlay(alignment: .topTrailing) { badge(model.requests) }
    }

    private func tag(_ text: String) -> some View {
        Text(text).font(DS.Typography.brand(.caption, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary)
            .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(DS.Colors.surfaceRaised)).offset(y: 10).fixedSize()
    }

    @ViewBuilder private func badge(_ count: Int) -> some View {
        if count > 0 {
            Text(count, format: .number).font(DS.Typography.brandFixed(15)).foregroundStyle(DS.Colors.textOnBrand)
                .frame(minWidth: 28, minHeight: 28).background(Circle().fill(DS.Colors.brand)).overlay(Circle().strokeBorder(DS.Colors.surfaceRaised, lineWidth: 2.5)).offset(x: 10, y: -8)
        }
    }

    private var bubble: some View {
        Text(model.brief.message)
            .font(DS.Typography.brand(.subheadline, weight: .semibold))
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DS.Colors.surfaceRaised).shadow(color: DS.Colors.groundShadow, radius: 8, y: 5))
    }

    // MARK: Tray

    private func label(_ thing: Thing) -> String {
        switch thing {
        case .jar: "Rent: \(model.dollars(model.roll.collected)) of \(model.dollars(model.roll.expected))"
        case .picture: "\(model.dashboard.occupiedUnits) of \(model.dashboard.unitCount) units rented"
        case .toolbox: "\(model.requests) repairs open"
        case .calendar: "\(model.openTasks.count) tasks today"
        case .phone: "\(model.dashboard.unreadNotifications) unread"
        }
    }

    @ViewBuilder private var tray: some View {
        if let open {
            VStack(alignment: .leading, spacing: 10) {
                Text(label(open)).font(DS.Typography.brand(.title3, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                if open == .calendar {
                    ForEach(model.openTasks.prefix(3)) { task in
                        Label(task.title, systemImage: task.icon).font(DS.Typography.brand(.subheadline)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                    }
                } else {
                    Text(detail(open)).font(DS.Typography.brand(.subheadline)).foregroundStyle(DS.Colors.textSecondary)
                }
                SakugaButton(title: "Open", kind: .primary, impact: .light, symbol: "chevron.forward", isFullWidth: true) { go(open) }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 30))
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func detail(_ thing: Thing) -> String {
        switch thing {
        case .jar: model.rentLine
        case .picture: "\(model.dashboard.vacantUnits) empty, \(model.dashboard.turnoverUnits) turning over."
        case .toolbox: "Sorted by urgency in Repairs."
        case .phone: "Messages and alerts."
        case .calendar: ""
        }
    }

    private func go(_ thing: Thing) {
        switch thing {
        case .jar: router.push(.rentCollection)
        case .picture: router.select(.properties)
        case .toolbox: router.select(.maintenance)
        case .calendar, .phone: router.push(.notifications)
        }
    }
}
#endif
