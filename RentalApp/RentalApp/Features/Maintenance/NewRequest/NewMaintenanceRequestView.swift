//
//  NewMaintenanceRequestView.swift
//  RentalApp (Purrperty)
//
//  Maintenance — The new-request form: where, what, how urgent, photos
//  and access. A system form in a sheet, with Cancel and Add in the
//  standard places, like Reminders or Calendar.
//

import SwiftUI
import PhotosUI

struct NewMaintenanceRequestView: View {

    @State private var viewModel: NewMaintenanceRequestViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsDiscardPrompt = false
    @FocusState private var focus: Field?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    private enum Field { case title, details }

    init(container: AppContainer) {
        _viewModel = State(initialValue: NewMaintenanceRequestViewModel(
            maintenance: container.maintenance,
            properties: container.properties,
            sync: container.sync,
            analytics: container.analytics
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                locationSection
                problemSection
                prioritySection
                photosSection
                accessSection

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, symbol: .caution)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await viewModel.load() }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await attach(items) }
            }
            .interactiveDismissDisabled(viewModel.hasChanges)
            .confirmationDialog("Discard this request?", isPresented: $showsDiscardPrompt, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: AppSymbol.close.rawValue) {
                if viewModel.hasChanges { showsDiscardPrompt = true } else { dismiss() }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            if viewModel.isSubmitting {
                ProgressView()
            } else {
                Button("Add", systemImage: AppSymbol.done.rawValue) { submit() }
                    .disabled(!viewModel.canSubmit)
            }
        }
    }

    // MARK: Where

    private var locationSection: some View {
        Section {
            Picker("Property", selection: propertySelection) {
                if viewModel.draft.propertyID == nil {
                    Text("Choose").tag(String?.none)
                }
                ForEach(viewModel.propertyOptions) { property in
                    Text(property.name).tag(String?.some(property.id))
                }
            }
            .disabled(viewModel.isLoadingProperties)

            if viewModel.draft.propertyID != nil {
                Picker("Unit", selection: unitSelection) {
                    Text("Common area").tag(String?.none)
                    ForEach(viewModel.unitOptions) { unit in
                        Text(unit.displayName).tag(String?.some(unit.id))
                    }
                }
                .disabled(viewModel.isLoadingUnits)

                if viewModel.draft.unitID != nil {
                    LabeledContent("Tenant", value: viewModel.draft.tenantName ?? "Vacant")
                }
            }
        } header: {
            Text("Where")
        }
    }

    // MARK: What

    private var problemSection: some View {
        @Bindable var viewModel = viewModel

        return Section {
            TextField("What's wrong?", text: $viewModel.draft.title)
                .focused($focus, equals: .title)
                .submitLabel(.next)
                .onSubmit { focus = .details }

            TextField("Details", text: $viewModel.draft.details, prompt: Text("Details (optional)"), axis: .vertical)
                .lineLimit(3...8)
                .focused($focus, equals: .details)

            Picker("Category", selection: $viewModel.draft.category) {
                ForEach(TicketCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.icon).tag(category)
                }
            }
        } header: {
            Text("Problem")
        } footer: {
            Text("For example, \"Kitchen sink leaking\".")
        }
    }

    // MARK: Urgency

    private var prioritySection: some View {
        @Bindable var viewModel = viewModel

        return Section {
            Picker("Priority", selection: $viewModel.draft.priority) {
                ForEach(TicketPriority.allCases) { priority in
                    Text(priority.title).tag(priority)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Text("Priority")
        } footer: {
            Text(priorityFooter)
        }
    }

    private var priorityFooter: String {
        switch viewModel.draft.priority {
        case .urgent: "No heat, no water, an active leak or anything unsafe."
        case .high:   "Needs fixing within a day or two."
        case .medium: "Needs fixing this week."
        case .low:    "Whenever it's convenient."
        }
    }

    // MARK: Photos

    private var photosSection: some View {
        // Read on the main actor; PhotosPicker's label closure isn't.
        let isPreparing = viewModel.isPreparingPhotos

        return Section {
            if !viewModel.draft.photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(viewModel.draft.photos.enumerated()), id: \.offset) { index, data in
                            AttachedPhoto(data: data, number: index + 1) {
                                withAnimation { viewModel.removePhoto(at: index) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: max(viewModel.remainingPhotoSlots, 1),
                matching: .images
            ) {
                HStack {
                    Label("Add Photos", systemImage: "photo.badge.plus")
                    if isPreparing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.remainingPhotoSlots == 0 || viewModel.isPreparingPhotos)
        } header: {
            Text("Photos")
        } footer: {
            Text("Up to \(MaintenanceRequestDraft.maxPhotos). A clear photo helps the vendor bring the right part.")
        }
    }

    // MARK: Access

    private var accessSection: some View {
        @Bindable var viewModel = viewModel

        return Section {
            Toggle("Tenant allows entry", isOn: $viewModel.draft.access.permissionToEnter.animation())
            if viewModel.draft.access.permissionToEnter {
                Picker("Best time", selection: $viewModel.draft.access.window) {
                    ForEach(AccessWindow.allCases) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
            }
        } header: {
            Text("Access")
        } footer: {
            Text(viewModel.draft.access.permissionToEnter
                 ? "The vendor can let themselves in during this time."
                 : "Without permission, give 24 hours' written notice before entering, unless it's an emergency.")
        }
    }

    // MARK: Bindings

    private var propertySelection: Binding<String?> {
        Binding(
            get: { viewModel.draft.propertyID },
            set: { id in Task { await viewModel.selectProperty(id: id) } }
        )
    }

    private var unitSelection: Binding<String?> {
        Binding(
            get: { viewModel.draft.unitID },
            set: { viewModel.selectUnit(id: $0) }
        )
    }

    // MARK: Actions

    private func attach(_ items: [PhotosPickerItem]) async {
        var originals: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                originals.append(data)
            }
        }
        pickerItems = []
        await viewModel.attachPhotos(originals)
    }

    private func submit() {
        focus = nil
        Task {
            if let ticket = await viewModel.submit() {
                toasts.success("Request added: \(ticket.title)")
                dismiss()
            }
        }
    }
}

// MARK: - Attached Photo

/// A thumbnail with a remove button. Equatable on its data, so typing in
/// the form doesn't decode every photo again.
private struct AttachedPhoto: View, Equatable {

    let data: Data
    let number: Int
    let onRemove: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data == rhs.data && lhs.number == rhs.number
    }

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            Button("Remove photo \(number)", systemImage: "xmark.circle.fill", action: onRemove)
                .labelStyle(.iconOnly)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.6))
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44, alignment: .topTrailing)
                .padding(2)
                .buttonStyle(.plain)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Photo \(number)")
    }
}

// MARK: - Previews

#Preview("New request") {
    NewMaintenanceRequestView(container: .preview)
}
