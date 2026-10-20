//
//  TenantRequestsView.swift
//  RentalApp (Purrperty)
//
//  Tenant Portal — Repair requests for the tenant's home: what's open,
//  where each one stands, who's coming, and what's been said. Read-only
//  apart from reporting a new problem; managing work is the landlord's.
//

import SwiftUI

struct TenantRequestsView: View {

    let viewModel: TenantPortalViewModel
    let onReportProblem: () -> Void

    var body: some View {
        List {
            if !viewModel.openRequests.isEmpty {
                Section("Open") {
                    ForEach(viewModel.openRequests) { ticket in
                        link(for: ticket)
                    }
                }
            }
            if !viewModel.closedRequests.isEmpty {
                Section("Done") {
                    ForEach(viewModel.closedRequests) { ticket in
                        link(for: ticket)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.requests.isEmpty {
                ContentUnavailableView {
                    Label("No Requests", systemImage: AppSymbol.maintenance.rawValue)
                } description: {
                    Text("Something broken or not working? Report it and your landlord will be notified.")
                } actions: {
                    Button("Report a Problem", action: onReportProblem)
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .navigationTitle("Requests")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Report a Problem", systemImage: AppSymbol.add.rawValue, action: onReportProblem)
            }
        }
        .refreshable { await viewModel.load() }
    }

    private func link(for ticket: MaintenanceTicket) -> some View {
        NavigationLink {
            TenantRequestDetailView(ticket: ticket, tracker: viewModel.visitTracker)
        } label: {
            TenantRequestRow(ticket: ticket)
        }
    }
}

// MARK: - Row

struct TenantRequestRow: View {

    let ticket: MaintenanceTicket

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ticket.title)
                .lineLimit(2)
            HStack(spacing: 12) {
                StatusLabel(ticket.status.tenantTitle, role: ticket.status.role)
                Text(ticket.createdAgo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail

struct TenantRequestDetailView: View {

    let ticket: MaintenanceTicket
    let tracker: RepairVisitTracker

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ticket.title)
                        .font(.title3.bold())
                    if !ticket.description.isEmpty {
                        Text(ticket.description)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                LabeledContent("Status") {
                    StatusLabel(ticket.status.tenantTitle, role: ticket.status.role)
                }
                LabeledContent("Priority", value: ticket.priority.title)
                LabeledContent("Type", value: ticket.category.rawValue)
                LabeledContent("Reported", value: ticket.createdAgo)
                if let vendor = ticket.vendor {
                    LabeledContent("Who's coming", value: "\(vendor.name), \(vendor.company)")
                }
                if let access = ticket.access {
                    LabeledContent("Entry", value: access.permissionToEnter ? "Allowed · \(access.window.rawValue)" : "Notice needed")
                }
            } footer: {
                Text(ticket.status.tenantExplanation)
            }

            if RepairVisitTrackingRows.applies(to: ticket) {
                Section("Visit") {
                    LabeledContent("When") {
                        Text(ticket.scheduledVisit ?? .now, format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                    }
                    RepairVisitTrackingRows(ticket: ticket, tracker: tracker)
                }
            }

            if !ticket.comments.isEmpty {
                Section("Updates") {
                    ForEach(ticket.comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.isManager ? "Your landlord" : comment.author)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(comment.time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(comment.text)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Status Wording

extension TicketStatus {

    /// How a tenant would put it.
    var tenantTitle: String {
        switch self {
        case .new: "Sent"
        case .inProgress: "Being worked on"
        case .scheduled: "Visit booked"
        case .done: "Fixed"
        }
    }

    /// Progress, not a warning: work being done is good news.
    var role: StatusRole {
        switch self {
        case .new, .inProgress, .scheduled: .informational
        case .done: .positive
        }
    }

    var tenantExplanation: String {
        switch self {
        case .new: "Your landlord has your request and will be in touch."
        case .inProgress: "Your landlord is arranging the repair."
        case .scheduled: "A visit is booked. Unless you've allowed entry, you'll get 24 hours' written notice first."
        case .done: "This was marked fixed. If it's still a problem, report it again or message your landlord."
        }
    }
}
