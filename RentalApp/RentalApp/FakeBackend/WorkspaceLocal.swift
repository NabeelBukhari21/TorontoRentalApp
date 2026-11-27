//
//  WorkspaceLocal.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — Mock repository state kept per workspace.
//
//  The in-memory repositories hold their writes as overlays on the seeded
//  graph. Those writes belong to the organization that made them: a new
//  account mustn't see the demo's edits, and the demo's edits come back
//  when its owner signs in again. Mark an overlay `@ObservationIgnored
//  @WorkspaceLocal` (Observation can't track a wrapped property; screens
//  refresh through `SyncEngine` instead).
//
//  Give a Codable overlay a `saved:` key and it is also kept on the phone
//  between launches (`WorkspaceArchive`), so what an account adds is
//  still there tomorrow.
//

import Foundation

@MainActor
@propertyWrapper
struct WorkspaceLocal<Value> {

    private let initial: Value
    private var values: [String: Value] = [:]
    /// Reads and writes the saved copy, for an overlay that is kept.
    private let saved: (load: @MainActor (String) -> Value?, store: @MainActor (Value, String) -> Void)?

    init(wrappedValue: Value) {
        initial = wrappedValue
        saved = nil
    }

    init(wrappedValue: Value, saved key: String) where Value: Codable {
        initial = wrappedValue
        saved = (
            load: { WorkspaceArchive.shared.value(key, in: $0) },
            store: { WorkspaceArchive.shared.set($0, for: key, in: $1) }
        )
    }

    var wrappedValue: Value {
        get {
            let workspace = FakeBackend.workspace.key
            return values[workspace] ?? saved?.load(workspace) ?? initial
        }
        set {
            let workspace = FakeBackend.workspace.key
            values[workspace] = newValue
            saved?.store(newValue, workspace)
        }
    }
}
