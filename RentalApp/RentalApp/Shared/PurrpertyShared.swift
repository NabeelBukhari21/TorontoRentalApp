//
//  PurrpertyShared.swift
//  RentalApp (Purrperty)
//
//  Shared — Compiled into BOTH the app and the PurrpertyWidgets extension
//  (Target Membership: RentalApp + PurrpertyWidgetsExtension).
//
//  • `PortfolioSnapshot` — what the widgets show. The app writes it to
//    the shared App Group container; the widget only reads.
//  • `RepairVisitAttributes` — the Live Activity for a booked repair
//    visit. ActivityKit matches activities by this type, so the app and
//    the extension must compile the same definition.
//
//  Keep this file free of app types: the extension can't see them.
//

import Foundation
import ActivityKit

// MARK: - App Group

enum PurrpertyAppGroup {
    static let identifier = "group.Seneca.Syed.RentalApp"

    /// Nil only if the App Group capability is missing from a target.
    static var defaults: UserDefaults? { UserDefaults(suiteName: identifier) }
}

// MARK: - Portfolio Snapshot

/// The numbers the widgets show. Aggregates only — no tenant names — since
/// widgets appear on the Lock Screen.
struct PortfolioSnapshot: Codable, Equatable, Sendable {

    struct Visit: Codable, Equatable, Sendable, Identifiable {
        let id: String
        let title: String
        let place: String
        let date: Date
    }

    var updatedAt: Date
    var month: Date
    var rentCollected: Int
    var rentExpected: Int
    var tenantsOwing: Int
    var amountOwing: Int
    var openRequests: Int
    var urgentRequests: Int
    var unassignedRequests: Int
    /// Soonest first, at most three.
    var upcomingVisits: [Visit]

    var collectionRate: Double {
        rentExpected == 0 ? 0 : Double(rentCollected) / Double(rentExpected)
    }

    // MARK: Storage

    private static let key = "purrperty.widget.snapshot.v1"

    static func load() -> PortfolioSnapshot? {
        guard let data = PurrpertyAppGroup.defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PortfolioSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        PurrpertyAppGroup.defaults?.set(data, forKey: Self.key)
    }

    /// Removes it, so a signed-out phone's widgets show nothing private.
    static func clear() {
        PurrpertyAppGroup.defaults?.removeObject(forKey: key)
    }

    /// For the widget gallery and placeholders.
    static let sample = PortfolioSnapshot(
        updatedAt: .now,
        month: .now,
        rentCollected: 41_250,
        rentExpected: 48_600,
        tenantsOwing: 3,
        amountOwing: 7_350,
        openRequests: 12,
        urgentRequests: 2,
        unassignedRequests: 4,
        upcomingVisits: [
            Visit(id: "a", title: "Kitchen sink leaking", place: "Unit 204 · Glenholme Row",
                  date: .now.addingTimeInterval(3 * 3600)),
            Visit(id: "b", title: "No heat in bedroom", place: "Unit 12 · Beacon Place",
                  date: .now.addingTimeInterval(26 * 3600))
        ]
    )
}

// MARK: - Repair Visit Live Activity

/// A booked repair visit, on the Lock Screen and in the Dynamic Island
/// until the job is done.
struct RepairVisitAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable, Sendable {
        enum Stage: String, Codable, Hashable, Sendable {
            case booked
            case done
        }

        var stage: Stage
        var visitTime: Date
    }

    let requestID: String
    let title: String
    /// "Unit 204 · Glenholme Row"
    let place: String
    /// Who's coming, e.g. "Beacon Electrical".
    let vendor: String?
}
