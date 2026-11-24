//
//  HomeScene.swift
//  RentalApp (Purrperty)
//
//  Dashboard — The top of Home: Purr in front of Toronto, under the sky as
//  it is right now (time of day, and the weather when it's known), saying
//  the one thing that matters. What he says is `DashboardMascotBrief`'s.
//

import SwiftUI

struct HomeScene: View {

    let brief: DashboardBrief
    let weather: Weather?
    let outfit: PurrOutfit
    let onOpenWardrobe: () -> Void

    @State private var tipIndex = 0
    @State private var reaction: PurrMood?
    @Environment(\.feedback) private var feedback
    @Environment(\.dynamicTypeSize) private var typeSize

    private var mood: PurrMood {
        if let reaction { return reaction }
        // Work comes first; an outfit is for quiet days.
        if brief.needsAttention { return brief.mood }
        if let costume = outfit.mood { return costume }
        switch weather?.sky {
        case .rain: return .rainyDay
        case .snow: return .freezing
        case .storm: return .rainyDay
        default: return brief.mood
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous)

        TiltScene {
            VStack(spacing: 0) {
                // The bubble hangs over the sky; Purr over the bubble's edge.
                MascotSpeechBubble(message: tipIndex == 0 ? brief.message : DashboardBrief.tips[(tipIndex - 1) % DashboardBrief.tips.count],
                                   tail: .bottom)
                    .padding(.horizontal, 16)
                    .padding(.top, 48)
                LivingPurr(mood: mood, size: typeSize.isAccessibilitySize ? 160 : 224, beat: tipIndex)
                    .padding(.top, -34)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
            .background {
                TorontoSky(weather: weather)
                    .clipShape(shape)
                    .shadow(color: DS.Colors.groundShadow, radius: 18, y: 10)
            }
            .overlay(alignment: .topLeading) { weatherChip }
            .overlay(alignment: .topTrailing) {
                Button(action: onOpenWardrobe) {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(SquishStyle(scale: 0.86))
                .padding(4)
                .accessibilityLabel("Purr's wardrobe")
            }
        }
        .contentShape(shape)
        .onTapGesture(perform: tickle)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Hear a tip") { tipIndex += 1 }
    }

    @ViewBuilder private var weatherChip: some View {
        if let weather {
            Link(destination: OpenMeteoWeather.attribution) {
                HStack(spacing: 5) {
                    Text("Toronto \(weather.summary)").font(DS.Typography.brand(.caption, weight: .semibold))
                    Text("Open-Meteo").font(DS.Typography.brand(.caption2, weight: .regular))
                }
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .glassEffect(.regular, in: .capsule)
            }
            .padding(11)
            .accessibilityLabel("Toronto weather, \(weather.summary), from Open-Meteo")
        }
    }

    private func tickle() {
        tipIndex += 1
        feedback?.play(.purr)
        guard reaction == nil, let move = PurrMood.signatureMoves.randomElement() else { return }
        reaction = move
        Task {
            try? await Task.sleep(for: .seconds(3))
            reaction = nil
        }
    }
}

// MARK: - Sky

/// The hour's sky over the Toronto skyline, with the weather falling.
struct TorontoSky: View {

    let weather: Weather?
    var date: Date = .now

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Hour { case dawn, day, dusk, night }

    private var hour: Hour {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Toronto") ?? .current
        switch calendar.component(.hour, from: date) {
        case 5..<8: return .dawn
        case 8..<17: return .day
        case 17..<20: return .dusk
        default: return .night
        }
    }

    private var isGrey: Bool { switch weather?.sky { case .rain, .storm, .fog, .cloudy, .snow: true; default: false } }

    private var colors: [Color] {
        switch hour {
        case .dawn: [Palette.dawnTop, Palette.dawnLow]
        case .day: isGrey ? [Palette.greyTop, Palette.greyLow] : [Palette.dayTop, Palette.dayLow]
        case .dusk: [Palette.duskTop, Palette.duskLow]
        case .night: [Palette.nightTop, Palette.nightLow]
        }
    }

    /// The sky's own colours. Like the mascot's, they don't follow the theme.
    private enum Palette {
        static let dawnTop = Color(hex: 0xFFD9A0), dawnLow = Color(hex: 0xFFF1DA)
        static let dayTop = Color(hex: 0x8FCBFF), dayLow = Color(hex: 0xE6F4FF)
        static let greyTop = Color(hex: 0xB7C3D0), greyLow = Color(hex: 0xE9EDF2)
        static let duskTop = Color(hex: 0xF07870), duskLow = Color(hex: 0xFFD27A)
        static let nightTop = Color(hex: 0x1D2350), nightLow = Color(hex: 0x4A4C8C)
        static let skylineDay = Color(hex: 0x2B1712, opacity: 0.16), skylineNight = Color(hex: 0x0E1130, opacity: 0.6)
        static let window = Color(hex: 0xFFE27A)
        static let ground = Color(hex: 0x7CC88F), groundNight = Color(hex: 0x2F5A55), groundSnow = Color(hex: 0xF4F8FF)
        static let sun = Color(hex: 0xFFC94D), moon = Color(hex: 0xFFF3D6)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                if hour == .night { stars(size) }
                Circle()
                    .fill(hour == .night ? Palette.moon : Palette.sun)
                    .frame(width: 58, height: 58)
                    .shadow(color: (hour == .night ? Palette.moon : Palette.sun).opacity(0.8), radius: 22)
                    .opacity(isGrey ? 0.35 : 1)
                    .floating(depth: -0.6, phase: 1, bob: 0.4)
                    .position(x: size.width * (hour == .dawn ? 0.14 : 0.86), y: hour == .day || hour == .night ? 96 : size.height * 0.55)
                clouds(size)
                Skyline()
                    .fill(hour == .night ? Palette.skylineNight : Palette.skylineDay)
                    .frame(height: 130)
                    .overlay { if hour == .night || hour == .dusk { Skyline.Windows().fill(Palette.window.opacity(0.85)) } }
                    .floating(depth: -0.25, bob: 0)
                    .position(x: size.width / 2, y: size.height - 106)
                Ellipse()
                    .fill(weather?.sky == .snow ? Palette.groundSnow : hour == .night ? Palette.groundNight : Palette.ground)
                    .frame(width: size.width * 1.5, height: 110)
                    .position(x: size.width / 2, y: size.height - 2)
                falling
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func stars(_ size: CGSize) -> some View {
        ForEach(0..<16, id: \.self) { i in
            Circle().fill(.white.opacity(0.4 + Double(i % 4) * 0.15))
                .frame(width: CGFloat(2 + i % 3))
                .position(x: size.width * CGFloat((i * 37) % 100) / 100, y: size.height * 0.55 * CGFloat((i * 53) % 100) / 100)
        }
    }

    private func clouds(_ size: CGSize) -> some View {
        let count = weather?.sky == .clear ? 1 : isGrey ? 4 : 2
        return ForEach(0..<count, id: \.self) { i in
            Image(systemName: "cloud.fill")
                .font(.system(size: [64, 46, 78, 52][i]))
                .foregroundStyle(.white.opacity(hour == .night ? 0.25 : 0.8))
                .floating(depth: -0.4 - Double(i) * 0.1, phase: Double(i) * 2)
                .position(x: size.width * [0.2, 0.62, 0.9, 0.4][i], y: [86, 56, 150, 190][i])
        }
    }

    // MARK: Falling

    @ViewBuilder private var falling: some View {
        let sky = weather?.sky
        if sky == .rain || sky == .storm || sky == .snow {
            let isSnow = sky == .snow
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Canvas { canvas, size in
                    for i in 0..<(isSnow ? 46 : 60) {
                        let seed = Double((i * 7919) % 1000) / 1000
                        let speed = isSnow ? 26 + seed * 26 : 320 + seed * 160
                        let y = (t * speed + seed * 4000).truncatingRemainder(dividingBy: size.height + 30) - 15
                        let x = Double((i * 104_729) % 1000) / 1000 * size.width + (isSnow ? sin(t + seed * 9) * 12 : -y * 0.12)
                        if isSnow {
                            let r = 1.6 + seed * 2.4
                            canvas.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.9)))
                        } else {
                            var drop = Path()
                            drop.move(to: CGPoint(x: x, y: y))
                            drop.addLine(to: CGPoint(x: x - 2, y: y + 13))
                            canvas.stroke(drop, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Skyline

/// Toronto, in cut paper: the CN Tower, the dome and some towers.
struct Skyline: Shape {

    /// x, width and height of each tower, as fractions.
    private static let towers: [(CGFloat, CGFloat, CGFloat)] = [
        (0.00, 0.07, 0.34), (0.08, 0.06, 0.50), (0.15, 0.05, 0.40), (0.44, 0.06, 0.46), (0.51, 0.07, 0.66),
        (0.59, 0.05, 0.54), (0.65, 0.07, 0.74), (0.73, 0.05, 0.48), (0.79, 0.08, 0.60), (0.88, 0.05, 0.42), (0.94, 0.07, 0.32),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (x, w, h) in Self.towers {
            path.addRoundedRect(in: CGRect(x: rect.width * x, y: rect.height * (1 - h), width: rect.width * w, height: rect.height * h + 20), cornerSize: CGSize(width: 4, height: 4))
        }
        // The tower.
        let cx = rect.width * 0.33
        path.move(to: CGPoint(x: cx - 8, y: rect.height + 20))
        path.addLine(to: CGPoint(x: cx - 3, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: cx + 3, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: cx + 8, y: rect.height + 20))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: cx - 14, y: rect.height * 0.23, width: 28, height: 13))
        path.addRoundedRect(in: CGRect(x: cx - 1.5, y: -rect.height * 0.06, width: 3, height: rect.height * 0.32), cornerSize: CGSize(width: 1.5, height: 1.5))
        // The dome.
        path.addEllipse(in: CGRect(x: rect.width * 0.2, y: rect.height * 0.74, width: rect.width * 0.12, height: rect.height * 0.5))
        return path
    }

    /// Lit windows, at night.
    struct Windows: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            for (i, tower) in Skyline.towers.enumerated() {
                for row in 0..<5 where (i + row * 3) % 4 != 0 {
                    let y = rect.height * (1 - tower.2) + 8 + CGFloat(row) * 12
                    guard y < rect.height * 0.8 else { continue }
                    path.addRect(CGRect(x: rect.width * tower.0 + 5 + CGFloat((i + row) % 2) * 8, y: y, width: 4, height: 5))
                }
            }
            return path
        }
    }
}
