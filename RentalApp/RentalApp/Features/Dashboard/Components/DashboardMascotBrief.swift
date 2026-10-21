//
//  DashboardMascotBrief.swift
//  RentalApp
//
//  Dashboard — The mascot's daily brief at the top of Home.
//
//  One sentence about the thing that matters most right now, with a mood
//  to match, in priority order:
//
//    urgent tasks      → concerned   ("needs you today")
//    requests open     → thinking    ("keeping an eye on them")
//    tasks lined up    → happy       ("you've got this")
//    nothing rented    → happy       ("let's get started")
//    nothing pending   → cool        ("running smoothly")
//
//  Tap the cat for a tip. Tips only describe features that exist today —
//  a mascot that recommends things the app can't do burns trust fast.
//

import SwiftUI

struct DashboardMascotBrief: View {

    let urgentTasks: Int
    let openRequests: Int
    let openTasks: Int
    /// Occupancy as a fraction (0…1). Values above 1 are read as percent.
    let occupancyRate: Double
    /// Units in the portfolio. Zero means a brand-new account.
    var unitCount: Int = 1

    @State private var tipIndex = 0

    private static let tips: [String] = [
        "Tip: you can search everything — properties, tenants, leases and more — from one search bar.",
        "Tip: pull down on any list to refresh it.",
        "Tip: no signal? Keep working — your changes sync as soon as you're back online."
    ]

    var body: some View {
        MascotGuide(
            mood: tipIndex == 0 ? brief.mood : .happy,
            message: tipIndex == 0 ? brief.message : Self.tips[(tipIndex - 1) % Self.tips.count],
            mascotSize: 100,
            onTapMascot: { tipIndex += 1 }
        )
        .accessibilityHint("Tap Purr for a tip")
    }

    // MARK: Brief

    private var brief: (mood: MascotMood, message: String) {
        if urgentTasks > 0 {
            return (.concerned, "\(urgentTasks) urgent \(plural("task", urgentTasks)) \(urgentTasks == 1 ? "needs" : "need") you today. Let's knock \(urgentTasks == 1 ? "it" : "them") out first!")
        }
        if openRequests > 0 {
            return (.thinking, "\(openRequests) maintenance \(plural("request", openRequests)) open. I'm keeping an eye on \(openRequests == 1 ? "it" : "them").")
        }
        if openTasks > 0 {
            return (.happy, "You've got \(openTasks) \(plural("task", openTasks)) lined up today. You've got this!")
        }
        if unitCount == 0 {
            return (.happy, "Add your first property with the + button and I'll keep track of it from here.")
        }
        let percent = occupancyRate > 1 ? occupancyRate : occupancyRate * 100
        if percent == 0 {
            return (.happy, "No units rented yet. Add a tenant when you lease one and rent tracking starts.")
        }
        return (.cool, "Everything's running smoothly — occupancy is at \(Int(percent.rounded()))%. Nice work!")
    }

    private func plural(_ word: String, _ count: Int) -> String {
        count == 1 ? word : word + "s"
    }
}

#Preview("Briefs") {
    ScrollView {
        VStack(spacing: DS.Spacing.xxl) {
            DashboardMascotBrief(urgentTasks: 2, openRequests: 4, openTasks: 5, occupancyRate: 0.94)
            DashboardMascotBrief(urgentTasks: 0, openRequests: 3, openTasks: 2, occupancyRate: 0.94)
            DashboardMascotBrief(urgentTasks: 0, openRequests: 0, openTasks: 0, occupancyRate: 0.97)
        }
        .padding()
    }
    .background(DS.Colors.background)
}
