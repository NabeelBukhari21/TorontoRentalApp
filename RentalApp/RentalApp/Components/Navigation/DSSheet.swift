//
//  DSSheet.swift
//  RentalApp
//
//  Navigation — Bottom sheets, reusable modals, and full-screen presentations.
//  DSModalCard is the shared modal chrome; containers map presentation
//  routes to placeholder content until real screens exist.
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

    /// Presents a bottom sheet with the design-system treatment:
    /// material background, large corner radius, custom grabber.
    func dsBottomSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: Set<PresentationDetent> = [.medium],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item) { value in
            content(value)
                .presentationDetents(detents)
                .presentationCornerRadius(DS.Radius.xxl)
                .presentationDragIndicator(.hidden)
                .presentationBackground(DS.Colors.surfaceRaised)
        }
    }
}

// MARK: - Sheet Container

/// Resolves a `DSSheetRoute` to modal content. Placeholders for now.
struct DSSheetContainer: View {

    let route: DSSheetRoute

    var body: some View {
        Group {
            switch route {
            case .globalSearch:
                GlobalSearchView()
            case .newProperty:
                // Reachable from a deep link or any other `router.present`
                // call site, not just the Properties FAB — so it points at
                // the real form rather than a placeholder.
                PropertyFormView(mode: .create)
            case .newTenant:
                CreateTenantView()
            default:
                placeholderCard
            }
        }
        .presentationDetents(route.detents)
        .presentationCornerRadius(DS.Radius.xxl)
        .presentationDragIndicator(.hidden)
        .presentationBackground(DS.Colors.surfaceRaised)
    }

    private var placeholderCard: some View {
        DSModalCard(title: route.title) {
            VStack(spacing: DS.Spacing.lg) {
                DSEmptyState(
                    icon: icon,
                    title: route.title,
                    message: "\(route.title) is on its way — this space is reserved for it in the next release."
                )
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private var icon: String {
        switch route {
        // `.globalSearch` never actually reaches `placeholderCard` — the
        // body switch above resolves it to `GlobalSearchView` first. It is
        // listed anyway because exhaustiveness is the point: writing
        // `default:` here would compile today and then silently give the
        // wrong icon to whatever case is added to `DSSheetRoute` next,
        // instead of failing the build the way this just did.
        case .globalSearch: DS.Icons.search
        case .quickActions: DS.Icons.add
        case .newProperty: DS.Icons.properties
        case .newMaintenanceRequest: DS.Icons.maintenance
        case .newTenant: DS.Icons.tenant
        case .filters: DS.Icons.filter
        }
    }
}

// MARK: - Full-Screen Container

/// Resolves a `DSFullScreenRoute` to an immersive cover. Placeholders for now.
struct DSFullScreenContainer: View {

    let route: DSFullScreenRoute

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background

            VStack(spacing: DS.Spacing.lg) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(foreground)
                    .dsFloating()

                Text(route.title)
                    .font(DS.Typography.title1)
                    .foregroundStyle(foreground)

                Text("This immersive flow arrives in the next release.")
                    .font(DS.Typography.callout)
                    .foregroundStyle(foreground)
                    .multilineTextAlignment(.center)

                Spacer()

                DSButton(title: "Dismiss", variant: .soft, size: .large, isFullWidth: true) {
                    dismiss()
                }
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .padding(DS.Spacing.xl)

            DSIconButton(icon: DS.Icons.close, diameter: 38) {
                dismiss()
            }
            .padding(DS.Spacing.xl)
        }
    }

    /// Text on this screen's background. The photo viewer is black in both
    /// modes, so it needs fixed white; the others sit on the brand gradient,
    /// where `textOnBrand` adapts with it.
    private var foreground: Color {
        switch route {
        case .photoViewer: DS.Colors.onFixedColor
        case .onboarding, .authentication: DS.Colors.textOnBrand
        }
    }

    @ViewBuilder
    private var background: some View {
        switch route {
        case .photoViewer:
            DS.Colors.mediaBackground.ignoresSafeArea()
        case .onboarding, .authentication:
            ZStack {
                DS.Gradients.brand.ignoresSafeArea()
                DSAmbientBackground().opacity(0.5)
            }
        }
    }

    private var icon: String {
        switch route {
        case .onboarding: DS.Icons.aiAssistant
        case .authentication: "lock.shield.fill"
        case .photoViewer: DS.Icons.camera
        }
    }
}

// MARK: - Previews

#Preview("Bottom Sheet") {
    struct Demo: View {
        @State private var sheet: DSSheetRoute? = nil

        var body: some View {
            ZStack {
                DSAmbientBackground()
                DSButton(title: "Present Sheet", variant: .primary) {
                    sheet = .quickActions
                }
            }
            .sheet(item: $sheet) { route in
                DSSheetContainer(route: route)
            }
        }
    }
    return Demo()
}

#Preview("Full Screen") {
    DSFullScreenContainer(route: .onboarding)
}
