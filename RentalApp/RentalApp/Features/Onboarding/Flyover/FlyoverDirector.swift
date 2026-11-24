//
//  FlyoverDirector.swift
//  RentalApp (Purrperty)
//
//  Onboarding — Flies the camera: the map underneath, what time it is in
//  the flight, and where each card's place is on screen.
//

import CoreLocation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class FlyoverDirector: NSObject {

    enum Phase { case loading, flying, landed, failed }

    let style: FlyoverStyle
    private(set) var phase: Phase = .loading
    /// Seconds into the flight.
    private(set) var time = 0.0
    private(set) var points: [Int: CGPoint] = [:]

    @ObservationIgnored private weak var map: MKMapView?
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var startedAt: CFTimeInterval?
    @ObservationIgnored private var hasRendered = false
    @ObservationIgnored private var isPreparing = false

    init(style: FlyoverStyle) {
        self.style = style
        super.init()
    }

    // MARK: Map

    func makeMap() -> MKMapView {
        let map = MKMapView()
        let configuration = MKImageryMapConfiguration(elevationStyle: .realistic)
        map.preferredConfiguration = configuration
        map.isUserInteractionEnabled = false
        map.showsCompass = false
        map.showsScale = false
        map.delegate = self
        map.overrideUserInterfaceStyle = .dark
        self.map = map
        // Starts over the busiest part of the flight, so its buildings are
        // already on the way.
        place(at: FlyoverStyle.duration * 0.6)
        return map
    }

    private func place(at time: Double) {
        let c = style.camera(at: time)
        map?.camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon),
            fromDistance: c.distance, pitch: c.pitch, heading: c.heading
        )
    }

    // MARK: Flight

    /// Waits for the city to load, then takes off. Gives up after a few
    /// seconds with nothing drawn (no network).
    func prepare() async {
        guard !isPreparing else { return }
        isPreparing = true
        #if DEBUG
        if let frames = FlyoverFrames.current(for: style) {
            self.frames = frames
            return takeOff()
        }
        #endif
        guard await rendered(within: 4) else {
            if phase == .loading, !Task.isCancelled { phase = .failed }
            return
        }
        hasRendered = false
        place(at: 0)
        _ = await rendered(within: 2)
        guard phase == .loading, !Task.isCancelled else { return }
        takeOff()
    }

    private func rendered(within seconds: Double) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !hasRendered, phase == .loading, ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(80))
        }
        return hasRendered
    }

    private func takeOff() {
        phase = .flying
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let start = startedAt ?? link.timestamp
        startedAt = start
        time = min(link.timestamp - start, FlyoverStyle.duration)
        let located: [Int: CGPoint]
        #if DEBUG
        if let frames {
            located = frames.points(at: time)
        } else {
            located = moveMap()
        }
        #else
        located = moveMap()
        #endif
        points = located
        if time >= FlyoverStyle.duration {
            stop()
            phase = .landed
        }
    }

    private func moveMap() -> [Int: CGPoint] {
        guard let map else { return [:] }
        place(at: time)
        return Dictionary(uniqueKeysWithValues: style.stops.map {
            ($0.id, map.convert(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon), toPointTo: map))
        })
    }

    #if DEBUG
    /// Frames rendered on a Mac, instead of the map (the simulator has no
    /// 3D imagery).
    private(set) var frames: FlyoverFrames?
    #endif
}

extension FlyoverDirector: MKMapViewDelegate {
    nonisolated func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        MainActor.assumeIsolated { if fullyRendered { hasRendered = true } }
    }

    nonisolated func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
        MainActor.assumeIsolated { if phase == .loading { phase = .failed } }
    }
}

struct FlyoverMap: UIViewRepresentable {
    let director: FlyoverDirector
    func makeUIView(context: Context) -> MKMapView { director.makeMap() }
    func updateUIView(_ view: MKMapView, context: Context) {}
}

#if DEBUG
/// Frames from tools/flyover, for checking the overlay in the simulator:
/// `-PurrpertyFlyoverFrames <folder holding hi_skyline, hi_hop, hi_space>`.
@MainActor
struct FlyoverFrames {
    private let images: [String]
    private let spots: [String: [[Double]]]
    private static let rate = 20.0

    static func current(for style: FlyoverStyle) -> FlyoverFrames? {
        guard let root = UserDefaults.standard.string(forKey: "PurrpertyFlyoverFrames") else { return nil }
        let folder = "\(root)/hi_\(style.rawValue)"
        guard let data = FileManager.default.contents(atPath: folder + "/points.json"),
              let spots = try? JSONDecoder().decode([String: [[Double]]].self, from: data) else { return nil }
        let count = Int(FlyoverStyle.duration * rate)
        return FlyoverFrames(images: (0..<count).map { folder + String(format: "/%04d.jpg", $0) }, spots: spots)
    }

    private func index(_ time: Double) -> Int { min(Int(time * Self.rate), images.count - 1) }
    func image(at time: Double) -> UIImage? { UIImage(contentsOfFile: images[index(time)]) }
    func points(at time: Double) -> [Int: CGPoint] {
        let list = spots["\(index(time))"] ?? []
        return Dictionary(uniqueKeysWithValues: list.enumerated().map { ($0.offset, CGPoint(x: $0.element[0], y: $0.element[1])) })
    }
}
#endif
