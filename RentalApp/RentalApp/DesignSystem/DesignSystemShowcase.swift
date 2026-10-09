//
//  DesignSystemShowcase.swift
//  RentalApp
//
//  Design System — Living gallery of every token and component.
//  Open this file's preview in Xcode canvas to browse the system.
//  Not shipped as a screen; it exists for design QA and reference.
//

import SwiftUI

struct DesignSystemShowcase: View {

    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var occupancy = 0.94
    @State private var revenue = 128

    private let filters = ["All", "Urgent", "In Progress", "Done"]

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxxl) {
                    header
                    colorSection
                    buttonSection
                    cardSection
                    inputSection
                    indicatorSection
                    avatarSection
                    progressSection
                    loadingSection
                    emptySection
                }
                .padding(DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.huge)
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Design System").dsOverline()
            Text("RentOS UI Kit")
                .font(DS.Typography.title1)
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .dsEntrance(index: 0)
    }

    private var colorSection: some View {
        section("Colors & Gradients", index: 1) {
            VStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    swatch(DS.Colors.brand, "Brand")
                    swatch(DS.Colors.accentSunnyInk, "Violet")
                    swatch(DS.Colors.accentSkyInk, "Cyan")
                    swatch(DS.Colors.accentCoralInk, "Coral")
                    swatch(DS.Colors.accentSunnyInk, "Amber")
                }
                HStack(spacing: DS.Spacing.sm) {
                    gradientSwatch(DS.Gradients.brand, "Brand")
                    gradientSwatch(DS.Gradients.ai, "AI")
                    gradientSwatch(DS.Gradients.warm, "Warm")
                    gradientSwatch(DS.Gradients.success, "Success")
                }
            }
        }
    }

    private var buttonSection: some View {
        section("Buttons", index: 2) {
            VStack(spacing: DS.Spacing.md) {
                DSButton(title: "Add Property", icon: DS.Icons.add, variant: .primary, size: .large, isFullWidth: true) {}
                HStack(spacing: DS.Spacing.md) {
                    DSButton(title: "Secondary", variant: .secondary) {}
                    DSButton(title: "Ghost", variant: .ghost) {}
                    DSButton(title: "Glass", icon: DS.Icons.ai, variant: .soft) {}
                }
                HStack(spacing: DS.Spacing.md) {
                    DSIconButton(icon: DS.Icons.search) {}
                    DSIconButton(icon: DS.Icons.filter) {}
                    DSIconButton(icon: DS.Icons.add, variant: .primary) {}
                }
            }
        }
    }

    private var cardSection: some View {
        section("Cards", index: 3) {
            HStack(spacing: DS.Spacing.md) {
                DSStatCard(
                    title: "Occupancy",
                    value: "94%",
                    icon: DS.Icons.occupancy,
                    trend: "+2.1%"
                )
                DSStatCard(
                    title: "Open Requests",
                    value: "12",
                    icon: DS.Icons.maintenance,
                    iconGradient: DS.Gradients.warm,
                    trend: "3 urgent",
                    trendKind: .danger
                )
            }
        }
    }

    private var inputSection: some View {
        section("Inputs", index: 4) {
            VStack(spacing: DS.Spacing.lg) {
                DSSearchBar(text: $searchText, placeholder: "Search properties…")

                HStack(spacing: DS.Spacing.sm) {
                    ForEach(filters, id: \.self) { filter in
                        DSChip(title: filter, isSelected: selectedFilter == filter) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }

    private var indicatorSection: some View {
        section("Badges & Status", index: 5) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.sm) {
                    DSBadge(text: "Urgent", kind: .danger, icon: DS.Icons.warning)
                    DSBadge(text: "Occupied", kind: .success)
                    DSBadge(text: "Pending", kind: .warning)
                    DSBadge(text: "3 new", kind: .info)
                }
                HStack(spacing: DS.Spacing.xl) {
                    DSStatusLabel(text: "Occupied", kind: .success)
                    DSStatusLabel(text: "Urgent", kind: .danger, pulses: true)
                    DSStatusLabel(text: "Vacant", kind: .neutral)
                }
            }
        }
    }

    private var avatarSection: some View {
        section("Avatars", index: 6) {
            HStack(spacing: DS.Spacing.lg) {
                DSAvatar(name: "Sarah Chen", size: .medium, status: .success)
                DSAvatar(name: "Marcus Johnson", size: .medium)
                DSAvatarStack(names: ["Sarah Chen", "Marcus Johnson", "Priya Patel", "Ada Lovelace", "Grace Hopper"])
                Spacer()
            }
        }
    }

    private var progressSection: some View {
        section("Progress & Counters", index: 7) {
            VStack(spacing: DS.Spacing.xl) {
                DSProgressBar(value: 0.72)

                HStack(spacing: DS.Spacing.xxl) {
                    DSProgressRing(value: occupancy, label: "Occupancy")

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSAnimatedCounter(value: revenue, prefix: "$", suffix: "K")
                        DSButton(title: "Shuffle Data", variant: .secondary, size: .small) {
                            occupancy = Double.random(in: 0.5...1)
                            revenue = Int.random(in: 80...400)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var loadingSection: some View {
        section("Loading Skeletons", index: 8) {
            VStack(spacing: DS.Spacing.md) {
                DSSkeletonCard()
                DSSkeleton(shape: .rect(height: 80, cornerRadius: DS.Radius.lg))
            }
        }
    }

    private var emptySection: some View {
        section("Empty State", index: 9) {
            DSEmptyState(
                icon: DS.Icons.properties,
                title: "No properties yet",
                message: "Add your first property to start managing units, tenants, and maintenance.",
                actionTitle: "Add Property",
                action: {}
            )
        }
    }

    // MARK: Helpers

    private func section<Content: View>(
        _ title: String,
        index: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title).dsOverline()
            content()
        }
        .dsEntrance(index: index)
    }

    private func swatch(_ color: Color, _ name: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(color)
                .frame(height: 44)
            Text(name)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func gradientSwatch(_ gradient: LinearGradient, _ name: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(gradient)
                .frame(height: 44)
            Text(name)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Design System Showcase") {
    DesignSystemShowcase()
}
