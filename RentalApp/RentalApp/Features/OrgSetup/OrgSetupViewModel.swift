//
//  OrgSetupViewModel.swift
//  RentalApp
//
//  Org Setup — View model for the organization onboarding wizard.
//  Owns step progression and all collected answers, and submits the
//  finished draft through `OrganizationServiceProtocol`.
//
//  The wizard doesn't bind the new workspace to the session itself —
//  it reports the created organization upward and the session
//  coordinator decides what that means. Same separation as the auth
//  screens.
//

import SwiftUI
import Observation

// MARK: - Steps

enum OrgSetupStep: Int, CaseIterable {
    case name
    case logo
    case propertyType
    case portfolioSize
    case inviteTeam

    var title: String {
        switch self {
        case .name: "Name your organization"
        case .logo: "Add your logo"
        case .propertyType: "What do you manage?"
        case .portfolioSize: "How many properties?"
        case .inviteTeam: "Invite your team"
        }
    }

    var subtitle: String {
        switch self {
        case .name: "This is how your workspace will appear to tenants and teammates."
        case .logo: "Upload a logo, or pick a look for your monogram — you can change it anytime."
        case .propertyType: "We'll tailor your dashboard to your portfolio."
        case .portfolioSize: "Helps us set up the right views for your scale."
        case .inviteTeam: "Property managers and coordinators can join you — or skip for now."
        }
    }
}

// MARK: - Options

enum PropertyTypeOption: String, CaseIterable, Identifiable {
    case condos
    case houses
    case multiUnit
    case commercial
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .condos: "Condos"
        case .houses: "Houses"
        case .multiUnit: "Multi-unit buildings"
        case .commercial: "Commercial"
        case .mixed: "Mixed portfolio"
        }
    }

    var subtitle: String {
        switch self {
        case .condos: "Condo units & townhomes"
        case .houses: "Single-family rentals"
        case .multiUnit: "Duplexes to apartment blocks"
        case .commercial: "Retail, office & industrial"
        case .mixed: "A bit of everything"
        }
    }

    var icon: String {
        switch self {
        case .condos: "building.fill"
        case .houses: "house.fill"
        case .multiUnit: DS.Icons.properties
        case .commercial: "storefront.fill"
        case .mixed: "square.grid.2x2.fill"
        }
    }
}

enum PortfolioSizeOption: String, CaseIterable, Identifiable {
    case starter
    case growing
    case established
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starter: "1–5"
        case .growing: "6–20"
        case .established: "21–50"
        case .large: "50+"
        }
    }

    var subtitle: String {
        switch self {
        case .starter: "Just getting started"
        case .growing: "Growing portfolio"
        case .established: "Established operator"
        case .large: "Large scale"
        }
    }

    var icon: String {
        switch self {
        case .starter: "leaf.fill"
        case .growing: "chart.line.uptrend.xyaxis"
        case .established: "building.2.fill"
        case .large: "globe.americas.fill"
        }
    }
}

// MARK: - View Model

@MainActor
@Observable
final class OrgSetupViewModel {

    // MARK: Flow State

    var step: OrgSetupStep = .name
    var movesForward = true
    var isComplete = false

    /// True while the draft is being submitted, so the continue button
    /// shows its spinner instead of jumping straight to the confetti.
    private(set) var isSubmitting = false
    private(set) var submissionError: String?

    /// The organization created on the final step.
    private(set) var createdOrganizationID: String?

    // MARK: Dependencies

    private let service: OrganizationServiceProtocol

    init(service: OrganizationServiceProtocol) {
        self.service = service
    }

    // MARK: Answers

    var orgName = ""
    var logoImage: UIImage?
    var logoGradientIndex = 0
    var propertyType: PropertyTypeOption?
    var portfolioSize: PortfolioSizeOption?
    var inviteEmails: [String] = []
    var inviteInput = ""
    var inviteError: String?

    /// Gradient choices for the generated monogram — luxury materials.
    static let monogramGradients: [[Color]] = [
        [Color(hex: 0xD4AF37), Color(hex: 0x8C6D1F)], // champagne gold
        [Color(hex: 0x43474F), RentOSBrand.obsidian], // obsidian
        [Color(hex: 0xC7CDD6), Color(hex: 0x6E7681)], // platinum
        [Color(hex: 0xFFB703), Color(hex: 0xB45309)], // saffron bronze
        [Color(hex: 0x1F6E5A), Color(hex: 0x0B3B30)]  // deep emerald
    ]

    var monogramGradient: LinearGradient {
        let colors = Self.monogramGradients[
            min(logoGradientIndex, Self.monogramGradients.count - 1)
        ]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Up to two initials from the organization name.
    var monogram: String {
        let parts = orgName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "R" : letters.joined().uppercased()
    }

    // MARK: Progress

    var progress: Double {
        Double(step.rawValue + 1) / Double(OrgSetupStep.allCases.count)
    }

    var canContinue: Bool {
        switch step {
        case .name:
            orgName.trimmingCharacters(in: .whitespaces).count >= 2
        case .logo, .inviteTeam:
            true // optional steps
        case .propertyType:
            propertyType != nil
        case .portfolioSize:
            portfolioSize != nil
        }
    }

    var continueTitle: String {
        switch step {
        case .logo where logoImage == nil:
            "Use Monogram"
        case .inviteTeam where inviteEmails.isEmpty:
            "Skip for Now"
        case .inviteTeam:
            "Finish Setup"
        default:
            "Continue"
        }
    }

    // MARK: Navigation

    /// Moves to the next step, or submits when there isn't one.
    func advance() async {
        if let next = OrgSetupStep(rawValue: step.rawValue + 1) {
            movesForward = true
            withAnimation(DS.Motion.smooth) { step = next }
        } else {
            await submit()
        }
    }

    /// Sends the draft to the organization service. Only the celebration
    /// is gated on success — a failure keeps the user on the last step
    /// with a retryable message rather than dropping them into an app
    /// with no workspace.
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        submissionError = nil
        defer { isSubmitting = false }

        let draft = OrganizationDraft(
            name: orgName.trimmingCharacters(in: .whitespaces),
            propertyTypeID: propertyType?.rawValue,
            portfolioSizeID: portfolioSize?.rawValue,
            inviteEmails: inviteEmails
        )

        do {
            try await service.createOrganization(draft)
            createdOrganizationID = "org_\(UUID().uuidString.prefix(8).lowercased())"
            withAnimation(DS.Motion.smooth) { isComplete = true }
        } catch {
            submissionError = (error as? AppError)?.errorDescription
                ?? AppError.unknown.errorDescription
        }
    }

    func goBack() {
        guard let previous = OrgSetupStep(rawValue: step.rawValue - 1) else { return }
        movesForward = false
        withAnimation(DS.Motion.smooth) { step = previous }
    }

    // MARK: Invites

    func addInvite() {
        let email = inviteInput.trimmingCharacters(in: .whitespaces).lowercased()

        guard email.range(
            of: #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#,
            options: .regularExpression
        ) != nil else {
            inviteError = "Enter a valid email address"
            return
        }

        guard !inviteEmails.contains(email) else {
            inviteError = "Already added"
            return
        }

        withAnimation(DS.Motion.bouncy) {
            inviteEmails.append(email)
            inviteInput = ""
            inviteError = nil
        }
    }

    func removeInvite(_ email: String) {
        withAnimation(DS.Motion.snappy) {
            inviteEmails.removeAll { $0 == email }
        }
    }
}
