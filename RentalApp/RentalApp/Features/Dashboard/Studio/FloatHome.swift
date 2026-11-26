//
//  FloatHome.swift — 2: Floating glass. The map fills the screen and the
//  cards float at its edges, like a heads-up display: the paw top left,
//  the day top right, your homes along the bottom. The city stays visible
//  in the middle.
//

#if DEBUG
import SwiftUI

struct FloatHome: View {
    let model: HomeStudioModel

    @State private var selection: String?
    @State private var page: String?
    @State private var picked: PawToe = .rent
    @State private var showsPaw = true
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            HomeMap(model: model, selection: $selection, insets: EdgeInsets(top: 330, leading: 0, bottom: 200, trailing: 0))
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 200).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 12) {
                HomeBar(model: model, onGlass: true)
                HStack(alignment: .top, spacing: 10) {
                    pawCard
                    VStack(spacing: 10) {
                        GlassStat(symbol: "checklist", value: "\(model.openTasks.count) to do", label: model.urgentTasks > 0 ? "\(model.urgentTasks) urgent" : "Today", accent: .mint) { router.push(.notifications) }
                        GlassStat(symbol: "wrench.fill", value: "\(model.requests) open", label: "Repairs", accent: .cherry) { router.select(.maintenance) }
                        GlassStat(symbol: "bell.fill", value: "\(model.dashboard.unreadNotifications) new", label: "Messages", accent: .sky) { router.push(.notifications) }
                    }
                }
                Spacer(minLength: 0)
                carousel
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .onChange(of: page) { _, id in if id != "all", id != selection { selection = id } }
        .onChange(of: selection) { _, id in withAnimation(DS.Motion.smooth) { page = id ?? "all" } }
    }

    private var pawCard: some View {
        VStack(spacing: 0) {
            PawGauge(model: model, picked: $picked, size: 170)
            Text(model.detail(picked))
                .font(DS.Typography.brand(.caption, weight: .semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: 160, height: 46)
                .contentTransition(.opacity)
        }
        .padding(8)
        .homeGlass(radius: 30)
        .overlay(alignment: .bottomTrailing) {
            PurrMascot(mood: model.mood(picked), size: 70, isInteractive: false).offset(x: 20, y: 14).allowsHitTesting(false)
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                allCard.id("all").containerRelativeFrame(.horizontal) { w, _ in w * 0.8 }
                ForEach(Array(model.properties.enumerated()), id: \.element.id) { i, property in
                    PropertyGlassCard(property: property, accent: HomeMap.accents[i % HomeMap.accents.count], isSelected: selection == property.id)
                        .id(property.id)
                        .containerRelativeFrame(.horizontal) { w, _ in w * 0.8 }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .padding(.horizontal, -14)
        .contentMargins(.horizontal, 14, for: .scrollContent)
    }

    private var allCard: some View {
        Button { withAnimation(DS.Motion.smooth) { selection = nil } } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("All \(model.properties.count) homes").font(DS.Typography.brand(.headline, weight: .bold))
                Text(model.brief.message).font(DS.Typography.brand(.footnote)).foregroundStyle(DS.Colors.textSecondary).lineLimit(2)
                Text("Swipe to visit each one").font(DS.Typography.brand(.caption, weight: .semibold)).foregroundStyle(DS.Colors.brandInk)
            }
            .foregroundStyle(DS.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(minHeight: 112)
            .homeGlass(radius: 24)
        }
        .buttonStyle(SquishStyle(scale: 0.97))
    }
}
#endif
