//
//  TenantListView.swift
//  RentalApp (RentOS)
//
//  Tenants — Directory: summary strip, animated search, status
//  filters, sort, and tenant rows that animate through changes.
//

import SwiftUI

struct TenantListView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.container) private var container
    @State private var viewModel: TenantListViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: TenantListViewModel(repository: container.tenants))
    }

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {

                    // Summary strip.
                    DSCard(style: .glass, padding: DS.Spacing.lg) {
                        HStack(spacing: DS.Spacing.lg) {
                            summaryItem(value: "\(viewModel.totalCount)", label: "Tenants")
                            divider
                            summaryItem(value: "\(viewModel.activeCount)", label: "Active")
                            divider
                            summaryItem(value: "\(viewModel.renewalsSoonCount)", label: "Renewals soon")
                            divider
                            summaryItem(
                                value: "\(viewModel.overdueCount)",
                                label: "Overdue",
                                valueColor: viewModel.overdueCount > 0 ? DS.Colors.danger : DS.Colors.textPrimary
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .dsEntrance(index: 0)

                    // Search + sort.
                    HStack(spacing: DS.Spacing.md) {
                        DSSearchBar(text: $viewModel.searchText, placeholder: "Search tenants, units…")

                        Menu {
                            ForEach(TenantSortField.allCases) { option in
                                Button {
                                    viewModel.sortField = option
                                } label: {
                                    if viewModel.sortField == option {
                                        Label(option.label, systemImage: "checkmark")
                                    } else {
                                        Text(option.label)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: DS.Icons.sort)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DS.Colors.brand)
                                .frame(width: 46, height: 46)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                        .strokeBorder(DS.Colors.outline, lineWidth: 1)
                                )
                        }
                        .accessibilityLabel("Sort tenants")
                    }
                    .dsEntrance(index: 1)

                    // Filter chips.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(TenantFilter.allCases) { filter in
                                DSChip(
                                    title: filter.rawValue,
                                    icon: filter.icon,
                                    isSelected: viewModel.filter == filter
                                ) {
                                    viewModel.filter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .dsEntrance(index: 2)

                    // Rows.
                    if viewModel.isLoading {
                        DSListSkeleton(rows: 6)
                    } else if let error = viewModel.error {
                        DSErrorView(error: error) { await viewModel.retry() }
                    } else if viewModel.isEmpty {
                        DSEmptyState(
                            icon: DS.Icons.tenants,
                            title: "No tenants found",
                            message: "Try a different search or filter, or add your first tenant.",
                            actionTitle: "Add Tenant",
                            action: { router.present(.newTenant) }
                        )
                        .padding(.top, DS.Spacing.xxl)
                    } else {
                        LazyVStack(spacing: DS.Spacing.md) {
                            ForEach(Array(viewModel.filteredTenants.enumerated()), id: \.element.id) { index, tenant in
                                TenantRow(tenant: tenant) {
                                    router.push(.tenantDetail(tenantID: tenant.id))
                                }
                                .dsEntrance(index: min(3 + index, 12))
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                                .task { await viewModel.loadMoreIfNeeded(currentItem: tenant) }
                            }

                            DSPaginationFooter(isLoading: viewModel.isLoadingMore)
                        }
                    }
                }
                .padding(DS.Spacing.lg)
                .padding(.bottom, DSTabBar.overlayClearance)
                .animation(DS.Motion.smooth, value: viewModel.filteredTenants.map(\.id))
            }
            .refreshable { await viewModel.refresh() }
        }
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .tenants) {
                await viewModel.refresh()
            }
        }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .leases) {
                await viewModel.refresh()
            }
        }
        .dsHeader(
            title: "Tenants",
            subtitle: "\(viewModel.activeCount) active leases",
            showsBack: true,
            trailingActions: [
                DSHeaderAction(icon: DS.Icons.add) {
                    router.present(.newTenant)
                }
            ]
        )
        .overlay(alignment: .bottomTrailing) {
            DSFloatingActionButton(icon: "person.badge.plus") {
                router.present(.newTenant)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DSTabBar.overlayClearance)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.Colors.outline)
            .frame(width: 0.5, height: 32)
    }

    private func summaryItem(
        value: String,
        label: String,
        valueColor: Color = DS.Colors.textPrimary
    ) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Typography.statValueSmall)
                .foregroundStyle(valueColor)

            Text(label)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
