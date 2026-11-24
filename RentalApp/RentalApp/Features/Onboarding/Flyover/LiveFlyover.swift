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
            picture.ignoresSafeArea()

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
            ForEach(director.style.stops) { stop in
                if let point = director.points[stop.id], time > stop.from, time < stop.to, !isFinale {
                    FlyoverPin(stop: stop, age: time - stop.from, side: side(stop.id), edge: proxy.size.width, x: point.x)
                        .position(x: point.x, y: max(point.y, 330))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
        }
        .animation(DS.Motion.bouncy, value: director.style.stops.map { time > $0.from && time < $0.to })
        .animation(.easeOut(duration: 0.25), value: isFinale)
    }

    /// Stems of different heights, so neighbours don't overlap.
    private func side(_ id: Int) -> CGFloat { [70, 128, 12, 186][id % 4] }

    // MARK: Words

    private var caption: some View {
        VStack {
            ZStack {
                ForEach(director.style.captions) { caption in
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
        .animation(DS.Motion.bouncy, value: director.style.captions.map { time > $0.from && time < $0.to })
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

// MARK: - Pin

/// A card on a stem over a building, or just a pin when it has no words.
private struct FlyoverPin: View {
    let stop: FlyoverStop
    let age: Double
    let side: CGFloat
    /// The screen's width and the pin's place on it, to keep the card on.
    let edge: CGFloat
    let x: CGFloat

    private static let cardWidth: CGFloat = 214
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
    private var stem: CGFloat { hasCard ? 46 + side : 26 }
    private var shift: CGFloat {
        let half = Self.cardWidth / 2 + 12
        return min(max(x, half), max(edge - half, half)) - x
    }

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
                if hasCard { card.offset(x: shift) } else {
                    ClayToken(symbol: stop.symbol, accent: accent, size: 46)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
                }
            }
            .offset(y: -stem - 22)
        }
        .frame(width: 1, height: 1)
    }

    private var card: some View {
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
        .padding(10)
        .frame(width: Self.cardWidth)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DS.Colors.surfaceRaised)
                .shadow(color: .black.opacity(0.4), radius: 14, y: 10)
        }
    }
}
