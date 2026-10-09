//
//  OrgSetupSteps.swift
//  RentalApp
//
//  Org Setup — The five wizard steps. Each is a glass card of
//  animated form content; the flow container provides header,
//  progress, and navigation.
//

import SwiftUI
import PhotosUI

// MARK: - Step 1 · Organization Name

struct OrgNameStep: View {

    @Bindable var viewModel: OrgSetupViewModel

    var body: some View {
        AuthCard {
            VStack(spacing: DS.Spacing.lg) {
                AuthTextField(
                    label: "Organization name",
                    text: $viewModel.orgName,
                    icon: "building.2.fill"
                )

                // Live workspace preview.
                HStack(spacing: DS.Spacing.md) {
                    Circle()
                        .fill(viewModel.monogramGradient)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(viewModel.monogram)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.Colors.onFixedColor)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.orgName.isEmpty ? "Your Workspace" : viewModel.orgName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1)

                        Text("rentos.app/\(slug)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    DSBadge(text: "Preview", kind: .info)
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .animation(DS.Motion.gentle, value: viewModel.orgName)
            }
        }
    }

    private var slug: String {
        let base = viewModel.orgName.isEmpty ? "your-workspace" : viewModel.orgName
        return base
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

// MARK: - Step 2 · Logo

struct OrgLogoStep: View {

    @Bindable var viewModel: OrgSetupViewModel
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        AuthCard {
            VStack(spacing: DS.Spacing.xl) {
                // Logo preview.
                ZStack {
                    Circle()
                        .fill(viewModel.monogramGradient)
                        .frame(width: 108, height: 108)
                        .opacity(viewModel.logoImage == nil ? 1 : 0)

                    if let image = viewModel.logoImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 108, height: 108)
                            .clipShape(Circle())
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                    } else {
                        Text(viewModel.monogram)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.onFixedColor)
                    }
                }
                .overlay(
                    Circle().strokeBorder(DS.Colors.highlightLine, lineWidth: 1.5)
                )
                .dsShadow(DS.Shadows.glow(DS.Colors.brand, intensity: 0.4))
                .dsFloating(amplitude: 4, duration: 3.6)
                .animation(DS.Motion.bouncy, value: viewModel.logoImage == nil)

                // Monogram gradient choices (hidden once a photo is set).
                if viewModel.logoImage == nil {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(OrgSetupViewModel.monogramGradients.indices, id: \.self) { index in
                            Button {
                                withAnimation(DS.Motion.snappy) {
                                    viewModel.logoGradientIndex = index
                                }
                            } label: {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: OrgSetupViewModel.monogramGradients[index],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().strokeBorder(
                                            viewModel.logoGradientIndex == index ? DS.Colors.textPrimary : DS.Colors.outline,
                                            lineWidth: 2
                                        )
                                    )
                                    .scaleEffect(viewModel.logoGradientIndex == index ? 1.15 : 1)
                            }
                            .buttonStyle(DSPressStyle(scale: 0.85))
                        }
                    }
                    .animation(DS.Motion.bouncy, value: viewModel.logoGradientIndex)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                VStack(spacing: DS.Spacing.md) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text(viewModel.logoImage == nil ? "Upload Logo" : "Choose a Different Photo")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(DS.Colors.brandInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(DS.Colors.outline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(DSPressStyle())

                    if viewModel.logoImage != nil {
                        Button {
                            withAnimation(DS.Motion.snappy) {
                                viewModel.logoImage = nil
                                pickerItem = nil
                            }
                        } label: {
                            Text("Remove photo")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.Colors.accentCoralInk)
                        }
                        .buttonStyle(DSPressStyle(scale: 0.95))
                        .transition(.opacity)
                    }
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                withAnimation(DS.Motion.bouncy) {
                    viewModel.logoImage = image
                }
            }
        }
    }
}

// MARK: - Step 3 · Property Type

struct OrgTypeStep: View {

    @Bindable var viewModel: OrgSetupViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(Array(PropertyTypeOption.allCases.enumerated()), id: \.element.id) { index, option in
                OrgOptionCard(
                    icon: option.icon,
                    title: option.title,
                    subtitle: option.subtitle,
                    isSelected: viewModel.propertyType == option
                ) {
                    viewModel.propertyType = option
                }
                .dsEntrance(index: index)
            }
        }
    }
}

// MARK: - Step 4 · Portfolio Size

struct OrgSizeStep: View {

    @Bindable var viewModel: OrgSetupViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(Array(PortfolioSizeOption.allCases.enumerated()), id: \.element.id) { index, option in
                Button {
                    viewModel.portfolioSize = option
                } label: {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: option.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                viewModel.portfolioSize == option
                                    ? AnyShapeStyle(DS.Gradients.ai)
                                    : AnyShapeStyle(DS.Colors.textSecondary)
                            )

                        Text(option.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.textPrimary)

                        Text(option.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xl)
                    .background(DS.Colors.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .strokeBorder(
                                viewModel.portfolioSize == option
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [DS.Colors.accentSkyInk.opacity(0.9), DS.Colors.accentSunnyInk.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                      )
                                    : AnyShapeStyle(DS.Colors.outline),
                                lineWidth: viewModel.portfolioSize == option ? 1.5 : 1
                            )
                    )
                    .scaleEffect(viewModel.portfolioSize == option ? 1.03 : 1)
                }
                .buttonStyle(DSPressStyle())
                .animation(DS.Motion.bouncy, value: viewModel.portfolioSize)
                .dsEntrance(index: index)
            }
        }
    }
}

// MARK: - Step 5 · Invite Team

struct OrgInviteStep: View {

    @Bindable var viewModel: OrgSetupViewModel

    var body: some View {
        AuthCard {
            VStack(spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.md) {
                    AuthTextField(
                        label: "Teammate email",
                        text: $viewModel.inviteInput,
                        icon: "envelope.fill",
                        keyboardType: .emailAddress,
                        error: viewModel.inviteError
                    )
                    .onChange(of: viewModel.inviteInput) { _, _ in
                        viewModel.inviteError = nil
                    }

                    DSIconButton(icon: DS.Icons.add, variant: .primary, diameter: 46) {
                        viewModel.addInvite()
                    }
                    .padding(.top, viewModel.inviteError == nil ? 0 : -26)
                }

                if viewModel.inviteEmails.isEmpty {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: DS.Icons.tenants)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(DS.Colors.textTertiary)

                        Text("Invites appear here — teammates get\nProperty Manager access to start.")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, DS.Spacing.lg)
                } else {
                    // Invited chips.
                    FlowLayoutCompat(spacing: DS.Spacing.sm) {
                        ForEach(viewModel.inviteEmails, id: \.self) { email in
                            OrgInviteChip(email: email) {
                                viewModel.removeInvite(email)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Simple wrapping layout for chips (iOS 16+ Layout).
struct FlowLayoutCompat: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
