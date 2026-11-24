// Renders a fly-over's map frames on a Mac, to preview a camera path (the
// simulator has no 3D imagery). Previews only: the app flies it live.
import AppKit
import MapKit

@main
enum Render {
    @MainActor
    static func main() {
        let style = FlyoverStyle(rawValue: CommandLine.arguments[1])!
        let out = CommandLine.arguments[2], fps = Double(CommandLine.arguments[3])!
        NSApplication.shared.setActivationPolicy(.accessory)
        Task { @MainActor in
            var points: [String: [[Double]]] = [:]
            for i in 0..<Int(FlyoverStyle.duration * fps) {
                let path = String(format: "%@/%04d.jpg", out, i)
                let spots = path + ".json"
                if let data = FileManager.default.contents(atPath: spots), let old = try? JSONDecoder().decode([[Double]].self, from: data) {
                    points["\(i)"] = old
                    continue
                }
                let c = style.camera(at: Double(i) / fps)
                let o = MKMapSnapshotter.Options()
                o.size = CGSize(width: 402, height: 874)
                o.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
                o.camera = MKMapCamera(lookingAtCenter: .init(latitude: c.lat, longitude: c.lon), fromDistance: c.distance, pitch: c.pitch, heading: c.heading)
                for _ in 0..<3 {
                    if let s = try? await MKMapSnapshotter(options: o).start() {
                        // Where each stop's card goes, for the overlay.
                        points["\(i)"] = style.stops.map { let p = s.point(for: .init(latitude: $0.lat, longitude: $0.lon)); return [p.x, p.y] }
                        try? JSONEncoder().encode(points["\(i)"]).write(to: URL(fileURLWithPath: spots))
                        if let tiff = s.image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                        try? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.86])?.write(to: URL(fileURLWithPath: path))
                        }
                        break
                    }
                }
            }
            try? JSONSerialization.data(withJSONObject: points).write(to: URL(fileURLWithPath: out + "/points.json"))
            exit(0)
        }
        NSApplication.shared.run()
    }
}
