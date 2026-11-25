//
//  RoleChoices.swift
//  RentalApp (Purrperty)
//
//  Auth — Who's signing up. Asked before the account is made, because the
//  role decides what the first session can do.
//

import SwiftUI

extension AuthViewModel {

    var roleChoices: [OnboardingChoice] {
        AppRole.allCases.map { role in
            OnboardingChoice(
                id: role.id, title: role == .propertyManager ? "Manager" : role.title, subtitle: role.signUpSubtitle, symbol: role.icon, accent: role.accent,
                isSelected: selectedRole == role
            ) {
                withAnimation(DS.Motion.bouncy) { self.selectedRole = role }
            }
        }
    }
}

extension AppRole {

    fileprivate var signUpSubtitle: String {
        switch self {
        case .owner: "I own rentals"
        case .propertyManager: "I manage for others"
        case .tenant: "I live in a rental"
        case .vendor: "I do the repairs"
        }
    }

    fileprivate var accent: DSAccent {
        switch self {
        case .owner: .gold
        case .propertyManager: .sky
        case .tenant: .mint
        case .vendor: .cherry
        }
    }

    /// Purr acts out the choice.
    var mood: PurrMood {
        switch self {
        case .owner: .keysReady
        case .propertyManager: .superhero
        case .tenant: .tenants
        case .vendor: .builder
        }
    }
}
