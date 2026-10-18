//
//  OnboardingProfile.swift
//  RentalApp (Purrperty)
//
//  Onboarding — What the user told Purr before they had an account.
//
//  The quiz runs before sign-up, so its answers can't live on a server
//  row yet. They're kept on the device in `OnboardingProfileStore` and
//  read afterwards to pre-fill workspace setup, suggest the first
//  property's size, and choose the outcomes the paywall leads with.
//
//  Every option maps to something the app actually does today. Mascot
//  copy may only promise features that exist (see CLAUDE.md).
//

import SwiftUI

// MARK: - Persona

enum OnboardingPersona: String, Codable, CaseIterable, Identifiable, Sendable {
    case landlord
    case propertyManager
    case tenant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .landlord:        "I own rentals"
        case .propertyManager: "I manage for others"
        case .tenant:          "I'm a tenant"
        }
    }

    var subtitle: String {
        switch self {
        case .landlord:        "Landlord or owner"
        case .propertyManager: "Property manager or team"
        case .tenant:          "I rent my home"
        }
    }

    var icon: String {
        switch self {
        case .landlord:        "key.fill"
        case .propertyManager: "person.2.fill"
        case .tenant:          "house.fill"
        }
    }

    var tint: Color {
        switch self {
        case .landlord:        .orange
        case .propertyManager: .blue
        case .tenant:          .green
        }
    }

    /// The account role sign-up creates.
    var role: AppRole {
        switch self {
        case .landlord:        .owner
        case .propertyManager: .propertyManager
        case .tenant:          .tenant
        }
    }

    /// Tenants skip the portfolio questions and the unlock summary —
    /// they have no portfolio, and their landlord invites them in.
    var asksPortfolioQuestions: Bool { self != .tenant }
}

// MARK: - Portfolio Size

enum OnboardingUnitRange: String, Codable, CaseIterable, Identifiable, Sendable {
    case one
    case twoToFive
    case sixToTwenty
    case twentyPlus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .one:         "1"
        case .twoToFive:   "2–5"
        case .sixToTwenty: "6–20"
        case .twentyPlus:  "20+"
        }
    }

    var subtitle: String {
        switch self {
        case .one:         "Just the one"
        case .twoToFive:   "A few doors"
        case .sixToTwenty: "A growing portfolio"
        case .twentyPlus:  "Serious scale"
        }
    }

    var icon: String {
        switch self {
        case .one:         "house.fill"
        case .twoToFive:   "house.and.flag.fill"
        case .sixToTwenty: "building.fill"
        case .twentyPlus:  "building.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .one:         .green
        case .twoToFive:   .blue
        case .sixToTwenty: .orange
        case .twentyPlus:  .red
        }
    }

    /// Purr's reaction once this is picked.
    var reaction: String {
        switch self {
        case .one:         "One home, done right. I'll keep it simple."
        case .twoToFive:   "A few doors to juggle. I'll keep them in one place."
        case .sixToTwenty: "Ooh, a real portfolio! I'll keep everything tidy."
        case .twentyPlus:  "Big leagues! I'll keep the whole lot on one screen."
        }
    }

    /// Workspace setup asks the same question. Answered once, here.
    var portfolioSize: PortfolioSizeOption {
        switch self {
        case .one, .twoToFive: .starter
        case .sixToTwenty:     .growing
        case .twentyPlus:      .established
        }
    }

    /// A sensible starting value for the first property's unit count.
    var suggestedUnitsPerProperty: Int {
        switch self {
        case .one, .twoToFive: 1
        case .sixToTwenty:     4
        case .twentyPlus:      8
        }
    }
}

// MARK: - Headaches

enum OnboardingHeadache: String, Codable, CaseIterable, Identifiable, Sendable {
    case lateRent
    case repairs
    case tenantMessages
    case paperwork
    case findingTenants

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lateRent:       "Late rent"
        case .repairs:        "Repairs"
        case .tenantMessages: "Tenant messages"
        case .paperwork:      "Paperwork"
        case .findingTenants: "Empty units"
        }
    }

    var icon: String {
        switch self {
        case .lateRent:       "dollarsign.circle.fill"
        case .repairs:        "wrench.and.screwdriver.fill"
        case .tenantMessages: "bubble.left.and.bubble.right.fill"
        case .paperwork:      "doc.text.fill"
        case .findingTenants: "door.left.hand.open"
        }
    }

    var tint: Color {
        switch self {
        case .lateRent:       .green
        case .repairs:        .red
        case .tenantMessages: .blue
        case .paperwork:      .orange
        case .findingTenants: .purple
        }
    }

    /// What the answer switches on. Shown on the "unlocked" screen.
    var unlock: OnboardingUnlock {
        switch self {
        case .lateRent:
            OnboardingUnlock(
                icon: "bell.badge.fill", tint: .green,
                title: "Payment alerts are on",
                detail: "You'll hear when rent lands, and when it's late."
            )
        case .repairs:
            OnboardingUnlock(
                icon: "wrench.and.screwdriver.fill", tint: .red,
                title: "Repairs, sorted by urgency",
                detail: "One inbox with priorities, vendors and photos."
            )
        case .tenantMessages:
            OnboardingUnlock(
                icon: "bubble.left.and.bubble.right.fill", tint: .blue,
                title: "Every tenant chat in one place",
                detail: "Real-time messages, with alerts switched on."
            )
        case .paperwork:
            OnboardingUnlock(
                icon: "doc.text.fill", tint: .orange,
                title: "A home for every document",
                detail: "Leases, receipts and notices, filed by property."
            )
        case .findingTenants:
            OnboardingUnlock(
                icon: "door.left.hand.open", tint: .purple,
                title: "Vacancies at a glance",
                detail: "Occupancy for every unit, and trends over time."
            )
        }
    }
}

// MARK: - Goal

enum OnboardingGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case saveTime
    case getPaidOnTime
    case fewerVacancies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveTime:       "Win back my time"
        case .getPaidOnTime:  "Get paid on time"
        case .fewerVacancies: "Keep units full"
        }
    }

    var subtitle: String {
        switch self {
        case .saveTime:       "Less admin, more life"
        case .getPaidOnTime:  "No more chasing rent"
        case .fewerVacancies: "Fewer empty months"
        }
    }

    var icon: String {
        switch self {
        case .saveTime:       "clock.fill"
        case .getPaidOnTime:  "creditcard.fill"
        case .fewerVacancies: "chart.line.uptrend.xyaxis"
        }
    }

    var tint: Color {
        switch self {
        case .saveTime:       .blue
        case .getPaidOnTime:  .green
        case .fewerVacancies: .red
        }
    }

    /// The outcome the paywall and the unlock screen lead with.
    var outcome: String {
        switch self {
        case .saveTime:       "Spend minutes, not evenings, on your rentals"
        case .getPaidOnTime:  "See who's paid and who hasn't, the moment it happens"
        case .fewerVacancies: "Spot empty units early and keep them full"
        }
    }

    var unlock: OnboardingUnlock {
        switch self {
        case .saveTime:
            OnboardingUnlock(
                icon: "sparkles", tint: .blue,
                title: "Purr's brief on Home",
                detail: "What needs you today, in one glance."
            )
        case .getPaidOnTime:
            OnboardingUnlock(
                icon: "creditcard.fill", tint: .green,
                title: "Rent collected, live",
                detail: "This month's collection on your Home screen."
            )
        case .fewerVacancies:
            OnboardingUnlock(
                icon: "chart.line.uptrend.xyaxis", tint: .red,
                title: "Occupancy trends",
                detail: "Per property, so a dip never sneaks up on you."
            )
        }
    }
}

// MARK: - Unlock

/// One line on the "Here's what you unlocked" screen.
struct OnboardingUnlock: Identifiable, Equatable {
    let icon: String
    /// System colour for the icon tile (white symbol on it).
    let tint: Color
    let title: String
    let detail: String

    var id: String { title }

    init(icon: String, tint: Color, title: String, detail: String) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.detail = detail
    }
}

// MARK: - Profile

struct OnboardingProfile: Codable, Equatable, Sendable {
    var persona: OnboardingPersona?
    var unitRange: OnboardingUnitRange?
    var headaches: Set<OnboardingHeadache> = []
    var goal: OnboardingGoal?

    /// Everything the answers switched on, in the order they're shown:
    /// portfolio first, then each headache, then the goal.
    var unlocks: [OnboardingUnlock] {
        var result: [OnboardingUnlock] = []
        if let unitRange {
            result.append(OnboardingUnlock(
                icon: "square.grid.2x2.fill", tint: .purple,
                title: "Your portfolio dashboard",
                detail: "Set up for \(unitRange.title) \(unitRange == .one ? "unit" : "units")."
            ))
        }
        result += OnboardingHeadache.allCases
            .filter(headaches.contains)
            .map(\.unlock)
        if let goal, !result.contains(goal.unlock) {
            result.append(goal.unlock)
        }
        return result
    }
}

// MARK: - Store

/// Device-local onboarding state. Survives sign-out, like the
/// onboarding-completed flag, because signing out isn't a fresh install.
@MainActor
final class OnboardingProfileStore {

    private enum Key {
        static let profile = "onboarding.profile.v1"
        static let pendingActivation = "onboarding.pendingActivation.v1"
    }

    private let persistence: PersistenceServiceProtocol

    init(persistence: PersistenceServiceProtocol) {
        self.persistence = persistence
    }

    var profile: OnboardingProfile {
        get {
            persistence.data(forKey: Key.profile)
                .flatMap { try? JSONDecoder().decode(OnboardingProfile.self, from: $0) }
                ?? OnboardingProfile()
        }
        set {
            persistence.set(try? JSONEncoder().encode(newValue), forKey: Key.profile)
        }
    }

    /// The account that signed up on this device and hasn't finished
    /// "getting started" (first property, notifications, plan) yet.
    /// Keyed by user so another account signing in here never inherits it.
    var pendingActivationUserID: String? {
        get { persistence.data(forKey: Key.pendingActivation).flatMap { String(data: $0, encoding: .utf8) } }
        set { persistence.set(newValue?.data(using: .utf8), forKey: Key.pendingActivation) }
    }
}
