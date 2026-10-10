//
//  OfflineCache.swift
//  RentalApp (Purrperty)
//
//  Core/Offline — The cache that survives launch.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY A SECOND CACHE
//  ─────────────────────────────────────────────────────────────────
//  `RepositoryCache` is a TTL dictionary. It stops a tab switch
//  re-fetching, which is what it was built for — and it dies with the
//  process. Cold-launching on the subway therefore shows an empty app
//  with a spinner, which is the exact moment offline support is supposed
//  to matter.
//
//  This is a second, lower tier rather than a replacement:
//
//    memory (RepositoryCache)  →  fast, holds anything, volatile
//    disk   (OfflineCache)     →  slower, Codable only, survives launch
//
//  Layering instead of merging keeps every existing call site working —
//  and honest about the trade. Only data worth showing while offline pays
//  the encode cost.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY FILES AND NOT A DATABASE
//  ─────────────────────────────────────────────────────────────────
//  A cache is disposable by definition: every entry can be re-fetched.
//  That removes the two things a database buys you here — durability
//  guarantees and query power — and leaves the costs: a schema to
//  migrate, and a corrupted store that bricks launch. One file per key,
//  written atomically, degrades to a cache miss on any failure.
//

import Foundation

// MARK: - Envelope

/// A cached value plus the metadata needed to judge it.
struct CachedEnvelope<Value: Codable & Sendable>: Codable, Sendable {

    let value: Value
    let storedAt: Date
    let lifetime: TimeInterval

    func isFresh(asOf now: Date = .now) -> Bool {
        now.timeIntervalSince(storedAt) < lifetime
    }

    /// How old this is, for the "Updated 4 minutes ago" affordance.
    func age(asOf now: Date = .now) -> TimeInterval {
        now.timeIntervalSince(storedAt)
    }
}

/// A read result that knows whether it is current.
///
/// The whole point of offline reads: the caller must be able to tell
/// "this is live" from "this is what we had". Returning a bare value
/// makes stale data indistinguishable from fresh, which is how an app
/// confidently shows yesterday's rent roll.
struct CachedRead<Value: Sendable>: Sendable {
    let value: Value
    let isStale: Bool
    let storedAt: Date?

    static func live(_ value: Value) -> Self {
        .init(value: value, isStale: false, storedAt: Date())
    }

    static func stale(_ value: Value, from date: Date) -> Self {
        .init(value: value, isStale: true, storedAt: date)
    }
}

// MARK: - Cache

/// Disk-backed cache for anything worth reading while offline.
///
/// An actor because writes happen from whatever context a repository
/// finished on, and file IO must not land on the main thread.
actor OfflineCache {

    private let directory: URL
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Ceiling on total bytes. Exceeding it evicts oldest-first.
    ///
    /// Bounded because a cache that grows forever eventually gets the app
    /// killed for disk usage — and on iOS the user sees that as the app
    /// being broken, not as a cache being thorough.
    private let byteBudget: Int

    /// Tracks sizes so eviction does not have to stat every file.
    private var index: [String: CacheIndexEntry] = [:]

    private struct CacheIndexEntry: Codable {
        var bytes: Int
        var storedAt: Date
        var lifetime: TimeInterval
    }

    private static let indexFilename = "index.json"

    init(
        directoryName: String = "OfflineCache",
        byteBudget: Int = 24 * 1024 * 1024
    ) {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = base.appendingPathComponent(directoryName, isDirectory: true)
        self.byteBudget = byteBudget

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        loadIndex()
    }

    // MARK: Reads

    /// Returns the entry regardless of freshness, so the caller can decide.
    ///
    /// Deliberately not `nil` for stale entries: when the network is down,
    /// a two-hour-old property list is exactly what should be rendered.
    /// Freshness is the caller's judgement, not the cache's.
    func entry<Value: Codable & Sendable>(
        for key: String,
        as type: Value.Type = Value.self
    ) -> CachedEnvelope<Value>? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }

        do {
            return try decoder.decode(CachedEnvelope<Value>.self, from: data)
        } catch {
            // A decode failure means the shape changed — an app update, most
            // likely. Drop it rather than retrying forever; the value is
            // re-fetchable by definition.
            remove(key)
            return nil
        }
    }

    func value<Value: Codable & Sendable>(
        for key: String,
        as type: Value.Type = Value.self
    ) -> Value? {
        entry(for: key, as: type)?.value
    }

    // MARK: Writes

    func store<Value: Codable & Sendable>(
        _ value: Value,
        for key: String,
        lifetime: TimeInterval = 600
    ) {
        let envelope = CachedEnvelope(value: value, storedAt: Date(), lifetime: lifetime)
        guard let data = try? encoder.encode(envelope) else { return }

        let url = fileURL(for: key)
        do {
            // Atomic: a half-written file after a crash would decode as
            // garbage on next launch, and the cache is read before anything
            // else can repair it.
            try data.write(to: url, options: .atomic)
            index[key] = CacheIndexEntry(
                bytes: data.count, storedAt: envelope.storedAt, lifetime: lifetime
            )
            enforceBudget()
            saveIndex()
        } catch {
            // Disk full, or a sandbox problem. Not fatal — the app simply
            // has no offline copy of this one thing.
        }
    }

    // MARK: Eviction

    func remove(_ key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
        index.removeValue(forKey: key)
        saveIndex()
    }

    /// Drops every key beginning with `prefix`. Mirrors `RepositoryCache`,
    /// so one invalidation call can clear both tiers.
    func invalidate(prefix: String) {
        for key in index.keys where key.hasPrefix(prefix) {
            try? fileManager.removeItem(at: fileURL(for: key))
            index.removeValue(forKey: key)
        }
        saveIndex()
    }

    func removeAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        index.removeAll()
        saveIndex()
    }

    /// Evicts expired entries first, then oldest-first until under budget.
    ///
    /// Expiry before age matters: an expired-but-recent entry is worth less
    /// than a fresh-but-older one, and evicting purely by age would throw
    /// away useful data while keeping dead data.
    private func enforceBudget() {
        let now = Date()

        for (key, entry) in index
        where now.timeIntervalSince(entry.storedAt) > entry.lifetime * 4 {
            // 4× the lifetime: past that even offline fallback is misleading.
            try? fileManager.removeItem(at: fileURL(for: key))
            index.removeValue(forKey: key)
        }

        var total = index.values.reduce(0) { $0 + $1.bytes }
        guard total > byteBudget else { return }

        for (key, entry) in index.sorted(by: { $0.value.storedAt < $1.value.storedAt }) {
            try? fileManager.removeItem(at: fileURL(for: key))
            index.removeValue(forKey: key)
            total -= entry.bytes
            if total <= byteBudget { break }
        }
    }

    var currentBytes: Int {
        index.values.reduce(0) { $0 + $1.bytes }
    }

    var entryCount: Int { index.count }

    // MARK: Paths

    /// Keys contain `:` and `/` (namespaces, ids), neither of which is a
    /// safe filename. Hashed rather than escaped so length is bounded too.
    private func fileURL(for key: String) -> URL {
        var hasher = Hasher()
        hasher.combine(key)
        let name = String(format: "%016llx", UInt64(bitPattern: Int64(hasher.finalize())))
        return directory.appendingPathComponent("\(name).json")
    }

    private func loadIndex() {
        let url = directory.appendingPathComponent(Self.indexFilename)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode([String: CacheIndexEntry].self, from: data)
        else { return }
        index = decoded
    }

    private func saveIndex() {
        let url = directory.appendingPathComponent(Self.indexFilename)
        guard let data = try? encoder.encode(index) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Namespaces

/// Cache keys, in one place so a typo cannot silently split a namespace
/// into two that never invalidate each other.
enum OfflineKey {

    static let properties      = "offline.properties"
    static let propertySummary = "offline.properties.summary"
    static let tenants         = "offline.tenants"
    static let maintenance     = "offline.maintenance"
    static let documents       = "offline.documents"
    static let notifications   = "offline.notifications"
    static let conversations   = "offline.conversations"
    static let dashboard       = "offline.dashboard"

    static func units(propertyID: String) -> String { "offline.units.\(propertyID)" }
    static func property(id: String) -> String { "offline.property.\(id)" }

    /// How long each namespace stays *fresh*. Past this it is still served
    /// offline — it is just marked stale.
    static func lifetime(for key: String) -> TimeInterval {
        switch key {
        case notifications, conversations: 120
        case dashboard, propertySummary:   300
        default:                            600
        }
    }
}
