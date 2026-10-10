//
//  SettingsModels.swift
//  RentalApp (Purrperty)
//
//  Settings — Sections, store, and mock account data.
//  The Appearance theme here drives the whole app's color scheme.
//

import SwiftUI
import Observation

// MARK: - Sections

enum SettingsSection: String, CaseIterable, Identifiable, Hashable, Codable {
    case profile
    case organization
    case team
    case billing
    case notifications
    case appearance
    case aiPreferences
    case integrations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: "Profile"
        case .organization: "Organization"
        case .team: "Team"
        case .billing: "Billing"
        case .notifications: "Notifications"
        case .appearance: "Appearance"
        case .aiPreferences: "AI Preferences"
        case .integrations: "Integrations"
        }
    }

    var icon: String {
        switch self {
        case .profile: "person.fill"
        case .organization: "building.2.fill"
        case .team: DS.Icons.tenants
        case .billing: DS.Icons.payment
        case .notifications: DS.Icons.notifications
        case .appearance: "paintbrush.fill"
        case .aiPreferences: DS.Icons.ai
        case .integrations: "puzzlepiece.extension.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .profile: "Name, contact, password"
        case .organization: "Workspace identity"
        case .team: "Members & roles"
        case .billing: "Plan, usage, invoices"
        case .notifications: "Alerts & digests"
        case .appearance: "Theme & display"
        case .aiPreferences: "Copilot behavior"
        case .integrations: "Connected services"
        }
    }

    var accent: DSAccent {
        switch self {
        case .profile, .organization: .violet
        case .team:                   .sky
        case .billing:                .mint
        case .notifications:          .coral
        case .appearance:             .sunny
        case .aiPreferences:          .violet
        case .integrations:           .sky
        }
    }

    /// AA-safe foreground for the section's icon tile.
    var tint: Color { accent.ink }
}

// MARK: - Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - Team & Integrations

struct TeamMember: Identifiable {
    let id = UUID()
    let name: String
    let email: String
    let role: String
    let isOwner: Bool
    let status: String
    let statusKind: DSStatusKind
}

struct IntegrationItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let detail: String
    var isConnected: Bool
}

struct InvoiceItem: Identifiable {
    let id = UUID()
    let period: String
    let amount: String
    let status: String
}
