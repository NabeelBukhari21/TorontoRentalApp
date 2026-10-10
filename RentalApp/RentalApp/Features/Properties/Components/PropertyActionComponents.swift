//
//  PropertyActionComponents.swift
//  RentalApp (Purrperty)
//
//  Properties — Selection, bulk actions, and the archive.
//

import SwiftUI

// MARK: - Selection Tick

/// The checkbox overlaid on a card while bulk mode is active.
struct SelectionTick: View {

    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isOn ? AnyShapeStyle(DS.Gradients.highlight) : AnyShapeStyle(DS.Colors.surfaceRaised))
                .frame(width: 26, height: 26)
                .overlay(
                    Circle().strokeBorder(
                        isOn ? DS.Colors.brand : DS.Colors.outline,
                        lineWidth: 1.5
                    )
                )

            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Colors.onHighlight)
            }
        }
        .dsShadow(DS.Shadows.soft)
        .animation(DS.Motion.bouncy, value: isOn)
    }
}

// MARK: - Bulk Action Bar

/// Floating bar shown while rows are selected.
///
/// It replaces the FAB rather than sitting beside it: two primary
/// actions competing in the same corner is how a user taps the wrong one.
struct BulkActionBar: View {

    let count: Int
    let onArchive: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Text(count == 0 ? "Select properties" : "\(count) selected")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.Colors.textPrimary)
                .contentTransition(.numericText())

            Spacer(minLength: DS.Spacing.md)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .buttonStyle(DSPressStyle(scale: 0.94))

            Button(action: onArchive) {
                HStack(spacing: DS.Spacing.xs + 2) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Archive")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                }
                .foregroundStyle(DS.Colors.onHighlight)
                .padding(.horizontal, DS.Spacing.md + 2)
                .padding(.vertical, DS.Spacing.sm + 1)
                .background(DS.Gradients.highlight, in: Capsule())
            }
            .buttonStyle(DSPressStyle(scale: 0.94))
            .disabled(count == 0)
            .opacity(count == 0 ? 0.5 : 1)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.surfaceRaised, in: Capsule())
        .overlay(Capsule().strokeBorder(DS.Gradients.cardHairline, lineWidth: 1))
        .dsShadow(DS.Shadows.floating)
        .padding(.horizontal, DS.Spacing.lg)
        .animation(DS.Motion.snappy, value: count)
    }
}

// MARK: - Archived Properties

/// The restore list. Reached from the header, not the main list, because
/// archived rows should never dilute the working set.
struct ArchivedPropertiesView: View {

    let viewModel: PropertyListViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.toasts) private var toasts

    var body: some View {
        NavigationStack {
            ZStack {
                DSAmbientBackground()

                if viewModel.isLoadingArchived {
                    DSListSkeleton(rows: 4)
                        .padding(DS.Spacing.lg)
                } else if viewModel.archived.isEmpty {
                    DSEmptyState(
                        icon: "archivebox",
                        title: "Nothing archived",
                        message: "Archived properties keep their units, leases, and history — and can be restored any time."
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: DS.Spacing.md) {
                            ForEach(Array(viewModel.archived.enumerated()), id: \.element.id) { index, property in
                                ArchivedRow(property: property) {
                                    restore(property)
                                }
                                .dsEntrance(index: min(index, 10))
                            }
                        }
                        .padding(DS.Spacing.lg)
                        .animation(DS.Motion.smooth, value: viewModel.archived.map(\.id))
                    }
                }
            }
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.loadArchived() }
        }
    }

    private func restore(_ property: Property) {
        Task {
            let outcome = await viewModel.restore(property)
            toasts.report(outcome, success: "\(property.name) restored")
        }
    }
}

// MARK: - Archived Row

private struct ArchivedRow: View {

    let property: Property
    let onRestore: () -> Void

    var body: some View {
        DSCard(style: .raised) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: property.kind.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .frame(width: 38, height: 38)
                    .background(DS.Colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(property.name)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(property.address)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.Spacing.sm)

                Button(action: onRestore) {
                    Text("Restore")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Colors.brandInk)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.brand.opacity(0.12), in: Capsule())
                }
                .buttonStyle(DSPressStyle(scale: 0.93))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
}

// MARK: - Previews

#Preview("Bulk bar") {
    ZStack {
        DSAmbientBackground()
        VStack(spacing: DS.Spacing.xl) {
            BulkActionBar(count: 3, onArchive: {}, onCancel: {})
            BulkActionBar(count: 0, onArchive: {}, onCancel: {})
            HStack(spacing: DS.Spacing.lg) {
                SelectionTick(isOn: true)
                SelectionTick(isOn: false)
            }
        }
    }
}
