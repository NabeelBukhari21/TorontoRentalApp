//
//  CreateTenantView.swift
//  RentalApp (Purrperty)
//
//  Tenants — Create flow, presented as a bottom sheet.
//  Live avatar preview, validated fields, lease term pickers,
//  simulated save with success animation.
//

import SwiftUI

// MARK: - View

struct CreateTenantView: View {

    @State private var viewModel: CreateTenantViewModel
    @Environment(\.dismiss) private var dismiss

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: CreateTenantViewModel(repository: container.tenants))
    }

    var body: some View {
        DSModalCard(title: "New Tenant", subtitle: "Add a tenant to your portfolio") {
            if viewModel.isSaved {
                savedContent
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                formContent
                    .transition(.opacity)
            }
        }
        .animation(DS.Motion.smooth, value: viewModel.isSaved)
        .task { await viewModel.load() }
    }

    // MARK: Form

    private var formContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.lg) {

                // Live avatar preview.
                VStack(spacing: DS.Spacing.sm) {
                    DSAvatar(name: viewModel.name.isEmpty ? "New Tenant" : viewModel.name, size: .large)
                        .animation(DS.Motion.smooth, value: viewModel.name)

                    Text(viewModel.name.isEmpty ? "New Tenant" : viewModel.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .contentTransition(.opacity)
                }
                .padding(.top, DS.Spacing.sm)

                DSTextField(
                    label: "Full name",
                    placeholder: "e.g. Maya Rodriguez",
                    text: $viewModel.name,
                    icon: "person.fill"
                )

                DSTextField(
                    label: "Email",
                    placeholder: "tenant@email.com",
                    text: $viewModel.email,
                    icon: "envelope.fill",
                    keyboardType: .emailAddress
                )

                DSTextField(
                    label: "Phone",
                    placeholder: "(416) 555-0100",
                    text: $viewModel.phone,
                    icon: "phone.fill",
                    keyboardType: .phonePad
                )

                DSDropdown(
                    label: "Property",
                    options: viewModel.propertyNames,
                    selection: $viewModel.property,
                    placeholder: "Choose a property"
                ) { $0 }

                HStack(spacing: DS.Spacing.md) {
                    DSTextField(
                        label: "Unit",
                        placeholder: "e.g. 204",
                        text: $viewModel.unit,
                        icon: DS.Icons.unit
                    )

                    DSTextField(
                        label: "Monthly rent",
                        placeholder: "2200",
                        text: $viewModel.rent,
                        icon: DS.Icons.payment,
                        keyboardType: .numberPad
                    )
                }

                // Lease term.
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Lease term")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textSecondary)

                    HStack(spacing: DS.Spacing.md) {
                        datePicker(label: "Starts", selection: $viewModel.leaseStart)
                        datePicker(label: "Ends", selection: $viewModel.leaseEnd)
                    }
                }

                DSButton(
                    title: "Add Tenant",
                    icon: "person.badge.plus",
                    variant: .primary,
                    size: .large,
                    isFullWidth: true,
                    isLoading: viewModel.isSaving
                ) {
                    Task { await viewModel.save() }
                }
                .disabled(!viewModel.canSave)
                .animation(DS.Motion.gentle, value: viewModel.canSave)
                .padding(.top, DS.Spacing.sm)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func datePicker(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textTertiary)

            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .tint(DS.Colors.brand)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Colors.outline, lineWidth: 1)
        )
    }

    // MARK: Saved

    private var savedContent: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            AuthSuccessBadge(tint: DS.Colors.brand)

            VStack(spacing: DS.Spacing.xs) {
                Text("\(viewModel.name) added")
                    .font(DS.Typography.title3)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("Lease invite sent to \(viewModel.email)")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            DSButton(title: "Done", variant: .primary, size: .large, isFullWidth: true) {
                dismiss()
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()
        }
        .padding(DS.Spacing.xl)
    }
}

// MARK: - Previews

#Preview("Create Tenant") {
    CreateTenantView()
}
