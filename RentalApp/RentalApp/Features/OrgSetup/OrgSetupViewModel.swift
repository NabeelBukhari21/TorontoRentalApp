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
    case inviteTeam

    var title: String {
        switch self {
        case .name: "Hang your sign"
        case .logo: "Add your logo"
        case .propertyType: "What do you manage?"
        case .inviteTeam: "Invite your team"
        }
    }

    var subtitle: String {
        switch self {
        case .name: "The name your tenants and team will see."
        case .logo: "Upload one, or keep the letters from your sign."
        case .propertyType: "We'll tailor your dashboard to your portfolio."
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

// MARK: - Recap

/// A workspace that has just been set up.
struct WorkspaceRecap {
    let name: String
    let monogram: String
    let colorIndex: Int
    let logo: UIImage?
    /// "Condos", "6–20 units".
    let details: [String]
    let invites: [String]
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
    private let ownerName: String
    let units: OnboardingUnitRange?
    private let journey: SetupJourney

    /// `units` is the quiz's answer; it isn't asked again here.
    init(service: OrganizationServiceProtocol, units: OnboardingUnitRange? = nil, journey: SetupJourney = .withoutQuestions, ownerName: String = "") {
        self.units = units
        self.journey = journey
        self.ownerName = ownerName
        self.service = service
    }

    // MARK: Answers

    var orgName = ""

    static let maxNameLength = 40

    /// Only while what's typed can't be used.
    var nameError: String? {
        let name = orgName.trimmingCharacters(in: .whitespaces)
        if name.count == 1 { return "One more letter, at least." }
        if name.count > Self.maxNameLength { return "Keep it to \(Self.maxNameLength) letters so it fits." }
        return nil
    }

    /// Ideas from the account's own name.
    var nameSuggestions: [String] {
        let words = ownerName.split(separator: " ").map(String.init)
        guard let first = words.first, let last = words.last else {
            return ["Maple Rentals", "Northside Homes", "Lakeview Living"]
        }
        let possessive = first.hasSuffix("s") ? "\(first)’" : "\(first)’s"
        return ["\(last) Rentals", "\(possessive) Homes", "\(last) Property Co.", "\(last) & Co. Living"]
    }
    var logoImage: UIImage?
    var logoGradientIndex = 0
    var propertyType: PropertyTypeOption?
    var inviteEmails: [String] = []
    var inviteInput = ""
    var inviteError: String?

    /// Gradient choices for the generated monogram. Defined in the design
    /// system (`DS.Gradients.monogramStops`), where the index contract and
    /// the contrast of the white letters are documented.
    static let monogramGradients: [[Color]] = DS.Gradients.monogramStops

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
        return letters.isEmpty ? "P" : letters.joined().uppercased()
    }

    // MARK: Progress

    var progress: Double {
        journey.progress(journey.workspaceStep(isComplete ? OrgSetupStep.allCases.count : step.rawValue))
    }

    var progressLabel: String { journey.label(journey.workspaceStep(step.rawValue)) }

    private var hasUnaddedInvite: Bool { !inviteInput.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The finished workspace, for the screen that shows it off.
    var recap: WorkspaceRecap {
        WorkspaceRecap(
            name: orgName.trimmingCharacters(in: .whitespaces), monogram: monogram, colorIndex: logoGradientIndex,
            logo: logoImage, details: [propertyType?.title, units?.unitsLabel].compactMap { $0 }, invites: inviteEmails
        )
    }

    var canContinue: Bool {
        switch step {
        case .name:
            (2...Self.maxNameLength).contains(orgName.trimmingCharacters(in: .whitespaces).count)
        case .logo, .inviteTeam:
            true // optional steps
        case .propertyType:
            propertyType != nil
        }
    }

    var continueTitle: String {
        switch step {
        case .logo where logoImage == nil:
            "Keep my letters"
        case .inviteTeam where hasUnaddedInvite:
            "Add and finish"
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
        if step == .inviteTeam, hasUnaddedInvite {
            addInvite()
            guard inviteError == nil else { return }
        }
        if let next = OrgSetupStep(rawValue: step.rawValue + 1) {
            movesForward = true
            withAnimation(DS.Motion.scene) { step = next }
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
            portfolioSizeID: units?.rawValue,
            inviteEmails: inviteEmails
        )

        do {
            createdOrganizationID = try await service.createOrganization(draft)
            withAnimation(DS.Motion.scene) { isComplete = true }
        } catch {
            submissionError = (error as? AppError)?.errorDescription
                ?? AppError.unknown.errorDescription
        }
    }

    func goBack() {
        guard let previous = OrgSetupStep(rawValue: step.rawValue - 1) else { return }
        movesForward = false
        withAnimation(DS.Motion.scene) { step = previous }
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
