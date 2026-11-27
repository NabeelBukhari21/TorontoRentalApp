//
//  DashboardView.swift
//  RentalApp (Purrperty)
//
//  Dashboard — Home. Toronto fills the screen with a pin on every
//  property. Across the top, one search finds any home, tenant or unit;
//  down the side, the paw's toes are gauges that light up their homes on
//  the map. The day scrolls up over the city in glass: the week, Purr's
//  brief, quick actions, the day's plan and the paw. Touch a pin for a
//  quick look at that home; touch the look to go inside.
//

import SwiftUI

struct DashboardView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.container) private var container
    @Environment(\.feedback) private var feedback
    @Environment(\.toasts) private var toasts

    @State private var model: HomeModel
    @State private var selection: String?
    @State private var picked: PawToe = .rent
    /// The gauge picked on the rail, if any; its homes light up.
    @State private var toe: PawToe?
    @State private var offset: CGFloat = 0
    @State private var isExploring = false
    @State private var tapThrough: CGPoint?
    @State private var showsWardrobe = false
    @State private var day = Date.now
    @State private var query = ""
    @FocusState private var isSearching: Bool

    /// Room the rail takes down the left of the map.
    private static let railWidth: CGFloat = 76
    /// The bar and the search over the top of the map.
    private static let topBars: CGFloat = 240
    /// Where the rail starts and ends, under the search.
    private static let railTop: CGFloat = 128
    private static let railBottom: CGFloat = railTop + 306

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
    private var search: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            // The city gets most of the screen, and at least the rail's
            // length, so the day starts under the gauges and peeks in below.
            let clear = max(Self.railBottom + 16, proxy.size.height * 0.66)
            let underCards = screen - proxy.safeAreaInsets.top - clear + 20
            ZStack(alignment: .top) {
                HomeMap(
                    model: model, selection: $selection,
                    insets: EdgeInsets(top: Self.topBars, leading: Self.railWidth, bottom: isExploring ? 150 : underCards, trailing: 0),
                    tapThrough: tapThrough,
                    screenHeight: screen,
                    lens: toe?.lens,
                    focus: toe?.lens.map { model.homes($0).map(\.id) } ?? []
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
                    cards(clear: clear)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topLeading) { rail }
            .overlay(alignment: .top) {
                VStack(spacing: 10) {
                    HomeBar(model: model, onGlass: true) { showsWardrobe = true }
                    HomeSearchField(query: $query, isFocused: $isSearching)
                    if !search.isEmpty {
                        HomeSearchResults(model: model, query: search) { home in
                            isSearching = false
                            query = ""
                            selection = home.id
                        }
                        .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .overlay(alignment: .bottom) { popup.padding(.horizontal, 14).padding(.bottom, 10) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("Home")
        .animation(DS.Motion.smooth, value: selection)
        .animation(DS.Motion.bouncy, value: toe)
        .animation(DS.Motion.smooth, value: search.isEmpty)
        .onChange(of: toe) { _, toe in
            selection = nil
            // The paw at the bottom follows the gauge picked up top.
            if let toe { picked = toe }
        }
        .task {
            await model.load()
            // An empty today: open the plan on the next day with something.
            let upcoming = dashboard.tasks.compactMap { HomeModel.date(of: $0) }.filter { $0 >= Calendar.current.startOfDay(for: .now) }.sorted()
            if let next = upcoming.first, !Calendar.current.isDateInToday(next) { day = next }
        }
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

    // MARK: Rail

    /// The gauges down the side of the map. They step aside while the
    /// search shows results, and fade as the day scrolls up over the map.
    @ViewBuilder private var rail: some View {
        let covered = isExploring ? 0 : min(1, offset / 48)
        if search.isEmpty {
            HomeToeRail(model: model, toe: $toe)
                .padding(.leading, 12)
                .padding(.top, Self.railTop)
                .opacity(1 - covered)
                .allowsHitTesting(covered < 0.5)
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }

    // MARK: Cards

    private func cards(clear: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                // See-through: the map shows here. A tap is passed down to
                // the nearest pin; the scroll view would otherwise take it.
                Color.clear
                    .frame(height: clear)
                    .contentShape(.rect)
                    .onTapGesture(coordinateSpace: .global) { tapThrough = $0 }
                    .overlay(alignment: .bottomTrailing) {
                        Button { withAnimation(DS.Motion.smooth) { isExploring = true } } label: {
                            Label("Explore map", systemImage: "map.fill")
                                .font(DS.Typography.brand(.subheadline, weight: .semibold))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .padding(.horizontal, 14).frame(height: 40)
                                .homeGlass(radius: 20)
                        }
                        .buttonStyle(SquishStyle())
                        .padding(.bottom, 8)
                    }
                    .accessibilityHidden(true)

                if let error = dashboard.error {
                    DSErrorView(error: error) { await model.refresh() }.homeGlass()
                }
                if let toe {
                    HomeToeCard(model: model, toe: toe) { self.toe = nil }
                }
                HomeWeekStrip(model: model, day: $day)
                HomeBrief(model: model)
                HomeQuickActions()
                HomeDayPlan(model: model, day: day)
                PawPanel(model: model, picked: $picked, pawSize: 170, compact: true)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in
            // Only what the wash and the rail need: rounding stops a
            // redraw per point.
            let stepped = (min(160, max(0, y)) / 8).rounded() * 8
            if stepped != offset { offset = stepped }
        }
        .purrRefreshable { await model.refresh() }
    }

    /// The whole city, with the gauge you picked explained over it.
    private var exploreBar: some View {
        VStack(spacing: 10) {
            Spacer()
            if let toe, selection == nil {
                HomeToeCard(model: model, toe: toe) { self.toe = nil }
            }
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
        .padding(.horizontal, 14)
    }

    // MARK: Popup

    @ViewBuilder private var popup: some View {
        if let id = selection, let index = model.properties.firstIndex(where: { $0.id == id }) {
            let property = model.properties[index]
            PropertyPopup(
                property: property, accent: HomeMap.accents[index % HomeMap.accents.count],
                monthly: model.dollars(Int(property.monthlyRevenue * 1000)),
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
