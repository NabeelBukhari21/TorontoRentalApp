//
//  PasswordRequirementRow.swift
//  RentalApp (Purrperty)
//
//  Auth — One rule of the new-password policy, ticking over as it's met
//  with a light haptic (playbook §3). Shared by every sign-up and reset
//  screen so the checklist always matches what validation enforces.
//

import SwiftUI


/// Each rule ticks over as it's met, with a light haptic (playbook §3).
struct PasswordRequirementRow: View {

    let requirement: PasswordRequirement

    var body: some View {
        Label {
            Text(requirement.rule.title)
                .foregroundStyle(requirement.isMet ? .primary : .secondary)
        } icon: {
            Image(systemName: requirement.isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(requirement.isMet ? AnyShapeStyle(.green) : AnyShapeStyle(Color(uiColor: .tertiaryLabel)))
                .contentTransition(.symbolEffect(.replace))
        }
        .font(.footnote)
        .sensoryFeedback(.impact(weight: .light), trigger: requirement.isMet) { _, met in met }
        .accessibilityElement(children: .combine)
        .accessibilityValue(requirement.isMet ? "Met" : "Not met")
    }
}
