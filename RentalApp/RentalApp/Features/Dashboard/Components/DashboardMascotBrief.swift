//
//  DashboardMascotBrief.swift
//  RentalApp
//
//  Dashboard — The mascot's daily brief at the top of Home.
//
//  One sentence about the thing that matters most right now, with Purr
//  acting it out, in priority order:
//
//    urgent tasks      → urgentIssue    ("needs you today")
//    requests open     → inspection     ("keeping an eye on them")
//    tasks lined up    → tasksWaiting   ("you've got this")
//    nothing rented    → firstVisit / vacancy
//    100% occupied     → victoryLap
//    nothing pending   → a greeting for the time of day, or the weekend
//
//  Tap Purr for a tip — and a surprise signature move. Tips only describe
//  features that exist today: a mascot that recommends things the app
//  can't do burns trust fast.
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
            mood: tipIndex == 0 ? brief.mood : .dailyTip,
            message: tipIndex == 0 ? brief.message : Self.tips[(tipIndex - 1) % Self.tips.count],
            mascotSize: 112,
            surprisesOnTap: true,
            onTapMascot: { tipIndex += 1 }
        )
        .accessibilityHint("Tap Purr for a tip")
    }

    // MARK: Brief

    private var brief: (mood: PurrMood, message: String) {
        if urgentTasks > 0 {
            return (.urgentIssue, "\(urgentTasks) urgent \(plural("task", urgentTasks)) \(urgentTasks == 1 ? "needs" : "need") you today. Let's knock \(urgentTasks == 1 ? "it" : "them") out first!")
        }
        if openRequests > 0 {
            return (.inspection, "\(openRequests) maintenance \(plural("request", openRequests)) open. I'm keeping an eye on \(openRequests == 1 ? "it" : "them").")
        }
        if openTasks > 0 {
            return (.tasksWaiting, "You've got \(openTasks) \(plural("task", openTasks)) lined up today. You've got this!")
        }
        if unitCount == 0 {
            return (.firstVisit, "Add your first property with the + button and I'll keep track of it from here.")
        }
        let percent = occupancyRate > 1 ? occupancyRate : occupancyRate * 100
        if percent == 0 {
            return (.vacancy, "No units rented yet. Add a tenant when you lease one and rent tracking starts.")
        }
        if percent >= 100 {
            return (.victoryLap, "Every unit is rented. Victory lap!")
        }
        return (Self.greeting(), "Everything's running smoothly — occupancy is at \(Int(percent.rounded()))%. Nice work!")
    }

    /// Purr's greeting when nothing needs attention: the weekend, or the
    /// time of day.
    private static func greeting(at date: Date = .now, calendar: Calendar = .current) -> PurrMood {
        if calendar.isDateInWeekend(date) { return .weekend }
        switch calendar.component(.hour, from: date) {
        case 5..<12: return .goodMorning
        case 12..<17: return .goodAfternoon
        case 17..<22: return .goodEvening
        default: return .lateNight
        }
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
