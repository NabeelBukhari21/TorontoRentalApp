//
//  ConflictCenter.swift
//  RentalApp (Purrperty)
//
//  Core/Offline — Surfacing a conflict to a human.
//
//  ─────────────────────────────────────────────────────────────────
//  THE PIECE THAT MADE THE VERSION COLUMNS REAL
//  ─────────────────────────────────────────────────────────────────
//  The realtime work added a `version` column, a `bump_version` trigger,
//  an `update_if_current()` RPC and a `ConflictPolicy` — and nothing ever
//  called any of it. Optimistic concurrency you never check is a column
//  that costs a write and buys nothing.
//
//  This closes it. A guarded write returns either the updated row or a
//  conflict envelope; the envelope runs through `ConflictResolver`, and
//  anything the policy marks `.ask` lands here for the user to settle.
//
//  Deliberately a queue rather than an alert: conflicts arrive from
//  background drains and realtime patches, often while the user is looking
//  at something else entirely. Interrupting them mid-task with a modal
//  about a property they edited an hour ago is worse than a badge they can
//  open when ready.
//

import SwiftUI
import Observation

// MARK: - Pending Conflict

/// A conflict awaiting a decision, erased of its payload type.
///
/// Type-erased because the centre holds conflicts from several domains at
/// once, and a generic queue would need one array per model.
struct PendingConflict: Identifiable, Sendable {

    let id = UUID()
    let topic: RealtimeTopic
    let recordID: String
    /// What the row is called, so the sheet can say "Queen West Lofts"
    /// rather than a UUID.
    let title: String
    /// Field name → (what you typed, what the server has).
    let differences: [FieldDifference]
    let detectedAt: Date

    /// Applies the user's choice. Supplied by whoever detected the
    /// conflict, because only it knows how to write the merged row back.
    let resolve: @MainActor @Sendable (ConflictChoice) async -> MutationOutcome

    struct FieldDifference: Identifiable, Sendable, Equatable {
        var id: String { field }
        let field: String
        /// Human label — `address_line1` reads badly in a dialog.
        let label: String
        let localValue: String
        let remoteValue: String
    }
}

extension PendingConflict {

    /// Diffs what the user has against the row the server returned.
    ///
    /// Both sides are keyed by *column* name, because that is the only
    /// vocabulary the two halves share — the local side comes from a Swift
    /// draft, the remote side from PostgREST JSON.
    ///
    /// Which columns clash is decided by `RowDiff`, not re-derived here:
    /// it already skips bookkeeping columns (`updated_at`, `version`,
    /// `origin_token`) that change on every write and are never a real
    /// conflict, and it compares typed values rather than their rendered
    /// text. This method only turns those columns into display rows.
    static func differences(local: [String: Any?], remote: Data) -> [FieldDifference] {
        // `RowDiff` speaks JSON on both sides; bridge the dictionary once.
        let bridged = local.reduce(into: [String: Any]()) { result, pair in
            result[pair.key] = pair.value ?? NSNull()
        }
        guard
            JSONSerialization.isValidJSONObject(bridged),
            let localData = try? JSONSerialization.data(withJSONObject: bridged)
        else { return [] }

        let row = (try? JSONSerialization.jsonObject(with: remote)) as? [String: Any] ?? [:]

        // `changedKeys` returns them sorted, so the sheet is stable — a list
        // that reshuffles between presentations reads as a bug.
        return RowDiff.changedKeys(local: localData, remote: remote).map { column in
            FieldDifference(
                field: column,
                label: ConflictFieldLabels.label(for: column),
                localValue: ConflictFieldLabels.display(bridged[column]),
                remoteValue: ConflictFieldLabels.display(row[column])
            )
        }
    }
}

/// What the user decided.
enum ConflictChoice: Sendable, Equatable {
    /// Overwrite the server with what I typed.
    case keepMine
    /// Discard my edit.
    case keepTheirs
    /// Per-field. Only offered when more than one field clashes — for a
    /// single field it is the same as the two options above with extra taps.
    case merge(fields: [String: Bool])   // field → keepLocal
}

// MARK: - Centre

@MainActor
@Observable
final class ConflictCenter {

    private(set) var pending: [PendingConflict] = []
    /// The one currently shown in the resolution sheet.
    var presented: PendingConflict?

    var hasPending: Bool { !pending.isEmpty }
    var count: Int { pending.count }

    private let toasts: ToastCenter

    init(toasts: ToastCenter) {
        self.toasts = toasts
    }

    /// Records a conflict and tells the user something needs them.
    func report(_ conflict: PendingConflict) {
        // Collapse repeats: editing the same row twice while offline should
        // produce one decision, not a stack of them.
        pending.removeAll { $0.topic == conflict.topic && $0.recordID == conflict.recordID }
        pending.append(conflict)

        toasts.show(Toast(
            message: "\(conflict.title) was changed elsewhere",
            style: .info,
            duration: .seconds(6)
        ))
    }

    func present(_ conflict: PendingConflict) {
        presented = conflict
    }

    /// Presents the oldest unresolved conflict. Used by the badge.
    func presentNext() {
        presented = pending.first
    }

    func resolve(_ conflict: PendingConflict, with choice: ConflictChoice) async {
        let outcome = await conflict.resolve(choice)

        switch outcome {
        case .succeeded:
            pending.removeAll { $0.id == conflict.id }
            presented = nil
            toasts.success("Conflict resolved")
        case .failed(let error):
            // Keep it queued: an unresolvable conflict that vanishes from the
            // list is a silently lost edit.
            toasts.failure(error)
        }
    }

    /// Discards without writing. The server's version stands.
    func dismiss(_ conflict: PendingConflict) {
        pending.removeAll { $0.id == conflict.id }
        presented = nil
    }

    func clear() {
        pending.removeAll()
        presented = nil
    }
}

// MARK: - Guarded Write Result

/// What a version-checked write returned.
enum GuardedWriteResult<Value: Sendable>: Sendable {
    case updated(Value)
    /// The row moved under us. Carries the server's current state so the
    /// caller can diff without a second round trip.
    case conflict(remote: Data, currentVersion: Int)
}

// MARK: - Field Labels

/// Column name → something a person would recognise.
///
/// Lives here rather than in the sheet because the same mapping is wanted
/// in the activity feed and in conflict toasts.
enum ConflictFieldLabels {

    static func label(for column: String) -> String {
        switch column {
        case "name":                 "Name"
        case "address_line1":        "Street address"
        case "address_city":         "City"
        case "address_postal_code":  "Postal code"
        case "neighborhood":         "Neighbourhood"
        case "kind":                 "Type"
        case "year_built":           "Year built"
        case "square_feet":          "Square feet"
        case "market_rent":          "Monthly rent"
        case "label":                "Unit label"
        case "bedrooms":             "Bedrooms"
        case "bathrooms":            "Bathrooms"
        case "status":               "Status"
        case "full_name":            "Full name"
        case "email":                "Email"
        case "phone":                "Phone"
        case "rent":                 "Rent"
        case "term_start":           "Lease start"
        case "term_end":             "Lease end"
        case "title":                "Title"
        case "details":              "Details"
        case "priority":             "Priority"
        default:
            // Fall back to a readable version of the column name rather than
            // showing raw snake_case to a landlord.
            column.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Renders a JSON value for display.
    static func display(_ value: Any?) -> String {
        switch value {
        case nil, is NSNull:        "—"
        case let string as String:  string.isEmpty ? "—" : string
        case let number as NSNumber: number.stringValue
        case let array as [Any]:    array.map { display($0) }.joined(separator: ", ")
        default:                    String(describing: value ?? "—")
        }
    }
}
