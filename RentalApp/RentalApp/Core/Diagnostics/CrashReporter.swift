//
//  CrashReporter.swift
//  RentalApp (Purrperty)
//
//  Core/Diagnostics — Catching the crash, and surviving it.
//
//  ─────────────────────────────────────────────────────────────────
//  WHAT YOU MAY DO IN A SIGNAL HANDLER
//  ─────────────────────────────────────────────────────────────────
//  Almost nothing. A signal handler runs on the crashing thread,
//  interrupting it at an arbitrary instruction — possibly in the middle
//  of `malloc`. The list of async-signal-safe functions is short and
//  does not include: `malloc`, `free`, anything that allocates, any
//  lock, `NSLog`, `print`, `String` interpolation, dictionary access,
//  ARC retain/release, or essentially any Swift runtime call.
//
//  This is the single most common defect in hand-rolled crash
//  reporters, and its symptom is the worst possible one: the handler
//  deadlocks on the allocator lock held by the thread it interrupted,
//  so instead of a crash the user gets a *hang*, and no report is ever
//  written. The crash reporter makes the crash worse.
//
//  The design here accepts that constraint instead of fighting it:
//
//  • Everything the handler could need is allocated and formatted
//    BEFORE the crash — at install time — into a fixed C buffer.
//  • The handler itself does exactly two things: `write(2)` to an
//    already-open file descriptor, and re-raise. Both are on the safe
//    list.
//  • All the expensive work — symbolication, JSON, upload — happens on
//    the NEXT launch, where there is a working runtime.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY NOT JUST USE A VENDOR SDK
//  ─────────────────────────────────────────────────────────────────
//  You should, eventually — PLCrashReporter and Crashlytics handle
//  Mach exceptions, stack unwinding across threads, and symbolication,
//  which is a great deal more than this does. This exists so the app
//  has a working diagnostics *pipeline* (consent, storage, upload,
//  breadcrumbs) that a vendor can be dropped into later without
//  redesigning anything around it. Its limits are stated honestly at
//  the bottom of this file.
//

import Foundation
import Darwin
import OSLog

// MARK: - Report

/// What is known about a crash. Written on the next launch, not during
/// the crash — the on-disk format during a crash is a raw byte buffer.
struct CrashReport: Codable, Sendable, Equatable {

    enum Kind: String, Codable, Sendable {
        case signal
        case uncaughtException
        /// The app was killed while in the foreground with no signal
        /// recorded — the signature of an OOM or a watchdog kill.
        case abnormalTermination
    }

    let id: UUID
    let kind: Kind
    /// e.g. "SIGSEGV" or the exception name.
    let reason: String
    let occurredAt: Date
    let appVersion: String
    let buildNumber: String
    let environment: String
    let osVersion: String
    let deviceModel: String
    /// Recent app events leading up to the crash.
    let breadcrumbs: [String]
    /// Present only with `.personalization` consent.
    let userID: String?
    /// Frame addresses. Not symbolicated on-device — see the note on
    /// symbolication at the bottom of this file.
    let callStack: [String]
}

// MARK: - Signal-Safe Storage

// Globals, not a class.
//
// A C signal handler is a bare function pointer and cannot capture
// context, so its state has to be reachable without a closure. It is
// also plain C storage rather than a Swift object on purpose: reading a
// class reference retains it, and a retain can allocate — which is the
// one thing the handler must never do. Int32 and a raw pointer can be
// read with no runtime involvement at all.
//
// `nonisolated(unsafe)` states plainly that this is unsynchronized by
// necessity: the handler runs where locks are forbidden, so a lock here
// would be worse than none.

/// Open before the crash. `open(2)` is itself safe, but doing it up
/// front means one less thing that can fail while the process is dying.
private nonisolated(unsafe) var crashFileDescriptor: Int32 = -1

/// Header bytes — version, build, environment — rendered at install
/// time while `String` still works, then held as raw memory.
private nonisolated(unsafe) var crashHeaderBuffer: UnsafeMutablePointer<CChar>?
private nonisolated(unsafe) var crashHeaderLength: Int = 0

/// Signal name as a compile-time constant.
///
/// A `switch` over `StaticString`, not a dictionary lookup: hashing and
/// `Dictionary` subscripting are Swift runtime calls that may allocate.
/// Every branch here resolves to a pointer into the binary's constant
/// data, so there is nothing to allocate.
private func crashSignalName(_ signal: Int32) -> StaticString {
    switch signal {
    case SIGABRT: "SIGABRT\n"
    case SIGILL:  "SIGILL\n"
    case SIGSEGV: "SIGSEGV\n"
    case SIGFPE:  "SIGFPE\n"
    case SIGBUS:  "SIGBUS\n"
    case SIGTRAP: "SIGTRAP\n"
    default:      "SIGUNKNOWN\n"
    }
}

/// The handler. Only `write`, `fsync`, `close`, `signal`, `raise` and
/// `_exit` — all on the POSIX async-signal-safe list.
private func handleFatalSignal(_ signal: Int32) {
    guard crashFileDescriptor >= 0 else {
        Darwin.signal(signal, SIG_DFL)
        raise(signal)
        return
    }

    if let header = crashHeaderBuffer, crashHeaderLength > 0 {
        _ = write(crashFileDescriptor, header, crashHeaderLength)
    }

    // `withUTF8Buffer` on a StaticString hands back a pointer to constant
    // storage; it does not allocate or copy.
    crashSignalName(signal).withUTF8Buffer { buffer in
        if let base = buffer.baseAddress {
            _ = write(crashFileDescriptor, base, buffer.count)
        }
    }

    _ = fsync(crashFileDescriptor)
    _ = Darwin.close(crashFileDescriptor)
    crashFileDescriptor = -1

    // Restore the default handler and re-raise, so the OS still produces
    // its own crash log. Swallowing the signal would mean losing the
    // real, symbolicated report Apple would otherwise generate — this
    // reporter supplements that, it does not replace it.
    Darwin.signal(signal, SIG_DFL)
    raise(signal)
}

/// Prepares the handler's storage. Runs at install time, on a normal
/// thread, where allocation and `String` are perfectly fine.
private func prepareCrashStorage(path: String, header: String) {
    // 0o600 — a crash report carries breadcrumbs describing user
    // activity, so it is not world-readable.
    crashFileDescriptor = open(path, O_CREAT | O_WRONLY | O_TRUNC, 0o600)

    let bytes = Array(header.utf8)
    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count)
    for (index, byte) in bytes.enumerated() {
        buffer[index] = CChar(bitPattern: byte)
    }
    crashHeaderBuffer = buffer
    crashHeaderLength = bytes.count
}

// MARK: - Reporter

@MainActor
final class CrashReporter {

    private let consent: ConsentStore
    private let breadcrumbs: BreadcrumbTrail
    private let configuration: AppConfiguration
    private let fileManager = FileManager.default

    private var isInstalled = false

    init(
        consent: ConsentStore,
        breadcrumbs: BreadcrumbTrail,
        configuration: AppConfiguration = .current
    ) {
        self.consent = consent
        self.breadcrumbs = breadcrumbs
        self.configuration = configuration
    }

    // MARK: Install

    /// Installs the handlers. Call once, as early as possible.
    ///
    /// Note this runs regardless of consent. Consent governs whether a
    /// report is *transmitted*, not whether it is captured: a user who
    /// has not yet been asked, crashes, and then grants consent should
    /// still be able to send that report. Nothing leaves the device
    /// without `.diagnostics` consent — see `pendingReports`.
    func install() {
        guard !isInstalled else { return }
        isInstalled = true

        prepareCrashStorage(
            path: Self.markerPath(fileManager: fileManager).path,
            header: """
                RENTOS-CRASH-V1
                version=\(configuration.build.version)
                build=\(configuration.build.build)
                env=\(configuration.environment.rawValue)
                time=\(Date().timeIntervalSince1970)
                signal=
                """
        )

        for signalNumber in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP] {
            Darwin.signal(signalNumber, handleFatalSignal)
        }

        NSSetUncaughtExceptionHandler { exception in
            // This one is NOT a signal handler — it runs on a normal
            // thread with a working runtime, so Foundation is allowed
            // here. It is only the C signal path that is constrained.
            CrashReporter.recordExceptionSynchronously(exception)
        }

        AppLog.diagnostics.notice("Crash handlers installed")
    }

    // MARK: Exception path

    private static func recordExceptionSynchronously(_ exception: NSException) {
        let payload = """
            RENTOS-CRASH-V1
            kind=exception
            name=\(exception.name.rawValue)
            time=\(Date().timeIntervalSince1970)
            stack=\(exception.callStackSymbols.prefix(40).joined(separator: "|"))
            """
        let path = markerPath(fileManager: .default)
        try? payload.data(using: .utf8)?.write(to: path, options: .atomic)
    }

    // MARK: Next-launch collection

    /// Reads any marker left by a previous run and converts it into a
    /// report. Called at launch, after the runtime is up.
    func collectPendingReport() -> CrashReport? {
        let path = Self.markerPath(fileManager: fileManager)
        guard let data = try? Data(contentsOf: path),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Consume it either way: a marker that fails to parse must not
        // be reprocessed on every subsequent launch forever.
        try? fileManager.removeItem(at: path)

        let fields = Self.parseMarker(text)
        let signalName = fields["signal"] ?? fields["name"] ?? "unknown"

        let report = CrashReport(
            id: UUID(),
            kind: fields["kind"] == "exception" ? .uncaughtException : .signal,
            reason: signalName,
            occurredAt: fields["time"].flatMap(Double.init).map(Date.init(timeIntervalSince1970:)) ?? Date(),
            appVersion: fields["version"] ?? configuration.build.version,
            buildNumber: fields["build"] ?? configuration.build.build,
            environment: fields["env"] ?? configuration.environment.rawValue,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: Self.deviceModel(),
            breadcrumbs: breadcrumbs.restorePrevious(),
            userID: consent.allows(.personalization) ? breadcrumbs.lastKnownUserID : nil,
            callStack: (fields["stack"] ?? "").split(separator: "|").map(String.init)
        )

        AppLog.diagnostics.notice(
            "Recovered crash report: \(report.reason, privacy: .public)"
        )
        return report
    }

    /// Whether a recovered report may leave the device.
    func mayTransmit() -> Bool {
        consent.allows(.diagnostics)
            && configuration.environment.transmitsDiagnostics
            && configuration.diagnosticsEndpoint != nil
    }

    // MARK: Helpers

    private static func markerPath(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("crash-marker.txt")
    }

    private static func parseMarker(_ text: String) -> [String: String] {
        var fields: [String: String] = [:]
        for line in text.split(separator: "\n") {
            guard let separator = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<separator])
            let value = String(line[line.index(after: separator)...])
            guard !value.isEmpty else { continue }
            fields[key] = value
        }
        return fields
    }

    private static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        // Fixed-size C tuple → String. Safe here; this is launch, not a
        // signal handler.
        let identifier = withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return identifier
    }
}

// MARK: - Known Limits
//
// Stated explicitly so nobody mistakes this for a full crash reporter:
//
// 1. NO MACH EXCEPTIONS. iOS delivers most fatal memory errors as Mach
//    exceptions before they become BSD signals. A Mach exception handler
//    needs a dedicated thread and `mach_msg` plumbing. In practice this
//    means some EXC_BAD_ACCESS crashes are missed.
//
// 2. NO ON-DEVICE SYMBOLICATION. Only the exception path captures
//    `callStackSymbols`, and those are unsymbolicated addresses in a
//    release build. Symbolication needs the dSYM, server-side. Upload
//    the dSYM with every release or the stacks are unreadable.
//
// 3. NO STACK CAPTURE FROM THE SIGNAL PATH. Walking the stack safely
//    inside a handler requires an async-signal-safe unwinder. Not
//    attempted rather than attempted badly.
//
// 4. OOM KILLS ARE NOT CRASHES. The jetsam killer sends no catchable
//    signal. `CrashReport.Kind.abnormalTermination` exists for the
//    heuristic — clean-exit flag absent on next launch — but that
//    heuristic is not wired up yet.
//
// When these matter more than the dependency cost, adopt PLCrashReporter
// and keep everything else in this folder: consent, breadcrumbs, upload
// and storage are all reusable as-is.
