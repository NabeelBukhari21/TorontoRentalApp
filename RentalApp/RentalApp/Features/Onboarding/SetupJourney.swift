//
//  SetupJourney.swift
//  RentalApp (Purrperty)
//
//  Onboarding — One progress bar for everything a new landlord does: the
//  questions, the workspace and the first property.
//

import Foundation

enum SetupJourney: Sendable {
    /// The whole way, from the first question.
    case full
    /// Signed up without the questions (from the sign-in screen).
    case withoutQuestions

    /// Persona to sign-up.
    static let questions = 8
    static let workspace = 4
    static let property = 4

    init(profile: OnboardingProfile) {
        self = profile.persona == nil ? .withoutQuestions : .full
    }

    private var before: Int { self == .full ? Self.questions : 0 }
    var total: Int { before + Self.workspace + Self.property }

    func workspaceStep(_ index: Int) -> Int { before + index }
    func propertyStep(_ index: Int) -> Int { before + Self.workspace + index }

    /// Starts a little way in, so it already feels under way (playbook §5).
    static func progress(step: Int, of total: Int) -> Double {
        0.1 + 0.9 * Double(step) / Double(max(total, 1))
    }

    func progress(_ step: Int) -> Double { Self.progress(step: step, of: total) }
    func label(_ step: Int) -> String { "Step \(step + 1) of \(total)" }
}
