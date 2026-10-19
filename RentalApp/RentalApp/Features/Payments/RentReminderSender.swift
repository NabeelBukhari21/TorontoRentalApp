//
//  RentReminderSender.swift
//  RentalApp (Purrperty)
//
//  Payments — Sends a polite rent reminder into the tenant's message
//  thread and notes it on the rent roll.
//
//  Reminders go where the rest of the conversation is, not to a separate
//  channel, so the tenant can reply and the manager sees the history.
//

import Foundation

@MainActor
final class RentReminderSender {

    private let messages: MessageRepositoryProtocol
    private let payments: PaymentRepositoryProtocol
    private let analytics: AnalyticsService

    init(messages: MessageRepositoryProtocol, payments: PaymentRepositoryProtocol, analytics: AnalyticsService) {
        self.messages = messages
        self.payments = payments
        self.analytics = analytics
    }

    /// The message a reminder sends. Friendly and factual: how much, since
    /// when, for which unit. No threats; formal notices are a separate step.
    static func message(firstName: String, owing: Int, oldestDueOn: Date, unitName: String) -> String {
        let month = oldestDueOn.formatted(.dateTime.month(.wide))
        let due = oldestDueOn.formatted(.dateTime.month(.abbreviated).day())
        return "Hi \(firstName), a friendly reminder that \(owing.formatted(.cad)) is outstanding on your rent account for \(unitName), starting with \(month) rent, which was due on \(due). If you've already sent it, thank you, and please ignore this. Reply here if you have any questions."
    }

    func send(_ text: String, toTenantID tenantID: String, conversationID: String, month: Date) async throws {
        try await messages.send(text, attachment: nil, in: conversationID)
        try await payments.noteReminder(forTenantID: tenantID, month: month)
        await analytics.track(.rentReminderSent)
    }
}
