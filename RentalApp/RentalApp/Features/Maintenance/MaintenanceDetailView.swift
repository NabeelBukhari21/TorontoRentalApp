//
//  MaintenanceDetailView.swift
//  RentalApp (Purrperty)
//
//  Maintenance — Ticket detail: workflow visualization, AI analysis
//  panel (obsidian), photos, vendor assignment, comments, timeline.
//

import SwiftUI

struct MaintenanceDetailView: View {

    let ticketID: String

    @Environment(AppRouter.self) private var router
    @Environment(\.container) private var container
    @State private var viewModel: MaintenanceDetailViewModel
    @FocusState private var commentFocused: Bool
    @State private var isSchedulingVisit = false
    
    init(ticketID: String, container: AppContainer = .shared) {
        self.ticketID = ticketID
        _viewModel = State(initialValue: MaintenanceDetailViewModel(
            ticketID: ticketID,
            repository: container.maintenance,
            visitTracker: .shared
        ))
    }

    private var ticket: MaintenanceTicket? { viewModel.ticket }

    private func conversationID(for ticket: MaintenanceTicket) -> String {
        viewModel.conversationID(for: ticket)
    }

    var body: some View {
        ZStack {
            DSAmbientBackground()

            if let ticket {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.lg) {
                        headerCard(ticket).dsEntrance(index: 0)
                        workflowCard(ticket).dsEntrance(index: 1)

                        if RepairVisitTrackingRows.applies(to: ticket) {
                            visitCard(ticket).dsEntrance(index: 1)
                        }
                        if let ai = ticket.ai {
                            aiPanel(ticket, ai: ai).dsEntrance(index: 2)
                        }

                        if ticket.photoCount > 0 {
                            photosCard(ticket).dsEntrance(index: 3)
                        }

                        vendorCard(ticket).dsEntrance(index: 4)
                        commentsCard(ticket).dsEntrance(index: 5)
                        timelineCard(ticket).dsEntrance(index: 6)
                    }
                    .padding(DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.huge)
                }
                .scrollDismissesKeyboard(.interactively)
            } else if let error = viewModel.error {
                DSErrorView(error: error) { await viewModel.retry() }
            } else {
                DSListSkeleton(rows: 4).padding(DS.Spacing.lg)
            }
        }
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .maintenanceUpdates) {
                await viewModel.refresh()
            }
        }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .maintenanceRequests) {
                await viewModel.refresh()
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isSchedulingVisit) {
            if let ticket {
                ScheduleVisitView(job: ticket, viewModel: viewModel)
            }
        }
    }

    // MARK: Header

    private func headerCard(_ ticket: MaintenanceTicket) -> some View {
        DSCard(style: .raised, cornerRadius: DS.Radius.xl, padding: DS.Spacing.xl) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    TicketPriorityBadge(priority: ticket.priority)
                    DSBadge(text: ticket.category.rawValue, icon: ticket.category.icon, accent: ticket.category.accent)
                    Spacer()
                    Text(ticket.createdAgo)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Text(ticket.title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !ticket.description.isEmpty {
                    Text(ticket.description)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let access = ticket.access {
                    Label(
                        access.permissionToEnter
                            ? "Entry allowed · \(access.window.rawValue)"
                            : "24-hour notice needed to enter",
                        systemImage: access.permissionToEnter ? "door.left.hand.open" : "clock"
                    )
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                }

                Rectangle().fill(DS.Colors.outline).frame(height: 0.5)

                HStack(spacing: DS.Spacing.md) {
                    DSAvatar(name: ticket.tenantName, size: .small)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(ticket.tenantName)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("\(ticket.unitName) · \(ticket.propertyName)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }

                    Spacer()

                    DSIconButton(icon: DS.Icons.messages, diameter: 36) {
                        router.push(.conversation(conversationID: conversationID(for: ticket)))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Workflow

    private func workflowCard(_ ticket: MaintenanceTicket) -> some View {
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack {
                    Text("Workflow").dsOverline()
                    Spacer()
                    DSBadge(text: ticket.status.title, kind: ticket.status.kind, icon: ticket.status.icon)
                }

                TicketWorkflowView(currentStatus: ticket.status) { newStatus in
                    // Scheduled means a visit is booked, so it asks when.
                    if newStatus == .scheduled {
                        isSchedulingVisit = true
                    } else {
                        Task { await viewModel.move(to: newStatus) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Visit

    private func visitCard(_ ticket: MaintenanceTicket) -> some View {
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("Visit").dsOverline()
                    Spacer()
                    if let visit = ticket.scheduledVisit {
                        Text(visit, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                RepairVisitTrackingRows(ticket: ticket, tracker: viewModel.visitTracker)
                    .font(DS.Typography.subheadline)
                Button("Change Time", systemImage: AppSymbol.calendar.rawValue) {
                    isSchedulingVisit = true
                }
                .font(DS.Typography.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: AI Panel

    private func aiPanel(_ ticket: MaintenanceTicket, ai: TicketAIAnalysis) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header.
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icons.ai)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        DS.Gradients.highlight
                    )
                    .symbolEffect(.pulse, options: .repeating)

                Text("AI ANALYSIS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(DS.Colors.textOnBrand)

                Spacer()

                Text("\(Int(ai.categoryConfidence * 100))% confidence")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textOnBrand)
            }

            // Urgency gauge + summary.
            HStack(spacing: DS.Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(DS.Colors.textOnBrand.opacity(0.25), lineWidth: 7)

                    Circle()
                        .trim(from: 0, to: ai.urgencyScore)
                        .stroke(
                            AngularGradient(
                                colors: [DS.Colors.accentSunny, DS.Colors.accentCoral],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(ai.urgencyScore * 100))")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DS.Colors.textOnBrand)
                        Text("urgency")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(DS.Colors.textOnBrand)
                    }
                }
                .frame(width: 74, height: 74)

                Text(ai.summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.Colors.textOnBrand)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Suggested actions.
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(Array(ai.suggestedActions.enumerated()), id: \.offset) { index, action in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DS.Colors.textOnBrand)
                            .padding(.top, 3)

                        Text(action)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(DS.Colors.textOnBrand)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .dsEntrance(index: index)
                }
            }

            // Draft reply.
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("DRAFT TENANT REPLY")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .kerning(1)
                    .foregroundStyle(DS.Colors.textOnBrand)

                Text(ai.draftReply)
                    .font(.system(size: 12.5, weight: .medium))
                    .italic()
                    .foregroundStyle(DS.Colors.textOnBrand)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.textOnBrand.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(DS.Colors.highlightLine, lineWidth: 1)
                    )

                Button {
                    Task { await viewModel.markReplySent() }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: ticket.replySent ? "checkmark.circle.fill" : DS.Icons.send)
                            .contentTransition(.symbolEffect(.replace))
                        Text(ticket.replySent ? "Reply Sent" : "Send to Tenant")
                    }
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(ticket.replySent ? DS.Colors.textOnBrand : DS.Colors.brandInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        ticket.replySent
                            ? AnyShapeStyle(
                                DS.Colors.textOnBrand.opacity(0.15)
                              )
                            : AnyShapeStyle(DS.Colors.surfaceRaised),
                        in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(DS.Colors.highlightLine, lineWidth: 1)
                    )
                }
                .buttonStyle(DSPressStyle())
                .disabled(ticket.replySent)
            }
        }
        .padding(DS.Spacing.xl)
        .dsHeroSurface()
    }

    // MARK: Photos

    private func photosCard(_ ticket: MaintenanceTicket) -> some View {
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("Photos").dsOverline()
                    Spacer()
                    Text("\(ticket.photoCount)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        if ticket.photoData.isEmpty {
                            ForEach(0..<ticket.photoCount, id: \.self) { index in
                                TicketPhotoThumb(index: index, paletteIndex: ticket.paletteIndex)
                                    .dsEntrance(index: index)
                            }
                        } else {
                            ForEach(Array(ticket.photoData.enumerated()), id: \.offset) { index, data in
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 92, height: 92)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                                        .accessibilityLabel("Photo \(index + 1)")
                                }
                            }
                        }

                        // Add photo affordance.
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(DS.Colors.outline, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .frame(width: 92, height: 92)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(DS.Colors.textTertiary)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Vendor

    private func vendorCard(_ ticket: MaintenanceTicket) -> some View {
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Vendor").dsOverline()

                if let vendor = ticket.vendor {
                    assignedVendorRow(vendor)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                } else if let suggested = ticket.ai.flatMap({ viewModel.vendor(id: $0.suggestedVendorID) }) {
                    VStack(spacing: DS.Spacing.md) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: DS.Icons.ai)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DS.Colors.brand)
                            Text("AI recommends")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                            Spacer()
                        }

                        vendorRow(suggested, ticketID: ticket.id, highlighted: true)

                        // Alternates.
                        ForEach(viewModel.alternateVendors(for: ticket, excluding: suggested.id)) { vendor in
                            vendorRow(vendor, ticketID: ticket.id, highlighted: false)
                        }
                    }
                } else {
                    // Not triaged yet: vendors for this trade, or everyone.
                    VStack(spacing: DS.Spacing.md) {
                        ForEach(viewModel.candidateVendors(for: ticket)) { vendor in
                            vendorRow(vendor, ticketID: ticket.id, highlighted: false)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func assignedVendorRow(_ vendor: Vendor) -> some View {
        HStack(spacing: DS.Spacing.md) {
            DSAvatar(name: vendor.name, size: .medium, status: .success)

            VStack(alignment: .leading, spacing: 1) {
                Text(vendor.name)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("\(vendor.company) · ⭐ \(String(format: "%.1f", vendor.rating)) · \(vendor.completedJobs) jobs")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            Spacer()

            DSBadge(text: "Assigned", kind: .success, icon: "checkmark")
        }
    }

    private func vendorRow(_ vendor: Vendor, ticketID: String, highlighted: Bool) -> some View {
        HStack(spacing: DS.Spacing.md) {
            DSAvatar(name: vendor.name, size: .medium)

            VStack(alignment: .leading, spacing: 1) {
                Text(vendor.name)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("\(vendor.company) · ⭐ \(String(format: "%.1f", vendor.rating)) · responds \(vendor.responseTime)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            DSButton(title: "Assign", variant: highlighted ? .primary : .secondary, size: .small) {
                Task { await viewModel.assign(vendor) }
            }
        }
        .padding(highlighted ? DS.Spacing.md : 0)
        .background {
            if highlighted {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Colors.brand.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(DS.Colors.brand.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: Comments

    private func commentsCard(_ ticket: MaintenanceTicket) -> some View {
        @Bindable var viewModel = viewModel
        return DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("Comments").dsOverline()
                    Spacer()
                    Text("\(ticket.comments.count)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .contentTransition(.numericText())
                }

                if ticket.comments.isEmpty {
                    Text("No comments yet — start the thread below.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.vertical, DS.Spacing.sm)
                }

                ForEach(ticket.comments) { comment in
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        DSAvatar(name: comment.author, size: .small)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: DS.Spacing.sm) {
                                Text(comment.author)
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(DS.Colors.textPrimary)

                                if comment.isManager {
                                    Text("MANAGER")
                                        .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                                        .foregroundStyle(DS.Colors.brandInk)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1.5)
                                        .background(DS.Colors.brand.opacity(0.12), in: Capsule())
                                }

                                Spacer()

                                Text(comment.time)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }

                            Text(comment.text)
                                .font(DS.Typography.footnote)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Composer.
                HStack(spacing: DS.Spacing.sm) {
                    TextField("Add a comment…", text: $viewModel.commentText)
                        .font(DS.Typography.footnote)
                        .focused($commentFocused)
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(height: 42)
                        .background(DS.Colors.surfaceSecondary, in: Capsule())

                    Button {
                        Task { await viewModel.submitComment() }
                        commentFocused = false
                    } label: {
                        Image(systemName: DS.Icons.send)
                            .font(.system(size: 26))
                            .foregroundStyle(
                                viewModel.commentText.isEmpty ? DS.Colors.textTertiary : DS.Colors.brand
                            )
                    }
                    .buttonStyle(DSPressStyle(scale: 0.85))
                    .disabled(viewModel.commentText.isEmpty)
                }
                .padding(.top, DS.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Timeline

    private func timelineCard(_ ticket: MaintenanceTicket) -> some View {
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Timeline").dsOverline()

                VStack(spacing: 0) {
                    let events = viewModel.timelineEvents
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        TenantTimelineRow(event: event, isLast: index == events.count - 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Previews

#Preview("Maintenance Detail") {
    NavigationStack {
        MaintenanceDetailView(ticketID: "t-leak-304")
    }
    .environment(AppRouter())
}
