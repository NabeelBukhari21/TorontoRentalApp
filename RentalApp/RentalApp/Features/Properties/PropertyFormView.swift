//
//  PropertyFormView.swift
//  RentalApp (RentOS)
//
//  Properties — Create and edit, one screen.
//
//  ─────────────────────────────────────────────────────────────────
//  ONE FORM, TWO MODES
//  ─────────────────────────────────────────────────────────────────
//  A separate "edit" screen is the classic way these diverge: the
//  create form gains a field, the edit form doesn't, and six months
//  later they validate differently. `Mode` carries the difference —
//  which is only the title, the button label, and whether an id exists.
//

import SwiftUI

// MARK: - View Model

@MainActor
@Observable
final class PropertyFormViewModel: ValidatedForm {

    enum Mode: Equatable {
        case create
        case edit(propertyID: String)

        var title: String {
            switch self {
            case .create: "New Property"
            case .edit:   "Edit Property"
            }
        }

        var submitTitle: String {
            switch self {
            case .create: "Create Property"
            case .edit:   "Save Changes"
            }
        }

        var propertyID: String? {
            if case .edit(let id) = self { return id }
            return nil
        }
    }

    let mode: Mode

    // Fields, each carrying its own rules.
    let name       = Field(rules: [.required("Name"), .minLength(2, "Name"), .maxLength(160)])
    let address    = Field(rules: [.required("Street address")])
    let city       = Field("Toronto", rules: [.required("City")])
    let postalCode = Field(rules: [.postalCode])
    let neighborhood = Field()
    let yearBuilt  = Field(rules: [.integer(in: 1800...2100, "Year built")])
    let squareFeet = Field(rules: [.integer(in: 0...1_000_000, "Square feet")])

    var kind: PropertyKind = .condo

    private(set) var isSubmitting = false
    private(set) var submitError: AppError?

    private let repository: PropertyRepositoryProtocol

    /// Where a version clash goes. Optional so previews and the in-memory
    /// backend — neither of which can produce one — need not supply it.
    private let conflicts: ConflictCenter?

    init(
        mode: Mode,
        repository: PropertyRepositoryProtocol,
        conflicts: ConflictCenter? = nil,
        existing: Property? = nil
    ) {
        self.mode = mode
        self.repository = repository
        self.conflicts = conflicts

        if let existing {
            name.reset(to: existing.name)
            neighborhood.reset(to: existing.neighborhood)
            kind = existing.kind
            if existing.yearBuilt > 0 { yearBuilt.reset(to: String(existing.yearBuilt)) }
            // `Property.address` is a display string ("12 Queen St W,
            // Toronto"); split it back into the two fields the user edits.
            let parts = existing.address.split(separator: ",", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            address.reset(to: parts.first ?? "")
            city.reset(to: parts.count > 1 ? parts[1] : "Toronto")
        }
    }

    var fields: [Field] {
        [name, address, city, postalCode, neighborhood, yearBuilt, squareFeet]
    }

    var draft: PropertyDraft {
        PropertyDraft(
            name: name.trimmed,
            kind: kind,
            addressLine1: address.trimmed,
            city: city.trimmed,
            postalCode: postalCode.trimmed,
            neighborhood: neighborhood.optionalTrimmed,
            yearBuilt: yearBuilt.intValue,
            squareFeet: squareFeet.intValue
        )
    }

    /// Submits and returns the saved property, or nil if it could not be
    /// saved. The caller decides what to do with the result — this view
    /// model does not know about navigation or toasts.
    func submit() async -> Property? {
        guard validateAll() else { return nil }
        guard !isSubmitting else { return nil }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            switch mode {
            case .create:
                return try await repository.createProperty(draft)
            case .edit(let id):
                return try await repository.updateProperty(id: id, with: draft)
            }
        } catch let conflict as PropertyConflict {
            // NOT an `AppError`. Flattening it would show "Something went
            // wrong. Please try again." and drop the user's edit on the
            // floor — the exact outcome the version column exists to
            // prevent. Hand it to the centre, which keeps the edit and asks.
            report(conflict)
            return nil
        } catch {
            submitError = AppError.from(error)
            return nil
        }
    }

    // MARK: Conflicts

    /// Queues a version clash for the user to settle.
    private func report(_ conflict: PropertyConflict) {
        guard let conflicts else {
            // No centre to queue into — better a blunt message than a
            // success the server did not perform.
            submitError = .validation(
                "This property was changed somewhere else. Reopen it to see the current details."
            )
            return
        }

        // Captured by value so the resolution still works after this form is
        // gone, which is the normal case: the sheet is dismissed and the
        // conflict is settled later from the badge.
        let draft = self.draft
        let repository = self.repository
        let recordID = conflict.recordID

        let local: [String: Any?] = [
            "name":                draft.name,
            "kind":                draft.kind.dbValue,
            "address_line1":       draft.addressLine1,
            "address_city":        draft.city,
            "address_postal_code": draft.postalCode,
            "neighborhood":        draft.neighborhood,
            "year_built":          draft.yearBuilt,
            "square_feet":         draft.squareFeet
        ]

        conflicts.report(PendingConflict(
            topic: .properties,
            recordID: recordID,
            title: draft.name,
            differences: PendingConflict.differences(local: local, remote: conflict.remote),
            detectedAt: .now,
            resolve: { choice in
                switch choice {
                case .keepTheirs:
                    // Nothing to write. The server's row already stands.
                    return .succeeded(undo: nil)

                case .keepMine, .merge:
                    // The repository adopted the server's version when it
                    // threw, so this guarded write now targets the current
                    // row instead of conflicting forever against a version
                    // we already know is stale.
                    do {
                        _ = try await repository.updateProperty(id: recordID, with: draft)
                        return .succeeded(undo: nil)
                    } catch {
                        return .failed(AppError.from(error))
                    }
                }
            }
        ))
    }
}

// MARK: - View

struct PropertyFormView: View {

    @State private var viewModel: PropertyFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    @State private var showsDiscardPrompt = false

    /// Handed the saved property so the list can splice it in without a
    /// full reload.
    private let onSaved: (Property) -> Void

    init(
        mode: PropertyFormViewModel.Mode,
        existing: Property? = nil,
        container: AppContainer = .shared,
        onSaved: @escaping (Property) -> Void = { _ in }
    ) {
        self.onSaved = onSaved
        _viewModel = State(initialValue: PropertyFormViewModel(
            mode: mode,
            repository: container.properties,
            conflicts: container.conflicts,
            existing: existing
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSAmbientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.lg) {
                        kindPicker
                            .dsEntrance(index: 0)

                        DSCard(style: .raised) {
                            VStack(spacing: DS.Spacing.lg) {
                                DSFormField(title: "Name", field: viewModel.name,
                                            placeholder: "Queen West Lofts")
                                DSFormField(title: "Street address", field: viewModel.address,
                                            placeholder: "412 Queen St W")
                                HStack(spacing: DS.Spacing.md) {
                                    DSFormField(title: "City", field: viewModel.city)
                                    DSFormField(title: "Postal code", field: viewModel.postalCode,
                                                placeholder: "M5V 2A8")
                                }
                            }
                        }
                        .dsEntrance(index: 1)

                        DSCard(style: .raised) {
                            VStack(spacing: DS.Spacing.lg) {
                                DSFormField(title: "Neighbourhood", field: viewModel.neighborhood,
                                            placeholder: "Queen West", isOptional: true)
                                HStack(spacing: DS.Spacing.md) {
                                    DSFormField(title: "Year built", field: viewModel.yearBuilt,
                                                placeholder: "1998", keyboard: .numberPad,
                                                isOptional: true)
                                    DSFormField(title: "Square feet", field: viewModel.squareFeet,
                                                placeholder: "24000", keyboard: .numberPad,
                                                isOptional: true)
                                }
                            }
                        }
                        .dsEntrance(index: 2)

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
                        // Never disabled on invalid input: tapping is how
                        // the user asks "what's wrong?", and `validateAll`
                        // answers by revealing every error at once.
                        .disabled(viewModel.isSubmitting)
                        .dsEntrance(index: 3)
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
                    Button("Cancel") { attemptDismiss() }
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

    // MARK: Kind

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("TYPE").dsOverline()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(PropertyKind.allCases, id: \.self) { kind in
                        DSChip(
                            title: kind.rawValue,
                            icon: kind.icon,
                            isSelected: viewModel.kind == kind
                        ) {
                            withAnimation(DS.Motion.bouncy) { viewModel.kind = kind }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: Actions

    private func save() {
        Task {
            if let saved = await viewModel.submit() {
                onSaved(saved)
                toasts.success(
                    viewModel.mode.propertyID == nil
                        ? "\(saved.name) created"
                        : "Changes saved"
                )
                dismiss()
            }
        }
    }

    /// Closing a form with unsaved edits is the one place a confirmation
    /// is worth interrupting for — losing typed work is worse than an
    /// extra tap.
    private func attemptDismiss() {
        if viewModel.isDirty {
            showsDiscardPrompt = true
        } else {
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview("Create Property") {
    PropertyFormView(mode: .create, container: .preview)
}
