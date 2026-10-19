//
//  NewMaintenanceRequestViewModel.swift
//  RentalApp (Purrperty)
//
//  Maintenance — State and rules for the new-request form.
//
//  Picking a property loads its units; picking a unit fills in the
//  tenant from the unit's current lease. Saving goes through the
//  repository, then tells the rest of the app through the sync engine so
//  the inbox behind the sheet refreshes.
//

import SwiftUI
import Observation

/// A unit the request is fixed to, when the person reporting it lives
/// there — a tenant reports for their own home and nowhere else.
struct RequestLocation: Sendable, Equatable {
    let propertyID: String
    let propertyName: String
    let unitID: String
    let unitName: String
    let tenantName: String
}

@MainActor
@Observable
final class NewMaintenanceRequestViewModel {

    // MARK: Dependencies

    private let maintenance: MaintenanceRepositoryProtocol
    private let properties: PropertyRepositoryProtocol
    private let sync: SyncEngine
    private let analytics: AnalyticsService

    // MARK: State

    var draft = MaintenanceRequestDraft()
    private(set) var propertyOptions: [Property] = []
    private(set) var unitOptions: [PropertyUnit] = []
    private(set) var isLoadingProperties = false
    private(set) var isLoadingUnits = false
    private(set) var isPreparingPhotos = false
    private(set) var isSubmitting = false
    var errorMessage: String?
    /// Set when a tenant is reporting: the location can't be changed.
    let fixedLocation: RequestLocation?

    init(
        maintenance: MaintenanceRepositoryProtocol,
        properties: PropertyRepositoryProtocol,
        sync: SyncEngine,
        analytics: AnalyticsService,
        fixedLocation: RequestLocation? = nil
    ) {
        self.maintenance = maintenance
        self.properties = properties
        self.sync = sync
        self.analytics = analytics
        self.fixedLocation = fixedLocation
        if let fixedLocation {
            draft.propertyID = fixedLocation.propertyID
            draft.propertyName = fixedLocation.propertyName
            draft.unitID = fixedLocation.unitID
            draft.unitName = fixedLocation.unitName
            draft.tenantName = fixedLocation.tenantName
        }
    }

    var isTenantReporting: Bool { fixedLocation != nil }

    // MARK: Derived

    var canSubmit: Bool {
        draft.propertyID != nil
            && draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
            && !isSubmitting && !isPreparingPhotos
    }

    /// Something worth confirming before it's thrown away.
    var hasChanges: Bool {
        var untouched = MaintenanceRequestDraft()
        if let fixedLocation {
            untouched.propertyID = fixedLocation.propertyID
            untouched.propertyName = fixedLocation.propertyName
            untouched.unitID = fixedLocation.unitID
            untouched.unitName = fixedLocation.unitName
            untouched.tenantName = fixedLocation.tenantName
        }
        return draft != untouched
    }

    var remainingPhotoSlots: Int {
        MaintenanceRequestDraft.maxPhotos - draft.photos.count
    }

    // MARK: Loading

    func load() async {
        guard fixedLocation == nil, propertyOptions.isEmpty else { return }
        isLoadingProperties = true
        defer { isLoadingProperties = false }
        do {
            let query = PropertyQuery(
                filter: .all,
                sort: SortOrder(.name),
                page: PageRequest(page: 0, size: 200)
            )
            propertyOptions = try await properties.properties(matching: query, forceRefresh: false).items
            // One property? Nothing to choose.
            if propertyOptions.count == 1, let only = propertyOptions.first {
                await selectProperty(id: only.id)
            }
        } catch {
            errorMessage = (error as? AppError ?? .unknown).errorDescription
        }
    }

    // MARK: Selection

    func selectProperty(id: String?) async {
        guard id != draft.propertyID else { return }
        draft.propertyID = id
        draft.propertyName = propertyOptions.first { $0.id == id }?.name ?? ""
        selectUnit(id: nil)
        unitOptions = []

        guard let id else { return }
        isLoadingUnits = true
        defer { isLoadingUnits = false }
        unitOptions = (try? await properties.units(forPropertyID: id)) ?? []
    }

    /// Nil selects the common area, which has no tenant.
    func selectUnit(id: String?) {
        let unit = unitOptions.first { $0.id == id }
        draft.unitID = unit?.id
        draft.unitName = unit?.displayName ?? ""
        draft.tenantName = unit?.tenantName
    }

    // MARK: Photos

    /// Downscales and attaches picked photos, up to the limit.
    func attachPhotos(_ originals: [Data]) async {
        isPreparingPhotos = true
        defer { isPreparingPhotos = false }
        for data in originals.prefix(remainingPhotoSlots) {
            if let jpeg = await ImageDownscaler.jpeg(from: data) {
                draft.photos.append(jpeg)
            }
        }
    }

    func removePhoto(at index: Int) {
        guard draft.photos.indices.contains(index) else { return }
        draft.photos.remove(at: index)
    }

    // MARK: Submit

    /// The new ticket on success; nil with `errorMessage` set on failure.
    func submit() async -> MaintenanceTicket? {
        guard canSubmit else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        do {
            let ticket = try await maintenance.create(draft)
            await analytics.track(.maintenanceTicketCreated(priority: draft.priority.title.lowercased()))
            await sync.publishLocalChange(.maintenanceRequests)
            return ticket
        } catch {
            errorMessage = (error as? AppError ?? .unknown).errorDescription
            return nil
        }
    }
}
