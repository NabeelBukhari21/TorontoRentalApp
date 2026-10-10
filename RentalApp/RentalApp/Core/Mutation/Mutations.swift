//
//  Mutations.swift
//  RentalApp (Purrperty)
//
//  Core — The write path.
//
//  ─────────────────────────────────────────────────────────────────
//  OPTIMISTIC BY DEFAULT, HONEST ON FAILURE
//  ─────────────────────────────────────────────────────────────────
//  A commercial app does not show a spinner when you archive a row. It
//  removes the row, tells you it happened, and offers to undo. If the
//  server then rejects it, the row comes back and the app says why.
//
//  Doing that correctly requires three things that are easy to get
//  wrong, so they live here once instead of in seven view models:
//
//  1. A snapshot taken *before* the local change, so rollback restores
//     the exact prior state rather than a re-fetch that may race.
//  2. Undo that is a real inverse operation against the server, not a
//     re-application of stale local state.
//  3. A window after which undo expires, so the snapshot cannot be
//     replayed against a row that has since moved on.
//

import Foundation

// MARK: - Undo

/// An inverse operation the user can trigger from the toast.
///
/// `perform` runs against the repository — undoing an archive really
/// un-archives it server-side. It is not a local state restore, which
/// would silently diverge from the database.
struct UndoToken: Identifiable, Sendable {

    let id = UUID()
    /// Shown on the toast, e.g. "Property archived".
    let message: String
    /// How long the offer stands. After this the toast dismisses and the
    /// token is dropped.
    let window: Duration
    private let action: @MainActor @Sendable () async throws -> Void

    init(
        message: String,
        window: Duration = .seconds(6),
        action: @escaping @MainActor @Sendable () async throws -> Void
    ) {
        self.message = message
        self.window = window
        self.action = action
    }

    @MainActor
    func perform() async throws {
        try await action()
    }
}

// MARK: - Outcome

/// What a mutation produced.
///
/// Deliberately not a bare `Bool`: the caller needs to know whether to
/// offer undo, and callers that ignore the result get a compiler nudge
/// via `@discardableResult` only where ignoring is actually correct.
enum MutationOutcome: Sendable {
    case succeeded(undo: UndoToken?)
    case failed(AppError)

    var isSuccess: Bool {
        if case .succeeded = self { return true }
        return false
    }

    var error: AppError? {
        if case .failed(let error) = self { return error }
        return nil
    }

    var undo: UndoToken? {
        if case .succeeded(let token) = self { return token }
        return nil
    }
}

// MARK: - Note on rollback
//
// There is deliberately no generic `Optimistic.perform` helper here.
// Every call site needs its snapshot for something slightly different —
// the archive path builds its undo token from the row it just removed,
// the bulk path has to put back only the subset that failed — and a
// wrapper general enough to cover all of them ended up less readable
// than three explicit lines in the view model. The types above
// (`MutationOutcome`, `UndoToken`) are the part worth sharing.

// MARK: - Error Normalisation

extension AppError {
    /// Anything thrown from a repository arrives here before the UI sees
    /// it, so a transport type can never reach a label.
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if error is CancellationError { return .unknown }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return .network }
        return .unknown
    }
}
