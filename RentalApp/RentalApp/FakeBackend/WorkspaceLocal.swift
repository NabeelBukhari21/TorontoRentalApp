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

import Foundation

@MainActor
@propertyWrapper
struct WorkspaceLocal<Value> {

    private let initial: Value
    private var values: [String: Value] = [:]

    init(wrappedValue: Value) {
        initial = wrappedValue
    }

    var wrappedValue: Value {
        get { values[FakeBackend.workspace.key] ?? initial }
        set { values[FakeBackend.workspace.key] = newValue }
    }
}
