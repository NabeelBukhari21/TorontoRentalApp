//
//  PushServiceBox.swift
//  RentalApp (RentOS)
//
//  Core/Notifications — Breaking the push ↔ coordinator cycle.
//
//  `NotificationCoordinator` needs a `PushServiceProtocol` to set badges and
//  request permission. `PushService` needs a `PushSink` — which is the
//  coordinator — to upload tokens and report taps. Neither can be finished
//  before the other exists.
//
//  The usual fixes are worse than this one:
//
//   • Make the sink `weak var` and set it after construction — works, but
//     every call site has to remember, and a forgotten assignment fails
//     silently at 3am when a push arrives.
//   • Merge them into one class — puts APNs registration, entitlement
//     handling and badge logic in the same type as repository calls, which
//     makes the whole thing untestable without a device.
//
//  A box makes the two-step construction explicit and impossible to skip:
//  the container builds the box, hands it to the coordinator, then attaches
//  the real service. Before attachment it degrades to a no-op rather than
//  trapping, so a preview that never attaches simply has no push.
//

import Foundation
import Observation

@MainActor
@Observable
final class PushServiceBox: PushServiceProtocol {

    private var wrapped: PushServiceProtocol?

    /// Completes the graph. Called once, immediately after the coordinator
    /// is constructed.
    func attach(_ service: PushServiceProtocol) {
        wrapped = service
        service.configure()
    }

    // MARK: PushServiceProtocol

    var authorization: PushAuthorizationState {
        wrapped?.authorization ?? .notDetermined
    }

    var deviceToken: String? { wrapped?.deviceToken }

    func configure() {
        wrapped?.configure()
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        await wrapped?.requestAuthorization() ?? false
    }

    func refreshAuthorization() async {
        await wrapped?.refreshAuthorization()
    }

    func register(deviceToken: Data) async {
        await wrapped?.register(deviceToken: deviceToken)
    }

    func setBadge(_ count: Int) async {
        await wrapped?.setBadge(count)
    }
}
