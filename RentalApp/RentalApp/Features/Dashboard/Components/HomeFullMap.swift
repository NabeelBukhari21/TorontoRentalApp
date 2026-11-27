//
//  HomeFullMap.swift
//  RentalApp (Purrperty)
//
//  Dashboard — What sits on the map itself: the search across the top,
//  the paw's toes as a rail of gauges down the side, and the lenses that
//  turn each pin into the number a gauge is about.
//

import SwiftUI

// MARK: - Lenses

/// What the pins report while a gauge is picked.
enum HomeLens {
    case owing, repairs, empty
}

extension HomeModel {

    /// Who owes at a home, most first.
    func owing(at property: Property) -> [RentRollRow] {
        owing.filter { $0.propertyName == property.name }
    }

    /// What a lens says about a home; nil when it has nothing to report.
    func badge(_ lens: HomeLens, for property: Property) -> HomePinBadge? {
        switch lens {
        case .owing:
            let total = owing(at: property).reduce(0) { $0 + $1.totalOwing }
            return total > 0 ? HomePinBadge(text: dollars(total), symbol: "exclamationmark", accent: .gold) : nil
        case .repairs:
            guard property.openRequests > 0 else { return nil }
            return property.urgentRequests > 0
                ? HomePinBadge(text: "\(property.urgentRequests) urgent", symbol: "flame.fill", accent: .cherry)
                : HomePinBadge(text: "\(property.openRequests) open", symbol: "wrench.fill", accent: .sky)
        case .empty:
            return property.vacantCount > 0 ? HomePinBadge(text: "\(property.vacantCount) empty", symbol: "door.left.hand.open", accent: .sky) : nil
        }
    }

    /// The homes a lens has something on, most first.
    func ranked(_ lens: HomeLens) -> [Property] {
        homes(lens).sorted { weight(lens, $0) > weight(lens, $1) }
    }

    private func weight(_ lens: HomeLens, _ property: Property) -> Double {
        switch lens {
        case .owing: Double(owing(at: property).reduce(0) { $0 + $1.totalOwing })
        case .repairs: Double(property.urgentRequests * 100 + property.openRequests)
        case .empty: Double(property.vacantCount)
        }
    }

    /// The homes a lens has something on.
    func homes(_ lens: HomeLens) -> [Property] {
        properties.filter { badge(lens, for: $0) != nil }
    }
}

// MARK: - Search

/// Find a home or a tenant from the top of the map.
struct HomeSearchField: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .bold)).foregroundStyle(DS.Colors.textSecondary)
            TextField("Find a home, tenant or unit", text: $query)
                .font(DS.Typography.brand(.body))
                .foregroundStyle(DS.Colors.textPrimary)
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { query = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.leading, 16).padding(.trailing, 4)
        .frame(height: 50)
        .homeGlass(radius: 25, tint: 0.8)
    }
}

/// What the search found: homes fly the map there, tenants open.
struct HomeSearchResults: View {
    let model: HomeModel
    let query: String
    let onHome: (Property) -> Void
    @Environment(AppRouter.self) private var router

    var body: some View {
        let homes = model.properties.filter { [$0.name, $0.neighborhood, $0.address].contains { $0.localizedCaseInsensitiveContains(query) } }.prefix(4)
        let tenants = model.roll.rows.filter { [$0.tenantName, $0.unitName, $0.propertyName].contains { $0.localizedCaseInsensitiveContains(query) } }.prefix(4)
        VStack(alignment: .leading, spacing: 4) {
            if homes.isEmpty, tenants.isEmpty {
                HStack(spacing: 10) {
                    PurrMascot(mood: .noResults, size: 52, isInteractive: false).padding(-6)
                    Text("Nothing here called “\(query)”.").font(DS.Typography.brand(.subheadline, weight: .semibold))
                }
                .padding(.vertical, 6)
            }
            if !homes.isEmpty { heading("Homes") }
            ForEach(homes) { home in
                row(symbol: home.kind.icon, accent: .gold, title: home.name, detail: "\(home.neighborhood) · \(home.occupiedCount)/\(home.unitCount) rented", trailing: "mappin") { onHome(home) }
            }
            if !tenants.isEmpty { heading("Tenants") }
            ForEach(tenants) { tenant in
                row(symbol: "person.fill", accent: .sky, title: tenant.tenantName,
                    detail: "\(tenant.unitName) · \(tenant.propertyName)" + (tenant.isOwing ? " · owes \(model.dollars(tenant.totalOwing))" : ""),
                    trailing: "chevron.forward") { router.push(.tenantDetail(tenantID: tenant.tenantID)) }
            }
            Divider().padding(.vertical, 4)
            row(symbol: "sparkles", accent: .cherry, title: "Ask Copilot", detail: "“\(query)”", trailing: "chevron.forward") {
                router.push(.askCopilot(question: query))
            }
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(12)
        .homeGlass(radius: 24, tint: 0.85)
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(DS.Typography.brand(.caption, weight: .bold)).foregroundStyle(DS.Colors.textSecondary)
            .textCase(.uppercase).padding(.top, 4).padding(.leading, 4)
    }

    private func row(symbol: String, accent: DSAccent, title: String, detail: String, trailing: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ClayToken(symbol: symbol, accent: accent, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(DS.Typography.brand(.subheadline, weight: .semibold)).lineLimit(1)
                    Text(detail).font(DS.Typography.brand(.caption)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: trailing).font(.footnote.weight(.bold)).foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(minHeight: 48)
            .contentShape(.rect)
        }
        .buttonStyle(SquishStyle(scale: 0.98))
    }
}

// MARK: - Gauge rail

/// The paw's five toes as gauges down the side of the map.
struct HomeToeRail: View {
    let model: HomeModel
    @Binding var toe: PawToe?
    @Environment(\.feedback) private var feedback

    var body: some View {
        VStack(spacing: 4) {
            ForEach([PawToe.rent, .homes, .repairs, .tasks, .streak]) { option in
                let isOn = toe == option
                Button {
                    feedback?.play(.select(option.rawValue))
                    withAnimation(DS.Motion.bouncy) { toe = isOn ? nil : option }
                } label: {
                    VStack(spacing: 1) {
                        ZStack {
                            Circle().stroke(option.accent.fill.opacity(0.22), lineWidth: 4)
                            Circle().trim(from: 0, to: model.level(option))
                                .stroke(option.accent.fill, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: option.symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(option.accent.ink)
                        }
                        .frame(width: 36, height: 36)
                        Text(model.value(option)).font(DS.Typography.brandFixed(12)).foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(width: 50, height: 56)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isOn ? option.accent.tint : .clear))
                    .scaleEffect(isOn ? 1.06 : 1)
                }
                .buttonStyle(SquishStyle(scale: 0.9))
                .accessibilityLabel("\(option.name), \(model.value(option))")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(5)
        .homeGlass(radius: 26)
    }
}

extension PawToe {
    /// The lens that shows this toe's homes on the map, where there is one.
    var lens: HomeLens? {
        switch self {
        case .rent: .owing
        case .homes: .empty
        case .repairs: .repairs
        case .tasks, .streak: nil
        }
    }
}

/// Purr on the toe you picked, with the way to it.
struct HomeToeCard: View {
    let model: HomeModel
    let toe: PawToe
    let onClose: () -> Void
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PurrMascot(mood: model.mood(toe), size: 78, isInteractive: false).padding(-6)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(toe.name) · \(model.value(toe))").font(DS.Typography.brand(.caption, weight: .bold)).foregroundStyle(toe.accent.ink).textCase(.uppercase)
                Text(model.detail(toe)).font(DS.Typography.brand(.headline, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open \(toe.name.lowercased())", systemImage: "chevron.forward") { toe.open(with: router) }
                    .labelStyle(.titleOnly)
                    .font(DS.Typography.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(DS.Colors.brandInk)
            }
            Spacer(minLength: 30)
        }
        .padding(16)
        .homeGlass()
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly).font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.Colors.textSecondary).frame(width: 44, height: 44)
        }
        .id(toe)
        .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
    }
}
