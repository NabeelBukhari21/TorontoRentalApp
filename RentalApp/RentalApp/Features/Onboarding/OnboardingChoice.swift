//
//  OnboardingChoice.swift
//  RentalApp (Purrperty)
//
//  Onboarding — How each step of the scene looks and what it offers: its
//  answers in one uniform shape, its layout, colour, props and wording.
//

import SwiftUI

/// One answer on a question step, whatever the question.
struct OnboardingChoice: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let accent: DSAccent
    let isSelected: Bool
    let select: () -> Void
}

/// The three ways a step stages Purr and its answers.
enum OnboardingStaging {
    /// Purr stands behind a counter holding the content.
    case counter
    /// Purr fills the bottom of the screen; content sits above his ears.
    case giant
    /// Answers float around Purr as bubbles.
    case orbit
}

extension OnboardingStep {

    var staging: OnboardingStaging {
        switch self {
        case .headaches, .building: .giant
        case .goal, .personalize: .orbit
        default: .counter
        }
    }

    /// Clay props around Purr: behind left, behind right, in front.
    var props: [String] {
        switch self {
        case .persona: ["key.fill", "house.fill", "questionmark"]
        case .units: ["building.2.fill", "house.fill", "door.left.hand.closed"]
        case .headaches: ["dollarsign", "wrench.and.screwdriver.fill"]
        case .building: ["hammer.fill", "gearshape.fill"]
        case .unlocked: ["star.fill", "sparkles", "trophy.fill"]
        case .signUp: ["lock.fill", "heart.fill", "envelope.fill"]
        default: []
        }
    }
}

extension OnboardingFlowViewModel {

    var choices: [OnboardingChoice] {
        switch step {
        case .persona:
            zip(OnboardingPersona.allCases, [DSAccent.gold, .sky, .mint]).map { item, accent in
                OnboardingChoice(id: item.id, title: item.title, subtitle: item.subtitle, symbol: item.icon, accent: accent,
                                 isSelected: profile.persona == item) { self.select(item) }
            }
        case .units:
            zip(OnboardingUnitRange.allCases, [DSAccent.mint, .sky, .gold, .cherry]).map { item, accent in
                OnboardingChoice(id: item.id, title: item.title, subtitle: item.subtitle, symbol: item.icon, accent: accent,
                                 isSelected: profile.unitRange == item) { self.select(item) }
            }
        case .headaches:
            zip(OnboardingHeadache.allCases, [DSAccent.mint, .cherry, .sky, .gold, .blush]).map { item, accent in
                OnboardingChoice(id: item.id, title: item.title, subtitle: "", symbol: item.icon, accent: accent,
                                 isSelected: profile.headaches.contains(item)) { self.toggle(item) }
            }
        case .goal:
            zip(OnboardingGoal.allCases, [DSAccent.sky, .mint, .cherry]).map { item, accent in
                OnboardingChoice(id: item.id, title: item.title, subtitle: item.subtitle, symbol: item.icon, accent: accent,
                                 isSelected: profile.goal == item) { self.select(item) }
            }
        case .personalize:
            zip(AppTheme.allCases, [DSAccent.blush, .gold, .sky]).map { item, accent in
                OnboardingChoice(id: item.id, title: item == .system ? "Automatic" : item.rawValue,
                                 subtitle: item == .system ? "Match your iPhone's setting" : "",
                                 symbol: item.icon, accent: accent,
                                 isSelected: theme == item) { self.theme = item }
            }
        default: []
        }
    }

    var look: OnboardingLook {
        let accent: DSAccent = switch step {
        case .persona, .unlocked: .gold
        case .units: .sky
        case .goal: .mint
        case .personalize: theme == .dark ? .sky : .gold
        default: .blush
        }
        let finish: OnboardingLook.Finish = switch step.staging {
        case .counter: .stage
        case .giant: .flat
        case .orbit: .glow
        }
        return OnboardingLook(accent: accent, finish: finish)
    }

    /// How full of liquid the screen is. Follows the real build tasks.
    var buildLevel: Double {
        guard step == .building else { return 0 }
        let done = Double(buildTasks.count { $0.state == .done })
        let total = Double(max(buildTasks.count, 1))
        return done == total ? 1.1 : 0.1 + 0.5 * done / total
    }

    var sceneTitle: String {
        switch step {
        case .building: "Building your Purrperty"
        case .unlocked: "Look what you unlocked!"
        case .signUp: "Create your account"
        default: question
        }
    }

    var sceneLine: String {
        switch step {
        case .building: "This takes a few seconds."
        case .unlocked: profile.goal?.outcome ?? ""
        case .signUp:
            profile.persona == .tenant
                ? "Join your landlord on Purrperty."
                : profile.goal?.outcome ?? "Save your setup so it's here every time you open the app."
        default: mascotLine
        }
    }
}
