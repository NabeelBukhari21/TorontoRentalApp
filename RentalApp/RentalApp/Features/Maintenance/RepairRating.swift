//
//  RepairRating.swift
//  RentalApp (Purrperty)
//
//  Maintenance — How a finished repair went, in paws. Kept on this phone:
//  there's no backend field for it yet, and the card says so.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class RepairRatingStore {

    private let persistence: PersistenceServiceProtocol
    private var ratings: [String: Int]
    private static let key = "repairRatings.v1"

    init(persistence: PersistenceServiceProtocol) {
        self.persistence = persistence
        ratings = persistence.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
    }

    /// 1…5, or 0 when it hasn't been rated.
    func rating(for ticketID: String) -> Int { ratings[ticketID] ?? 0 }

    func rate(_ ticketID: String, _ score: Int) {
        ratings[ticketID] = min(5, max(1, score))
        persistence.set(try? JSONEncoder().encode(ratings), forKey: Self.key)
    }
}

struct RepairRatingCard: View {
    let ticketID: String
    let store: RepairRatingStore

    var body: some View {
        DSCard(style: .raised) {
            VStack(spacing: DS.Spacing.md) {
                Text("How did the repair go?")
                    .font(DS.Typography.brand(.title3, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                SakugaRating(score: Binding(get: { store.rating(for: ticketID) }, set: { store.rate(ticketID, $0) }))
                Text("Saved on this phone.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
        }
    }
}
