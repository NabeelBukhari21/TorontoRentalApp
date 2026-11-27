//
//  WorkspaceArchive.swift
//  RentalApp (Purrperty)
//
//  Fake Backend — What the mock backend keeps on the phone between
//  launches: each workspace's edits (see `WorkspaceLocal(saved:)`), and
//  the mock directory of accounts and invites (`MockDirectory`).
//
//  One JSON file per workspace in Application Support. Reads are cached
//  decoded, so a saved overlay costs no more to read than a plain one.
//  Stands in for the database until Supabase is configured.
//

import Foundation
import OSLog

@MainActor
final class WorkspaceArchive {

    static let shared = WorkspaceArchive()

    private let folder: URL
    /// Workspace key → entry key → encoded value, as on disk.
    private var files: [String: [String: Data]] = [:]
    /// Decoded values, so a read doesn't decode again.
    private var decoded: [String: Any] = [:]

    init(folder: URL? = nil) {
        let base = folder ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
        self.folder = base.appending(path: "MockWorkspaces", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
        #if DEBUG
        // Test builds: launch with `-PurrpertyResetMockData YES` to start
        // from the seeded demo again, with no saved accounts or edits.
        if UserDefaults.standard.bool(forKey: "PurrpertyResetMockData") { eraseAll() }
        #endif
    }

    func value<Value: Decodable>(_ key: String, in workspace: String, as type: Value.Type = Value.self) -> Value? {
        let id = "\(workspace)|\(key)"
        if let cached = decoded[id] as? Value { return cached }
        guard let data = file(workspace)[key], let value = try? JSONDecoder().decode(Value.self, from: data) else { return nil }
        decoded[id] = value
        return value
    }

    func set<Value: Encodable>(_ value: Value, for key: String, in workspace: String) {
        decoded["\(workspace)|\(key)"] = value
        guard let data = try? JSONEncoder().encode(value) else { return }
        var entries = file(workspace)
        entries[key] = data
        files[workspace] = entries
        write(workspace, entries)
    }

    /// Forgets everything saved, for every workspace.
    func eraseAll() {
        files = [:]
        decoded = [:]
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    // MARK: Files

    private func url(_ workspace: String) -> URL {
        let name = workspace.map { $0.isLetter || $0.isNumber || $0 == "_" ? $0 : "-" }
        return folder.appending(path: String(name) + ".json")
    }

    private func file(_ workspace: String) -> [String: Data] {
        if let entries = files[workspace] { return entries }
        let entries = (try? Data(contentsOf: url(workspace))).flatMap { try? JSONDecoder().decode([String: Data].self, from: $0) } ?? [:]
        files[workspace] = entries
        return entries
    }

    private func write(_ workspace: String, _ entries: [String: Data]) {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url(workspace), options: [.atomic, .completeFileProtection])
        } catch {
            AppLog.database.failure("Couldn't save the mock workspace", error: error)
        }
    }
}
