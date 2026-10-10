//
//  ConflictResolution.swift
//  RentalApp (Purrperty)
//
//  Core/Realtime — When two people edit the same row.
//
//  ─────────────────────────────────────────────────────────────────
//  LAST-WRITE-WINS IS A CHOICE, NOT A DEFAULT
//  ─────────────────────────────────────────────────────────────────
//  Most apps get conflict resolution by accident: whoever's `UPDATE` lands
//  second overwrites the first, silently. That is fine for a status toggle
//  and unacceptable for a rent amount, and the difference is not something
//  the transport can decide.
//
//  So conflicts are detected rather than avoided. Every row carries a
//  `version`; an update sends the version it read, and Postgres refuses
//  the write if the row has moved on. The app then chooses per field:
//
//    • Server wins   — derived or authoritative fields (status, counters).
//    • Local wins    — the user is mid-edit and typed this deliberately.
//    • Ask           — both sides changed something that matters. Rare, and
//                      the only honest answer for money and dates.
//
//  The important property is that nothing is lost without someone deciding.
//

import Foundation

// MARK: - Versioned Record

/// A row that participates in optimistic concurrency.
protocol VersionedRecord: Sendable {
    var recordID: String { get }
    /// Bumped by a database trigger on every update. The client never sets
    /// it — a client-controlled version is not a guard, it is a formality.
    var version: Int { get }
    var updatedAt: Date { get }
}

// MARK: - Conflict

/// A write rejected because the row changed underneath it.
struct SyncConflict<Value: Sendable>: Identifiable, Sendable {

    let id = UUID()
    let topic: RealtimeTopic
    let recordID: String
    /// What the user tried to write.
    let local: Value
    /// What the server currently holds.
    let remote: Value
    /// Fields that differ between the two, so the UI can show only what
    /// actually clashes instead of a wall of identical values.
    let conflictingFields: [String]
    let detectedAt: Date

    init(
        topic: RealtimeTopic,
        recordID: String,
        local: Value,
        remote: Value,
        conflictingFields: [String]
    ) {
        self.topic = topic
        self.recordID = recordID
        self.local = local
        self.remote = remote
        self.conflictingFields = conflictingFields
        self.detectedAt = Date()
    }
}

// MARK: - Policy

/// How to resolve a clash on a given field.
enum FieldResolution: Sendable {
    case serverWins
    case localWins
    case ask
}

/// Per-topic, per-field resolution rules.
///
/// Expressed as data so the policy is reviewable in one place rather than
/// scattered through repositories as ad-hoc `if` statements.
struct ConflictPolicy: Sendable {

    /// Field name → resolution. Anything unlisted uses `fallback`.
    private let rules: [RealtimeTopic: [String: FieldResolution]]
    private let fallback: FieldResolution

    init(
        rules: [RealtimeTopic: [String: FieldResolution]],
        fallback: FieldResolution = .serverWins
    ) {
        self.rules = rules
        self.fallback = fallback
    }

    func resolution(for topic: RealtimeTopic, field: String) -> FieldResolution {
        rules[topic]?[field] ?? fallback
    }

    /// Whether any conflicting field needs a human.
    func requiresPrompt(topic: RealtimeTopic, fields: [String]) -> Bool {
        fields.contains { resolution(for: topic, field: $0) == .ask }
    }

    /// The shipping policy.
    ///
    /// The shape of it: anything the server computes goes to the server;
    /// anything a human typed goes to the human; money, dates, and identity
    /// stop and ask. `status` is server-wins because two people moving a
    /// ticket usually means one of them saw something newer — and a status
    /// is cheap to change back.
    static let standard = ConflictPolicy(
        rules: [
            .properties: [
                "name": .ask,
                "address_line1": .ask,
                "kind": .localWins,
                "neighborhood": .localWins,
                "year_built": .localWins
            ],
            .units: [
                "market_rent": .ask,          // money
                "label": .ask,                // identity
                "status": .serverWins,        // derived from leases
                "bedrooms": .localWins,
                "bathrooms": .localWins
            ],
            .tenants: [
                "full_name": .ask,
                "email": .ask,
                "phone": .localWins,
                "status": .serverWins,
                "on_time_payment_rate": .serverWins   // computed
            ],
            .leases: [
                "rent": .ask,
                "term_start": .ask,
                "term_end": .ask,
                "status": .serverWins
            ],
            .maintenanceRequests: [
                // Two managers triaging at once: take the server's, since
                // the later writer usually has newer information.
                "status": .serverWins,
                "priority": .serverWins,
                "assigned_vendor_id": .serverWins,
                "title": .ask,
                "details": .localWins
            ],
            .documents: [
                "name": .localWins,
                "tags": .localWins
            ]
        ],
        fallback: .serverWins
    )
}

// MARK: - Resolver

/// Applies a policy to a detected conflict.
struct ConflictResolver: Sendable {

    let policy: ConflictPolicy

    init(policy: ConflictPolicy = .standard) {
        self.policy = policy
    }

    enum Outcome<Value: Sendable>: Sendable {
        /// Resolved automatically; write this.
        case resolved(Value)
        /// Server's version was taken wholesale; discard the local edit.
        case tookRemote
        /// Needs the user.
        case needsUser(SyncConflict<Value>)
    }

    /// Decides what to do with a rejected write.
    ///
    /// - Parameter merge: builds a merged value from a per-field decision
    ///   map. Supplied by the caller because only it knows the value's
    ///   shape; the resolver owns the *policy*, not the struct layout.
    func resolve<Value: Sendable>(
        _ conflict: SyncConflict<Value>,
        merge: (_ decisions: [String: FieldResolution]) -> Value
    ) -> Outcome<Value> {

        guard !conflict.conflictingFields.isEmpty else {
            // Nothing actually differs — the version moved because another
            // field changed. Safe to take the remote and move on.
            return .tookRemote
        }

        if policy.requiresPrompt(topic: conflict.topic, fields: conflict.conflictingFields) {
            return .needsUser(conflict)
        }

        var decisions: [String: FieldResolution] = [:]
        for field in conflict.conflictingFields {
            decisions[field] = policy.resolution(for: conflict.topic, field: field)
        }

        // Every field resolved to serverWins: no write needed at all.
        if decisions.values.allSatisfy({ $0 == .serverWins }) {
            return .tookRemote
        }

        return .resolved(merge(decisions))
    }
}

// MARK: - Field Diffing

/// Compares two encoded rows and reports which top-level keys differ.
///
/// Works on JSON rather than typed structs so one implementation serves
/// every domain. The alternative — a `diff(_:_:)` per model — is nine
/// hand-written functions that drift from their models.
enum RowDiff {

    static func changedKeys(local: Data, remote: Data) -> [String] {
        guard
            let l = try? JSONSerialization.jsonObject(with: local) as? [String: Any],
            let r = try? JSONSerialization.jsonObject(with: remote) as? [String: Any]
        else { return [] }

        var changed: [String] = []
        for (key, localValue) in l {
            // Bookkeeping columns are not conflicts; they change on every
            // write by definition.
            if Self.ignored.contains(key) { continue }
            let remoteValue = r[key]
            if !isEqual(localValue, remoteValue) { changed.append(key) }
        }
        return changed.sorted()
    }

    private static let ignored: Set<String> = [
        "updated_at", "created_at", "version", "origin_token"
    ]

    private static func isEqual(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil):
            return true
        case let (x as String, y as String):
            return x == y
        case let (x as NSNumber, y as NSNumber):
            return x == y
        case let (x as Bool, y as Bool):
            return x == y
        case let (x as [Any], y as [Any]):
            return x.count == y.count && zip(x, y).allSatisfy { isEqual($0, $1) }
        case (is NSNull, nil), (nil, is NSNull), (is NSNull, is NSNull):
            return true
        default:
            return false
        }
    }
}
