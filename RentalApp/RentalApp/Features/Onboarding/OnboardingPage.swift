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

    var subtitle: String {
        switch self {
        case .intro:
            "Properties, tenants, maintenance, and messages — beautifully organized in one place."
        case .maintenance:
            "AI reads every request, sets urgency, picks the right vendor, and drafts the tenant reply."
        case .portfolio:
            "Track units, occupancy, and leases across your whole portfolio in real time."
        case .insights:
            "Live analytics and AI recommendations keep your portfolio healthy and profitable."
        }
    }

    var isLast: Bool { self == OnboardingPage.allCases.last }

    var next: OnboardingPage? {
        OnboardingPage(rawValue: rawValue + 1)
    }
}
