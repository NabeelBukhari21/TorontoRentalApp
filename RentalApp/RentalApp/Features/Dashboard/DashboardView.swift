//
//  DashboardView.swift
//  RentalApp (Purrperty)
//
//  Dashboard — Home. Toronto fills the top with a pin on every property;
//  the day scrolls up over it in glass: the paw (rent, homes, repairs,
//  tasks, streak), the numbers, and today's tasks. Touch a pin for a quick
//  look at that home; touch the look to go inside.
//

import SwiftUI

struct DashboardView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.container) private var container
    @Environment(\.feedback) private var feedback
    @Environment(\.toasts) private var toasts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model: HomeModel
    @State private var selection: String?
    @State private var picked: PawToe = .rent
    @State private var offset: CGFloat = 0
    @State private var isExploring = false
    @State private var tapThrough: CGPoint?
    @State private var showsWardrobe = false

    init(container: AppContainer = .shared) {
        let dashboard = DashboardViewModel(
            dashboard: container.dashboard,
            notifications: container.notifications,
            payments: container.payments,
            weather: container.weather,
            wardrobe: container.wardrobe,
            preferences: container.preferences
        )
        _model = State(initialValue: HomeModel(dashboard: dashboard, container: container))
    }

    private var dashboard: DashboardViewModel { model.dashboard }

    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let mapHeight = proxy.size.height * 0.58
            let underCards = screen - proxy.safeAreaInsets.top - mapHeight + 110
            ZStack(alignment: .top) {
                HomeMap(
                    model: model, selection: $selection,
                    insets: EdgeInsets(top: 160, leading: 0, bottom: isExploring ? 150 : underCards, trailing: 0),
                    tapThrough: tapThrough,
                    screenHeight: screen
                )
                .ignoresSafeArea()

                // The map fades behind the cards as they cover it. A wash,
                // not a blur: blurring a live 3D map each frame is costly.
                LinearGradient(colors: [DS.Colors.background.opacity(0), DS.Colors.background.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                    .opacity(isExploring ? 0 : min(1, max(0, offset / 160)))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if isExploring {
                    exploreBar.transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    cards(mapHeight: mapHeight, width: proxy.size.width)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                HomeBar(model: model, onGlass: true) { showsWardrobe = true }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .overlay(alignment: .bottom) { popup.padding(.horizontal, 14).padding(.bottom, 10) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("Home")
        .animation(DS.Motion.smooth, value: selection)
        .task { await model.load() }
        .sheet(isPresented: $showsWardrobe) { WardrobeView(wardrobe: dashboard.wardrobe) }
        .onChange(of: dashboard.newOutfits) { _, outfits in
            guard !outfits.isEmpty else { return }
            feedback?.play(.celebrate)
            toasts.success(
                outfits.count == 1 ? "New outfit for Purr: \(outfits[0].title)" : "\(outfits.count) new outfits for Purr",
                mood: outfits[0].mood ?? .celebrate
            )
            dashboard.announcedOutfits()
        }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .properties) { await model.refresh() }
        }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .maintenanceRequests) { await model.refresh() }
        }
        .liveUpdates(container.sync) {
            // Leases and the payments against them: rent collected.
            LiveList.reloadSubscription(topic: .leases) { await model.refresh() }
        }
    }

    // MARK: Cards

    private func cards(mapHeight: CGFloat, width: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                // See-through: the map shows here. A tap is passed down to
                // the nearest pin; the scroll view would otherwise take it.
                Color.clear
                    .frame(height: mapHeight - 110)
                    .contentShape(.rect)
                    .onTapGesture(coordinateSpace: .global) { tapThrough = $0 }
                    .overlay(alignment: .bottomTrailing) {
                        Button { withAnimation(DS.Motion.smooth) { isExploring = true } } label: {
                            Label("Explore map", systemImage: "map.fill")
                                .font(DS.Typography.brand(.subheadline, weight: .semibold))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .padding(.horizontal, 14).frame(height: 40)
                                .glassEffect(.regular.interactive(), in: .capsule)
                        }
                        .buttonStyle(SquishStyle())
                        .padding(.bottom, 8)
                    }
                    .accessibilityHidden(true)

                if let error = dashboard.error {
                    DSErrorView(error: error) { await model.refresh() }.homeGlass()
                }
                PawPanel(model: model, picked: $picked, pawSize: min(300, width - 80))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    GlassStat(symbol: "dollarsign", value: model.dollars(model.roll.collected), label: "Rent this month", accent: .mint) { router.push(.rentCollection) }
                    GlassStat(symbol: "key.fill", value: "\(dashboard.occupiedUnits)/\(dashboard.unitCount)", label: "Units rented", accent: .gold) { router.select(.properties) }
                    GlassStat(symbol: "wrench.fill", value: "\(model.requests)", label: "Repairs open", accent: .cherry) { router.select(.maintenance) }
                    GlassStat(symbol: "bell.fill", value: "\(dashboard.unreadNotifications)", label: "Unread", accent: .sky) { router.push(.notifications) }
                }
                TodayGlass(model: model)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in
            // Only what the wash needs: rounding stops a redraw per point.
            let stepped = (min(160, max(0, y)) / 8).rounded() * 8
            if stepped != offset { offset = stepped }
        }
        .purrRefreshable { await model.refresh() }
    }

    private var exploreBar: some View {
        VStack {
            Spacer()
            Button { withAnimation(DS.Motion.smooth) { isExploring = false; selection = nil } } label: {
                Label("Back to my day", systemImage: "chevron.up")
                    .font(DS.Typography.brand(.headline, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, 18).frame(height: 50)
                    .homeGlass(radius: 25)
            }
            .buttonStyle(SquishStyle())
            .padding(.bottom, selection == nil ? 12 : 230)
        }
    }

    // MARK: Popup

    @ViewBuilder private var popup: some View {
        if let id = selection, let index = model.properties.firstIndex(where: { $0.id == id }) {
            let property = model.properties[index]
            PropertyPopup(
                property: property, accent: HomeMap.accents[index % HomeMap.accents.count],
                onOpen: { router.push(.propertyDetail(propertyID: property.id)) },
                onClose: { selection = nil }
            )
            .id(property.id)
            .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Previews

#Preview("Home") {
    RootNavigationView()
}
