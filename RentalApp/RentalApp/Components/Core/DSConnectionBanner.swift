//
//  DSConnectionBanner.swift
//  RentalApp (Purrperty)
//
//  Components — Connection status, shown only when it matters.
//
//  Three rules, learned from apps that get this wrong:
//
//  1. Silence when healthy. A persistent "Connected" chip is noise that
//     trains users to ignore the space where the real warning appears.
//  2. Don't flash. A 200ms blip during a Wi-Fi handoff should show nothing
//     at all, so the banner waits before appearing.
//  3. Say whose problem it is. "Reconnecting…" when the user has no signal
//     is unactionable; "You're offline" tells them what to do.
//

import SwiftUI

struct DSConnectionBanner: View {

    let state: RealtimeConnectionState
    let pendingCount: Int
    let onRetry: () -> Void

    /// Gates the appearance so a brief drop never renders.
    @State private var isVisible = false

    private var tint: Color {
        switch state {
        case .offline:            DS.Colors.warning
        case .failed:             DS.Colors.danger
        case .connecting,
             .reconnecting:       DS.Colors.info
        case .connected, .idle:   DS.Colors.success
        }
    }

    private var icon: String {
        switch state {
        case .offline:      "wifi.slash"
        case .failed:       DS.Icons.warning
        default:            "arrow.triangle.2.circlepath"
        }
    }

    private var message: String {
        guard let base = state.bannerMessage else { return "" }
        guard pendingCount > 0 else { return base }
        // Reassurance beats accuracy here: the user wants to know their work
        // is not lost, not the exact queue depth semantics.
        let noun = pendingCount == 1 ? "change" : "changes"
        return "\(base) \(pendingCount) \(noun) waiting to sync."
    }

    var body: some View {
        Group {
            if isVisible, state.bannerMessage != nil {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                        .symbolEffect(.pulse, isActive: !isOffline)

                    Text(message)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: DS.Spacing.xs)

                    // Retry only where tapping can actually help. Offering it
                    // with no network invites a pointless tap.
                    if case .failed = state {
                        Button("Retry", action: onRetry)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.brand)
                            .buttonStyle(DSPressStyle(scale: 0.94))
                    }
                }
                .padding(.horizontal, DS.Spacing.md + 2)
                .padding(.vertical, DS.Spacing.sm + 2)
                .background(DS.Colors.surfaceRaised, in: Capsule())
                .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
                .dsShadow(DS.Shadows.soft)
                .padding(.horizontal, DS.Spacing.lg)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: state) { await updateVisibility() }
        .animation(DS.Motion.smooth, value: isVisible)
    }

    private var isOffline: Bool {
        if case .offline = state { return true }
        return false
    }

    /// Appear after a grace period, disappear immediately.
    ///
    /// Asymmetric on purpose: a slow appearance hides blips, and a slow
    /// disappearance would leave a stale warning on screen after recovery.
    private func updateVisibility() async {
        guard state.bannerMessage != nil else {
            isVisible = false
            return
        }
        // Offline is worth saying straight away; a reconnect attempt is not.
        let grace: Duration = isOffline ? .milliseconds(250) : .seconds(2)
        try? await Task.sleep(for: grace)
        guard !Task.isCancelled else { return }
        isVisible = true
    }
}

// MARK: - Host

private struct ConnectionBannerHost: ViewModifier {

    let engine: SyncEngine
    let outbox: MutationOutbox

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                DSConnectionBanner(
                    state: engine.state,
                    pendingCount: outbox.pendingCount,
                    onRetry: { engine.retryNow() }
                )
                // Below the status bar, above the header.
                .padding(.top, DS.Spacing.xs)
            }
    }
}

extension View {
    /// Mount the connection banner. Applied once, at the root.
    func dsConnectionBanner(engine: SyncEngine, outbox: MutationOutbox) -> some View {
        modifier(ConnectionBannerHost(engine: engine, outbox: outbox))
    }
}

// MARK: - Previews

#Preview("Connection states") {
    ZStack {
        DSAmbientBackground()
        VStack(spacing: DS.Spacing.lg) {
            DSConnectionBanner(state: .offline, pendingCount: 3, onRetry: {})
            DSConnectionBanner(state: .reconnecting(attempt: 2, nextRetry: .now), pendingCount: 0, onRetry: {})
            DSConnectionBanner(state: .failed("Connection failed"), pendingCount: 1, onRetry: {})
            // Renders nothing — healthy is silent.
            DSConnectionBanner(state: .connected(since: .now), pendingCount: 0, onRetry: {})
        }
    }
}
