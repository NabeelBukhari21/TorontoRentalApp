//
//  ScheduleVisitView.swift
//  RentalApp (Purrperty)
//
//  Components — Booking a repair visit, shared by the vendor portal and
//  the staff request screen.
//

import SwiftUI
import Observation

/// Whoever can book a visit on a job. Observable, so the sheet follows
/// the work in progress and any error.
@MainActor
protocol VisitScheduling: AnyObject, Observable {
    var isWorking: Bool { get }
    var errorMessage: String? { get }
    /// Books the visit; returns whether it worked. On failure
    /// `errorMessage` says why.
    func schedule(_ job: MaintenanceTicket, at date: Date, note: String) async -> Bool
}

/// Book or rebook the visit. Checks Ontario's entry rules: without the
/// tenant's agreement (and outside an emergency) the visit needs 24 hours'
/// notice and has to fall between 8 a.m. and 8 p.m.
///
/// Used by the vendor booking their own visit and by staff scheduling one
/// from the request.
struct ScheduleVisitView: View {

    let job: MaintenanceTicket
    let viewModel: any VisitScheduling

    @State private var date: Date
    @State private var note = ""
    /// Declared by whoever books it. Only a real emergency (a flood, no
    /// heat in winter, a gas smell) allows entry without notice; an urgent
    /// job still needs the tenant's agreement or 24 hours' notice.
    @State private var isEmergency = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    init(job: MaintenanceTicket, viewModel: any VisitScheduling) {
        self.job = job
        self.viewModel = viewModel
        _date = State(initialValue: job.scheduledVisit ?? Self.suggestedStart(for: job))
    }

    private var tenantConsented: Bool { job.access?.permissionToEnter == true }

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
                    if !tenantConsented, job.priority == .urgent {
                        Toggle("Emergency entry", isOn: $isEmergency)
                    }
                } footer: {
                    if let problem {
                        Label(problem, symbol: .caution)
                            .foregroundStyle(.red)
                    } else if isEmergency {
                        Text("In an emergency, entry needs no notice. Use it only for real emergencies, such as a flood or no heat.")
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
                toasts.success("Visit booked for \(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))", mood: .scheduledVisit)
                dismiss()
            }
        }
    }

    /// The next 9 a.m. that satisfies the notice rule or, when the tenant
    /// has agreed to entry, the next hour on the clock during the day.
    private static func suggestedStart(for job: MaintenanceTicket) -> Date {
        let calendar = Calendar.current
        if job.access?.permissionToEnter == true {
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: .now) ?? .now
            let onTheHour = calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
            let hour = calendar.component(.hour, from: onTheHour)
            if OntarioTenancyRules.entryWindow.contains(hour) { return onTheHour }
            // Evening or night: the next morning at nine.
            let day = hour < OntarioTenancyRules.entryWindow.lowerBound
                ? calendar.startOfDay(for: onTheHour)
                : calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: onTheHour)) ?? onTheHour
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? onTheHour
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

