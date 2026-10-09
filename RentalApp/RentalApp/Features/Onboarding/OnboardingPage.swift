//
//  OnboardingPage.swift
//  RentalApp
//
//  Onboarding — Page model. Content only; layout and animation
//  live in the views.
//

import SwiftUI

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case intro
    case maintenance
    case portfolio
    case insights

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .intro: "Your entire portfolio,\none home"
        case .maintenance: "Maintenance that\nruns itself"
        case .portfolio: "Every property\nat a glance"
        case .insights: "Insights before\nyou ask"
        }
    }

    /// What the mascot says on this page — first person, friendly, short
    /// enough to type out in about a second.
    var mascotLine: String {
        switch self {
        case .intro:
            "Hi! I'm here to help you run your rentals — homes, tenants and repairs, all in one place."
        case .maintenance:
            "When something breaks, I'll sort the urgency, find the right vendor and draft the reply."
        case .portfolio:
            "Every unit, lease and vacancy — I keep an eye on all of it, live."
        case .insights:
            "And I'll spot trends before you ask. Ready? Let's go!"
        }
    }

    /// How the mascot feels on this page.
    var mascotMood: MascotMood {
        switch self {
        case .intro:       .happy
        case .maintenance: .thinking
        case .portfolio:   .happy
        case .insights:    .cheer
        }
    }

    var isLast: Bool { self == OnboardingPage.allCases.last }

    var next: OnboardingPage? {
        OnboardingPage(rawValue: rawValue + 1)
    }
}
