//
//  DSOfflineIndicators.swift
//  RentalApp (RentOS)
//
//  Components — Telling the truth about what the user is looking at.
//
//  The connection banner says whether the *app* is online. These say
//  whether the *data on this screen* is current, which is a different
//  question and the one that actually matters when someone is about to act
//  on a number.
//
//  Restraint is the design here. A permanent "OFFLINE" chip trains people
//  to ignore the space it occupies; these appear only when something is
//  genuinely not current, and disappear the moment it is.
//

import SwiftUI

// MARK: - Staleness

/// "Saved copy from 20 minutes ago" — shown above a list served from cache.
struct DSStaleDataBar: View {

    let storedAt: Date
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Colors.warning)

            Text("Saved copy · \(storedAt.formatted(.relative(presentation: .named)))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)

            Spacer(minLength: DS.Spacing.xs)

            Button(action: onRefresh) {
                if isRefreshing {
                    ProgressView().controlSize(.mini).tint(DS.Colors.brand)
                } else {
                    Text("Refresh")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Colors.brand)
                }
            }
            .buttonStyle(DSPressStyle(scale: 0.94))
            .disabled(isRefreshing)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.warning.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(DS.Colors.warning.opacity(0.28), lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Pending Badge

/// Marks a row whose change has not reached the server yet.
///
/// Deliberately understated — a small clock, not a warning colour. The
/// change *will* land; the user does not need to worry, only to know that
/// closing the app now means it syncs later.
struct DSPendingBadge: View {

    var label: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 9, weight: .bold))
            if let label {
                Text(label)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(DS.Colors.textTertiary)
        .padding(.horizontal, label == nil ? 4 : DS.Spacing.xs + 2)
        .padding(.vertical, 3)
        .background(DS.Colors.surfaceSecondary, in: Capsule())
        .overlay(Capsule().strokeBorder(DS.Colors.outline, lineWidth: 0.5))
    }
}

// MARK: - Pending Changes Sheet

/// The queue, made visible.
///
/// Users tolerate a delay far better when they can see exactly what is
/// waiting. An invisible queue that fails at 2am is indistinguishable from
/// lost work.
struct PendingChangesView: View {

    let outbox: MutationOutbox
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DSAmbientBackground()

                if !outbox.hasPending && outbox.failures.isEmpty {
                    DSEmptyState(
                        icon: "checkmark.circle",
                        title: "Everything is synced",
                        message: "No changes are waiting to reach the server."
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            if outbox.hasPending {
                                section(
                                    title: "WAITING TO SYNC",
                                    rows: outbox.pendingSummaries.map {
                                        PendingRowData(
                                            id: $0.id, summary: $0.summary,
                                            detail: queuedDetail($0.queuedAt, attempts: $0.attempts),
                                            isFailure: false
                                        )
                                    }
                                )
                            }

                            if !outbox.failures.isEmpty {
                                section(
                                    title: "COULDN'T SYNC",
                                    rows: outbox.failures.map {
                                        PendingRowData(
                                            id: $0.id, summary: $0.summary,
                                            detail: $0.lastError ?? "Rejected by the server",
                                            isFailure: true
                                        )
                                    }
                                )

                                DSButton(
                                    title: "Dismiss failures",
                                    variant: .secondary,
                                    size: .medium,
                                    isFullWidth: true
                                ) {
                                    outbox.clearFailures()
                                }
                            }
                        }
                        .padding(DS.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Pending changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if outbox.hasPending {
                        Button("Sync now") {
                            Task { await outbox.drain() }
                        }
                        .disabled(outbox.isDraining)
                    }
                }
            }
        }
    }

    private struct PendingRowData: Identifiable {
        let id: UUID
        let summary: String
        let detail: String
        let isFailure: Bool
    }

    private func section(title: String, rows: [PendingRowData]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title).dsOverline()

            ForEach(rows) { row in
                DSCard(style: .glass) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: row.isFailure
                              ? DS.Icons.warning : "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(row.isFailure ? DS.Colors.danger : DS.Colors.textTertiary)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.summary)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text(row.detail)
                                .font(DS.Typography.caption)
                                .foregroundStyle(
                                    row.isFailure ? DS.Colors.danger : DS.Colors.textTertiary
                                )
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Retry count is only worth showing once it is non-trivial — "attempt 1"
    /// is noise, "attempt 4" is information.
    private func queuedDetail(_ queuedAt: Date, attempts: Int) -> String {
        let base = "Queued \(queuedAt.formatted(.relative(presentation: .named)))"
        return attempts > 1 ? "\(base) · attempt \(attempts)" : base
    }
}

// MARK: - Conflict Resolution Sheet

struct ConflictResolutionView: View {

    let conflict: PendingConflict
    let center: ConflictCenter

    @Environment(\.dismiss) private var dismiss
    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            ZStack {
                DSAmbientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        DSCard(style: .glass) {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                Text(conflict.title)
                                    .font(DS.Typography.title3)
                                    .foregroundStyle(DS.Colors.textPrimary)

                                Text("This was changed somewhere else while you were editing. Choose which version to keep.")
                                    .font(DS.Typography.footnote)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ForEach(conflict.differences) { difference in
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                Text(difference.label.uppercased()).dsOverline()

                                comparison(
                                    label: "Yours",
                                    value: difference.localValue,
                                    tint: DS.Colors.brand
                                )
                                comparison(
                                    label: "Theirs",
                                    value: difference.remoteValue,
                                    tint: DS.Colors.info
                                )
                            }
                        }

                        VStack(spacing: DS.Spacing.md) {
                            DSButton(
                                title: "Keep mine",
                                variant: .primary,
                                size: .large,
                                isFullWidth: true,
                                isLoading: isResolving
                            ) {
                                resolve(.keepMine)
                            }

                            DSButton(
                                title: "Keep theirs",
                                variant: .secondary,
                                size: .large,
                                isFullWidth: true
                            ) {
                                resolve(.keepTheirs)
                            }
                        }
                        .disabled(isResolving)
                    }
                    .padding(DS.Spacing.lg)
                }
            }
            .navigationTitle("Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Deciding later is legitimate — the conflict stays
                    // queued rather than silently resolving itself.
                    Button("Later") { dismiss() }
                }
            }
        }
    }

    private func comparison(label: String, value: String, tint: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private func resolve(_ choice: ConflictChoice) {
        isResolving = true
        Task {
            await center.resolve(conflict, with: choice)
            isResolving = false
            dismiss()
        }
    }
}

// MARK: - Presentation

private struct ConflictResolutionModifier: ViewModifier {

    @Bindable var center: ConflictCenter

    func body(content: Content) -> some View {
        content.sheet(item: $center.presented) { conflict in
            ConflictResolutionView(conflict: conflict, center: center)
        }
    }
}

extension View {

    /// Presents whichever conflict the centre has surfaced.
    ///
    /// Applied once, at the root. `ConflictResolutionView` was previously
    /// built and then never presented anywhere — a conflict could be
    /// detected, queued and toasted, and the user still had no way to act on
    /// it. Mounting it at the root also matches how conflicts actually
    /// arrive: from background drains, while the user is on some other
    /// screen entirely.
    func dsConflictResolution(_ center: ConflictCenter) -> some View {
        modifier(ConflictResolutionModifier(center: center))
    }
}

// MARK: - Previews

#Preview("Offline indicators") {
    ZStack {
        DSAmbientBackground()
        VStack(spacing: DS.Spacing.xl) {
            DSStaleDataBar(
                storedAt: Date().addingTimeInterval(-1_200),
                isRefreshing: false,
                onRefresh: {}
            )
            HStack(spacing: DS.Spacing.md) {
                DSPendingBadge()
                DSPendingBadge(label: "Pending")
            }
        }
        .padding(DS.Spacing.xl)
    }
}
