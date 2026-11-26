//
//  HomeGlass.swift
//  RentalApp (Purrperty)
//
//  Dashboard — What the map homes share: the map with a pin on every
//  property, and the glass cards that sit over it.
//

#if DEBUG
import MapKit
import SwiftUI

// MARK: - Map

struct HomeMap: View {
    let model: HomeStudioModel
    @Binding var selection: String?
    /// Room taken by what sits over the map, so the city fits between.
    var insets = EdgeInsets()

    @State private var camera: MapCameraPosition = .camera(MapCamera(centerCoordinate: .init(latitude: 43.67, longitude: -79.39), distance: 30_000, heading: 0, pitch: 40))
    @State private var hasFit = false
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
                    HomePin(property: pin.property, accent: pin.accent, isSelected: selection == pin.id) {
                        feedback?.play(.select(0))
                        withAnimation(DS.Motion.smooth) { selection = selection == pin.id ? nil : pin.id }
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls { }
        .task(id: pins.count) {
            guard pins.count > 0, !hasFit else { return }
            hasFit = true
            fitAll(animated: false)
        }
        .onChange(of: selection) { _, id in
            if let id, let place = model.places[id] {
                withAnimation(.easeInOut(duration: 1.3)) {
                    // Aim a little south, so the home sits above the cards.
                    let shift = 0.0036 * Double(insets.bottom - insets.top) / 300
                    camera = .camera(MapCamera(centerCoordinate: .init(latitude: place.latitude - shift, longitude: place.longitude), distance: 1100, heading: 0, pitch: 60))
                }
            } else {
                fitAll(animated: true)
            }
        }
    }

    /// Every property in view, with room for the cards over the map.
    private func fitAll(animated: Bool) {
        let places = Array(model.places.values)
        guard !places.isEmpty else { return }
        let lats = places.map(\.latitude), lons = places.map(\.longitude)
        let latSpan = max(0.02, lats.max()! - lats.min()!), lonSpan = max(0.02, lons.max()! - lons.min()!)
        // The visible part of the screen is what's between the cards; the
        // region grows so the homes land there.
        let visible = max(0.25, 1 - Double(insets.top + insets.bottom) / 860)
        let height = latSpan * 1.25 / visible
        let middle = (lats.min()! + lats.max()!) / 2
        let shift = height * Double(insets.bottom - insets.top) / 860 / 2
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
            .scaleEffect(isSelected ? 1.3 : 1, anchor: .bottom)
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
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }
}

/// The paw with Purr explaining the toe you picked.
struct PawPanel: View {
    let model: HomeStudioModel
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

/// One property as a glass card.
struct PropertyGlassCard: View {
    let property: Property
    let accent: DSAccent
    var isSelected = false
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button { router.push(.propertyDetail(propertyID: property.id)) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ClayToken(symbol: property.kind.icon, accent: accent, size: 42)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(property.name).font(DS.Typography.brand(.headline, weight: .bold)).lineLimit(1)
                        Text(property.neighborhood).font(DS.Typography.brand(.footnote)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                OnboardingProgressTube(progress: max(0.04, property.occupancyRate), label: "", fill: accent.fill, track: DS.Colors.track.opacity(0.6))
                HStack {
                    Text("\(property.occupiedCount)/\(property.unitCount) rented")
                    Spacer()
                    if property.openRequests > 0 { Label("\(property.openRequests)", systemImage: "wrench.fill").foregroundStyle(property.urgentRequests > 0 ? DS.Colors.brandInk : DS.Colors.textSecondary) }
                }
                .font(DS.Typography.brand(.footnote, weight: .semibold))
            }
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(14)
            .homeGlass(radius: 24)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(accent.fill, lineWidth: isSelected ? 3 : 0))
        }
        .buttonStyle(SquishStyle(scale: 0.97))
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
    let model: HomeStudioModel
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
#endif
