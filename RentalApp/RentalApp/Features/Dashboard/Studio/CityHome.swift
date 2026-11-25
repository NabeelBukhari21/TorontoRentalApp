//
//  CityHome.swift — C: The city. Home is Toronto itself, with a clay pin
//  on every property. Swipe the cards and the camera flies to each one.
//

#if DEBUG
import MapKit
import SwiftUI

struct CityHome: View {
    let model: HomeStudioModel

    @State private var camera: MapCameraPosition = .camera(MapCamera(centerCoordinate: .init(latitude: 43.6440, longitude: -79.3900), distance: 13_000, heading: 344, pitch: 58))
    @State private var page: String? = "today"
    @Environment(AppRouter.self) private var router
    @Environment(\.feedback) private var feedback

    private let accents: [DSAccent] = [.cherry, .gold, .mint, .sky, .blush]

    var body: some View {
        // Read here: changes inside the map's content aren't observed.
        let pins = model.properties.enumerated().compactMap { i, property in
            model.places[property.id].map { Pin(property: property, place: $0, accent: accents[i % accents.count]) }
        }
        Map(position: $camera, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
            ForEach(pins) { spot in
                Annotation(spot.property.name, coordinate: spot.place, anchor: .bottom) {
                    pin(spot.property, spot.accent)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom).frame(height: 190).ignoresSafeArea().allowsHitTesting(false)
        }
        .overlay(alignment: .top) { HomeBar(model: model, ink: .white).padding(.horizontal, 16).padding(.top, 4) }
        .overlay(alignment: .bottom) { cards }
        .task(id: model.properties.count) { await model.locate() }
        .onChange(of: page) { _, id in fly(to: id) }
    }

    private struct Pin: Identifiable {
        let property: Property
        let place: CLLocationCoordinate2D
        let accent: DSAccent
        var id: String { property.id }
    }

    private func fly(to id: String?) {
        feedback?.play(.scrub)
        let target: MapCamera
        if let id, let place = model.places[id] {
            target = MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: place.latitude - 0.0016, longitude: place.longitude), distance: 900, heading: 20, pitch: 58)
        } else {
            target = MapCamera(centerCoordinate: .init(latitude: 43.6440, longitude: -79.3900), distance: 13_000, heading: 344, pitch: 58)
        }
        withAnimation(.easeInOut(duration: 1.4)) { camera = .camera(target) }
    }

    // MARK: Pins

    /// A house on a ring that shows how full it is.
    private func pin(_ property: Property, _ accent: DSAccent) -> some View {
        let isOpen = page == property.id
        return Button { withAnimation(DS.Motion.smooth) { page = property.id } } label: {
            VStack(spacing: -4) {
                ZStack {
                    Circle().fill(DS.Colors.surfaceRaised)
                    Circle().trim(from: 0, to: property.occupancyRate).stroke(accent.fill, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90)).padding(4)
                    ClayToken(symbol: property.kind.icon, accent: accent, size: 38)
                }
                .frame(width: 58, height: 58)
                .overlay(alignment: .topTrailing) {
                    if property.openRequests > 0 {
                        Text(property.openRequests, format: .number).font(DS.Typography.brandFixed(13)).foregroundStyle(DS.Colors.textOnBrand)
                            .frame(width: 22, height: 22).background(Circle().fill(DS.Colors.brand)).overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    }
                }
                Image(systemName: "triangle.fill").font(.system(size: 14)).rotationEffect(.degrees(180)).foregroundStyle(DS.Colors.surfaceRaised)
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 6)
            .scaleEffect(isOpen ? 1.25 : 1, anchor: .bottom)
            .animation(DS.Motion.bouncy, value: isOpen)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(property.name)
    }

    // MARK: Cards

    private var cards: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                today.id("today").containerRelativeFrame(.horizontal) { w, _ in w - 56 }
                ForEach(Array(model.properties.enumerated()), id: \.element.id) { i, property in
                    card(property, accents[i % accents.count])
                        .id(property.id)
                        .containerRelativeFrame(.horizontal) { w, _ in w - 56 }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 28, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: 232)
        .padding(.bottom, 12)
    }

    private func sheet(_ content: some View) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(DS.Colors.surfaceRaised.opacity(0.94)).shadow(color: .black.opacity(0.35), radius: 18, y: 10))
            .scrollTransition { view, phase in view.scaleEffect(phase.isIdentity ? 1 : 0.93).opacity(phase.isIdentity ? 1 : 0.75) }
    }

    private var today: some View {
        sheet(
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text(model.brief.message).font(DS.Typography.brand(.headline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    PurrMascot(mood: model.brief.mood, size: 108, isInteractive: false).padding(.top, -62).padding(.trailing, -6)
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    number("Rent in", "\(Int((model.rentRate * 100).rounded()))%", .mint) { router.push(.rentCollection) }
                    number("Rented", "\(Int((model.occupancy * 100).rounded()))%", .gold) { router.select(.properties) }
                    number("Repairs", "\(model.requests)", .cherry) { router.select(.maintenance) }
                }
            }
        )
    }

    private func number(_ title: String, _ value: String, _ accent: DSAccent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(value).font(DS.Typography.brandFixed(28))
                Text(title).font(DS.Typography.brand(.caption, weight: .semibold))
            }
            .foregroundStyle(accent.onFill)
            .frame(maxWidth: .infinity).frame(height: 78)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.clay(accent.fill, shade: accent.ink, size: 70)))
        }
        .buttonStyle(SquishStyle(scale: 0.94))
    }

    private func card(_ property: Property, _ accent: DSAccent) -> some View {
        sheet(
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ClayToken(symbol: property.kind.icon, accent: accent, size: 52)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(property.name).font(DS.Typography.brand(.title3, weight: .bold)).foregroundStyle(DS.Colors.textPrimary).lineLimit(1)
                        Text(property.address).font(DS.Typography.brand(.footnote)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                    }
                }
                HStack(spacing: 16) {
                    fact("key.fill", "\(property.occupiedCount)/\(property.unitCount) let")
                    fact("dollarsign.circle.fill", "$\(property.monthlyRevenue.formatted(.number.precision(.fractionLength(1))))K")
                    fact("wrench.fill", "\(property.openRequests) open")
                }
                Spacer(minLength: 0)
                SakugaButton(title: "Go inside", kind: .primary, impact: .light, symbol: "chevron.forward", isFullWidth: true) {
                    router.push(.propertyDetail(propertyID: property.id))
                }
            }
        )
    }

    private func fact(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol).font(DS.Typography.brand(.subheadline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary)
    }
}
#endif
