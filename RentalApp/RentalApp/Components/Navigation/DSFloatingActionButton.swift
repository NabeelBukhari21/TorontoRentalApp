//
//  DSFloatingActionButton.swift
//  RentalApp
//
//  Navigation — Floating action button system.
//  Single-action mode, or speed-dial mode with labeled mini actions
//  that cascade out over a dimmed scrim.
//

import SwiftUI

// MARK: - FAB Action

struct DSFABAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let action: () -> Void

    init(icon: String, title: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.action = action
    }
}

// MARK: - FAB

struct DSFloatingActionButton: View {

    var icon: String = DS.Icons.add
    var actions: [DSFABAction] = []
    var primaryAction: (() -> Void)? = nil

    @State private var isExpanded = false

    private var isSpeedDial: Bool { !actions.isEmpty }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isExpanded {
                // Scrim — tap anywhere to collapse.
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { toggle() }
                    .transition(.opacity)
            }

            VStack(alignment: .trailing, spacing: DS.Spacing.md) {
                if isExpanded {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        miniAction(action, index: index)
                    }
                }

                mainButton
            }
        }
        .animation(DS.Motion.bouncy, value: isExpanded)
    }

    // MARK: Main Button

    private var mainButton: some View {
        Button {
            if isSpeedDial {
                toggle()
            } else {
                primaryAction?()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(isExpanded ? 45 : 0))
                .frame(width: 58, height: 58)
                .background(DS.Gradients.brand)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )
                .dsShadow(DS.Shadows.glow(DS.Colors.brand, intensity: 0.45))
        }
        .buttonStyle(DSPressStyle(scale: 0.9))
        .accessibilityLabel(isSpeedDial ? "Quick actions" : "Add")
    }

    // MARK: Mini Actions

    private func miniAction(_ action: DSFABAction, index: Int) -> some View {
        Button {
            toggle()
            action.action()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(action.title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(DS.Gradients.glassHighlight, lineWidth: 1)
                    )

                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.brand)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle().strokeBorder(DS.Gradients.glassHighlight, lineWidth: 1)
                    )
                    .dsShadow(DS.Shadows.card)
            }
        }
        .buttonStyle(DSPressStyle(scale: 0.92))
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.6, anchor: .bottomTrailing)
                    .combined(with: .opacity)
                    .animation(DS.Motion.bouncy.delay(Double(actions.count - 1 - index) * 0.05)),
                removal: .scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity)
            )
        )
    }

    private func toggle() {
        withAnimation(DS.Motion.bouncy) {
            isExpanded.toggle()
        }
    }
}

// MARK: - Previews

#Preview("FAB — Speed Dial") {
    ZStack(alignment: .bottomTrailing) {
        DSAmbientBackground()

        DSFloatingActionButton(actions: [
            DSFABAction(icon: DS.Icons.properties, title: "New Property") {},
            DSFABAction(icon: DS.Icons.maintenance, title: "New Request") {},
            DSFABAction(icon: DS.Icons.messages, title: "New Message") {}
        ])
        .padding(DS.Spacing.xl)
    }
}

#Preview("FAB — Single Action") {
    ZStack(alignment: .bottomTrailing) {
        DSAmbientBackground()

        DSFloatingActionButton {}
            .padding(DS.Spacing.xl)
    }
}
