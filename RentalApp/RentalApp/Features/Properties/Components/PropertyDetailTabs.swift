//
//  PropertyDetailTabs.swift
//  RentalApp (Purrperty)
//
//  Properties — The six detail tab contents. Every row animates in
//  with the shared entrance cascade.
//

import SwiftUI
import Charts

// MARK: - Overview

struct PropertyOverviewTab: View {

    let property: Property
    let viewModel: PropertyDetailViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Key stats.
            HStack(spacing: DS.Spacing.md) {
                DSStatCard(
                    title: "Occupancy",
                    value: "\(Int(property.occupancyRate * 100))%",
                    icon: DS.Icons.occupancy,
                    trend: property.isFull ? "Full" : "\(property.vacantCount) vacant",
                    trendKind: property.isFull ? .success : .warning
                )
                DSStatCard(
                    title: "Revenue",
                    value: "$\(String(format: "%.1f", property.monthlyRevenue))K",
                    icon: DS.Icons.payment,
                    iconGradient: DS.Gradients.success,
                    trend: "/month",
                    trendKind: .info
                )
            }
            .dsEntrance(index: 0)

            // Map.
            PropertyMapPreview(property: property)
                .dsEntrance(index: 1)

            // About.
            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("About").dsOverline()

                    aboutRow(icon: property.kind.icon, label: "Type", value: property.kind.rawValue)
                    aboutRow(icon: DS.Icons.unit, label: "Units", value: "\(property.unitCount)")
                    aboutRow(icon: "calendar", label: "Built", value: "\(property.yearBuilt)")
                    aboutRow(icon: DS.Icons.maintenance, label: "Open requests", value: "\(property.openRequests)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 2)
        }
    }

    private func aboutRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.brandInk)
                .frame(width: 28, height: 28)
                .background(DS.Colors.brand.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            Text(label)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Colors.textPrimary)
        }
    }
}

// MARK: - Units

struct PropertyUnitsTab: View {

    let property: Property
    let viewModel: PropertyDetailViewModel

    @Environment(\.toasts) private var toasts

    @State private var sheet: UnitSheet?
    @State private var pendingConfirmation: DSConfirmation?

    private enum UnitSheet: Identifiable {
        case create
        case edit(PropertyUnit)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let unit): "edit-\(unit.id)"
            }
        }
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Button {
                sheet = .create
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: DS.Icons.add)
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Unit")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(DS.Colors.brand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(
                            DS.Colors.brand.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1, dash: [5])
                        )
                )
            }
            .buttonStyle(DSPressStyle())

            if viewModel.units.isEmpty {
                Text("No units yet. Add the first one to start tracking occupancy.")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, DS.Spacing.lg)
            }

            ForEach(Array(viewModel.units.enumerated()), id: \.element.id) { index, unit in
                DSCard(style: .raised, padding: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: DS.Icons.unit)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(unit.status.kind.color)
                            .frame(width: 38, height: 38)
                            .background(unit.status.kind.tint)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(unit.name)
                                .font(DS.Typography.headline)
                                .foregroundStyle(DS.Colors.textPrimary)

                            Text("\(unit.beds) bd · \(unit.baths) ba · \(unit.sqft) sq ft")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textSecondary)

                            if let tenant = unit.tenantName {
                                Text(tenant)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                            Text("$\(unit.rent)")
                                .font(DS.Typography.subheadline.monospacedDigit())
                                .foregroundStyle(DS.Colors.textPrimary)

                            DSBadge(text: unit.status.rawValue, kind: unit.status.kind)
                        }
                    }
                }
                .contextMenu {
                    Button {
                        sheet = .edit(unit)
                    } label: {
                        Label("Edit Unit", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmDelete(unit)
                    } label: {
                        Label("Delete Unit", systemImage: "trash")
                    }
                }
                .dsEntrance(index: index)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(DS.Motion.smooth, value: viewModel.units.map(\.id))
        .dsConfirmation($pendingConfirmation)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .create:
                UnitFormView(mode: .create(propertyID: property.id)) {
                    viewModel.didSaveUnit($0)
                }
            case .edit(let unit):
                UnitFormView(mode: .edit(unitID: unit.id), existing: unit) {
                    viewModel.didSaveUnit($0)
                }
            }
        }
    }

    /// A unit with a live lease cannot be deleted — the server refuses and
    /// the message says why, so the dialog does not promise otherwise.
    private func confirmDelete(_ unit: PropertyUnit) {
        pendingConfirmation = DSConfirmation(
            title: "Delete \(unit.name)?",
            message: unit.tenantName == nil
                ? "This removes the unit from the property."
                : "\(unit.tenantName!) currently occupies this unit. End the lease first.",
            confirmTitle: "Delete"
        ) {
            Task {
                let outcome = await viewModel.deleteUnit(unit)
                toasts.report(outcome, success: "\(unit.name) deleted")
            }
        }
    }
}

// MARK: - Tenants

struct PropertyTenantsTab: View {

    let property: Property
    let viewModel: PropertyDetailViewModel

    var body: some View {
        let tenants = viewModel.tenantRows

        return VStack(spacing: DS.Spacing.md) {
            if tenants.isEmpty {
                DSEmptyState(
                    icon: DS.Icons.tenants,
                    title: "No tenants yet",
                    message: "Tenants appear here once units are leased."
                )
            } else {
                ForEach(Array(tenants.enumerated()), id: \.element.id) { index, tenant in
                    DSCard(style: .raised, padding: DS.Spacing.lg) {
                        HStack(spacing: DS.Spacing.md) {
                            DSAvatar(name: tenant.name, size: .medium, status: tenant.rentKind == .success ? .success : .danger)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tenant.name)
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(DS.Colors.textPrimary)

                                Text("\(tenant.unit) · Lease ends \(tenant.leaseEnds)")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }

                            Spacer()

                            DSBadge(text: tenant.rentStatus, kind: tenant.rentKind)
                        }
                    }
                    .dsEntrance(index: index)
                }
            }
        }
    }
}

// MARK: - Maintenance

struct PropertyMaintenanceTab: View {

    let property: Property
    let viewModel: PropertyDetailViewModel

    var body: some View {
        let requests = viewModel.requestRows

        return VStack(spacing: DS.Spacing.md) {
            if requests.isEmpty {
                DSEmptyState(
                    icon: "checkmark.seal.fill",
                    title: "All clear",
                    message: "No open maintenance requests for this property."
                )
            } else {
                ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
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

                            DSBadge(
                                text: request.status,
                                kind: request.kind,
                                icon: request.kind == .danger ? DS.Icons.warning : nil
                            )
                        }
                    }
                    .dsEntrance(index: index)
                }
            }
        }
    }
}

// MARK: - Documents

struct PropertyDocumentsTab: View {

    let property: Property
    let viewModel: PropertyDetailViewModel

    var body: some View {
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
}

// MARK: - Analytics

struct PropertyAnalyticsTab: View {

    let property: Property
    let viewModel: PropertyDetailViewModel

    @State private var chartsRevealed = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Occupancy trend.
            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Occupancy · 12 months").dsOverline()

                    Chart(viewModel.occupancyTrend) { point in
                        LineMark(
                            x: .value("Month", point.month),
                            y: .value("Rate", point.rate * 100)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(DS.Gradients.brand)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        AreaMark(
                            x: .value("Month", point.month),
                            y: .value("Rate", point.rate * 100)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DS.Colors.brand.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .chartYScale(domain: 55...105)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                    .frame(height: 120)
                    .opacity(chartsRevealed ? 1 : 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 0)

            // Revenue bars.
            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Revenue · 6 months").dsOverline()

                    Chart(viewModel.revenueTrend) { point in
                        BarMark(
                            x: .value("Month", point.month),
                            y: .value("Revenue", chartsRevealed ? point.amount : 0)
                        )
                        .foregroundStyle(DS.Gradients.ai)
                        .cornerRadius(4)
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                    .frame(height: 120)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 1)

            // AI note.
            DSCard(style: .raised) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: DS.Icons.ai)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Gradients.ai)
                        .symbolEffect(.pulse, options: .repeating)

                    Text(aiNote)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 2)
        }
        .onAppear {
            withAnimation(DS.Motion.entrance.delay(0.35)) {
                chartsRevealed = true
            }
        }
    }

    private var aiNote: String {
        property.isFull
            ? "\(property.name) is fully leased with stable revenue. Comparable rents in \(property.neighborhood) suggest a 4–6% upside at renewal."
            : "\(property.vacantCount) vacant unit\(property.vacantCount == 1 ? "" : "s") at \(property.name). Listing mid-week with photos historically fills \(property.neighborhood) units 30% faster."
    }
}
