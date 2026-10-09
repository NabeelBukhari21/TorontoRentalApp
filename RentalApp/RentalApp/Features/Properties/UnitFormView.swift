//
//  UnitFormView.swift
//  RentalApp (RentOS)
//
//  Properties — Create and edit a unit.
//
//  Presented as a sheet from the Units tab rather than a pushed screen:
//  adding three units in a row should not mean three navigations back.
//

import SwiftUI

// MARK: - View Model

@MainActor
@Observable
final class UnitFormViewModel: ValidatedForm {

    enum Mode: Equatable {
        case create(propertyID: String)
        case edit(unitID: String)

        var title: String {
            switch self {
            case .create: "New Unit"
            case .edit:   "Edit Unit"
            }
        }

        var submitTitle: String {
            switch self {
            case .create: "Add Unit"
            case .edit:   "Save Changes"
            }
        }
    }

    let mode: Mode

    let label      = Field(rules: [.required("Label"), .maxLength(40)])
    let squareFeet = Field(rules: [.integer(in: 0...100_000, "Square feet")])
    let rent       = Field(rules: [.required("Rent"), .currency(min: 0, "Rent")])

    var bedrooms = 1
    var bathrooms = 1
    var floor = 1

    private(set) var isSubmitting = false
    private(set) var submitError: AppError?

    private let repository: PropertyRepositoryProtocol

    init(mode: Mode, repository: PropertyRepositoryProtocol, existing: PropertyUnit? = nil) {
        self.mode = mode
        self.repository = repository

        if let existing {
            label.reset(to: existing.name)
            bedrooms = existing.beds
            bathrooms = existing.baths
            if existing.sqft > 0 { squareFeet.reset(to: String(existing.sqft)) }
            rent.reset(to: String(existing.rent))
        }
    }

    var fields: [Field] { [label, squareFeet, rent] }

    var draft: UnitDraft {
        UnitDraft(
            label: label.trimmed,
            bedrooms: bedrooms,
            bathrooms: Decimal(bathrooms),
            squareFeet: squareFeet.intValue,
            marketRent: rent.decimalValue ?? 0,
            floor: floor
        )
    }

    func submit() async -> PropertyUnit? {
        guard validateAll(), !isSubmitting else { return nil }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            switch mode {
            case .create(let propertyID):
                return try await repository.createUnit(draft, propertyID: propertyID)
            case .edit(let unitID):
                return try await repository.updateUnit(id: unitID, with: draft)
            }
        } catch {
            submitError = AppError.from(error)
            return nil
        }
    }
}

// MARK: - View

struct UnitFormView: View {

    @State private var viewModel: UnitFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    @State private var showsDiscardPrompt = false

    private let onSaved: (PropertyUnit) -> Void

    init(
        mode: UnitFormViewModel.Mode,
        existing: PropertyUnit? = nil,
        container: AppContainer = .shared,
        onSaved: @escaping (PropertyUnit) -> Void = { _ in }
    ) {
        self.onSaved = onSaved
        _viewModel = State(initialValue: UnitFormViewModel(
            mode: mode,
            repository: container.properties,
            existing: existing
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSAmbientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.lg) {
                        DSCard(style: .raised) {
                            VStack(spacing: DS.Spacing.lg) {
                                DSFormField(title: "Label", field: viewModel.label,
                                            placeholder: "Suite 402")

                                HStack(spacing: DS.Spacing.md) {
                                    DSStepperField(title: "Bedrooms",
                                                   value: $viewModel.bedrooms, range: 0...8)
                                    DSStepperField(title: "Bathrooms",
                                                   value: $viewModel.bathrooms, range: 1...6)
                                }
                            }
                        }
                        .dsEntrance(index: 0)

                        DSCard(style: .raised) {
                            VStack(spacing: DS.Spacing.lg) {
                                DSFormField(title: "Monthly rent", field: viewModel.rent,
                                            placeholder: "2400", icon: DS.Icons.payment,
                                            keyboard: .decimalPad)
                                HStack(spacing: DS.Spacing.md) {
                                    DSFormField(title: "Square feet", field: viewModel.squareFeet,
                                                placeholder: "740", keyboard: .numberPad,
                                                isOptional: true)
                                    DSStepperField(title: "Floor",
                                                   value: $viewModel.floor, range: 0...60)
                                }
                            }
                        }
                        .dsEntrance(index: 1)

                        if let error = viewModel.submitError {
                            AuthFormError(message: error.errorDescription ?? "Couldn't save.")
                        }

                        DSButton(
                            title: viewModel.mode.submitTitle,
                            variant: .primary,
                            size: .large,
                            isFullWidth: true,
                            isLoading: viewModel.isSubmitting
                        ) {
                            save()
                        }
                        .disabled(viewModel.isSubmitting)
                        .dsEntrance(index: 2)
                    }
                    .padding(DS.Spacing.lg)
                    .animation(DS.Motion.gentle, value: viewModel.submitError)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(viewModel.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.isDirty { showsDiscardPrompt = true } else { dismiss() }
                    }
                }
            }
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showsDiscardPrompt,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func save() {
        Task {
            if let unit = await viewModel.submit() {
                onSaved(unit)
                toasts.success("\(unit.name) saved")
                dismiss()
            }
        }
    }
}

// MARK: - Previews

#Preview("New Unit") {
    UnitFormView(mode: .create(propertyID: "preview"), container: .preview)
}
