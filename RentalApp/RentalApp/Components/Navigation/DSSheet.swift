//
//  DSSheet.swift
//  RentalApp
//
//  Navigation — Legacy modal chrome. Route presentations moved to
//  Navigation/PresentationViews.swift. `DSModalCard` remains only until
//  the Tenants and Documents screens are rebuilt (UI rebuild, phase 3).
//

import SwiftUI

// MARK: - Modal Card

/// Shared chrome for every modal: grabber, title row, close button, content.
struct DSModalCard<Content: View>: View {

    let title: String
    var subtitle: String? = nil
    private let content: Content

    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DS.Colors.textTertiary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, DS.Spacing.md)

            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DS.Typography.title3)
                        .foregroundStyle(DS.Colors.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(DS.Typography.footnote)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }

                Spacer()

                DSIconButton(icon: DS.Icons.close, diameter: 34) {
                    dismiss()
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - Presentation Helpers

extension View {

    /// Presents a native sheet with the given detents. The system supplies
    /// the Liquid Glass material, corner radius and grabber.
    func dsBottomSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: Set<PresentationDetent> = [.medium],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item) { value in
            content(value)
                .presentationDetents(detents)
        }
    }
}
