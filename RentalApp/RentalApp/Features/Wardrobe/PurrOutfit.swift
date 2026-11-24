//
//  PurrOutfit.swift
//  RentalApp (Purrperty)
//
//  Wardrobe — Outfits Purr earns from real milestones and wears on Home
//  when nothing needs attention. Each is one of the rig's own costumes.
//

import Foundation
import Observation

enum PurrOutfit: String, CaseIterable, Identifiable, Codable, Sendable {
    case everyday
    case hardHat
    case keys
    case headphones
    case partyHat
    case crown
    case workout
    case cape
    case gradCap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyday: "Everyday"
        case .hardHat: "Hard hat"
        case .keys: "Key keeper"
        case .headphones: "Headphones"
        case .partyHat: "Party hat"
        case .crown: "Crown"
        case .workout: "Gym kit"
        case .cape: "Cape"
        case .gradCap: "Grad cap"
        }
    }

    /// How it's earned.
    var milestone: String {
        switch self {
        case .everyday: "Always yours"
        case .hardHat: "Add your first property"
        case .keys: "Rent out your first unit"
        case .headphones: "Clear every open repair"
        case .partyHat: "Rent out every unit"
        case .crown: "Collect a full month's rent"
        case .workout: "1 month of rent on time"
        case .cape: "3 months of rent on time"
        case .gradCap: "6 months of rent on time"
        }
    }

    /// The costume; nil wears whatever the moment calls for.
    var mood: PurrMood? {
        switch self {
        case .everyday: nil
        case .hardHat: .builder
        case .keys: .keysReady
        case .headphones: .vibing
        case .partyHat: .partyTime
        case .crown: .royalWave
        case .workout: .workout
        case .cape: .superhero
        case .gradCap: .graduation
        }
    }
}

/// The facts outfits are earned from.
struct WardrobeFacts: Equatable {
    var properties = 0
    var units = 0
    var rentedUnits = 0
    var openRequests = 0
    var hasRequests = false
    var isMonthCollected = false
    var streak = 0

    func earns(_ outfit: PurrOutfit) -> Bool {
        switch outfit {
        case .everyday: true
        case .hardHat: properties > 0
        case .keys: rentedUnits > 0
        case .headphones: hasRequests && openRequests == 0
        case .partyHat: units > 0 && rentedUnits >= units
        case .crown: isMonthCollected
        case .workout: streak >= 1
        case .cape: streak >= 3
        case .gradCap: streak >= 6
        }
    }
}

/// What's been earned and what Purr is wearing, per account. Once earned,
/// an outfit is kept.
@MainActor
@Observable
final class WardrobeStore {

    private struct Closet: Codable {
        var earned: Set<PurrOutfit> = [.everyday]
        var worn: PurrOutfit = .everyday
    }

    private let persistence: PersistenceServiceProtocol
    /// Whose closet is open. Set as the session changes.
    var account = "none"
    private var closets: [String: Closet] = [:]

    init(persistence: PersistenceServiceProtocol) {
        self.persistence = persistence
    }

    private var key: String { "wardrobe.v1.\(account)" }

    private var closet: Closet {
        get {
            closets[key]
                ?? persistence.data(forKey: key).flatMap { try? JSONDecoder().decode(Closet.self, from: $0) }
                ?? Closet()
        }
        set {
            closets[key] = newValue
            persistence.set(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }

    var earned: Set<PurrOutfit> { closet.earned }

    var worn: PurrOutfit {
        get { closet.worn }
        set { if earned.contains(newValue) { closet.worn = newValue } }
    }

    /// Adds whatever the facts earn; returns what's new.
    func update(with facts: WardrobeFacts) -> [PurrOutfit] {
        let new = PurrOutfit.allCases.filter { facts.earns($0) && !closet.earned.contains($0) }
        if !new.isEmpty { closet.earned.formUnion(new) }
        return new
    }
}
