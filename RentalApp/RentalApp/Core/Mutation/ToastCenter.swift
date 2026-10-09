//
//  ToastCenter.swift
//  RentalApp (RentOS)
//
//  Core — The one place transient feedback is announced.
//
//  Every mutation in the app reports here: successes with an optional
//  undo, failures with a retry. Putting it in the environment rather
//  than giving each screen its own banner means a toast raised from a
//  detail sheet survives that sheet being dismissed — which is exactly
//  when the user most needs to see "couldn't save".
//

import SwiftUI
import Observation

// MARK: - Toast

struct Toast: Identifiable, Sendable {

    enum Style: Sendable {
        case success
        case failure
        case info

        var icon: String {
            switch self {
            case .success: DS.Icons.success
            case .failure: DS.Icons.warning
            case .info:    DS.Icons.info
            }
        }

        var kind: DSStatusKind {
            switch self {
            case .success: .success
            case .failure: .danger
            case .info:    .info
            }
        }
    }

    let id = UUID()
    let message: String
    let style: Style
    let undo: UndoToken?
    /// Offered on failure so the user is not left re-doing the gesture.
    let retry: (@MainActor @Sendable () async -> Void)?
    let duration: Duration

    init(
        message: String,
        style: Style,
        undo: UndoToken? = nil,
        retry: (@MainActor @Sendable () async -> Void)? = nil,
        duration: Duration = .seconds(4)
    ) {
        self.message = message
        self.style = style
        self.undo = undo
        self.retry = retry
        self.duration = duration
    }
}

// MARK: - Center

@MainActor
@Observable
final class ToastCenter {

    private(set) var current: Toast?
    private(set) var isUndoing = false

    private var dismissTask: Task<Void, Never>?

    // MARK: Presenting

    /// Announces the result of a mutation. This is the single call a view
    /// model makes after any write, which is why it takes the outcome
    /// rather than a message: the wording follows from the result.
    func report(
        _ outcome: MutationOutcome,
        success: String,
        retry: (@MainActor @Sendable () async -> Void)? = nil
    ) {
        switch outcome {
        case .succeeded(let undo):
            show(Toast(
                message: undo?.message ?? success,
                style: .success,
                undo: undo,
                duration: undo.map(\.window) ?? .seconds(3)
            ))
        case .failed(let error):
            show(Toast(
                message: error.errorDescription ?? "Something went wrong.",
                style: .failure,
                retry: retry,
                duration: .seconds(6)
            ))
        }
    }

    func success(_ message: String) {
        show(Toast(message: message, style: .success, duration: .seconds(3)))
    }

    func failure(_ error: AppError, retry: (@MainActor @Sendable () async -> Void)? = nil) {
        show(Toast(
            message: error.errorDescription ?? "Something went wrong.",
            style: .failure,
            retry: retry,
            duration: .seconds(6)
        ))
    }

    func info(_ message: String) {
        show(Toast(message: message, style: .info))
    }

    func show(_ toast: Toast) {
        dismissTask?.cancel()
        withAnimation(DS.Motion.bouncy) { current = toast }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: toast.duration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(DS.Motion.gentle) { current = nil }
    }

    // MARK: Undo

    /// Runs the undo action and replaces the toast with the result.
    ///
    /// A failed undo is reported rather than swallowed: if un-archiving
    /// fails, the row stays gone and the user needs to know the button
    /// did not work.
    func performUndo() async {
        guard let toast = current, let token = toast.undo, !isUndoing else { return }
        isUndoing = true
        defer { isUndoing = false }

        do {
            try await token.perform()
            show(Toast(message: "Undone", style: .success, duration: .seconds(2)))
        } catch {
            failure(AppError.from(error))
        }
    }

    func runRetry() async {
        guard let retry = current?.retry else { return }
        dismiss()
        await retry()
    }
}

// MARK: - Environment

private struct ToastCenterKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ToastCenter()
}

extension EnvironmentValues {
    /// The app-wide toast center. Defaults to a live instance so a
    /// preview that triggers a mutation shows feedback instead of
    /// trapping on a missing dependency.
    var toasts: ToastCenter {
        get { self[ToastCenterKey.self] }
        set { self[ToastCenterKey.self] = newValue }
    }
}
