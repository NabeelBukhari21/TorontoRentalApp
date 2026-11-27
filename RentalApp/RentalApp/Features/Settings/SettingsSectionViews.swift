//
//  SettingsSectionViews.swift
//  RentalApp (Purrperty)
//
//  Settings — Section dispatcher + Profile, Organization, and Team pages.
//

import PhotosUI
import SwiftUI
import UIKit

// MARK: - Dispatcher

struct SettingsSectionView: View {

    let section: SettingsSection

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {
                    if let mood = section.purrMood {
                        PurrMascot(mood: mood, size: 120)
                    }
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

private extension SettingsSection {
    /// Purr at the top of the page. Nil where the page already leads with
    /// a face (the avatar, Purr's looks, Copilot).
    var purrMood: PurrMood? {
        switch self {
        case .profile, .appearance, .aiPreferences: nil
        case .organization:  .properties
        case .team:          .inviteFriends
        case .billing:       .receipt
        case .notifications: .notifications
        case .integrations:  .comingSoon
        }
    }
}

// MARK: - Profile

struct SettingsProfilePage: View {

    @State private var viewModel: ProfileSettingsViewModel
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isConfirmingReset = false
    @Environment(\.toasts) private var toasts

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: ProfileSettingsViewModel(repository: container.profile, auth: container.auth))
    }

    private var avatarImage: Image? {
        viewModel.photo.flatMap(UIImage.init(data:)).map(Image.init(uiImage:))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: DS.Spacing.lg) {
            // Avatar.
            VStack(spacing: DS.Spacing.sm) {
                DSAvatar(name: viewModel.fullName, image: avatarImage, size: .xlarge)
                    .dsFloating(amplitude: 3, duration: 3.8)

                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Text("Change photo")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Colors.brand)
                }
                .buttonStyle(DSPressStyle(scale: 0.95))
                .onChange(of: pickedPhoto) { _, item in
                    guard let item else { return }
                    Task {
                        // Kept small: it's an avatar, not a gallery.
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data),
                           let small = image.preparingThumbnail(of: CGSize(width: 400, height: 400))?.jpegData(compressionQuality: 0.8) {
                            viewModel.photo = small
                            toasts.success("Photo updated", mood: .profilePhoto)
                        }
                        pickedPhoto = nil
                    }
                }
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
                SettingsNavRow(icon: "lock.fill", title: "Change password", subtitle: "We'll email you a link to set a new one") {
                    isConfirmingReset = true
                }
            }
            .dsEntrance(index: 2)
            .confirmationDialog("Send a password reset link to \(viewModel.email)?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                Button("Send Link") {
                    Task {
                        if let failure = await viewModel.sendPasswordReset() {
                            toasts.failure(.validation(failure))
                        } else {
                            toasts.success("Reset link sent to \(viewModel.email)", mood: .resetEmailSent)
                        }
                    }
                }
            }

            SettingsSaveButton(title: "Save Profile") { try await viewModel.save() }
                .dsEntrance(index: 3)
        }
    }
}

// MARK: - Organization

struct SettingsOrganizationPage: View {

    @State private var viewModel: ProfileSettingsViewModel
    @State private var portfolio: OrganizationPortfolioViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: ProfileSettingsViewModel(repository: container.profile))
        _portfolio = State(initialValue: OrganizationPortfolioViewModel(
            properties: container.properties,
            tenants: container.tenants
        ))
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
                SettingsValueRow(icon: DS.Icons.properties, title: "Properties",
                                 value: portfolio.portfolio.map { "\($0.propertyCount)" } ?? "—")
                SettingsRowDivider()
                SettingsValueRow(icon: DS.Icons.unit, title: "Units",
                                 value: portfolio.portfolio.map { "\($0.totalUnits)" } ?? "—")
                SettingsRowDivider()
                SettingsValueRow(icon: DS.Icons.tenants, title: "Tenants",
                                 value: portfolio.tenantSummary.map { "\($0.total)" } ?? "—")
            }
            .dsEntrance(index: 2)
            .task { await portfolio.load() }

            SettingsSaveButton(title: "Save Organization") { try await viewModel.save() }
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
                SettingsValueRow(icon: DS.Icons.maintenance, title: "Maintenance Coordinator", value: "Tickets & vendors", tint: DS.Colors.accentGoldInk)
            }
            .dsEntrance(index: 2)
        }
    }
}
