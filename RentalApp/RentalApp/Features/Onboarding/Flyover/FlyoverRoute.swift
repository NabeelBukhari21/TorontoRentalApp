//
//  FlyoverRoute.swift
//  RentalApp (Purrperty)
//
//  Onboarding — The three live fly-overs of Toronto, as camera paths over
//  Apple's photorealistic 3D imagery. Only numbers here: the same file
//  drives the app and the Mac tool that previews a path
//  (tools/flyover/preview.sh).
//

import Foundation

enum FlyoverStyle: String, CaseIterable, Sendable {
    /// In over the harbour, down between the towers, once round two of them.
    case skyline
    /// From a condo tower to a campus to a street of houses.
    case hop
    /// From space to one roof.
    case space

    /// Seconds, and when the closing cheer comes.
    static let duration = 12.0
    static let finale = 10.35
}

/// One moment of the camera.
struct FlyoverKey: Sendable {
    let t, lat, lon, distance, heading, pitch: Double
}

struct FlyoverCamera: Equatable, Sendable {
    let lat, lon, distance, heading, pitch: Double
}

/// A card pinned to a place, and when it's on screen.
struct FlyoverStop: Identifiable, Sendable {
    let id: Int
    let lat, lon: Double
    let from, to: Double
    let symbol, title, detail: String
    let accent: String
}

struct FlyoverCaption: Identifiable, Sendable {
    let id: Int
    let from, to: Double
    let text: String
}

extension FlyoverStyle {

    var keys: [FlyoverKey] {
        switch self {
        case .skyline: [
            .init(t: 0, lat: 43.6270, lon: -79.3830, distance: 5200, heading: 348, pitch: 62),
            .init(t: 2.2, lat: 43.6385, lon: -79.3822, distance: 2500, heading: 356, pitch: 66),
            .init(t: 4.2, lat: 43.6436, lon: -79.3818, distance: 1250, heading: 12, pitch: 67),
            .init(t: 6.4, lat: 43.6432, lon: -79.3812, distance: 820, heading: 52, pitch: 64),
            .init(t: 8.6, lat: 43.6432, lon: -79.3812, distance: 760, heading: 104, pitch: 62),
            .init(t: 10.4, lat: 43.6436, lon: -79.3815, distance: 1000, heading: 138, pitch: 60),
            .init(t: 12, lat: 43.6436, lon: -79.3815, distance: 1080, heading: 148, pitch: 60),
        ]
        case .hop: [
            .init(t: 0, lat: 43.6424, lon: -79.3845, distance: 1500, heading: 8, pitch: 52),
            .init(t: 2.4, lat: 43.6421, lon: -79.3820, distance: 900, heading: 34, pitch: 60),
            .init(t: 4.2, lat: 43.6510, lon: -79.3900, distance: 1500, heading: 340, pitch: 56),
            .init(t: 5.8, lat: 43.6578, lon: -79.3997, distance: 700, heading: 330, pitch: 58),
            .init(t: 7.0, lat: 43.6578, lon: -79.3996, distance: 580, heading: 300, pitch: 60),
            .init(t: 8.0, lat: 43.6640, lon: -79.3800, distance: 1150, heading: 350, pitch: 56),
            .init(t: 9.1, lat: 43.6667, lon: -79.3657, distance: 460, heading: 18, pitch: 58),
            .init(t: 12, lat: 43.6669, lon: -79.3655, distance: 400, heading: 40, pitch: 60),
        ]
        case .space: [
            .init(t: 0, lat: 42.0, lon: -80.5, distance: 9_000_000, heading: 0, pitch: 0),
            .init(t: 1.6, lat: 43.2, lon: -79.8, distance: 1_200_000, heading: 0, pitch: 0),
            .init(t: 3.2, lat: 43.62, lon: -79.40, distance: 60_000, heading: 0, pitch: 12),
            .init(t: 4.8, lat: 43.6480, lon: -79.3860, distance: 7000, heading: 344, pitch: 48),
            .init(t: 6.6, lat: 43.6520, lon: -79.3820, distance: 3300, heading: 352, pitch: 58),
            .init(t: 8.6, lat: 43.6510, lon: -79.3810, distance: 1700, heading: 20, pitch: 57),
            .init(t: 10.4, lat: 43.6494, lon: -79.3795, distance: 900, heading: 52, pitch: 52),
            .init(t: 12, lat: 43.6494, lon: -79.3795, distance: 820, heading: 62, pitch: 52),
        ]
        }
    }

    var stops: [FlyoverStop] {
        switch self {
        case .skyline: [
            .init(id: 0, lat: 43.6431, lon: -79.3806, from: 4.4, to: 11, symbol: "banknote.fill", title: "Rent recorded", detail: "$2,150 · Unit 4B", accent: "mint"),
            .init(id: 1, lat: 43.6427, lon: -79.3818, from: 5.6, to: 11, symbol: "wrench.and.screwdriver.fill", title: "Repair booked", detail: "Thu 10 am · Leaky tap", accent: "blush"),
            .init(id: 2, lat: 43.6438, lon: -79.3800, from: 6.9, to: 11, symbol: "calendar", title: "Lease renews", detail: "In 60 days", accent: "sky"),
            .init(id: 3, lat: 43.6441, lon: -79.3818, from: 8.1, to: 11, symbol: "door.left.hand.open", title: "Unit 12 is vacant", detail: "Asking $2,400", accent: "gold"),
        ]
        case .hop: [
            .init(id: 0, lat: 43.6421, lon: -79.3817, from: 0.9, to: 3.5, symbol: "building.2.fill", title: "Condo tower", detail: "Rent recorded · $2,150", accent: "mint"),
            .init(id: 1, lat: 43.6580, lon: -79.3994, from: 5.0, to: 7.4, symbol: "wrench.and.screwdriver.fill", title: "Student rentals", detail: "Repair booked · Thu 10 am", accent: "blush"),
            .init(id: 2, lat: 43.6667, lon: -79.3657, from: 8.7, to: 11.2, symbol: "house.fill", title: "Family house", detail: "Lease renews in 60 days", accent: "gold"),
        ]
        case .space:
            zip(0..., [(43.6494, -79.3795), (43.6532, -79.3832), (43.6465, -79.3870), (43.6560, -79.3800), (43.6505, -79.3722), (43.6590, -79.3900), (43.6450, -79.3760), (43.6545, -79.3950)]).map { i, p in
                .init(id: i, lat: p.0, lon: p.1, from: 4.7 + Double(i) * 0.22, to: i == 0 ? 11 : 9.6,
                      symbol: ["banknote.fill", "house.fill", "key.fill", "building.2.fill"][i % 4],
                      title: i == 0 ? "All rent in" : "", detail: i == 0 ? "14 homes, one map" : "", accent: ["cherry", "gold", "mint", "sky"][i % 4])
            }
        }
    }

    var captions: [FlyoverCaption] {
        switch self {
        case .skyline: [
            .init(id: 0, from: 0.5, to: 3.9, text: "This is your city"),
            .init(id: 1, from: 4.3, to: 7.4, text: "Every rental in it, on one screen"),
            .init(id: 2, from: 7.7, to: 10.1, text: "Rent, repairs, leases. Sorted."),
        ]
        case .hop: [
            .init(id: 0, from: 0.6, to: 3.6, text: "One tower or twenty doors"),
            .init(id: 1, from: 4.6, to: 7.5, text: "Student rooms, always in hand"),
            .init(id: 2, from: 7.9, to: 10.2, text: "Right down to your street"),
        ]
        case .space: [
            .init(id: 0, from: 0.5, to: 3.0, text: "Somewhere down there…"),
            .init(id: 1, from: 3.4, to: 6.6, text: "…are your rentals"),
            .init(id: 2, from: 7.0, to: 10.1, text: "Now they're all under one paw"),
        ]
        }
    }

    /// The camera at `time`: a smooth curve through the keys, with the
    /// distance in logarithms so a zoom feels even.
    func camera(at time: Double) -> FlyoverCamera {
        let k = keys
        let t = min(max(time, k[0].t), k[k.count - 1].t)
        let i = min(max(0, (k.lastIndex { $0.t <= t } ?? 0)), k.count - 2)
        let span = k[i + 1].t - k[i].t, u = (t - k[i].t) / span

        func curve(_ value: (FlyoverKey) -> Double) -> Double {
            func slope(_ j: Int) -> Double {
                guard j > 0, j < k.count - 1 else { return 0 }
                let a = (value(k[j]) - value(k[j - 1])) / (k[j].t - k[j - 1].t)
                let b = (value(k[j + 1]) - value(k[j])) / (k[j + 1].t - k[j].t)
                // Never overshoots: flat where the direction turns.
                return a * b <= 0 ? 0 : 2 * a * b / (a + b)
            }
            let u2 = u * u, u3 = u2 * u
            return (2 * u3 - 3 * u2 + 1) * value(k[i]) + (u3 - 2 * u2 + u) * span * slope(i)
                + (3 * u2 - 2 * u3) * value(k[i + 1]) + (u3 - u2) * span * slope(i + 1)
        }

        // Headings as a running turn, so 350° to 10° goes the short way.
        var turns: [Double] = [k[0].heading]
        for j in 1..<k.count {
            var d = (k[j].heading - k[j - 1].heading).truncatingRemainder(dividingBy: 360)
            if d > 180 { d -= 360 }
            if d < -180 { d += 360 }
            turns.append(turns[j - 1] + d)
        }
        func heading(_ key: FlyoverKey) -> Double { turns[k.firstIndex { $0.t == key.t } ?? 0] }

        return FlyoverCamera(
            lat: curve(\.lat), lon: curve(\.lon), distance: exp(curve { log($0.distance) }),
            heading: curve(heading).truncatingRemainder(dividingBy: 360), pitch: curve(\.pitch)
        )
    }
}
