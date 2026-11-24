//
//  OrgSetupSteps.swift
//  RentalApp
//
//  Org Setup — What each step puts on Purr's counter. (Property type and
//  portfolio size are answer cards; see `OrgSetupFlowView`.)
//

import SwiftUI
import PhotosUI

// MARK: - Monogram

/// The workspace's logo, or its initials on the chosen gradient.
private struct OrgMark: View {
    let viewModel: OrgSetupViewModel
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(viewModel.monogramGradient)
            if let image = viewModel.logoImage {
                Image(uiImage: image).resizable().scaledToFill().clipShape(.circle)
            } else {
                Text(viewModel.monogram)
                    .font(DS.Typography.brandFixed(size * 0.38))
                    .foregroundStyle(DS.Colors.onFixedColor)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(DS.Colors.highlightLine, lineWidth: 1.5))
        .shadow(color: DS.Colors.groundShadow, radius: 8, y: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Step 1 · Organization Name

struct OrgNameStep: View {

    @Bindable var viewModel: OrgSetupViewModel

    var body: some View {
        VStack(spacing: 12) {
            StageField(symbol: "building.2.fill", prompt: "Organization name", text: $viewModel.orgName)
                .textContentType(.organizationName)

            HStack(spacing: 12) {
                OrgMark(viewModel: viewModel, size: 44)
                Text(viewModel.orgName.isEmpty ? "Your Workspace" : viewModel.orgName)
                    .font(DS.Typography.brand(.headline, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                DSBadge(text: "Preview", kind: .info)
            }
            .stagePanel()
            .animation(DS.Motion.gentle, value: viewModel.orgName)
        }
    }
}

// MARK: - Step 2 · Logo

struct OrgLogoStep: View {

    @Bindable var viewModel: OrgSetupViewModel
    @State private var pickerItem: PhotosPickerItem?
    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(spacing: 16) {
            OrgMark(viewModel: viewModel, size: 92)
                .jelly(on: viewModel.logoGradientIndex)
                .animation(DS.Motion.bouncy, value: viewModel.logoImage == nil)

            // Monogram gradient choices (hidden once a photo is set).
            if viewModel.logoImage == nil {
                HStack(spacing: 12) {
                    ForEach(OrgSetupViewModel.monogramGradients.indices, id: \.self) { index in
                        Button {
                            feedback?.play(.select(index))
                            withAnimation(DS.Motion.bouncy) { viewModel.logoGradientIndex = index }
                        } label: {
                            Circle()
                                .fill(LinearGradient(colors: OrgSetupViewModel.monogramGradients[index], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().strokeBorder(
                                    viewModel.logoGradientIndex == index ? DS.Colors.textPrimary : DS.Colors.outline, lineWidth: 2.5
                                ))
                                .scaleEffect(viewModel.logoGradientIndex == index ? 1.15 : 1)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(SquishStyle(scale: 0.85))
                        .accessibilityLabel("Colour \(index + 1)")
                        .accessibilityAddTraits(viewModel.logoGradientIndex == index ? .isSelected : [])
                    }
                }
                .transition(.opacity)
            }

            // Read on the main actor; PhotosPicker's label closure isn't.
            let pickerTitle = viewModel.logoImage == nil ? "Upload a logo" : "Choose a different photo"
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(pickerTitle, systemImage: "photo.fill")
                    .font(DS.Typography.brand(.callout, weight: .semibold))
                    .foregroundStyle(DS.Colors.brandInk)
                    .frame(maxWidth: .infinity)
                    .stageField()
            }
            .buttonStyle(SquishStyle(scale: 0.97))

            if viewModel.logoImage != nil {
                StageLink(title: "Remove photo") {
                    withAnimation(DS.Motion.snappy) {
                        viewModel.logoImage = nil
                        pickerItem = nil
                    }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                withAnimation(DS.Motion.bouncy) { viewModel.logoImage = image }
            }
        }
    }
}

// MARK: - Step 5 · Invite Team

struct OrgInviteStep: View {

    @Bindable var viewModel: OrgSetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                StageField(symbol: "envelope.fill", prompt: "Teammate email", text: $viewModel.inviteInput, error: viewModel.inviteError)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { viewModel.addInvite() }
                    .onChange(of: viewModel.inviteInput) { _, _ in viewModel.inviteError = nil }

                Button { viewModel.addInvite() } label: {
                    Image(systemName: DS.Icons.add)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DS.Colors.textOnBrand)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(.clay(DS.Colors.brand, shade: DS.Colors.brandDeep, size: 48)))
                }
                .buttonStyle(PressableDepthStyle(edge: DS.Colors.brandDeep, depth: 4))
                .accessibilityLabel("Add teammate")
            }

            if viewModel.inviteEmails.isEmpty {
                Text("Teammates get Property Manager access to start.")
                    .font(DS.Typography.brand(.footnote, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
            } else {
                FlowLayoutCompat(spacing: DS.Spacing.sm) {
                    ForEach(viewModel.inviteEmails, id: \.self) { email in
                        OrgInviteChip(email: email) { viewModel.removeInvite(email) }
                    }
                }
            }
        }
    }
}

// MARK: - Done

/// The new workspace, summed up.
struct OrgSummary: View {
    let viewModel: OrgSetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                OrgMark(viewModel: viewModel, size: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.orgName)
                        .font(DS.Typography.brand(.title3, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)
                    Text(summaryLine)
                        .font(DS.Typography.brand(.subheadline, weight: .regular))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            if !viewModel.inviteEmails.isEmpty {
                HStack {
                    DSAvatarStack(names: viewModel.inviteEmails, maxVisible: 4)
                    Text("\(viewModel.inviteEmails.count) \(viewModel.inviteEmails.count == 1 ? "teammate" : "teammates") to invite")
                        .font(DS.Typography.brand(.footnote, weight: .regular))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
        .stagePanel()
        .accessibilityElement(children: .combine)
    }

    private var summaryLine: String {
        var parts: [String] = []
        if let type = viewModel.propertyType { parts.append(type.title) }
        if let size = viewModel.portfolioSize { parts.append("\(size.title) properties") }
        return parts.isEmpty ? "Ready to add your first property" : parts.joined(separator: " · ")
    }
}

// MARK: - Layout

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
