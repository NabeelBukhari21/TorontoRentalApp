//
//  WeatherService.swift
//  RentalApp (Purrperty)
//
//  Weather — Toronto's current weather, for the sky on Home. From
//  Open-Meteo (open-meteo.com, CC BY 4.0), which needs no key or account.
//  The request names the city, never the person: the coordinates are
//  downtown Toronto's, always. Decorative, so every failure is silent.
//

import Foundation
import OSLog

struct Weather: Equatable, Sendable {
    enum Sky: Equatable, Sendable { case clear, cloudy, fog, rain, snow, storm }

    let sky: Sky
    let celsius: Int

    /// "3° · Rain"
    var summary: String {
        let name = switch sky {
        case .clear: "Clear"
        case .cloudy: "Cloudy"
        case .fog: "Fog"
        case .rain: "Rain"
        case .snow: "Snow"
        case .storm: "Storm"
        }
        return "\(celsius)° · \(name)"
    }
}

protocol WeatherServiceProtocol: Sendable {
    func current() async -> Weather?
}

actor OpenMeteoWeather: WeatherServiceProtocol {

    static let attribution = URL(string: "https://open-meteo.com/")!

    private var cached: (weather: Weather, at: Date)?
    private static let freshFor: TimeInterval = 30 * 60

    private static let endpoint = URL(string:
        "https://api.open-meteo.com/v1/forecast?latitude=43.65&longitude=-79.38&current=temperature_2m,weather_code&timezone=America%2FToronto")!

    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        let current: Current
    }

    func current() async -> Weather? {
        if let cached, Date.now.timeIntervalSince(cached.at) < Self.freshFor { return cached.weather }
        do {
            var request = URLRequest(url: Self.endpoint, timeoutInterval: 8)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return cached?.weather }
            let now = try JSONDecoder().decode(Response.self, from: data).current
            let weather = Weather(sky: Self.sky(for: now.weather_code), celsius: Int(now.temperature_2m.rounded()))
            cached = (weather, .now)
            return weather
        } catch {
            AppLog.app.debug("Weather unavailable: \(error.localizedDescription, privacy: .public)")
            return cached?.weather
        }
    }

    /// WMO weather codes.
    static func sky(for code: Int) -> Weather.Sky {
        switch code {
        case 0, 1: .clear
        case 2, 3: .cloudy
        case 45, 48: .fog
        case 51...67, 80...82: .rain
        case 71...77, 85, 86: .snow
        case 95...99: .storm
        default: .cloudy
        }
    }
}
