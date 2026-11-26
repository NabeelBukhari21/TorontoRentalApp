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
    @State private var day = Date.now
    @State private var asked: PurrQuestion?
    @State private var layout = HomeLayout.saved

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
            .overlay(alignment: .bottom) {
                if layout == .ask, selection == nil, !isExploring {
                    PurrAskBar(asked: $asked).padding(.horizontal, 14).padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) { popup.padding(.horizontal, 14).padding(.bottom, 10) }
            #if DEBUG
            .overlay(alignment: .trailing) { HomeLayoutSwitcher(layout: $layout).padding(.trailing, 4).offset(y: 30) }
            #endif
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("Home")
        .animation(DS.Motion.smooth, value: selection)
        .animation(DS.Motion.bouncy, value: layout)
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
                stack(width: width)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, layout == .ask ? 130 : 24)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in
            // Only what the wash needs: rounding stops a redraw per point.
            let stepped = (min(160, max(0, y)) / 8).rounded() * 8
            if stepped != offset { offset = stepped }
        }
        .purrRefreshable { await model.refresh() }
    }

    /// What sits under the map, in the chosen layout.
    @ViewBuilder private func stack(width: CGFloat) -> some View {
        switch layout {
        case .now:
            PawPanel(model: model, picked: $picked, pawSize: min(300, width - 80))
            stats
            TodayGlass(model: model)
        case .day:
            HomeWeekStrip(model: model, day: $day)
            HomeBrief(model: model)
            HomeQuickActions()
            HomeDayPlan(model: model, day: day)
            PawPanel(model: model, picked: $picked, pawSize: 170, compact: true)
        case .money:
            HomeQuickActions()
            HomeCashFlow(model: model)
            HomeDecisions(model: model)
            PawPanel(model: model, picked: $picked, pawSize: 170, compact: true)
            HomeActivity(model: model)
        case .ask:
            PurrQuestionRings(asked: $asked)
            if let asked {
                PurrAnswer(model: model, question: asked) { withAnimation(DS.Motion.bouncy) { self.asked = nil } }
                    .id(asked)
                    .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
            }
            PawPanel(model: model, picked: $picked, pawSize: min(300, width - 80))
            stats
            TodayGlass(model: model)
        }
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            GlassStat(symbol: "dollarsign", value: model.dollars(model.roll.collected), label: "Rent this month", accent: .mint) { router.push(.rentCollection) }
            GlassStat(symbol: "key.fill", value: "\(dashboard.occupiedUnits)/\(dashboard.unitCount)", label: "Units rented", accent: .gold) { router.select(.properties) }
            GlassStat(symbol: "wrench.fill", value: "\(model.requests)", label: "Repairs open", accent: .cherry) { router.select(.maintenance) }
            GlassStat(symbol: "bell.fill", value: "\(dashboard.unreadNotifications)", label: "Unread", accent: .sky) { router.push(.notifications) }
        }
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

// MARK: - Layouts

/// Three ways to fill Home under the map, being compared.
enum HomeLayout: String, CaseIterable {
    /// The paw, the numbers and today.
    case now = "Now"
    /// The week and today's plan, with Purr's brief.
    case day = "1"
    /// Money over time and the decisions waiting.
    case money = "2"
    /// Ask Purr: questions he answers from what's here.
    case ask = "3"

    static let key = "PurrpertyHomeLayout"

    static var saved: HomeLayout {
        #if DEBUG
        UserDefaults.standard.string(forKey: key).flatMap(HomeLayout.init(rawValue:)) ?? .day
        #else
        .now
        #endif
    }
}

#if DEBUG
/// Test builds: flip between the layouts.
private struct HomeLayoutSwitcher: View {
    @Binding var layout: HomeLayout
    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(spacing: 2) {
            ForEach(HomeLayout.allCases, id: \.self) { option in
                Button {
                    feedback?.play(.tap)
                    layout = option
                    UserDefaults.standard.set(option.rawValue, forKey: HomeLayout.key)
                } label: {
                    Text(option.rawValue)
                        .font(DS.Typography.brand(.caption, weight: .bold))
                        .foregroundStyle(layout == option ? DS.Colors.textOnBrand : DS.Colors.textPrimary)
                        .frame(minWidth: 34, minHeight: 30)
                        .background(Capsule().fill(layout == option ? DS.Colors.brand : .clear))
                }
                .buttonStyle(SquishStyle(scale: 0.9))
            }
        }
        .padding(3)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
#endif

// MARK: - Previews

#Preview("Home") {
    RootNavigationView()
}
