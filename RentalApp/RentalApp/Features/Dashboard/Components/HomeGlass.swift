//
//  HomeGlass.swift
//  RentalApp (Purrperty)
//
//  Dashboard — What the map homes share: the map with a pin on every
//  property, and the glass cards that sit over it.
//

import MapKit
import SwiftUI

// MARK: - Map

struct HomeMap: View {
    let model: HomeModel
    @Binding var selection: String?
    /// Room taken by what sits over the map, so the city fits between.
    var insets = EdgeInsets()
    /// A tap that reached the map through something laid over it: the
    /// nearest pin to it, if any, is picked.
    var tapThrough: CGPoint? = nil
    /// The whole screen's height, safe areas included.
    var screenHeight: CGFloat = 874

    @State private var camera: MapCameraPosition = .camera(MapCamera(centerCoordinate: .init(latitude: 43.67, longitude: -79.39), distance: 30_000, heading: 0, pitch: 40))
    @State private var hasFit = false
    /// Zoomed out over the city: small pins, so neighbours don't pile up.
    @State private var isFar = true
    /// What the map shows, and where it is on screen: enough to find a
    /// pin under a finger. (MapReader's converter has nothing for 3D
    /// imagery.)
    @State private var shown: MKMapRect?
    @State private var frame: CGRect = .zero
    @Environment(\.feedback) private var feedback

    static let accents: [DSAccent] = [.cherry, .gold, .mint, .sky, .blush]

    private struct Pin: Identifiable {
        let property: Property
        let place: CLLocationCoordinate2D
        let accent: DSAccent
        var id: String { property.id }
    }

    var body: some View {
        // Read here: changes inside the map's content aren't observed.
        let pins = model.properties.enumerated().compactMap { i, property in
            model.places[property.id].map { Pin(property: property, place: $0, accent: Self.accents[i % Self.accents.count]) }
        }
        Map(position: $camera, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
            ForEach(pins) { pin in
                Annotation(pin.property.name, coordinate: pin.place, anchor: .bottom) {
                    HomePin(property: pin.property, accent: pin.accent, isSelected: selection == pin.id, isSmall: isFar && selection != pin.id) {
                        feedback?.play(.select(0))
                        withAnimation(DS.Motion.smooth) { selection = selection == pin.id ? nil : pin.id }
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls { }
        .onMapCameraChange(frequency: .onEnd) { context in
            let far = context.camera.distance > 9000
            if far != isFar { withAnimation(DS.Motion.bouncy) { isFar = far } }
            shown = context.rect
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .onChange(of: tapThrough) { _, point in
            guard let point else { return }
            let nearest = pins.compactMap { pin in
                // The pin stands on its place; its middle is a little above.
                screenPoint(pin.place).map { (pin.id, hypot($0.x - point.x, $0.y - (isFar ? 20 : 32) - point.y)) }
            }
            .min { $0.1 < $1.1 }
            if let nearest, nearest.1 < 44 {
                feedback?.play(.select(0))
                withAnimation(DS.Motion.smooth) { selection = nearest.0 }
            } else if selection != nil {
                withAnimation(DS.Motion.smooth) { selection = nil }
            }
        }
        .task(id: pins.count) {
            guard pins.count > 0, !hasFit else { return }
            hasFit = true
            fitAll(animated: false)
        }
        .onChange(of: selection) { _, id in
            if let id, let place = model.places[id] {
                withAnimation(.easeInOut(duration: 1.3)) {
                    // Aim a little south, so the home sits above the cards.
                    // From the screen's middle to the clear part's, at this
                    // height and tilt about 0.0000147° a point (measured).
                    let clearMiddle = (insets.top + screenHeight - insets.bottom) / 2
                    let shift = Double(screenHeight / 2 - clearMiddle) * 0.0000147
                    camera = .camera(MapCamera(centerCoordinate: .init(latitude: place.latitude - shift, longitude: place.longitude), distance: 1100, heading: 0, pitch: 60))
                }
            } else {
                fitAll(animated: true)
            }
        }
    }

    /// Where a place is on screen, looking straight down; the overview is.
    private func screenPoint(_ place: CLLocationCoordinate2D) -> CGPoint? {
        guard let shown, shown.width > 0, frame.width > 0 else { return nil }
        let p = MKMapPoint(place)
        // The map fills its frame, cropping the longer side of the rect.
        let scale = max(frame.width / shown.width, frame.height / shown.height)
        return CGPoint(x: frame.midX + (p.x - shown.midX) * scale, y: frame.midY + (p.y - shown.midY) * scale)
    }

    /// Every property in view, with room for the cards over the map.
    private func fitAll(animated: Bool) {
        let places = Array(model.places.values)
        guard !places.isEmpty else { return }
        let lats = places.map(\.latitude), lons = places.map(\.longitude)
        let latSpan = max(0.02, lats.max()! - lats.min()!), lonSpan = max(0.02, lons.max()! - lons.min()!)
        // The homes go in the part of the screen the cards leave clear:
        // the region is as many times taller as the screen is than that gap.
        let screen = Double(screenHeight)
        let clear = max(0.18, 1 - Double(insets.top + insets.bottom) / screen)
        let height = latSpan * 1.35 / clear
        let middle = (lats.min()! + lats.max()!) / 2
        // From the screen's middle down to the gap's middle, in degrees.
        let shift = height * Double(insets.bottom - insets.top) / screen / 2
        let region = MKCoordinateRegion(
            center: .init(latitude: middle - shift, longitude: (lons.min()! + lons.max()!) / 2),
            span: .init(latitudeDelta: height, longitudeDelta: lonSpan * 1.3)
        )
        withAnimation(animated ? .easeInOut(duration: 1.2) : nil) { camera = .region(region) }
    }
}

/// A home on a ring that shows how full it is, with its open repairs.
struct HomePin: View {
    let property: Property
    let accent: DSAccent
    let isSelected: Bool
    var isSmall = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: -4) {
                ZStack {
                    Circle().fill(DS.Colors.surfaceRaised)
                    Circle().trim(from: 0, to: property.occupancyRate)
                        .stroke(accent.fill, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90)).padding(3.5)
                    ClayToken(symbol: property.kind.icon, accent: accent, size: 32)
                }
                .frame(width: 50, height: 50)
                .overlay(alignment: .topTrailing) {
                    if property.urgentRequests > 0 {
                        Text(property.urgentRequests, format: .number).font(DS.Typography.brandFixed(12)).foregroundStyle(DS.Colors.textOnBrand)
                            .frame(minWidth: 20, minHeight: 20).background(Circle().fill(DS.Colors.brand)).overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .offset(x: 4, y: -4)
                    }
                }
                Image(systemName: "triangle.fill").font(.system(size: 12)).rotationEffect(.degrees(180)).foregroundStyle(DS.Colors.surfaceRaised)
            }
            .shadow(color: .black.opacity(0.4), radius: 7, y: 5)
            .scaleEffect(isSelected ? 1.3 : isSmall ? 0.6 : 1, anchor: .bottom)
            .frame(width: isSmall ? 34 : 54, height: isSmall ? 40 : 64, alignment: .bottom)
            .animation(DS.Motion.bouncy, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(property.name), \(property.occupiedCount) of \(property.unitCount) rented")
    }
}

// MARK: - Glass

extension View {
    /// A card of the app's glass: frosted, a warm tint, a bright rim.
    func homeGlass(radius: CGFloat = 28, tint: Double = 0.45) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            shape.fill(DS.Colors.surfaceRaised.opacity(tint))
        }
        .glassEffect(.regular, in: shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

/// The paw with Purr explaining the toe you picked.
struct PawPanel: View {
    let model: HomeModel
    @Binding var picked: PawToe
    var pawSize: CGFloat = 250
    var compact = false
    @Environment(AppRouter.self) private var router

    var body: some View {
        let layout = compact ? AnyLayout(HStackLayout(spacing: 6)) : AnyLayout(VStackLayout(spacing: 4))
        layout {
            PawGauge(model: model, picked: $picked, size: pawSize)
            HStack(alignment: .center, spacing: 10) {
                PurrMascot(mood: model.mood(picked), size: compact ? 74 : 96, isInteractive: false).padding(-6)
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.detail(picked))
                        .font(DS.Typography.brand(compact ? .subheadline : .headline, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                    Button("Open \(picked.name.lowercased())", systemImage: "chevron.forward") { go() }
                        .labelStyle(.titleOnly)
                        .font(DS.Typography.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(DS.Colors.brandInk)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(compact ? 12 : 16)
        .homeGlass()
    }

    private func go() {
        switch picked {
        case .rent, .streak: router.push(.rentCollection)
        case .homes: router.select(.properties)
        case .repairs: router.select(.maintenance)
        case .tasks: router.push(.notifications)
        }
    }
}

/// A number on glass that leads somewhere.
struct GlassStat: View {
    let symbol: String
    let value: String
    let label: String
    let accent: DSAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ClayToken(symbol: symbol, accent: accent, size: 40)
                VStack(alignment: .leading, spacing: -2) {
                    Text(value).font(DS.Typography.brandFixed(24)).foregroundStyle(DS.Colors.textPrimary).minimumScaleFactor(0.6).lineLimit(1)
                    Text(label).font(DS.Typography.brand(.caption, weight: .semibold)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .homeGlass(radius: 22)
        }
        .buttonStyle(SquishStyle(scale: 0.95))
    }
}

/// Today's tasks on glass; tap one to tick it off.
struct TodayGlass: View {
    let model: HomeModel
    var limit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Today").font(DS.Typography.brand(.title3, weight: .bold))
                Spacer()
                Text("\(model.openTasks.count) left").font(DS.Typography.brand(.footnote, weight: .semibold)).foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(.bottom, 4)
            ForEach(model.dashboard.tasks.prefix(limit)) { task in
                Button { Task { await model.dashboard.toggleTask(task) } } label: {
                    HStack(spacing: 12) {
                        SakugaCheckMark(isOn: task.isDone)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(task.title).font(DS.Typography.brand(.subheadline, weight: .semibold)).strikethrough(task.isDone).lineLimit(1)
                            Text(task.due).font(DS.Typography.brand(.caption)).foregroundStyle(task.isUrgent ? DS.Colors.brandInk : DS.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if task.isUrgent { Image(systemName: "flame.fill").foregroundStyle(DS.Colors.brandInk) }
                    }
                    .frame(minHeight: 48)
                    .contentShape(.rect)
                }
                .buttonStyle(SquishStyle(scale: 0.98))
            }
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(16)
        .homeGlass()
    }
}
