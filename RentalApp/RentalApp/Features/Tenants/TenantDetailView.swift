//
//  TenantDetailView.swift
//  RentalApp (Purrperty)
//
//  Tenants — Profile: header with large avatar and quick actions,
//  obsidian lease card, and animated tabs for Timeline, Maintenance,
//  Documents, and Messages.
//

import SwiftUI

// MARK: - Tabs

enum TenantDetailTab: Int, CaseIterable, Identifiable {
    case overview
    case timeline
    case maintenance
    case documents
    case messages

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .timeline: "Timeline"
        case .maintenance: "Maintenance"
        case .documents: "Documents"
        case .messages: "Messages"
        }
    }

    var icon: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .timeline: "clock.arrow.circlepath"
        case .maintenance: DS.Icons.maintenance
        case .documents: DS.Icons.documents
        case .messages: DS.Icons.messages
        }
    }
}

// MARK: - Detail View

struct TenantDetailView: View {

    let tenantID: String

    init(tenantID: String, container: AppContainer = .shared) {
        self.tenantID = tenantID
        _viewModel = State(initialValue: TenantDetailViewModel(
            tenantID: tenantID,
            repository: container.tenants
        ))
    }

    /// The lease forms this screen presents.
    private enum LeaseSheet: String, Identifiable {
        case renew, move
        var id: String { rawValue }
    }

    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container
    @State private var viewModel: TenantDetailViewModel
    @State private var leaseSheet: LeaseSheet?
    @State private var selectedTab: TenantDetailTab = .overview
    @State private var movesForward = true
    @Namespace private var tabNamespace

    private var tenant: Tenant? { viewModel.tenant }

    var body: some View {
        ZStack {
            DSAmbientBackground()

            if let tenant {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.lg) {
                        profileHeader(tenant)
                            .dsEntrance(index: 0)

                        tabBar
                            .dsEntrance(index: 1)

                        tabContent(tenant)
                            .id(selectedTab)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: movesForward ? .trailing : .leading)
                                        .combined(with: .opacity),
                                    removal: .move(edge: movesForward ? .leading : .trailing)
                                        .combined(with: .opacity)
                                )
                            )
                    }
                    .padding(DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.huge)
                }
            } else if let error = viewModel.error {
                DSErrorView(error: error) { await viewModel.retry() }
            } else {
                DSListSkeleton(rows: 4).padding(DS.Spacing.lg)
            }
        }
        .task { await viewModel.load() }
        .task(id: selectedTab) { await viewModel.loadTab(selectedTab) }
        .navigationTitle(tenant?.name ?? "Tenant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if tenant != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Lease", systemImage: AppSymbol.lease.rawValue) {
                        Button("Renew Lease", systemImage: "arrow.clockwise") { leaseSheet = .renew }
                        Button("Move to Another Unit", systemImage: "arrow.left.arrow.right") { leaseSheet = .move }
                        Divider()
                        Button("Payments", systemImage: AppSymbol.rent.rawValue) {
                            router.push(.tenantLedger(tenantID: tenantID))
                        }
                    }
                }
            }
        }
        .sheet(item: $leaseSheet) { sheet in
            switch sheet {
            case .renew:
                RenewLeaseView(tenantID: tenantID, container: container) { _ in
                    Task { await viewModel.refresh() }
                }
            case .move:
                MoveTenantView(tenantID: tenantID, container: container) { _ in
                    Task { await viewModel.refresh() }
                }
            }
        }
    }

    // MARK: Profile Header

    private func profileHeader(_ tenant: Tenant) -> some View {
        DSCard(style: .raised, cornerRadius: DS.Radius.xl, padding: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.lg) {
                DSAvatar(
                    name: tenant.name,
                    size: .xlarge,
                    status: tenant.status.kind == .success ? .success
                        : (tenant.status == .overdue ? .danger : .info)
                )
                .dsFloating(amplitude: 3, duration: 3.8)

                VStack(spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(tenant.name)
                            .font(DS.Typography.title2)
                            .foregroundStyle(DS.Colors.textPrimary)

                        if tenant.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DS.Colors.brand)
                        }
                    }

                    Text("\(tenant.unitName) · \(tenant.propertyName)")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                HStack(spacing: DS.Spacing.sm) {
                    DSBadge(text: tenant.status.rawValue, kind: tenant.status.kind)
                    DSBadge(text: "\(tenant.onTimeRate)% on-time", kind: tenant.onTimeRate >= 95 ? .success : .warning)
                    if tenant.leaseProgress > 0.85 {
                        DSBadge(text: "Renewal soon", kind: .warning, icon: "clock.fill")
                    }
                }

                // Quick actions.
                HStack(spacing: DS.Spacing.xl) {
                    quickAction(icon: DS.Icons.messages, label: "Message") {
                        router.push(.conversation(conversationID: tenant.id))
                    }
                    quickAction(icon: "phone.fill", label: "Call") {}
                    quickAction(icon: "envelope.fill", label: "Email") {}
                    quickAction(icon: DS.Icons.lease, label: "Lease") {
                        movesForward = true
                        withAnimation(DS.Motion.smooth) { selectedTab = .documents }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func quickAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.brandInk)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.brand.opacity(0.12), in: Circle())
                    .overlay(Circle().strokeBorder(DS.Colors.brand.opacity(0.25), lineWidth: 1))

                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .buttonStyle(DSPressStyle(scale: 0.9))
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(TenantDetailTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func tabButton(_ tab: TenantDetailTab) -> some View {
        let isSelected = tab == selectedTab

        return Button {
            movesForward = tab.rawValue > selectedTab.rawValue
            withAnimation(DS.Motion.smooth) { selectedTab = tab }
        } label: {
            HStack(spacing: DS.Spacing.xs + 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? DS.Colors.textOnBrand : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md + 2)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background {
                if isSelected {
                    Capsule()
                        .fill(DS.Gradients.brand)
                        .matchedGeometryEffect(id: "tenant.tab.pill", in: tabNamespace)
                } else {
                    Capsule()
                        .fill(DS.Colors.surfaceRaised)
                        .overlay(Capsule().strokeBorder(DS.Colors.outline, lineWidth: 1))
                }
            }
        }
        .buttonStyle(DSPressStyle(scale: 0.94))
    }

    // MARK: Tab Content

    @ViewBuilder
    private func tabContent(_ tenant: Tenant) -> some View {
        switch selectedTab {
        case .overview:
            overviewTab(tenant)
        case .timeline:
            timelineTab(tenant)
        case .maintenance:
            maintenanceTab(tenant)
        case .documents:
            documentsTab(tenant)
        case .messages:
            messagesTab(tenant)
        }
    }

    // MARK: Overview

    private func overviewTab(_ tenant: Tenant) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            TenantLeaseCard(tenant: tenant)
                .dsEntrance(index: 0)

            // Near the end of the term (the "Renewal soon" badge): offer the next step.
            if tenant.leaseProgress > 0.85 {
                Button("Renew Lease", systemImage: "arrow.clockwise") { leaseSheet = .renew }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }

            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Contact").dsOverline()

                    contactRow(icon: "envelope.fill", value: tenant.email)
                    contactRow(icon: "phone.fill", value: tenant.phone)
                    contactRow(icon: "mappin.circle.fill", value: "\(tenant.unitName), \(tenant.propertyName)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 1)

            // Recent activity preview.
            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        Text("Recent Activity").dsOverline()
                        Spacer()
                        Button {
                            movesForward = true
                            withAnimation(DS.Motion.smooth) { selectedTab = .timeline }
                        } label: {
                            Text("See all")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.brand)
                        }
                        .buttonStyle(DSPressStyle(scale: 0.95))
                    }

                    VStack(spacing: 0) {
                        let events = viewModel.recentTimeline
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            TenantTimelineRow(event: event, isLast: index == events.count - 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 2)
        }
    }

    private func contactRow(icon: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.brandInk)
                .frame(width: 28, height: 28)
                .background(DS.Colors.brand.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            Text(value)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    // MARK: Timeline

    private func timelineTab(_ tenant: Tenant) -> some View {
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Full Timeline").dsOverline()

                VStack(spacing: 0) {
                    let events = viewModel.timelineEvents
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        TenantTimelineRow(event: event, isLast: index == events.count - 1)
                            .dsEntrance(index: index)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Maintenance

    private func maintenanceTab(_ tenant: Tenant) -> some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(Array(viewModel.maintenanceRows.enumerated()), id: \.element.id) { index, request in
                DSCard(style: .raised, padding: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(request.kind.tint)
                                .frame(width: 38, height: 38)

                            Image(systemName: DS.Icons.maintenance)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(request.kind.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.title)
                                .font(DS.Typography.headline)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)

                            Text("\(request.unit) · \(request.time)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }

                        Spacer()

                        DSBadge(text: request.status, kind: request.kind)
                    }
                }
                .dsEntrance(index: index)
            }
        }
    }

    // MARK: Documents

    private func documentsTab(_ tenant: Tenant) -> some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(Array(viewModel.documentRows.enumerated()), id: \.element.id) { index, doc in
                DSCard(style: .raised, padding: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: doc.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.Colors.brandInk)
                            .frame(width: 38, height: 38)
                            .background(DS.Colors.brand.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.name)
                                .font(DS.Typography.headline)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)

                            Text(doc.detail)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
                .dsEntrance(index: index)
            }
        }
    }

    // MARK: Messages

    private func messagesTab(_ tenant: Tenant) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Latest Thread").dsOverline()

                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(Array(viewModel.messagePreviews.enumerated()), id: \.element.id) { index, message in
                            messageBubble(message, tenant: tenant)
                                .dsEntrance(index: index)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            DSButton(
                title: "Open Conversation",
                icon: DS.Icons.send,
                variant: .primary,
                size: .large,
                isFullWidth: true
            ) {
                router.push(.conversation(conversationID: tenant.id))
            }
            .dsEntrance(index: 4)
        }
    }

    private func messageBubble(_ message: TenantMessagePreview, tenant: Tenant) -> some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            if message.isFromTenant {
                DSAvatar(name: tenant.name, size: .small)
            } else {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.isFromTenant ? .leading : .trailing, spacing: 2) {
                Text(message.text)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(message.isFromTenant ? DS.Colors.textPrimary : DS.Colors.textOnBrand)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm + 2)
                    .background(
                        message.isFromTenant
                            ? AnyShapeStyle(DS.Colors.surfaceSecondary)
                            : AnyShapeStyle(DS.Gradients.brand),
                        in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    )

                Text(message.time)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            if message.isFromTenant {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isFromTenant ? .leading : .trailing)
    }
}

// MARK: - Previews

#Preview("Tenant Detail") {
    NavigationStack {
        TenantDetailView(tenantID: "sarah-chen")
    }
    .environment(AppRouter())
}
