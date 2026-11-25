//
//  AddressSearch.swift
//  RentalApp (Purrperty)
//
//  Address — Suggestions as a street is typed, and a check that the
//  address is real. Apple Maps answers both, so what's typed goes to
//  Apple; no location permission is used.
//

import CoreLocation
import Foundation
import MapKit
import Observation

/// A real address, in the app's own fields.
struct ResolvedAddress: Hashable, Sendable {
    let street: String
    let city: String
    let postalCode: String
    let latitude: Double
    let longitude: Double

    /// "M5V 2T6" out of a longer line.
    static func postalCode(in text: String) -> String? {
        guard let range = text.range(of: #"[A-Za-z]\d[A-Za-z] ?\d[A-Za-z]\d"#, options: .regularExpression) else { return nil }
        let code = text[range].uppercased().filter { $0 != " " }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}

struct AddressSuggestion: Identifiable, Equatable {
    let id: Int
    let title: String
    let subtitle: String
}

@MainActor
@Observable
final class AddressSearch: NSObject {

    enum Status: Equatable {
        case idle
        case checking
        /// Found, exactly as it stands in the form.
        case verified(ResolvedAddress)
        /// Maps knows a different address.
        case didYouMean(ResolvedAddress)
        case notFound
        /// No answer (offline): the form carries on without it.
        case unavailable
    }

    private(set) var suggestions: [AddressSuggestion] = []
    private(set) var status: Status = .idle

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var completions: [MKLocalSearchCompletion] = []
    /// The street last filled in by a pick, so filling it isn't typing.
    @ObservationIgnored private var filledStreet: String?

    /// The Greater Toronto Area, to rank by.
    private static let home = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.70, longitude: -79.42),
        span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.6)
    )

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.region = Self.home
    }

    var isVerified: Bool {
        if case .verified = status { true } else { false }
    }

    /// Checked and not confirmed; carrying on keeps what was typed.
    var isUnconfirmed: Bool {
        switch status {
        case .didYouMean, .notFound: true
        case .idle, .checking, .verified, .unavailable: false
        }
    }

    // MARK: Typing

    func streetChanged(to street: String) {
        guard street != filledStreet else { return }
        filledStreet = nil
        status = .idle
        let query = street.trimmingCharacters(in: .whitespaces)
        if query.count < 3 {
            clear()
        } else {
            completer.queryFragment = query
        }
    }

    /// City or postal code edited: what was verified no longer stands.
    func detailsChanged(city: String, postalCode: String) {
        guard case .verified(let address) = status,
              address.city != city || (address.postalCode != postalCode && !address.postalCode.isEmpty) else { return }
        status = .idle
    }

    func clear() {
        completer.cancel()
        completions = []
        suggestions = []
    }

    // MARK: Picking

    /// The full address behind a suggestion.
    func resolve(_ suggestion: AddressSuggestion) async -> ResolvedAddress? {
        guard completions.indices.contains(suggestion.id) else { return nil }
        let request = MKLocalSearch.Request(completion: completions[suggestion.id])
        clear()
        status = .checking
        switch await find(request, street: suggestion.title) {
        case .found(let address):
            accept(address)
            return address
        case .nothing: status = .notFound
        case .failed: status = .unavailable
        }
        return nil
    }

    /// Take an address Maps found (a suggestion, or "did you mean").
    func accept(_ address: ResolvedAddress) {
        filledStreet = address.street
        clear()
        status = .verified(address)
    }

    // MARK: Checking

    /// Checks an address typed by hand. True when the form can carry on.
    func check(street: String, city: String, postalCode: String) async -> Bool {
        switch status {
        case .verified, .unavailable: return true
        // Seen the note and pressed again: they know their own address.
        case .didYouMean, .notFound: return true
        case .checking: return false
        case .idle: break
        }
        clear()
        status = .checking
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(street), \(city), ON \(postalCode)"
        request.resultTypes = .address
        request.region = Self.home

        switch await find(request, street: nil) {
        case .found(let address):
            let sameNumber = Self.houseNumber(address.street) == Self.houseNumber(street)
            let sameName = Self.streetKey(address.street) == Self.streetKey(street)
            let samePlace = address.city.caseInsensitiveCompare(city.trimmingCharacters(in: .whitespaces)) == .orderedSame
            let typedCode = ResolvedAddress.postalCode(in: postalCode)
            let sameCode = typedCode == nil || address.postalCode.isEmpty || typedCode == address.postalCode
            if sameNumber, sameName, samePlace, sameCode {
                accept(address)
                return true
            }
            // Only a near miss is worth suggesting.
            let isClose = Self.houseNumber(address.street) != nil && sameName
            status = isClose ? .didYouMean(address) : .notFound
            return false
        case .nothing:
            status = .notFound
            return false
        case .failed:
            status = .unavailable
            return true
        }
    }

    private enum Finding {
        case found(ResolvedAddress), nothing, failed
    }

    private func find(_ request: MKLocalSearch.Request, street: String?) async -> Finding {
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first(where: { Self.isCanadian($0) }) else { return .nothing }
            return Self.resolved(item, street: street).map(Finding.found) ?? .nothing
        } catch let error as MKError where error.code == .placemarkNotFound {
            return .nothing
        } catch {
            return .failed
        }
    }

    private static func isCanadian(_ item: MKMapItem) -> Bool {
        item.addressRepresentations?.region?.identifier == "CA"
    }

    private static func resolved(_ item: MKMapItem, street: String?) -> ResolvedAddress? {
        guard let full = item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: false) else { return nil }
        let lines = full.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let typed = street.flatMap { houseNumber($0) == nil ? nil : $0 }
        guard let line = lines.first(where: { houseNumber($0) != nil && ResolvedAddress.postalCode(in: $0) == nil }) ?? typed ?? lines.first,
              let city = item.addressRepresentations?.cityName else { return nil }
        let place = item.location.coordinate
        return ResolvedAddress(
            street: line, city: city, postalCode: ResolvedAddress.postalCode(in: full) ?? "",
            latitude: place.latitude, longitude: place.longitude
        )
    }

    // MARK: Comparing

    /// "100" of "100 King St W".
    private static func houseNumber(_ street: String) -> String? {
        let first = street.split(whereSeparator: { $0 == " " || $0 == "," }).first.map(String.init) ?? ""
        return first.first?.isNumber == true ? first.lowercased() : nil
    }

    /// The street's name without its number, type or direction, so "King
    /// Street West" and "King St W" agree.
    private static func streetKey(_ street: String) -> String {
        street.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .first { $0.contains(where: \.isLetter) && $0.first?.isNumber != true } ?? ""
    }
}

// MARK: - Completer

/// MapKit calls these on the main thread.
extension AddressSearch: MKLocalSearchCompleterDelegate {

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated { showResults() }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated { clear() }
    }

    private func showResults() {
        guard filledStreet == nil else { return }
        completions = Array(completer.results.filter { !$0.subtitle.contains("United States") }.prefix(4))
        suggestions = completions.enumerated().map { AddressSuggestion(id: $0.offset, title: $0.element.title, subtitle: $0.element.subtitle) }
    }
}
