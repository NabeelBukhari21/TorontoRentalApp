//
//  HeroHome.swift — 3: Map on top. The city fills the top of the screen,
//  and the dashboard scrolls up over it in glass: the paw first, overlapping
//  the map, then the numbers, your homes and the day. The map stays behind,
//  blurring as the cards cover it.
//

#if DEBUG
import SwiftUI

struct HeroHome: View {
    let model: HomeStudioModel

    @State private var selection: String?
    @State private var picked: PawToe = .rent
    @State private var offset: CGFloat = 0
    @State private var isExploring = false
    @Environment(AppRouter.self) private var router

    var body: some View {
        GeometryReader { proxy in
            let mapHeight = proxy.size.height * 0.46
            ZStack(alignment: .top) {
                HomeMap(model: model, selection: $selection, insets: EdgeInsets(top: 80, leading: 0, bottom: isExploring ? 120 : proxy.size.height - mapHeight, trailing: 0))
                    .ignoresSafeArea()
                // The map frosts over as the cards cover it.
                Rectangle().fill(.ultraThinMaterial)
                    .opacity(isExploring ? 0 : min(1, max(0, offset / 180)))
                    .ignoresSafeArea().allowsHitTesting(false)

                if !isExploring {
                    ScrollView {
                        VStack(spacing: 14) {
                            // See-through: the map shows here, and the button explores it.
                            Color.clear.frame(height: mapHeight - 110)
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
                            PawPanel(model: model, picked: $picked, pawSize: min(300, proxy.size.width - 80))
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                GlassStat(symbol: "dollarsign", value: model.dollars(model.roll.collected), label: "Rent this month", accent: .mint) { router.push(.rentCollection) }
                                GlassStat(symbol: "key.fill", value: "\(model.dashboard.occupiedUnits)/\(model.dashboard.unitCount)", label: "Units rented", accent: .gold) { router.select(.properties) }
                                GlassStat(symbol: "wrench.fill", value: "\(model.requests)", label: "Repairs open", accent: .cherry) { router.select(.maintenance) }
                                GlassStat(symbol: "bell.fill", value: "\(model.dashboard.unreadNotifications)", label: "Unread", accent: .sky) { router.push(.notifications) }
                            }
                            TodayGlass(model: model)
                            homes
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in offset = y }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
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
                        .padding(.bottom, 12)
                    }
                }
            }
            .overlay(alignment: .top) {
                HomeBar(model: model, onGlass: true).padding(.horizontal, 16).padding(.top, 4)
            }
        }
    }

    private var homes: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your homes").font(DS.Typography.brand(.title3, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Button("See all") { router.select(.properties) }.font(DS.Typography.brand(.subheadline, weight: .semibold)).foregroundStyle(DS.Colors.brandInk)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(model.properties.enumerated()), id: \.element.id) { i, property in
                        PropertyGlassCard(property: property, accent: HomeMap.accents[i % HomeMap.accents.count]).frame(width: 240)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }
}
#endif
