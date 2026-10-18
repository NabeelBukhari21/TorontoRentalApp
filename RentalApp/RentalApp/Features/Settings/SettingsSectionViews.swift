//
//  SettingsSectionViews.swift
//  RentalApp (Purrperty)
//
//  Settings — Section dispatcher + Profile, Organization, and Team pages.
//

import SwiftUI

// MARK: - Dispatcher

struct SettingsSectionView: View {

    let section: SettingsSection

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                Group {
                    switch section {
                    case .profile: SettingsProfilePage()
                    case .organization: SettingsOrganizationPage()
                    case .team: SettingsTeamPage()
                    case .billing: SettingsBillingPage()
                    case .notifications: SettingsNotificationsPage()
                    case .appearance: SettingsAppearancePage()
                    case .aiPreferences: SettingsAIPage()
                    case .integrations: SettingsIntegrationsPage()
                    }
                }
                .padding(DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.huge)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Profile

struct SettingsProfilePage: View {

    @State private var viewModel: ProfileSettingsViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: ProfileSettingsViewModel(repository: container.profile))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: DS.Spacing.lg) {
            // Avatar.
            VStack(spacing: DS.Spacing.sm) {
                DSAvatar(name: viewModel.fullName, size: .xlarge)
                    .dsFloating(amplitude: 3, duration: 3.8)

                Button {} label: {
                    Text("Change photo")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Colors.brand)
                }
                .buttonStyle(DSPressStyle(scale: 0.95))
            }
            .dsEntrance(index: 0)

            DSCard(style: .raised) {
                VStack(spacing: DS.Spacing.lg) {
                    DSTextField(label: "Full name", placeholder: "Your name", text: $viewModel.fullName, icon: "person.fill")
                    DSTextField(label: "Email", placeholder: "you@email.com", text: $viewModel.email, icon: "envelope.fill", keyboardType: .emailAddress)
                    DSTextField(label: "Phone", placeholder: "(416) 555-0100", text: $viewModel.phone, icon: "phone.fill", keyboardType: .phonePad)
                    DSTextField(label: "Role title", placeholder: "e.g. Portfolio Owner", text: $viewModel.jobTitle, icon: "briefcase.fill")
                }
            }
            .dsEntrance(index: 1)

            SettingsSectionCard(title: "Security") {
                SettingsNavRow(icon: "lock.fill", title: "Change password", subtitle: "Last changed 3 months ago") {}
                SettingsRowDivider()
                SettingsNavRow(icon: "faceid", title: "Face ID", subtitle: "Unlock Purrperty with Face ID") {}
            }
            .dsEntrance(index: 2)

            SettingsSaveButton(title: "Save Profile")
                .dsEntrance(index: 3)
        }
    }
}

// MARK: - Organization

struct SettingsOrganizationPage: View {

    @State private var viewModel: ProfileSettingsViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: ProfileSettingsViewModel(repository: container.profile))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: DS.Spacing.lg) {
            // Workspace identity.
            DSCard(style: .raised, cornerRadius: DS.Radius.xl, padding: DS.Spacing.xl) {
                HStack(spacing: DS.Spacing.lg) {
                    Circle()
                        .fill(DS.Gradients.hero)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Text(orgMonogram)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.Colors.textOnBrand)
                        )
                        .overlay(
                            Circle().strokeBorder(DS.Colors.highlightLine, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.orgName)
                            .font(DS.Typography.title3)
                            .foregroundStyle(DS.Colors.textPrimary)

                        Text("rentos.app/\(viewModel.orgSlug)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 0)

            DSCard(style: .raised) {
                VStack(spacing: DS.Spacing.lg) {
                    DSTextField(label: "Organization name", placeholder: "Name", text: $viewModel.orgName, icon: "building.2.fill")
                    DSTextField(label: "Workspace URL", placeholder: "slug", text: $viewModel.orgSlug, icon: "link")
                    DSTextField(label: "City", placeholder: "City", text: $viewModel.orgCity, icon: "mappin.circle.fill")
                }
            }
            .dsEntrance(index: 1)

            SettingsSectionCard(title: "Portfolio") {
                SettingsValueRow(icon: DS.Icons.properties, title: "Properties", value: "12")
                SettingsRowDivider()
                SettingsValueRow(icon: DS.Icons.unit, title: "Units", value: "48")
                SettingsRowDivider()
                SettingsValueRow(icon: DS.Icons.tenants, title: "Active tenants", value: "45")
            }
            .dsEntrance(index: 2)

            SettingsSaveButton(title: "Save Organization")
                .dsEntrance(index: 3)
        }
    }

    private var orgMonogram: String {
        let parts = viewModel.orgName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

// MARK: - Team

struct SettingsTeamPage: View {

    @State private var viewModel: TeamSettingsViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: TeamSettingsViewModel(repository: container.profile))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return VStack(spacing: DS.Spacing.lg) {
            // Invite.
            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Invite teammate").dsOverline()

                    HStack(spacing: DS.Spacing.md) {
                        DSTextField(
                            label: "Email",
                            placeholder: "teammate@company.com",
                            text: $viewModel.inviteEmail,
                            icon: "envelope.fill",
                            keyboardType: .emailAddress
                        )

                        DSIconButton(icon: DS.Icons.send, variant: .primary, diameter: 46) {
                            viewModel.sendInvite()
                        }
                    }
                }
            }
            .dsEntrance(index: 0)

            // Members.
            SettingsSectionCard(title: "Members · \(viewModel.members.count)") {
                ForEach(Array(viewModel.members.enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: DS.Spacing.md) {
                        DSAvatar(name: member.name, size: .medium)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: DS.Spacing.xs) {
                                Text(member.name)
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(DS.Colors.textPrimary)

                                if member.isOwner {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(DS.Colors.brand)
                                }
                            }

                            Text("\(member.role) · \(member.email)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        DSBadge(text: member.status, kind: member.statusKind)
                    }
                    .padding(DS.Spacing.md + 2)

                    if index < viewModel.members.count - 1 {
                        SettingsRowDivider()
                    }
                }
            }
            .dsEntrance(index: 1)
            .animation(DS.Motion.smooth, value: viewModel.members.map(\.id))

            // Roles explainer.
            SettingsSectionCard(title: "Roles") {
                SettingsValueRow(icon: "crown.fill", title: "Owner", value: "Everything")
                SettingsRowDivider()
                SettingsValueRow(icon: DS.Icons.tenant, title: "Property Manager", value: "Manage & message", tint: DS.Colors.accentSkyInk)
                SettingsRowDivider()
                SettingsValueRow(icon: DS.Icons.maintenance, title: "Maintenance Coordinator", value: "Tickets & vendors", tint: DS.Colors.accentSunnyInk)
            }
            .dsEntrance(index: 2)
        }
    }
}
