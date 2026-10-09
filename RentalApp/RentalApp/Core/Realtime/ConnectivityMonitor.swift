//
//  ConnectivityMonitor.swift
//  RentalApp (RentOS)
//
//  Core/Realtime — Is there a network at all?
//
//  Worth separating from the socket's own state for one reason: the two
//  failures need different words. "Reconnecting…" when the user is in an
//  elevator is a lie they can't act on; "You're offline" is information.
//
//  It also stops the reconnect loop from burning battery. Retrying a
//  socket on a device with no route is guaranteed to fail — the monitor
//  lets the engine wait for a path instead of backing off against nothing.
//

import Foundation
import Network
import Observation

@MainActor
@Observable
final class ConnectivityMonitor {

    private(set) var isOnline = true
    /// True on cellular, so the UI can avoid auto-downloading a 20MB PDF
    /// and the engine can widen its coalescing windows.
    private(set) var isConstrained = false
    private(set) var isExpensive = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ca.rentos.connectivity")

    /// Fired on every transition to online, so the sync engine can resync
    /// the gap immediately rather than waiting for its next backoff tick.
    private var onReachable: [@MainActor () -> Void] = []

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.apply(path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        // NWPathMonitor.cancel is safe from any context, unlike touching
        // the isolated properties above.
        monitor.cancel()
    }

    func onBecameReachable(_ handler: @escaping @MainActor () -> Void) {
        onReachable.append(handler)
    }

    private func apply(_ path: NWPath) {
        let wasOnline = isOnline
        isOnline = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        // Only on the transition — a Wi-Fi to cellular handoff fires several
        // satisfied paths in a row, and resyncing on each is wasteful.
        if !wasOnline && isOnline {
            onReachable.forEach { $0() }
        }
    }
}
