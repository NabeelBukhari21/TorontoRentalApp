//
//  VendorJobsView.swift
//  RentalApp (Purrperty)
//
//  Vendor Portal — Jobs, in the order a contractor works through them:
//  new jobs to accept, booked visits by date, accepted jobs still to book,
//  then finished work.
//

import SwiftUI

struct VendorJobsView: View {

    let viewModel: VendorPortalViewModel

    var body: some View {
        List {
            section("New", footer: "Accept a job to take it on, or decline it to send it back.", jobs: viewModel.newJobs)
            section("Booked", footer: nil, jobs: viewModel.bookedJobs)
            section("To Book", footer: "Accepted, with no visit booked yet.", jobs: viewModel.acceptedJobs)
            section("Done", footer: nil, jobs: viewModel.doneJobs)
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.jobs.isEmpty {
                ContentUnavailableView(
                    "No Jobs",
                    systemImage: AppSymbol.vendor.rawValue,
                    description: Text("Jobs sent to you will appear here.")
                )
            }
        }
        .navigationTitle("Jobs")
        .navigationSubtitle(viewModel.account?.company ?? "")
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private func section(_ title: String, footer: String?, jobs: [MaintenanceTicket]) -> some View {
        if !jobs.isEmpty {
            Section {
                ForEach(jobs) { job in
                    NavigationLink {
                        VendorJobDetailView(jobID: job.id, viewModel: viewModel)
                    } label: {
                        VendorJobRow(job: job)
                    }
                }
            } header: {
                Text("\(title) · \(jobs.count)")
            } footer: {
                if let footer { Text(footer) }
            }
        }
    }
}

// MARK: - Row

struct VendorJobRow: View {

    let job: MaintenanceTicket

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(job.title)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if job.priority <= .high, job.status != .done {
                    StatusLabel(job.priority.title, role: job.priority == .urgent ? .critical : .caution)
                }
            }
            Text("\(job.unitName) · \(job.propertyName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let visit = job.scheduledVisit, job.status == .scheduled {
                Label(visit.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()), systemImage: AppSymbol.calendar.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            } else {
                Text("\(job.category.rawValue) · \(job.createdAgo)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
