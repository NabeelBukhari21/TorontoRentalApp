//
//  TowerHome.swift — B: The tower. Every property is a floor of one
//  building; a lit window is a rented unit, and Purr rides the lift as you
//  scroll from the roof to the lobby.
//

#if DEBUG
import SwiftUI

struct TowerHome: View {
    let model: HomeStudioModel

    @State private var scroll: CGFloat = 0
    @State private var reach: CGFloat = 1
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accents: [DSAccent] = [.cherry, .sky, .mint, .gold, .blush]

    var body: some View {
        ZStack(alignment: .top) {
            TorontoSky(weather: model.dashboard.weather).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    roof
                    VStack(spacing: 8) {
                        ForEach(Array(model.properties.enumerated()), id: \.element.id) { i, property in
                            floor(property, accents[i % accents.count], number: model.properties.count - i)
                        }
                        lobby
                    }
                    .padding(8)
                    .background {
                        UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18, style: .continuous)
                            .fill(.clay(DS.Colors.surface, shade: DSAccent.gold.ink, size: 120))
                            .shadow(color: .black.opacity(0.22), radius: 22, y: 8)
                    }
                    .overlay(alignment: .topTrailing) { lift }
                    street
                }
                .padding(.horizontal, 14)
                .padding(.top, 112)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: [CGFloat].self) { [$0.contentOffset.y, max(1, $0.contentSize.height - $0.containerSize.height)] } action: { _, v in
                scroll = v[0]
                reach = v[1]
            }

            VStack(spacing: 10) {
                HomeBar(model: model, onGlass: true)
                HStack(spacing: 8) {
                    chip("dollarsign.circle.fill", "\(Int((model.rentRate * 100).rounded()))% rent in", .mint)
                    chip("key.fill", "\(model.dashboard.occupiedUnits)/\(model.dashboard.unitCount) let", .gold)
                    chip("wrench.fill", "\(model.requests)", .cherry)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    private func chip(_ symbol: String, _ text: String, _ accent: DSAccent) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(accent.ink)
            Text(text).foregroundStyle(DS.Colors.textPrimary)
        }
        .font(DS.Typography.brand(.subheadline, weight: .semibold))
        .padding(.horizontal, 12).frame(height: 36)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: Roof

    private var roof: some View {
        ZStack(alignment: .bottom) {
            LivingPurr(mood: model.urgentTasks > 0 ? .urgentIssue : model.brief.mood, size: 220, showsFloor: false, beat: model.urgentTasks)
                .offset(x: -56, y: 22)
            Text(model.brief.message)
                .font(DS.Typography.brand(.footnote, weight: .semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DS.Colors.surfaceRaised).shadow(color: DS.Colors.groundShadow, radius: 8, y: 5))
                .frame(width: 170)
                .offset(x: 98, y: -112)
            RoofTiles().fill(.clay(DS.Colors.brand, shade: DS.Colors.brandDeep, size: 90)).frame(height: 58)
                .overlay { RoofTiles.Lines().stroke(DS.Colors.brandDeep.opacity(0.6), lineWidth: 2.5) }
                .padding(.horizontal, -10)
        }
        .frame(height: 240, alignment: .bottom)
    }

    // MARK: Floors

    private func floor(_ property: Property, _ accent: DSAccent, number: Int) -> some View {
        Button { router.push(.propertyDetail(propertyID: property.id)) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(number, format: .number).font(DS.Typography.brandFixed(18)).foregroundStyle(accent.onFill)
                        .frame(width: 34, height: 34).background(Circle().fill(.clay(accent.fill, shade: accent.ink, size: 34)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(property.name).font(DS.Typography.brand(.headline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary).lineLimit(1)
                        Text("\(property.neighborhood) · \(property.occupiedCount) of \(property.unitCount) let").font(DS.Typography.brand(.footnote, weight: .regular)).foregroundStyle(DS.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                windows(property, accent)
            }
            .padding(12)
            .padding(.trailing, 58)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accent.fill.mix(with: DS.Colors.background, by: 0.72))
            }
        }
        .buttonStyle(SquishStyle(scale: 0.98))
        .accessibilityLabel("\(property.name), \(property.occupiedCount) of \(property.unitCount) units rented, \(property.openRequests) repairs")
    }

    /// One window a unit (up to 16): lit, dark, or with a repair inside.
    private func windows(_ property: Property, _ accent: DSAccent) -> some View {
        let count = min(property.unitCount, 16)
        let lit = property.unitCount == 0 ? 0 : Int((Double(property.occupiedCount) / Double(property.unitCount) * Double(count)).rounded())
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                let isLit = i < lit
                UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 9)
                    .fill(isLit ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE9A8), DS.Colors.accentGold], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(DS.Colors.textPrimary.opacity(0.2)))
                    .frame(height: 34)
                    .overlay { if i < min(property.urgentRequests, lit) { Image(systemName: "wrench.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(DS.Colors.brandDeep) } }
                    .overlay { UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 9).strokeBorder(DS.Colors.background, lineWidth: 2.5) }
                    .shadow(color: isLit ? DS.Colors.accentGold.opacity(0.5) : .clear, radius: 5)
            }
        }
    }

    // MARK: Lift

    private var lift: some View {
        GeometryReader { proxy in
            let p = min(max(scroll / reach, 0), 1)
            ZStack(alignment: .top) {
                Capsule().fill(DS.Colors.textPrimary.opacity(0.14)).frame(width: 54).overlay { Rectangle().fill(DS.Colors.textPrimary.opacity(0.35)).frame(width: 3, height: max(0, (proxy.size.height - 90) * p + 10)).frame(maxHeight: .infinity, alignment: .top) }
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.clay(DS.Colors.accentGold, shade: DSAccent.gold.ink, size: 60))
                    .overlay { PurrMascot(mood: p > 0.9 ? .moneyDance : .welcomeBack, size: 62, isInteractive: false).offset(y: -2) }
                    .frame(width: 54, height: 66)
                    .clipShape(.rect(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(DS.Colors.surfaceRaised, lineWidth: 3))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 5)
                    .offset(y: 8 + (proxy.size.height - 84) * p)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: p)
            }
            .frame(width: 54)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Lobby

    private var lobby: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lobby").font(DS.Typography.brand(.title3, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
            Button { router.push(.rentCollection) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Rent desk"); Spacer(); Text("\(model.dollars(model.roll.collected)) of \(model.dollars(model.roll.expected))") }
                        .font(DS.Typography.brand(.subheadline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary)
                    OnboardingProgressTube(progress: max(0.03, model.rentRate), label: "", fill: DSAccent.mint.fill, track: DS.Colors.track)
                }
            }
            .buttonStyle(SquishStyle(scale: 0.98))
            ForEach(model.openTasks.prefix(4)) { task in
                HStack(spacing: 10) {
                    SakugaCheckMark(isOn: task.isDone)
                    Text(task.title).font(DS.Typography.brand(.subheadline)).foregroundStyle(DS.Colors.textPrimary).lineLimit(1)
                    Spacer(minLength: 0)
                    if task.isUrgent { Image(systemName: "flame.fill").foregroundStyle(DS.Colors.brandInk) }
                }
                .contentShape(.rect)
                .onTapGesture { Task { await model.dashboard.toggleTask(task) } }
            }
        }
        .padding(14)
        .padding(.trailing, 58)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DS.Colors.surfaceRaised))
    }

    private var street: some View {
        ZStack {
            Rectangle().fill(Color(hex: 0x55505A)).frame(height: 60)
            HStack(spacing: 18) { ForEach(0..<9, id: \.self) { _ in Capsule().fill(.white.opacity(0.8)).frame(width: 26, height: 4) } }
            HStack { Image(systemName: "tree.fill").font(.system(size: 54)).foregroundStyle(DSAccent.mint.ink).offset(y: -38); Spacer(); Image(systemName: "car.side.fill").font(.system(size: 44)).foregroundStyle(DS.Colors.brand).offset(y: -8) }
                .padding(.horizontal, 22)
        }
        .padding(.horizontal, -14)
    }
}

/// A scalloped roof.
private struct RoofTiles: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX + 40, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - 40, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 12))
            let n = 9, w = r.width / CGFloat(n)
            for i in 0..<n {
                p.addQuadCurve(to: CGPoint(x: r.maxX - CGFloat(i + 1) * w, y: r.maxY - 12), control: CGPoint(x: r.maxX - (CGFloat(i) + 0.5) * w, y: r.maxY + 14))
            }
            p.closeSubpath()
        }
    }

    struct Lines: Shape {
        func path(in r: CGRect) -> Path {
            Path { p in
                for i in 1..<9 {
                    let f = CGFloat(i) / 9
                    p.move(to: CGPoint(x: r.minX + 40 + (r.width - 80) * f, y: r.minY + 4))
                    p.addLine(to: CGPoint(x: r.minX + r.width * f, y: r.maxY - 12))
                }
            }
        }
    }
}
#endif
