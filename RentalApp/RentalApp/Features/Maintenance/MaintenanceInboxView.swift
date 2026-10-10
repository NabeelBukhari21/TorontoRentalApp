//
//  MaintenanceInboxView.swift
//  RentalApp (Purrperty)
//
//  Maintenance — The flagship inbox. Animated list ⇄ kanban modes,
//  priority filters, and tickets that glide between columns.
//

import SwiftUI

// MARK: - Inbox View

struct MaintenanceInboxView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.container) private var container
    @State private var viewModel: MaintenanceInboxViewModel
    @Namespace private var modeNamespace

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: MaintenanceInboxViewModel(
            repository: container.maintenance,
            notifications: container.notifications
        ))
    }

    var body: some View {
        ZStack {
            DSAmbientBackground()

            VStack(spacing: DS.Spacing.md) {
                controls

                if viewModel.mode == .list {
                    listMode
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                } else {
                    boardMode
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .maintenanceRequests) {
                await viewModel.refresh()
            }
        }
        .refreshable { await viewModel.refresh() }
        .dsHeader(
            title: "Maintenance",
            subtitle: "\(viewModel.openCount) open · \(viewModel.urgentCount) urgent",
            trailingActions: [
                DSHeaderAction(icon: DS.Icons.notifications, badge: viewModel.unreadNotifications) {
                    router.push(.notifications)
                },
                DSHeaderAction(icon: DS.Icons.tenant) {
                    router.push(.profile)
                }
            ]
        )
        .overlay(alignment: .bottomTrailing) {
            DSFloatingActionButton {
                router.present(.newMaintenanceRequest)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DSTabBar.overlayClearance)
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: DS.Spacing.md) {
            // Stats strip.
            DSCard(style: .raised, padding: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.lg) {
                    stat(value: "\(viewModel.openCount)", label: "Open")
                    statDivider
                    stat(
                        value: "\(viewModel.urgentCount)",
                        label: "Urgent",
                        color: viewModel.urgentCount > 0 ? DS.Colors.danger : DS.Colors.textPrimary
                    )
                    statDivider
                    stat(value: "\(viewModel.unassignedCount)", label: "Unassigned")
                    statDivider
                    stat(value: viewModel.averageResolutionText, label: "Avg resolve")
                }
                .frame(maxWidth: .infinity)
            }
            .dsEntrance(index: 0)

            // Search + mode toggle.
            HStack(spacing: DS.Spacing.md) {
                DSSearchBar(text: $viewModel.searchText, placeholder: "Search requests…")

                modeToggle
            }
            .dsEntrance(index: 1)

            // Priority filter chips.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    DSChip(title: "All", isSelected: viewModel.priorityFilter == nil) {
                        viewModel.priorityFilter = nil
                    }

                    ForEach(TicketPriority.allCases) { priority in
                        DSChip(
                            title: priority.title,
                            icon: priority.icon,
                            isSelected: viewModel.priorityFilter == priority
                        ) {
                            viewModel.priorityFilter =
                                viewModel.priorityFilter == priority ? nil : priority
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .dsEntrance(index: 2)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var modeToggle: some View {
        HStack(spacing: 2) {
            ForEach(MaintenanceViewMode.allCases) { mode in
                Button {
                    withAnimation(DS.Motion.smooth) { viewModel.mode = mode }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.mode == mode ? DS.Colors.textOnBrand : DS.Colors.textSecondary)
                        .frame(width: 40, height: 38)
                        .background {
                            if viewModel.mode == mode {
                                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                    .fill(DS.Gradients.brand)
                                    .matchedGeometryEffect(id: "mode.pill", in: modeNamespace)
                            }
                        }
                }
                .buttonStyle(DSPressStyle(scale: 0.92))
                .accessibilityLabel("\(mode.rawValue) view")
            }
        }
        .padding(3)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Colors.outline, lineWidth: 1)
        )
    }

    private var statDivider: some View {
        Rectangle().fill(DS.Colors.outline).frame(width: 0.5, height: 28)
    }

    private func stat(value: String, label: String, color: Color = DS.Colors.textPrimary) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(DS.Typography.statValueSmall)
                .foregroundStyle(color)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: List Mode

    private var listMode: some View {
        ScrollView(showsIndicators: false) {
            if viewModel.isLoading {
                DSListSkeleton(rows: 6)
                    .padding(.horizontal, DS.Spacing.lg)
            } else if let error = viewModel.error {
                DSErrorView(error: error) { await viewModel.retry() }
            } else if viewModel.isEmpty {
                DSEmptyState(
                    icon: "checkmark.seal.fill",
                    title: "Inbox zero",
                    message: "No requests match — enjoy the quiet while it lasts."
                )
                .padding(.top, DS.Spacing.huge)
            } else {
                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(Array(viewModel.filteredTickets.enumerated()), id: \.element.id) { index, ticket in
                        TicketCard(ticket: ticket) {
                            router.push(.maintenanceDetail(requestID: ticket.id))
                        }
                        .dsEntrance(index: min(index, 12))
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .task { await viewModel.loadMoreIfNeeded(currentItem: ticket) }
                    }

                    DSPaginationFooter(isLoading: viewModel.isLoadingMore)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DSTabBar.overlayClearance)
                .animation(DS.Motion.smooth, value: viewModel.filteredTickets.map(\.id))
            }
        }
    }

    // MARK: Board Mode

    private var boardMode: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                ForEach(TicketStatus.allCases) { status in
                    kanbanColumn(status)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DSTabBar.overlayClearance)
        }
    }

    private func kanbanColumn(_ status: TicketStatus) -> some View {
        let tickets = viewModel.columnTickets(status)

        return VStack(spacing: DS.Spacing.md) {
            // Column header.
            HStack(spacing: DS.Spacing.sm) {
                DSStatusDot(kind: status.kind, pulses: status == .new && !tickets.isEmpty)

                Text(status.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)

                Spacer()

                Text("\(tickets.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(status.kind.color)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(status.kind.tint, in: Capsule())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DS.Spacing.xs)

            // Cards.
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.sm) {
                    if tickets.isEmpty {
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: status.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(DS.Colors.textTertiary.opacity(0.5))
                            Text("Nothing here")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xxl)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(DS.Colors.outline, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                    } else {
                        ForEach(tickets) { ticket in
                            KanbanTicketCard(
                                ticket: ticket,
                                action: {
                                    router.push(.maintenanceDetail(requestID: ticket.id))
                                },
                                onMove: { newStatus in
                                    Task { await viewModel.move(ticket.id, to: newStatus) }
                                }
                            )
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                }
                .animation(DS.Motion.bouncy, value: tickets.map(\.id))
            }
        }
        .frame(width: 258)
        .padding(DS.Spacing.md)
        .background(
            DS.Colors.surfaceSecondary.opacity(0.5),
            in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(DS.Colors.outline, lineWidth: 1)
        )
    }
}
