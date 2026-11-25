//
//  LiveFlyover.swift
//  RentalApp (Purrperty)
//
//  Onboarding — The fly-over itself: Toronto in Apple's 3D imagery, with
//  cards standing on their buildings, captions, and Purr at the end.
//

import SwiftUI

struct LiveFlyover: View {

    @State private var director: FlyoverDirector
    let onLanded: () -> Void
    /// No map (offline, or no 3D here): the drawn video plays instead.
    let onUnavailable: () -> Void

    @Environment(\.feedback) private var feedback

    /// The score is 8.7 s; it comes in to end with the flight.
    private static let scoreDelay = 3.1

    init(style: FlyoverStyle, onLanded: @escaping () -> Void, onUnavailable: @escaping () -> Void) {
        _director = State(initialValue: FlyoverDirector(style: style))
        self.onLanded = onLanded
        self.onUnavailable = onUnavailable
    }

    private var time: Double { director.time }
    private var isFinale: Bool { time > FlyoverStyle.finale }

    var body: some View {
        ZStack {
            Color.black
                .overlay { picture }
                .clipped()
                .ignoresSafeArea()

            // Keeps the caption and Skip readable over a bright city.
            VStack {
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom).frame(height: 240)
                Spacer()
            }
            .ignoresSafeArea()
            .opacity(director.phase == .loading ? 0 : 1)

            cards.ignoresSafeArea()

            caption

            finale

            if director.phase == .loading { cover.transition(.opacity) }
        }
        .background(Color.black.ignoresSafeArea())
        .animation(.easeOut(duration: 0.5), value: director.phase == .loading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A flight over Toronto in 3D. Cards on the buildings show rent recorded, a repair booked and a lease renewing, then Purr cheers.")
        .task { await director.prepare() }
        .onDisappear {
            director.stop()
            feedback?.stopMusic()
        }
        .onChange(of: director.phase) { _, phase in
            switch phase {
            case .landed: onLanded()
            case .failed: onUnavailable()
            case .loading, .flying: break
            }
        }
        .onChange(of: time > Self.scoreDelay) { _, starts in
            if starts { feedback?.startMusic("flyover") }
        }
        .onChange(of: director.style.stops.count { time > $0.from }) { old, new in
            if new > old { feedback?.play(.deal(new - 1)) }
        }
        .onChange(of: isFinale) { _, now in
            if now { feedback?.play(.celebrate) }
        }
    }

    @ViewBuilder private var picture: some View {
        #if DEBUG
        if let frames = director.frames {
            if let image = frames.image(at: time) {
                Image(uiImage: image).resizable().scaledToFill()
            }
        } else {
            FlyoverMap(director: director)
        }
        #else
        FlyoverMap(director: director)
        #endif
    }

    // MARK: Loading

    private var cover: some View {
        ZStack {
            DS.Colors.launchBackground
            VStack(spacing: 14) {
                PurrMascot(mood: .searching, size: 190, isInteractive: false)
                Text("Finding Toronto…")
                    .font(DS.Typography.brand(.title2, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                ProgressView().tint(DS.Colors.brand)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Cards

    private var cards: some View {
        GeometryReader { proxy in
            ForEach(placements(in: proxy.size)) { spot in
                FlyoverPin(stop: spot.stop, age: time - spot.stop.from, stem: spot.stem, shift: spot.shift)
                    .position(spot.point)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(DS.Motion.bouncy, value: placements(in: CGSize(width: 402, height: 874)).map(\.id))
        .animation(.easeOut(duration: 0.25), value: isFinale)
    }

    private struct Spot: Identifiable {
        let stop: FlyoverStop
        let point: CGPoint
        let stem, shift: CGFloat
        var id: Int { stop.id }
    }

    /// Below the caption.
    private static let ceiling: CGFloat = 262
    private static let preferredStems: [CGFloat] = [116, 190, 60, 250]

    /// Each card rises from its place until it's clear of the others; one
    /// with no room, or whose place has left the screen, waits.
    private func placements(in size: CGSize) -> [Spot] {
        guard !isFinale else { return [] }
        var taken: [CGRect] = []
        var spots: [Spot] = []
        for stop in director.style.stops where time > stop.from && time < stop.to {
            guard let point = director.points[stop.id],
                  point.x > 14, point.x < size.width - 14, point.y < size.height - 60 else { continue }
            let card = stop.title.isEmpty ? CGSize(width: 46, height: 46) : FlyoverPin.card
            let half = card.width / 2 + 12
            let x = min(max(point.x, half), size.width - half)
            var y = stop.title.isEmpty ? point.y - 40 : max(point.y - Self.preferredStems[stop.id % 4], Self.ceiling)
            func frame() -> CGRect { CGRect(x: x - card.width / 2, y: y - card.height / 2, width: card.width, height: card.height) }
            while let hit = taken.first(where: { $0.insetBy(dx: -6, dy: -6).intersects(frame()) }) {
                y = hit.minY - card.height / 2 - 8
            }
            guard y >= Self.ceiling - 1, point.y - y > card.height / 2 else { continue }
            taken.append(frame())
            spots.append(Spot(stop: stop, point: point, stem: point.y - y, shift: x - point.x))
        }
        return spots
    }

    // MARK: Words

    private var caption: some View {
        FlyoverCaptions(captions: director.style.captions, time: time)
    }

    // MARK: Finale

    private var finale: some View {
        VStack(spacing: 0) {
            Spacer()
            if isFinale {
                VStack(spacing: 0) {
                    PurrMascot(mood: .partyTime, size: 250, isInteractive: false)
                        .padding(.bottom, -34)
                        .zIndex(1)
                    VStack(spacing: 4) {
                        PurrpertyWordmark(fontSize: 46)
                        Text("Every rental, under one paw.")
                            .font(DS.Typography.brand(.headline))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .padding(.top, 34)
                    .padding(.bottom, 26)
                    .frame(maxWidth: .infinity)
                    .background {
                        UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38, style: .continuous)
                            .fill(DS.Colors.background)
                            .shadow(color: .black.opacity(0.35), radius: 24, y: -8)
                            .ignoresSafeArea()
                    }
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(DS.Motion.bouncy, value: isFinale)
    }
}

// MARK: - Captions

/// The words over a flight or the film, on a solid card clear of Skip.
struct FlyoverCaptions: View {
    let captions: [FlyoverCaption]
    let time: Double

    var body: some View {
        VStack {
            ZStack {
                ForEach(captions) { caption in
                    if time > caption.from, time < caption.to {
                        Text(caption.text)
                            .font(DS.Typography.brand(27, weight: .bold))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .fill(.clay(DS.Colors.surfaceRaised, shade: DSAccent.gold.ink, size: 60))
                                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity),
                                removal: .opacity.combined(with: .offset(y: -14))
                            ))
                    }
                }
            }
            .padding(.horizontal, 24)
            // Clear of Skip.
            .padding(.top, 66)
            Spacer()
        }
        .animation(DS.Motion.bouncy, value: captions.map { time > $0.from && time < $0.to })
        .allowsHitTesting(false)
    }
}

// MARK: - Pin

/// A card on a stem over a building, or just a pin when it has no words.
private struct FlyoverPin: View {
    let stop: FlyoverStop
    let age: Double
    /// How far up the card is, and how far aside to stay on screen.
    let stem, shift: CGFloat

    static let card = CGSize(width: 214, height: 64)
    private var accent: DSAccent {
        switch stop.accent {
        case "mint": .mint
        case "blush": .blush
        case "sky": .sky
        case "gold": .gold
        default: .cherry
        }
    }
    private var hasCard: Bool { !stop.title.isEmpty }

    var body: some View {
        ZStack {
            // Ripples where it stands.
            ForEach(0..<2, id: \.self) { ring in
                let t = (age * 0.8 + Double(ring) * 0.5).truncatingRemainder(dividingBy: 1)
                Ellipse().stroke(accent.fill.opacity(1 - t), lineWidth: 3)
                    .frame(width: 20 + 50 * t, height: 10 + 25 * t)
            }
            Capsule().fill(.white).frame(width: 3, height: stem)
                .offset(y: -stem / 2)
            Circle().fill(accent.fill).overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .frame(width: 16, height: 16)
            Group {
                if hasCard { label.offset(x: shift) } else {
                    ClayToken(symbol: stop.symbol, accent: accent, size: 46)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
                }
            }
            .offset(y: -stem)
        }
        .frame(width: 1, height: 1)
    }

    private var label: some View {
        HStack(spacing: 10) {
            ClayToken(symbol: stop.symbol, accent: accent, size: 42)
            VStack(alignment: .leading, spacing: 0) {
                Text(stop.title)
                    .font(DS.Typography.brandFixed(17))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(stop.detail)
                    .font(DS.Typography.brandFixed(13))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(width: Self.card.width, height: Self.card.height)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DS.Colors.surfaceRaised)
                .shadow(color: .black.opacity(0.4), radius: 14, y: 10)
        }
    }
}
