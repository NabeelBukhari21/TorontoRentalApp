//
//  MaintenanceModels.swift
//  RentalApp (Purrperty)
//
//  Maintenance — Models, mock data, and the shared observable store.
//  The store keeps inbox, kanban, and detail perfectly in sync;
//  a MaintenanceService will hydrate it later.
//

import SwiftUI
import Observation

// MARK: - Priority

enum TicketPriority: Int, Codable, CaseIterable, Identifiable, Comparable {
    case urgent = 0
    case high
    case medium
    case low

    var id: Int { rawValue }

    static func < (lhs: TicketPriority, rhs: TicketPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .urgent: "Urgent"
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }

    /// Each priority's colour. Coral → sunny → sky → mint reads as a heat
    /// scale from "now" to "whenever", without leaning on red alone.
    var accent: DSAccent {
        switch self {
        case .urgent: .coral
        case .high:   .sunny
        case .medium: .sky
        case .low:    .mint
        }
    }

    /// AA-safe foreground for this priority (text, icons, stripes).
    var color: Color { accent.ink }

    var kind: DSStatusKind {
        switch self {
        case .urgent: .danger
        case .high: .warning
        case .medium: .info
        case .low: .neutral
        }
    }

    var icon: String {
        switch self {
        case .urgent: "exclamationmark.octagon.fill"
        case .high: "exclamationmark.triangle.fill"
        case .medium: "minus.circle.fill"
        case .low: "arrow.down.circle.fill"
        }
    }
}

// MARK: - Status

enum TicketStatus: Int, Codable, CaseIterable, Identifiable {
    case new = 0
    case inProgress
    case scheduled
    case done

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .new: "New"
        case .inProgress: "In Progress"
        case .scheduled: "Scheduled"
        case .done: "Done"
        }
    }

    var kind: DSStatusKind {
        switch self {
        case .new: .info
        case .inProgress: .warning
        case .scheduled: .neutral
        case .done: .success
        }
    }

    var icon: String {
        switch self {
        case .new: "tray.fill"
        case .inProgress: "wrench.fill"
        case .scheduled: "calendar"
        case .done: "checkmark.seal.fill"
        }
    }
}

// MARK: - Category

enum TicketCategory: String, CaseIterable {
    case plumbing = "Plumbing"
    case electrical = "Electrical"
    case hvac = "HVAC"
    case appliance = "Appliance"
    case general = "General"

    /// Each trade gets its own colour, so a list of requests can be scanned
    /// by kind at a glance.
    var accent: DSAccent {
        switch self {
        case .plumbing:   .sky
        case .electrical: .sunny
        case .hvac:       .mint
        case .appliance:  .coral
        case .general:    .violet
        }
    }

    var icon: String {
        switch self {
        case .plumbing: "drop.fill"
        case .electrical: "bolt.fill"
        case .hvac: "wind"
        case .appliance: "refrigerator.fill"
        case .general: "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Vendor

struct Vendor: Identifiable, Hashable {
    let id: String
    let name: String
    let company: String
    let specialty: TicketCategory
    let rating: Double
    let completedJobs: Int
    let responseTime: String
}

// MARK: - Comments & AI

struct TicketComment: Identifiable {
    let id = UUID()
    let author: String
    let isManager: Bool
    let text: String
    let time: String
}

struct TicketAIAnalysis {
    /// 0...1 — AI-estimated urgency.
    let urgencyScore: Double
    let categoryConfidence: Double
    let summary: String
    let suggestedActions: [String]
    let draftReply: String
    let suggestedVendorID: String
}

// MARK: - Ticket

struct MaintenanceTicket: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let propertyName: String
    let unitName: String
    let tenantName: String
    let priority: TicketPriority
    var status: TicketStatus
    let category: TicketCategory
    let createdAgo: String
    let photoCount: Int
    let paletteIndex: Int
    let ai: TicketAIAnalysis
    var vendor: Vendor?
    var comments: [TicketComment]
    var replySent = false
}

// MARK: - Mock Data

enum MaintenanceMockData {

    static let vendors: [Vendor] = [
        Vendor(id: "rapid-plumbing", name: "Mike Torres", company: "Rapid Plumbing Co.",
               specialty: .plumbing, rating: 4.9, completedJobs: 214, responseTime: "~2h"),
        Vendor(id: "volt-electric", name: "Dana Wells", company: "Volt Electric",
               specialty: .electrical, rating: 4.8, completedJobs: 167, responseTime: "~4h"),
        Vendor(id: "north-hvac", name: "Sam Osei", company: "NorthAir HVAC",
               specialty: .hvac, rating: 4.7, completedJobs: 143, responseTime: "~6h"),
        Vendor(id: "fixit-appliance", name: "Lena Kowalski", company: "FixIt Appliance",
               specialty: .appliance, rating: 4.8, completedJobs: 189, responseTime: "~5h"),
        Vendor(id: "handy-general", name: "Omar Haddad", company: "Handy General Services",
               specialty: .general, rating: 4.6, completedJobs: 302, responseTime: "~1d")
    ]

    static let tickets: [MaintenanceTicket] = [
        MaintenanceTicket(
            id: "t-leak-304",
            title: "Water leak under kitchen sink",
            description: "Water is pooling under the sink and the cabinet floor is soaked. Tenant has placed a bucket but it's filling every few hours.",
            propertyName: "Maple Duplex", unitName: "Unit 304", tenantName: "Sarah Chen",
            priority: .urgent, status: .new, category: .plumbing,
            createdAgo: "26m ago", photoCount: 3, paletteIndex: 1,
            ai: TicketAIAnalysis(
                urgencyScore: 0.93, categoryConfidence: 0.97,
                summary: "Active water leak with pooling — risk of cabinet and subfloor damage within 24–48h. Shut-off valve accessible under sink.",
                suggestedActions: [
                    "Ask tenant to close the under-sink shut-off valve",
                    "Dispatch plumber within 4 hours",
                    "Photograph cabinet base for insurance records"
                ],
                draftReply: "Hi Sarah — thanks for the photos. Please turn the small valve under the sink clockwise to stop the flow. A plumber will be there today; I'll confirm the exact time within the hour.",
                suggestedVendorID: "rapid-plumbing"
            ),
            vendor: nil,
            comments: [
                TicketComment(author: "Sarah Chen", isManager: false,
                              text: "It's getting worse — the bucket filled twice since this morning.", time: "18m ago")
            ]
        ),
        MaintenanceTicket(
            id: "t-heat-201",
            title: "No heat in living room",
            description: "Baseboard heater in the living room isn't warming up. Rest of the unit is fine.",
            propertyName: "Annex Victorian", unitName: "Unit 2", tenantName: "Amara Diallo",
            priority: .high, status: .new, category: .hvac,
            createdAgo: "3h ago", photoCount: 1, paletteIndex: 3,
            ai: TicketAIAnalysis(
                urgencyScore: 0.71, categoryConfidence: 0.88,
                summary: "Single-zone heating failure. Not an emergency in July, but the unit has a history of thermostat faults.",
                suggestedActions: [
                    "Ask tenant to check the breaker panel",
                    "Book HVAC tech this week",
                    "Review unit's thermostat service history"
                ],
                draftReply: "Hi Amara — sorry about that! Could you check if the breaker labeled 'LR heat' has tripped? Either way we'll have a technician out this week.",
                suggestedVendorID: "north-hvac"
            ),
            vendor: nil,
            comments: []
        ),
        MaintenanceTicket(
            id: "t-dish-102",
            title: "Dishwasher not draining",
            description: "Standing water after every cycle. Tenant has tried the filter — no change.",
            propertyName: "Queen West Lofts", unitName: "Unit 102", tenantName: "Marcus Johnson",
            priority: .medium, status: .inProgress, category: .appliance,
            createdAgo: "2d ago", photoCount: 2, paletteIndex: 0,
            ai: TicketAIAnalysis(
                urgencyScore: 0.45, categoryConfidence: 0.94,
                summary: "Likely drain pump or air-gap blockage. Same model failed identically in Unit 305 in March — pump replacement resolved it.",
                suggestedActions: [
                    "Reuse March repair notes from Unit 305",
                    "Order drain pump (part DW-4512) in advance",
                    "Schedule 1-hour appliance visit"
                ],
                draftReply: "Hi Marcus — thanks for trying the filter. We've seen this before with these units; a tech is booked and we expect a quick fix.",
                suggestedVendorID: "fixit-appliance"
            ),
            vendor: vendors[3],
            comments: [
                TicketComment(author: "You", isManager: true,
                              text: "Part ordered — Lena confirmed Thursday morning.", time: "1d ago"),
                TicketComment(author: "Marcus Johnson", isManager: false,
                              text: "Thursday works, I'll be home all morning.", time: "22h ago")
            ]
        ),
        MaintenanceTicket(
            id: "t-light-hall",
            title: "Hallway light flickering",
            description: "Second-floor hallway fixture flickers intermittently. Bulb replaced already.",
            propertyName: "Liberty Village Flats", unitName: "Floor 2 Hall", tenantName: "Common Area",
            priority: .medium, status: .scheduled, category: .electrical,
            createdAgo: "3d ago", photoCount: 0, paletteIndex: 5,
            ai: TicketAIAnalysis(
                urgencyScore: 0.38, categoryConfidence: 0.9,
                summary: "Intermittent flicker after bulb swap points to a loose neutral or failing ballast. Low risk, common-area priority.",
                suggestedActions: [
                    "Bundle with other electrical work at this property",
                    "Schedule during daytime — no unit access needed"
                ],
                draftReply: "Thanks for the report — an electrician is scheduled for Friday morning. No access to any unit is needed.",
                suggestedVendorID: "volt-electric"
            ),
            vendor: vendors[1],
            comments: []
        ),
        MaintenanceTicket(
            id: "t-door-407",
            title: "Balcony door seal replacement",
            description: "Draft coming through the balcony door seal; tenant reports whistling on windy days.",
            propertyName: "Liberty Village Flats", unitName: "Unit 407", tenantName: "Liam O'Connor",
            priority: .low, status: .inProgress, category: .general,
            createdAgo: "5d ago", photoCount: 2, paletteIndex: 2,
            ai: TicketAIAnalysis(
                urgencyScore: 0.22, categoryConfidence: 0.85,
                summary: "Cosmetic/comfort issue. Seal kit is a standard part; 45-minute job.",
                suggestedActions: [
                    "Order seal kit for 82\" sliding door",
                    "Combine with Unit 212 window latch fix"
                ],
                draftReply: "Hi Liam — the replacement seal is on order. We'll knock this out along with another small job on your floor.",
                suggestedVendorID: "handy-general"
            ),
            vendor: vendors[4],
            comments: []
        ),
        MaintenanceTicket(
            id: "t-outlet-2204",
            title: "Bedroom outlet not working",
            description: "One outlet in the primary bedroom stopped working. No breaker trip visible.",
            propertyName: "Harbourfront Suite 2204", unitName: "Suite 2204", tenantName: "Isabella Rossi",
            priority: .high, status: .scheduled, category: .electrical,
            createdAgo: "1d ago", photoCount: 1, paletteIndex: 3,
            ai: TicketAIAnalysis(
                urgencyScore: 0.66, categoryConfidence: 0.92,
                summary: "Dead receptacle with no visible trip — possible GFCI upstream or backstab failure. Premium unit; prioritize fast turnaround.",
                suggestedActions: [
                    "Ask tenant to test/reset bathroom GFCI",
                    "Dispatch electrician within 48h"
                ],
                draftReply: "Hi Isabella — quick thing to try: press 'reset' on the bathroom outlet, it sometimes controls the bedroom circuit. An electrician is booked for tomorrow regardless.",
                suggestedVendorID: "volt-electric"
            ),
            vendor: vendors[1],
            comments: []
        ),
        MaintenanceTicket(
            id: "t-faucet-annex",
            title: "Kitchen faucet dripping",
            description: "Slow but constant drip from the kitchen faucet, worse on hot water.",
            propertyName: "Annex Victorian", unitName: "Unit 3", tenantName: "Vacant",
            priority: .low, status: .done, category: .plumbing,
            createdAgo: "1w ago", photoCount: 1, paletteIndex: 4,
            ai: TicketAIAnalysis(
                urgencyScore: 0.18, categoryConfidence: 0.96,
                summary: "Worn cartridge — resolved with standard replacement during vacancy turnover.",
                suggestedActions: ["Completed during turnover"],
                draftReply: "Resolved.",
                suggestedVendorID: "rapid-plumbing"
            ),
            vendor: vendors[0],
            comments: []
        ),
        MaintenanceTicket(
            id: "t-fan-danforth",
            title: "Bathroom fan noise",
            description: "Grinding noise from the bathroom exhaust fan.",
            propertyName: "Danforth Triplex", unitName: "Unit 201", tenantName: "Priya Patel",
            priority: .medium, status: .done, category: .general,
            createdAgo: "2w ago", photoCount: 0, paletteIndex: 2,
            ai: TicketAIAnalysis(
                urgencyScore: 0.3, categoryConfidence: 0.82,
                summary: "Bearing wear — fan motor replaced.",
                suggestedActions: ["Completed"],
                draftReply: "Resolved.",
                suggestedVendorID: "handy-general"
            ),
            vendor: vendors[4],
            comments: []
        ),
        MaintenanceTicket(
            id: "t-fridge-118",
            title: "Fridge making clicking sound",
            description: "Repetitive clicking every few minutes; cooling still OK.",
            propertyName: "Liberty Village Flats", unitName: "Unit 118", tenantName: "Jack Thompson",
            priority: .low, status: .new, category: .appliance,
            createdAgo: "6h ago", photoCount: 1, paletteIndex: 0,
            ai: TicketAIAnalysis(
                urgencyScore: 0.28, categoryConfidence: 0.79,
                summary: "Clicking with normal cooling usually indicates a failing start relay — inexpensive if addressed before compressor strain.",
                suggestedActions: [
                    "Order universal start relay",
                    "Book 30-min appliance check next week"
                ],
                draftReply: "Hi Jack — thanks for flagging early. It's likely a small relay part; we'll swap it next week before it becomes a real problem.",
                suggestedVendorID: "fixit-appliance"
            ),
            vendor: nil,
            comments: []
        )
    ]

    // MARK: Timeline

    static func timeline(for ticket: MaintenanceTicket) -> [TenantEvent] {
        var events: [TenantEvent] = [
            TenantEvent(
                icon: "tray.fill", kind: .info,
                title: "Request received",
                detail: "Reported by \(ticket.tenantName) · \(ticket.unitName)",
                date: ticket.createdAgo
            ),
            TenantEvent(
                icon: DS.Icons.ai, kind: .warning,
                title: "AI triage complete",
                detail: "Classified \(ticket.category.rawValue) · \(ticket.priority.title) priority in 0.4s",
                date: ticket.createdAgo
            )
        ]

        if let vendor = ticket.vendor {
            events.append(
                TenantEvent(
                    icon: "person.badge.shield.checkmark.fill", kind: .neutral,
                    title: "Vendor assigned",
                    detail: "\(vendor.name) · \(vendor.company)",
                    date: "—"
                )
            )
        }

        if ticket.status == .scheduled {
            events.append(
                TenantEvent(
                    icon: "calendar", kind: .neutral,
                    title: "Visit scheduled",
                    detail: "Tenant confirmed access window",
                    date: "—"
                )
            )
        }

        if ticket.status == .done {
            events.append(
                TenantEvent(
                    icon: "checkmark.seal.fill", kind: .success,
                    title: "Resolved",
                    detail: "Work completed and verified",
                    date: "—"
                )
            )
        }

        return events.reversed()
    }
}
