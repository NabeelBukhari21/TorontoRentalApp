//
//  UnitDetailView.swift
//  RentalApp (Purrperty)
//
//  Properties — One unit: its details, who lives there, and its repairs.
//  Reached from a property's Units tab and from search.
//

import SwiftUI
import Observation
import OSLog

// MARK: - View Model

@MainActor
@Observable
final class UnitDetailViewModel {

    private let properties: PropertyRepositoryProtocol
    private let maintenance: MaintenanceRepositoryProtocol
    let unitID: String

    private(set) var state: LoadState<UnitDetail> = .idle
    private(set) var requests: [MaintenanceTicket] = []

    init(unitID: String, properties: PropertyRepositoryProtocol, maintenance: MaintenanceRepositoryProtocol) {
        self.unitID = unitID
        self.properties = properties
        self.maintenance = maintenance
    }

    var detail: UnitDetail? { state.value }

    /// Open requests first, then the rest, newest first within each.
    var openRequests: [MaintenanceTicket] { requests.filter { $0.status != .done } }
    var closedRequests: [MaintenanceTicket] { requests.filter { $0.status == .done } }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await properties.unit(id: unitID))
            let query = MaintenanceQuery(
                filter: MaintenanceFilter(unitID: unitID),
                sort: SortOrder(.createdAt, .descending),
                page: PageRequest(page: 0, size: 100)
            )
            requests = try await maintenance.tickets(matching: query, forceRefresh: false).items
        } catch is CancellationError {
            // The screen went away mid-load; the next appearance tries again.
        } catch {
            AppLog.sync.failure("Unit load failed", error: error)
            if state.value == nil {
                state = .failed(error as? AppError ?? .unknown)
            }
        }
    }
}

// MARK: - View

struct UnitDetailView: View {

    @State private var viewModel: UnitDetailViewModel
    @State private var isEditing = false
    @Environment(\.container) private var container

    init(unitID: String, container: AppContainer = .shared) {
        _viewModel = State(initialValue: UnitDetailViewModel(
            unitID: unitID,
            properties: container.properties,
            maintenance: container.maintenance
        ))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                ContentUnavailableView {
                    Label("Couldn't Load This Unit", symbol: .caution)
                } description: {
                    Text(error.errorDescription ?? "")
                } actions: {
                    Button("Try Again") { Task { await viewModel.load() } }
                }
            case .loaded(let detail):
                content(detail)
            }
        }
        .background(Color.groupedBackground)
        .navigationTitle(viewModel.detail?.unit.displayName ?? "Unit")
        .navigationSubtitle(viewModel.detail?.propertyName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let unit = viewModel.detail?.unit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { isEditing = true }
                        .accessibilityHint("Edit \(unit.displayName)")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let unit = viewModel.detail?.unit {
                UnitFormView(mode: .edit(unitID: unit.id), existing: unit) { _ in
                    Task { await viewModel.load() }
                }
            }
        }
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .maintenanceRequests) { await viewModel.load() }
        }
    }

    private func content(_ detail: UnitDetail) -> some View {
        let unit = detail.unit
        return List {
            Section {
                LabeledContent("Status") {
                    StatusLabel(unit.status.rawValue, role: unit.status.role)
                }
                LabeledContent("Bedrooms", value: unit.beds == 0 ? "Studio" : "\(unit.beds)")
                LabeledContent("Bathrooms", value: "\(unit.baths)")
                if unit.sqft > 0 {
                    LabeledContent("Size", value: "\(unit.sqft.formatted()) sq ft")
                }
                LabeledContent(unit.tenantName == nil ? "Asking rent" : "Rent") {
                    Text(unit.rent, format: .cad)
                }
                NavigationLink(value: AppRoute.propertyDetail(propertyID: detail.propertyID)) {
                    LabeledContent("Property", value: detail.propertyName)
                }
            }

            Section("Tenant") {
                if let name = unit.tenantName {
                    if let tenantID = unit.tenantID {
                        NavigationLink(value: AppRoute.tenantDetail(tenantID: tenantID)) {
                            Label(name, systemImage: AppSymbol.person.rawValue)
                        }
                    } else {
                        Label(name, systemImage: AppSymbol.person.rawValue)
                    }
                } else {
                    Text("Vacant. Add a tenant from Tenants when it's leased.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if viewModel.requests.isEmpty {
                    Text("No repair requests for this unit.")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.openRequests + viewModel.closedRequests) { ticket in
                    NavigationLink(value: AppRoute.maintenanceDetail(requestID: ticket.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ticket.title)
                                .lineLimit(2)
                            HStack(spacing: 12) {
                                StatusLabel(ticket.status.title, role: ticket.status.role)
                                Text(ticket.createdAgo)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } header: {
                Text("Repairs")
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.load() }
    }
}

// MARK: - Status Role

extension PropertyUnit.UnitStatus {
    var role: StatusRole {
        switch self {
        case .occupied: .positive
        case .vacant: .caution
        case .notice: .informational
        }
    }
}

// MARK: - Previews

#Preview("Unit") {
    NavigationStack {
        UnitDetailView(unitID: "preview", container: .preview)
    }
}
