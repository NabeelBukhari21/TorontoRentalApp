//
//  SettingsHubView.swift
//  RentalApp (Purrperty)
//
//  Settings — Hub: profile header card and grouped section navigation.
//

import SwiftUI

struct SettingsHubView: View {

    @Environment(AppRouter.self) private var router
    @Environment(SessionViewModel.self) private var session
    @State private var viewModel: SettingsHubViewModel
    @State private var showSignOutDialog = false
    @State private var biometricEnabled = false

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: SettingsHubViewModel(
            profile: container.profile,
            billing: container.billing,
            integrations: container.integrations
        ))
    }

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {

                    // Profile header.
                    profileCard
                        .dsEntrance(index: 0)

                    // Account.
                    SettingsSectionCard(title: "Account") {
                        sectionRow(.profile)
                        SettingsRowDivider()
                        sectionRow(.organization)
                        SettingsRowDivider()
                        sectionRow(.team, badge: "\(viewModel.memberCount)")
                    }
                    .dsEntrance(index: 1)

                    // Workspace.
                    SettingsSectionCard(title: "Workspace") {
                        sectionRow(.billing, badge: viewModel.planName == "Purrperty Premium" ? "Premium" : nil)
                        SettingsRowDivider()
                        sectionRow(.notifications)
                        SettingsRowDivider()
                        sectionRow(.appearance)
                    }
                    .dsEntrance(index: 2)

                    // Intelligence & connections.
                    SettingsSectionCard(title: "Intelligence") {
                        sectionRow(.aiPreferences)
                        SettingsRowDivider()
                        sectionRow(.integrations, badge: viewModel.connectedIntegrations > 0
                            ? "\(viewModel.connectedIntegrations) active"
                            : "Coming soon")
                    }
                    .dsEntrance(index: 3)

                    // Security. Only shown when the device actually has
                    // biometrics — an inert toggle is worse than none.
                    if session.biometricKind.isAvailable {
                        SettingsSectionCard(title: "Security") {
                            SettingsToggleRow(
                                icon: session.biometricKind.icon,
                                title: "Unlock with \(session.biometricKind.title)",
                                subtitle: "Skip the password when you reopen Purrperty",
                                isOn: $biometricEnabled
                            )
                        }
                        .dsEntrance(index: 4)
                        .onChange(of: biometricEnabled) { _, newValue in
                            Task { await session.setBiometricEnabled(newValue) }
                        }
                    }

                    // Sign out.
                    Button {
                        showSignOutDialog = true
                    } label: {
                        Text("Sign Out")
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                    .strokeBorder(DS.Colors.danger.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(DSPressStyle())
                    .disabled(session.isSigningOut)
                    .dsEntrance(index: 5)

                    Text("Purrperty 1.0 · Made in Toronto")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.sm)
                }
                .padding(DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.huge)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { biometricEnabled = session.session?.biometricEnabled ?? false }
        .confirmationDialog(
            "Sign out of Purrperty?",
            isPresented: $showSignOutDialog,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task { await session.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Profile Card

    private var profileCard: some View {
        DSCard(style: .raised, cornerRadius: DS.Radius.xl, padding: DS.Spacing.xl) {
            HStack(spacing: DS.Spacing.lg) {
                DSAvatar(name: viewModel.fullName, size: .large, status: .success)

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.fullName)
                        .font(DS.Typography.title3)
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text(viewModel.email)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.sm) {
                        DSBadge(text: viewModel.jobTitle, kind: .info)
                        DSBadge(text: viewModel.orgName, kind: .neutral)
                    }
                }

                Spacer(minLength: 0)

                DSIconButton(icon: "pencil", diameter: 36) {
                    router.push(.settingsSection(section: .profile))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Rows

    private func sectionRow(_ section: SettingsSection, badge: String? = nil) -> some View {
        SettingsNavRow(
            icon: section.icon,
            title: section.title,
            subtitle: section.subtitle,
            tint: section.tint,
            badge: badge
        ) {
            router.push(.settingsSection(section: section))
        }
    }
}

// MARK: - Previews

#Preview("Settings Hub") {
    NavigationStack {
        SettingsHubView()
    }
    .environment(AppRouter())
}
