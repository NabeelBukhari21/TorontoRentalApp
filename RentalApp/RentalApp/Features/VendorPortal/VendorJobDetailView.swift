//
//  VendorJobDetailView.swift
//  RentalApp (Purrperty)
//
//  Vendor Portal — One job: what's wrong, where, how to get in, what's
//  been said, and the next step. The main action changes with the job:
//  Accept → Book Visit → Mark Done.
//

import SwiftUI

struct VendorJobDetailView: View {

    let jobID: String
    let viewModel: VendorPortalViewModel

    @State private var sheet: Sheet?
    @State private var isDeclining = false
    @State private var isAddingNote = false
    @State private var declineReason = ""
    @State private var noteText = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    private enum Sheet: String, Identifiable {
        case schedule, complete
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if let job = viewModel.job(id: jobID) {
                content(job)
            } else {
                // Declined: it's no longer this vendor's job.
                ContentUnavailableView("Job Returned", systemImage: AppSymbol.vendor.rawValue,
                                       description: Text("This job is no longer assigned to you."))
            }
        }
        .navigationTitle("Job")
        .navigationBarTitleDisplayMode(.inline)
        // The job's own actions sit at the bottom; the tab bar would crowd them.
        .toolbar(.hidden, for: .tabBar)
    }

    private func content(_ job: MaintenanceTicket) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.title)
                        .font(.title3.bold())
                    if !job.description.isEmpty {
                        Text(job.description)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Details") {
                LabeledContent("Status") {
                    StatusLabel(job.status.vendorTitle, role: job.status.role)
                }
                LabeledContent("Priority", value: job.priority.title)
                LabeledContent("Trade", value: job.category.rawValue)
                LabeledContent("Sent", value: job.createdAgo)
                if job.photoCount > 0 {
                    LabeledContent("Photos", value: "\(job.photoCount)")
                }
            }

            locationSection(job)

            if RepairVisitTrackingRows.applies(to: job) {
                Section("Visit") {
                    RepairVisitTrackingRows(ticket: job, tracker: viewModel.visitTracker)
                }
            }

            if !job.comments.isEmpty {
                Section("Updates") {
                    ForEach(job.comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.isManager ? "Property manager" : comment.author)
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

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, symbol: .caution)
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            if job.status != .done {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: AppSymbol.more.rawValue) {
                        Button("Add Note", systemImage: "text.bubble") { isAddingNote = true }
                        if job.status == .scheduled {
                            Button("Rebook Visit", systemImage: AppSymbol.calendar.rawValue) { sheet = .schedule }
                        }
                        Button("Decline Job", systemImage: "xmark.circle", role: .destructive) { isDeclining = true }
                    }
                }
            }
        }
        .primaryActionBar { actions(job) }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .schedule:
                ScheduleVisitView(job: job, viewModel: viewModel)
            case .complete:
                CompleteJobView(job: job, viewModel: viewModel)
            }
        }
        .alert("Decline this job?", isPresented: $isDeclining) {
            TextField("Reason (optional)", text: $declineReason)
            Button("Decline", role: .destructive) { decline(job) }
            Button("Cancel", role: .cancel) { declineReason = "" }
        } message: {
            Text("It goes back to the property manager to send to someone else.")
        }
        .alert("Add a Note", isPresented: $isAddingNote) {
            TextField("Note", text: $noteText)
            Button("Add") { addNote(to: job) }
            Button("Cancel", role: .cancel) { noteText = "" }
        } message: {
            Text("The property manager and the tenant can see notes.")
        }
    }

    // MARK: Location

    private func locationSection(_ job: MaintenanceTicket) -> some View {
        Section {
            LabeledContent("Unit", value: job.unitName)
            LabeledContent("Property", value: job.propertyName)
            if let address = job.propertyAddress,
               let url = URL(string: "maps://?q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                Link(destination: url) {
                    Label(address, systemImage: AppSymbol.address.rawValue)
                }
            }
            if let visit = job.scheduledVisit, job.status == .scheduled {
                LabeledContent("Visit") {
                    Text(visit.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                }
            }
            LabeledContent("Entry", value: entryText(job))
        } header: {
            Text("Where")
        } footer: {
            if job.status != .done, job.access?.permissionToEnter != true, job.priority != .urgent {
                Text("The tenant hasn't agreed to entry, so they need 24 hours' written notice, and the visit has to be between 8 a.m. and 8 p.m. The property manager sends the notice when you book.")
            }
        }
    }

    private func entryText(_ job: MaintenanceTicket) -> String {
        if job.priority == .urgent { return "Emergency: no notice needed" }
        guard let access = job.access else { return "Notice needed" }
        return access.permissionToEnter ? "Tenant allows entry · \(access.window.rawValue)" : "Notice needed"
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(_ job: MaintenanceTicket) -> some View {
        switch job.status {
        case .new:
            PrimaryActionButton(title: "Accept Job", isLoading: viewModel.isWorking) { accept(job) }
            Button("Decline", role: .destructive) { isDeclining = true }
                .frame(minHeight: 44)
        case .inProgress:
            PrimaryActionButton(title: "Book Visit") { sheet = .schedule }
            Button("Mark Done") { sheet = .complete }
                .frame(minHeight: 44)
        case .scheduled:
            PrimaryActionButton(title: "Mark Done") { sheet = .complete }
        case .done:
            EmptyView()
        }
    }

    private func accept(_ job: MaintenanceTicket) {
        Task {
            if await viewModel.accept(job) {
                toasts.success("Job accepted")
            }
        }
    }

    private func decline(_ job: MaintenanceTicket) {
        let reason = declineReason
        declineReason = ""
        Task {
            if await viewModel.decline(job, reason: reason) {
                toasts.success("Job sent back")
                dismiss()
            }
        }
    }

    private func addNote(to job: MaintenanceTicket) {
        let text = noteText
        noteText = ""
        Task { _ = await viewModel.addNote(text, to: job) }
    }
}

// MARK: - Schedule Visit

/// Book or rebook the visit. Checks Ontario's entry rules: without the
/// tenant's agreement (and outside an emergency) the visit needs 24 hours'
/// notice and has to fall between 8 a.m. and 8 p.m.
struct ScheduleVisitView: View {

    let job: MaintenanceTicket
    let viewModel: VendorPortalViewModel

    @State private var date: Date
    @State private var note = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    init(job: MaintenanceTicket, viewModel: VendorPortalViewModel) {
        self.job = job
        self.viewModel = viewModel
        _date = State(initialValue: job.scheduledVisit ?? Self.suggestedStart(for: job))
    }

    private var tenantConsented: Bool { job.access?.permissionToEnter == true }
    private var isEmergency: Bool { job.priority == .urgent }

    private var problem: String? {
        OntarioTenancyRules.entryProblem(at: date, tenantConsented: tenantConsented, isEmergency: isEmergency)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Visit", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    TextField("Note for the tenant", text: $note, prompt: Text("Note (optional)"), axis: .vertical)
                        .lineLimit(1...4)
                } footer: {
                    if let problem {
                        Label(problem, symbol: .caution)
                            .foregroundStyle(.red)
                    } else if isEmergency {
                        Text("Urgent job: in an emergency no notice is needed.")
                    } else if tenantConsented {
                        Text("The tenant has agreed to entry\(job.access.map { " (\($0.window.rawValue.lowercased()))" } ?? "").")
                    } else {
                        Text("The property manager gives the tenant written notice for this time.")
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, symbol: .caution).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(job.scheduledVisit == nil ? "Book Visit" : "Rebook Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: AppSymbol.close.rawValue) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isWorking {
                        ProgressView()
                    } else {
                        Button("Book", systemImage: AppSymbol.done.rawValue) { book() }
                            .disabled(problem != nil)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func book() {
        Task {
            if await viewModel.schedule(job, at: date, note: note) {
                toasts.success("Visit booked for \(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))")
                dismiss()
            }
        }
    }

    /// The next 9 a.m. that satisfies the notice rule, or an hour from now
    /// when no notice is needed.
    private static func suggestedStart(for job: MaintenanceTicket) -> Date {
        let calendar = Calendar.current
        if job.priority == .urgent || job.access?.permissionToEnter == true {
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: .now) ?? .now
            return calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
        }
        let earliest = Date.now.addingTimeInterval(TimeInterval(OntarioTenancyRules.entryNoticeHours * 3600))
        var day = calendar.startOfDay(for: earliest)
        for _ in 0..<3 {
            if let nine = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day), nine >= earliest {
                return nine
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return earliest
    }
}

// MARK: - Complete Job

struct CompleteJobView: View {

    let job: MaintenanceTicket
    let viewModel: VendorPortalViewModel

    @State private var notes = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    private var canSubmit: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What was done", text: $notes, prompt: Text("For example, \"Replaced the cartridge and tested for leaks.\""), axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Work Done")
                } footer: {
                    Text("The property manager and the tenant see this.")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, symbol: .caution).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Mark Done")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: AppSymbol.close.rawValue) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isWorking {
                        ProgressView()
                    } else {
                        Button("Done", systemImage: AppSymbol.done.rawValue) { complete() }
                            .disabled(!canSubmit)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func complete() {
        Task {
            if await viewModel.complete(job, notes: notes) {
                toasts.success("Job marked done")
                dismiss()
            }
        }
    }
}

// MARK: - Status Wording

extension TicketStatus {

    /// How a contractor would put it.
    var vendorTitle: String {
        switch self {
        case .new: "Waiting for you"
        case .inProgress: "Accepted"
        case .scheduled: "Visit booked"
        case .done: "Done"
        }
    }
}
