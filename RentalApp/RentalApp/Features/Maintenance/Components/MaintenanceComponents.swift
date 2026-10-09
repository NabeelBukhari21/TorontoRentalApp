//
//  MaintenanceComponents.swift
//  RentalApp (RentOS)
//
//  Maintenance — Shared components: ticket cards (list + kanban),
//  photo thumbnails, and the workflow stage visualization.
//

import SwiftUI

// MARK: - List Ticket Card

struct TicketCard: View {

    let ticket: MaintenanceTicket
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Priority color rail.
                RoundedRectangle(cornerRadius: 2)
                    .fill(ticket.priority.color)
                    .frame(width: 4)
                    .padding(.vertical, DS.Spacing.md)

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        // Category tile.
                        Image(systemName: ticket.category.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ticket.priority.color)
                            .frame(width: 38, height: 38)
                            .background(ticket.priority.color.opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ticket.title)
                                .font(DS.Typography.headline)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)

                            Text("\(ticket.unitName) · \(ticket.propertyName) · \(ticket.createdAgo)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        TicketPriorityBadge(priority: ticket.priority)
                    }

                    HStack(spacing: DS.Spacing.sm) {
                        DSBadge(text: ticket.status.title, kind: ticket.status.kind, icon: ticket.status.icon)

                        if ticket.photoCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: DS.Icons.camera)
                                    .font(.system(size: 10, weight: .semibold))
                                Text("\(ticket.photoCount)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(DS.Colors.textTertiary)
                        }

                        // AI chip.
                        HStack(spacing: 3) {
                            Image(systemName: DS.Icons.ai)
                                .font(.system(size: 9, weight: .bold))
                            Text("\(Int(ticket.ai.urgencyScore * 100))")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(DS.Colors.brandInk)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(DS.Colors.brand.opacity(0.12), in: Capsule())

                        Spacer(minLength: 0)

                        if let vendor = ticket.vendor {
                            HStack(spacing: DS.Spacing.xs) {
                                DSAvatar(name: vendor.name, size: .small)
                                Text(vendor.name.split(separator: " ").first.map(String.init) ?? "")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }
                        } else {
                            Text("Unassigned")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.surfaceRaised,
                in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(
                        ticket.priority == .urgent
                            ? AnyShapeStyle(ticket.priority.color.opacity(0.45))
                            : AnyShapeStyle(DS.Gradients.cardHairline),
                        lineWidth: 1
                    )
            )
            .dsShadow(
                ticket.priority == .urgent
                    ? DS.Shadows.glow(DS.Colors.danger, intensity: 0.18)
                    : DS.Shadows.soft
            )
        }
        .buttonStyle(DSPressStyle())
    }
}

// MARK: - Priority Badge

struct TicketPriorityBadge: View {

    let priority: TicketPriority

    @State private var pulses = false

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: priority.icon)
                .font(.system(size: 9, weight: .bold))

            Text(priority.title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(priority.color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 3.5)
        .background(priority.color.opacity(0.13), in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                priority.color.opacity(priority == .urgent && pulses ? 0.7 : 0.25),
                lineWidth: 1
            )
        )
        .onAppear {
            guard priority == .urgent else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulses = true
            }
        }
    }
}

// MARK: - Kanban Card

struct KanbanTicketCard: View {

    let ticket: MaintenanceTicket
    let action: () -> Void
    var onMove: (TicketStatus) -> Void = { _ in }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    TicketPriorityBadge(priority: ticket.priority)
                    Spacer()
                    Image(systemName: ticket.category.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Text(ticket.title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(ticket.unitName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)

                HStack {
                    if let vendor = ticket.vendor {
                        DSAvatar(name: vendor.name, size: .small)
                    } else {
                        Circle()
                            .strokeBorder(DS.Colors.outline, style: StrokeStyle(lineWidth: 1, dash: [3]))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "person.fill.questionmark")
                                    .font(.system(size: 9))
                                    .foregroundStyle(DS.Colors.textTertiary)
                            )
                    }

                    Spacer()

                    if ticket.photoCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: DS.Icons.camera)
                                .font(.system(size: 9, weight: .semibold))
                            Text("\(ticket.photoCount)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(DS.Colors.textTertiary)
                    }

                    Text(ticket.createdAgo)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surfaceRaised,
                in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [ticket.priority.color.opacity(0.4), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .dsShadow(DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle(scale: 0.96))
        .contextMenu {
            ForEach(TicketStatus.allCases.filter { $0 != ticket.status }) { status in
                Button {
                    onMove(status)
                } label: {
                    Label("Move to \(status.title)", systemImage: status.icon)
                }
            }
        }
    }
}

// MARK: - Photo Thumbnail (placeholder)

struct TicketPhotoThumb: View {

    let index: Int
    let paletteIndex: Int
    var size: CGFloat = 92

    var body: some View {
        ZStack {
            PropertyPalettes.gradient(paletteIndex + index)

            LinearGradient(
                colors: [.clear, DS.Colors.mediaBackground.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )

            Image(systemName: DS.Icons.camera)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DS.Colors.onFixedColor)

            VStack {
                Spacer()
                HStack {
                    Text("IMG_0\(index + 1)")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.Colors.onFixedColor)
                    Spacer()
                }
                .padding(6)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Colors.highlightLine, lineWidth: 1)
        )
    }
}

// MARK: - Workflow Visualization

/// Four-stage workflow with animated connectors. Tap a stage to move the ticket.
struct TicketWorkflowView: View {

    let currentStatus: TicketStatus
    var onSelect: (TicketStatus) -> Void = { _ in }

    @State private var pulseCurrent = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TicketStatus.allCases) { status in
                stageNode(status)

                if status != .done {
                    connector(after: status)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseCurrent = true
            }
        }
    }

    private func stageNode(_ status: TicketStatus) -> some View {
        let isDone = status.rawValue < currentStatus.rawValue
        let isCurrent = status == currentStatus

        return Button {
            onSelect(status)
        } label: {
            VStack(spacing: DS.Spacing.sm) {
                ZStack {
                    // Pulse halo on current stage.
                    if isCurrent {
                        Circle()
                            .fill(status.kind.color.opacity(0.25))
                            .frame(width: 42, height: 42)
                            .scaleEffect(pulseCurrent ? 1.25 : 0.9)
                    }

                    Circle()
                        .fill(
                            isDone || isCurrent
                                ? AnyShapeStyle(DS.Gradients.brand)
                                : AnyShapeStyle(DS.Colors.surfaceSecondary)
                        )
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle().strokeBorder(
                                isCurrent ? status.kind.color.opacity(0.7) : DS.Colors.outline,
                                lineWidth: isCurrent ? 1.5 : 1
                            )
                        )

                    Image(systemName: isDone ? "checkmark" : status.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(
                            isDone || isCurrent ? DS.Colors.textOnBrand : DS.Colors.textTertiary
                        )
                        .contentTransition(.symbolEffect(.replace))
                }

                Text(status.title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(isCurrent ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(DSPressStyle(scale: 0.9))
    }

    private func connector(after status: TicketStatus) -> some View {
        let isFilled = status.rawValue < currentStatus.rawValue

        return Capsule()
            .fill(
                isFilled
                    ? AnyShapeStyle(DS.Gradients.brand)
                    : AnyShapeStyle(DS.Colors.outline)
            )
            .frame(height: 3)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.bottom, DS.Spacing.lg) // optical alignment with circles
            .animation(DS.Motion.smooth, value: isFilled)
    }
}

// MARK: - Previews

#Preview("Maintenance Components") {
    ZStack {
        DSAmbientBackground()

        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                TicketCard(ticket: MaintenanceMockData.tickets[0]) {}
                KanbanTicketCard(ticket: MaintenanceMockData.tickets[0], action: {})
                    .frame(width: 250)

                DSCard(style: .raised) {
                    TicketWorkflowView(currentStatus: .inProgress)
                }

                HStack {
                    TicketPhotoThumb(index: 0, paletteIndex: 1)
                    TicketPhotoThumb(index: 1, paletteIndex: 1)
                    TicketPhotoThumb(index: 2, paletteIndex: 1)
                }
            }
            .padding(DS.Spacing.xl)
        }
    }
}
