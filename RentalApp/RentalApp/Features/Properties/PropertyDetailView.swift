//
//  PropertyDetailView.swift
//  RentalApp (Purrperty)
//
//  Properties — Detail screen: hero header with parallax feel,
//  animated segmented tabs (Overview / Units / Tenants / Maintenance /
//  Documents / Analytics), and directional tab transitions.
//

import SwiftUI

// MARK: - Tabs

enum PropertyDetailTab: Int, CaseIterable, Identifiable {
    case overview
    case units
    case tenants
    case maintenance
    case documents
    case analytics

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .units: "Units"
        case .tenants: "Tenants"
        case .maintenance: "Maintenance"
        case .documents: "Documents"
        case .analytics: "Analytics"
        }
    }

    var icon: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .units: DS.Icons.unit
        case .tenants: DS.Icons.tenants
        case .maintenance: DS.Icons.maintenance
        case .documents: DS.Icons.documents
        case .analytics: DS.Icons.reports
        }
    }
}

// MARK: - Detail View

struct PropertyDetailView: View {

    let propertyID: String

    init(propertyID: String, container: AppContainer = .shared) {
        self.propertyID = propertyID
        _viewModel = State(initialValue: PropertyDetailViewModel(
            propertyID: propertyID,
            repository: container.properties
        ))
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts
    @State private var viewModel: PropertyDetailViewModel
    @State private var showsEditSheet = false
    @State private var pendingConfirmation: DSConfirmation?
    @State private var selectedTab: PropertyDetailTab = .overview
    @State private var movesForward = true

    private var property: Property? { viewModel.property }

    var body: some View {
        ZStack {
            DSAmbientBackground()

            if let property {
                content(for: property)
            } else if let error = viewModel.error {
                DSErrorView(error: error) { await viewModel.retry() }
            } else {
                DSCardSkeleton(cards: 2).padding(DS.Spacing.lg)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .task(id: selectedTab) { await viewModel.loadTab(selectedTab) }
        .dsConfirmation($pendingConfirmation)
        .sheet(isPresented: $showsEditSheet) {
            if let property {
                PropertyFormView(
                    mode: .edit(propertyID: property.id),
                    existing: property
                ) { _ in
                    // Re-read rather than splice: the detail screen shows
                    // derived figures (occupancy, revenue) that the form
                    // does not carry, so a spliced row would show stale
                    // aggregates next to fresh text.
                    Task { await viewModel.refresh() }
                }
            }
        }
    }

    // MARK: Actions

    private func archive(_ property: Property) {
        Task {
            do {
                try await viewModel.archive()
                toasts.success("\(property.name) archived", mood: .saved)
                dismiss()
            } catch {
                toasts.failure(AppError.from(error)) { archive(property) }
            }
        }
    }

    private func confirmDelete(_ property: Property) {
        pendingConfirmation = DSConfirmation(
            title: "Delete \(property.name)?",
            message: "This can't be undone. Units and history are removed with it.",
            confirmTitle: "Delete"
        ) {
            Task {
                do {
                    try await viewModel.delete()
                    toasts.success("\(property.name) deleted", mood: .goodbye)
                    dismiss()
                } catch {
                    toasts.failure(AppError.from(error))
                }
            }
        }
    }

    // MARK: Content

    private func content(for property: Property) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                hero(for: property)

                tabBar
                    .padding(.vertical, DS.Spacing.md)

                tabContent(for: property)
                    .id(selectedTab)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: movesForward ? .trailing : .leading)
                                .combined(with: .opacity),
                            removal: .move(edge: movesForward ? .leading : .trailing)
                                .combined(with: .opacity)
                        )
                    )
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.huge)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: Hero

    private func hero(for property: Property) -> some View {
        ZStack(alignment: .bottomLeading) {
            PropertyHeroImage(property: property, height: 260, showsKind: false)

            LinearGradient(
                colors: [.clear, DS.Colors.mediaBackground.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Title block.
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    PropertyKindChip(kind: property.kind)
                    PropertyOccupancyBadge(property: property)
                }

                Text(property.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.onFixedColor)

                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(property.neighborhood) · \(property.address)")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(DS.Colors.onFixedColor)
            }
            .padding(DS.Spacing.lg)
            .dsEntrance(index: 0)

            // Top controls.
            VStack {
                HStack {
                    DSIconButton(icon: "chevron.left", diameter: 38) {
                        dismiss()
                    }

                    Spacer()

                    Menu {
                        Button {
                            showsEditSheet = true
                        } label: {
                            Label("Edit Property", systemImage: "pencil")
                        }

                        Button {
                            archive(property)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }

                        Divider()

                        Button(role: .destructive) {
                            confirmDelete(property)
                        } label: {
                            Label("Delete Property", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: DS.Icons.more)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(DS.Colors.surfaceRaised, in: Circle())
                            .overlay(Circle().strokeBorder(DS.Colors.outline, lineWidth: 1))
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, 56)

                Spacer()
            }
        }
        .frame(height: 260)
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            SakugaTabs(
                values: PropertyDetailTab.allCases, title: \.title,
                selection: Binding(get: { selectedTab }, set: { tab in
                    movesForward = tab.rawValue > selectedTab.rawValue
                    withAnimation(DS.Motion.smooth) { selectedTab = tab }
                })
            )
            .frame(width: CGFloat(PropertyDetailTab.allCases.count) * 112)
            // Room for the ears and the shadow.
            .padding(.top, 20)
            .padding(.bottom, 12)
            .padding(.horizontal, DS.Spacing.lg)
        }
        .scrollClipDisabled()
    }

    // MARK: Tab Content

    @ViewBuilder
    private func tabContent(for property: Property) -> some View {
        switch selectedTab {
        case .overview:
            PropertyOverviewTab(property: property, viewModel: viewModel)
        case .units:
            PropertyUnitsTab(property: property, viewModel: viewModel)
        case .tenants:
            PropertyTenantsTab(property: property, viewModel: viewModel)
        case .maintenance:
            PropertyMaintenanceTab(property: property, viewModel: viewModel)
        case .documents:
            PropertyDocumentsTab(property: property, viewModel: viewModel)
        case .analytics:
            PropertyAnalyticsTab(property: property, viewModel: viewModel)
        }
    }
}

// MARK: - Previews

#Preview("Property Detail") {
    PropertyDetailView(propertyID: "maple-duplex")
        .environment(AppRouter())
}
