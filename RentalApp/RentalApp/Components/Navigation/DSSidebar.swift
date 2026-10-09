//
//  DSSidebar.swift
//  RentalApp
//
//  Navigation — iPad sidebar for NavigationSplitView.
//  Sections mirror the tab bar plus workspace and account destinations.
//

import SwiftUI

struct DSSidebar: View {

    @Bindable var router: AppRouter

    var body: some View {
        List {
            Section {
                ForEach(AppTab.allCases) { tab in
                    tabRow(tab)
                }
            } header: {
                Text("Workspace").dsOverline()
            }

            Section {
                routeRow(.documents)
                routeRow(.notifications)
            } header: {
                Text("Library").dsOverline()
            }

            Section {
                routeRow(.profile)
                routeRow(.settings)
            } header: {
                Text("Account").dsOverline()
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle("RentOS")
    }

    // MARK: Rows

    private func tabRow(_ tab: AppTab) -> some View {
        let isSelected = router.selectedTab == tab

        return Button {
            router.select(tab)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                iconTile(tab.icon, highlighted: isSelected)

                Text(tab.title)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)

                Spacer()

                if isSelected {
                    Circle()
                        .fill(DS.Colors.brand)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Colors.brand.opacity(0.10))
                : nil
        )
    }

    private func routeRow(_ route: AppRoute) -> some View {
        Button {
            router.push(route)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                iconTile(route.icon, highlighted: false)

                Text(route.title)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)

                Spacer()

                Image(systemName: DS.Icons.chevronRight)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconTile(_ icon: String, highlighted: Bool) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(highlighted ? AnyShapeStyle(Color.white) : AnyShapeStyle(DS.Colors.brand))
            .frame(width: 30, height: 30)
            .background {
                if highlighted {
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(DS.Gradients.brand)
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(DS.Colors.brand.opacity(0.10))
                }
            }
    }
}
