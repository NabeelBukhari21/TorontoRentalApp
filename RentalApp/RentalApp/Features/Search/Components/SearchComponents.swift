//
//  SearchComponents.swift
//  RentalApp (RentOS)
//
//  Search — Result rows, section headers, suggestions.
//

import SwiftUI

// MARK: - Result Row

struct SearchResultRow: View {

    let result: SearchResult
    let isSelected: Bool
    let action: () -> Void

    /// A result with no destination is shown, but not offered as tappable —
    /// navigating somewhere wrong is worse than not navigating.
    private var isOpenable: Bool { result.route != nil }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: result.kind.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(result.kind.tint)
                    .frame(width: 34, height: 34)
                    .background(
                        result.kind.tint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    if let subtitle = result.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    // The matched snippet, with the server's highlighting.
                    Text(SearchHighlight.attributed(result.headline))
                        .font(.system(size: 12.5))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DS.Spacing.sm)

                if isOpenable {
                    Image(systemName: DS.Icons.chevronRight)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.top, 2)
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(isSelected ? DS.Colors.brand.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected ? DS.Colors.brand.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(DSPressStyle(scale: 0.98))
        .disabled(!isOpenable)
        .opacity(isOpenable ? 1 : 0.65)
        .animation(DS.Motion.snappy, value: isSelected)
    }
}

// MARK: - Section Header

struct SearchSectionHeader: View {

    let kind: SearchKind
    let count: Int

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(kind.label.uppercased()).dsOverline()

            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(kind.tint)
                .padding(.horizontal, DS.Spacing.xs + 2)
                .padding(.vertical, 1)
                .background(kind.tint.opacity(0.14), in: Capsule())

            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
        // Pinned headers scroll under content, so they need a backdrop or the
        // rows read through them.
        .background(.ultraThinMaterial)
    }
}

// MARK: - Suggestion Row

struct SearchSuggestionRow: View {

    let suggestion: SearchSuggestion
    let onTap: () -> Void
    /// Only recents can be removed; a shortcut has nothing to forget.
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Button(action: onTap) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(suggestion.text)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.textPrimary)

                        if let subtitle = suggestion.subtitle {
                            Text(subtitle)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(DSPressStyle(scale: 0.98))

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: DS.Icons.close)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(DSPressStyle(scale: 0.9))
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Search Entry Button

/// The affordance that opens global search. Sits in a screen header.
struct SearchEntryButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: DS.Icons.search)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(DS.Gradients.glassHighlight, lineWidth: 1))
        }
        .buttonStyle(DSPressStyle())
        // Hardware-keyboard shortcut. Free on iPad and the Mac catalyst
        // build, invisible on a phone.
        .keyboardShortcut("k", modifiers: .command)
    }
}

// MARK: - Previews

#Preview("Search rows") {
    ZStack {
        DSAmbientBackground()
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                SearchSectionHeader(kind: .property, count: 3)

                SearchResultRow(
                    result: SearchResult(
                        kind: .property, entityID: "1",
                        title: "Queen West Lofts",
                        subtitle: "412 Queen St W, Toronto",
                        headline: "A converted warehouse in «Queen» West with 24 units",
                        status: "active", updatedAt: .now, rank: 1
                    ),
                    isSelected: true, action: {}
                )

                SearchResultRow(
                    result: SearchResult(
                        kind: .maintenanceRequest, entityID: "2",
                        title: "Kitchen tap dripping",
                        subtitle: "Harbourfront · urgent",
                        headline: "Tenant reports the «tap» has been «dripping» since Tuesday",
                        status: "new", updatedAt: .now, rank: 0.8
                    ),
                    isSelected: false, action: {}
                )

                SearchResultRow(
                    result: SearchResult(
                        kind: .vendor, entityID: "3",
                        title: "Bathurst Plumbing",
                        subtitle: "Marco Bianchi · plumbing",
                        headline: "Preferred vendor for «plumbing» across three properties",
                        status: "preferred", updatedAt: .now, rank: 0.5
                    ),
                    isSelected: false, action: {}
                )
            }
            .padding(DS.Spacing.lg)
        }
    }
}
