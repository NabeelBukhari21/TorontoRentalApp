//
//  SheetHome.swift — 1: The sheet. The whole city, and a glass sheet you
//  pull up from the bottom, as in Maps: the paw first, then your homes,
//  then the day. Touch a pin and the sheet shows that home.
//

#if DEBUG
import SwiftUI

struct SheetHome: View {
    let model: HomeStudioModel

    enum Detent: CaseIterable { case peek, half, full }

    @State private var selection: String?
    @State private var detent: Detent = .peek
    @State private var drag: CGFloat = 0
    @State private var picked: PawToe = .rent
    @Environment(AppRouter.self) private var router

    var body: some View {
        GeometryReader { proxy in
            let heights: [Detent: CGFloat] = [.peek: 300, .half: proxy.size.height * 0.62, .full: proxy.size.height - 70]
            let height = max(170, (heights[detent] ?? 300) - drag)
            ZStack(alignment: .bottom) {
                HomeMap(model: model, selection: $selection, insets: EdgeInsets(top: 60, leading: 0, bottom: 520, trailing: 0))
                    .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 170).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea().allowsHitTesting(false)
                sheet(height: height, heights: heights)
            }
            .overlay(alignment: .top) { HomeBar(model: model, onGlass: true).padding(.horizontal, 16).padding(.top, 4) }
        }
        .onChange(of: selection) { _, id in if id != nil, detent == .peek { withAnimation(DS.Motion.bouncy) { detent = .half } } }
    }

    private func sheet(height: CGFloat, heights: [Detent: CGFloat]) -> some View {
        VStack(spacing: 0) {
            Capsule().fill(DS.Colors.textTertiary).frame(width: 44, height: 5).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .gesture(DragGesture()
                    .onChanged { drag = $0.translation.height }
                    .onEnded { value in
                        let end = (heights[detent] ?? 0) - value.predictedEndTranslation.height
                        let next = Detent.allCases.min { abs((heights[$0] ?? 0) - end) < abs((heights[$1] ?? 0) - end) } ?? .peek
                        withAnimation(DS.Motion.bouncy) { detent = next; drag = 0 }
                    })
                .onTapGesture { withAnimation(DS.Motion.bouncy) { detent = detent == .peek ? .half : .peek } }
            ScrollView {
                VStack(spacing: 14) {
                    if let id = selection, let property = model.properties.first(where: { $0.id == id }), let i = model.properties.firstIndex(where: { $0.id == id }) {
                        PropertyGlassCard(property: property, accent: HomeMap.accents[i % HomeMap.accents.count], isSelected: true)
                            .overlay(alignment: .topTrailing) {
                                Button("Show all", systemImage: "xmark") { withAnimation(DS.Motion.smooth) { selection = nil } }
                                    .labelStyle(.iconOnly).font(.footnote.weight(.bold)).foregroundStyle(DS.Colors.textSecondary)
                                    .frame(width: 44, height: 44)
                            }
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                    PawPanel(model: model, picked: $picked, pawSize: 170, compact: true)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        GlassStat(symbol: "dollarsign", value: model.dollars(model.roll.collected), label: "Rent this month", accent: .mint) { router.push(.rentCollection) }
                        GlassStat(symbol: "key.fill", value: "\(model.dashboard.occupiedUnits)/\(model.dashboard.unitCount)", label: "Units rented", accent: .gold) { router.select(.properties) }
                        GlassStat(symbol: "wrench.fill", value: "\(model.requests)", label: "Repairs open", accent: .cherry) { router.select(.maintenance) }
                        GlassStat(symbol: "bell.fill", value: "\(model.dashboard.unreadNotifications)", label: "Unread", accent: .sky) { router.push(.notifications) }
                    }
                    TodayGlass(model: model)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your homes").font(DS.Typography.brand(.title3, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                        ForEach(Array(model.properties.enumerated()), id: \.element.id) { i, property in
                            PropertyGlassCard(property: property, accent: HomeMap.accents[i % HomeMap.accents.count])
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 20)
            }
            .scrollDisabled(detent == .peek)
            .scrollIndicators(.hidden)
        }
        .frame(height: height, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous).fill(DS.Colors.background.opacity(0.35))
        }
        .glassEffect(.regular, in: UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: -4)
    }
}
#endif
