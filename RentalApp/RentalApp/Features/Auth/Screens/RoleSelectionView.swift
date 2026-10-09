//
//  RoleSelectionView.swift
//  RentalApp (RentOS)
//
//  Auth — "How will you use RentOS?" Asked before sign-up because the
//  role decides everything downstream: whether an organization is
//  required, which tabs exist, and what the copilot is allowed to do.
//  Asking after account creation would mean rebuilding the session.
//

import SwiftUI

struct RoleSelectionView: View {

    @Bindable var viewModel: AuthViewModel
    let onNavigate: (AuthFlowView.Screen) -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            AuthHeader(
                title: "How will you use RentOS?",
                subtitle: "This shapes your workspace. You can change it later."
            )
            .dsEntrance(index: 0)

            VStack(spacing: DS.Spacing.md) {
                ForEach(Array(AppRole.allCases.enumerated()), id: \.element.id) { index, role in
                    RoleOptionCard(
                        role: role,
                        isSelected: viewModel.selectedRole == role
                    ) {
                        withAnimation(DS.Motion.bouncy) {
                            viewModel.selectedRole = role
                        }
                    }
                    .dsEntrance(index: index + 1)
                }
            }

            VStack(spacing: DS.Spacing.md) {
                DSButton(
                    title: "Continue",
                    variant: .primary,
                    size: .large,
                    isFullWidth: true
                ) {
                    onNavigate(.signUp)
                }

                AuthFooterLink(prompt: "Already have an account?", actionTitle: "Sign in") {
                    onNavigate(.login)
                }
            }
            .dsEntrance(index: AppRole.allCases.count + 1)
        }
    }
}

// MARK: - Option Card

/// Glass row that fills with champagne when selected. Uses the same
/// press, radius, and hairline vocabulary as every other selectable
/// card in the app (org setup, filters) so it reads as one system.
private struct RoleOptionCard: View {

    let role: AppRole
    let isSelected: Bool
    let action: () -> Void

    /// `.background(_:in:)` takes a `ShapeStyle`, and a `Group` of two
    /// different styles isn't one — they have to be erased to a single
    /// type first.
    private var tileFill: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(
                LinearGradient(
                    colors: [RentOSBrand.gold, RentOSBrand.goldDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
              )
            : AnyShapeStyle(Color.white.opacity(0.06))
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: role.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? RentOSBrand.obsidian : DS.Colors.brand)
                    .frame(width: 44, height: 44)
                    .background(
                        tileFill,
                        in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(role.title)
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(role.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: DS.Spacing.sm)

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? RentOSBrand.gold : Color.white.opacity(0.22),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RentOSBrand.gold)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(DS.Spacing.md + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(RentOSBrand.gold.opacity(0.55))
                            : AnyShapeStyle(DS.Gradients.glassHighlight),
                        lineWidth: 1
                    )
            )
            .dsShadow(
                isSelected
                    ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.28)
                    : DS.Shadows.soft
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(DSPressStyle(scale: 0.97))
    }
}

// MARK: - Previews

#Preview("Role Selection") {
    AuthFlowView(container: .preview, onAuthenticated: { _ in })
}
