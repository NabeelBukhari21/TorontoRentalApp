//
//  AppComponents.swift
//  RentalApp (Purrperty)
//
//  AppStyle — The few reusable views the system doesn't provide.
//
//  • `.appCard()`      — a content tile on the grouped background, for
//                        things a List row can't hold (charts, stats).
//  • `StatusLabel`     — a meaning (positive/caution/…) as symbol + text.
//  • `SymbolTile`      — the Settings-app style icon square for rows.
//  • `AvatarView`      — initials in a circle, for people without photos.
//

import SwiftUI

// MARK: - Card

private struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.secondaryGroupedBackground,
                // Concentric with whatever contains it, never tighter
                // than the system's inset-grouped row radius.
                in: .rect(corners: .concentric(minimum: 20), isUniform: true)
            )
    }
}

extension View {
    /// A content tile on the grouped background. Use a `List` section
    /// instead whenever the content is rows.
    func appCard() -> some View {
        modifier(AppCardModifier())
    }
}

// MARK: - Status Label

/// A state, shown as its role's symbol and colour plus text.
/// VoiceOver reads the text; the symbol is decorative.
struct StatusLabel: View {

    let title: String
    let role: StatusRole

    init(_ title: String, role: StatusRole) {
        self.title = title
        self.role = role
    }

    var body: some View {
        // An HStack rather than a Label: as the content of a list row's
        // LabeledContent, a Label is laid out as a row of its own and
        // leaves a tall empty gap.
        HStack(spacing: 6) {
            Image(symbol: role.symbol)
                .foregroundStyle(role.color)
                .accessibilityHidden(true)
            Text(title)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Symbol Tile

/// The filled rounded square used beside rows in Settings.
struct SymbolTile: View {

    let systemName: String
    var color: Color = .accentColor

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 30

    init(symbol: AppSymbol, color: Color = .accentColor) {
        self.systemName = symbol.rawValue
        self.color = color
    }

    init(systemName: String, color: Color = .accentColor) {
        self.systemName = systemName
        self.color = color
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: side, height: side)
            .background(color.gradient, in: .rect(cornerRadius: side * 0.24))
            .accessibilityHidden(true)
    }
}

// MARK: - Avatar

/// Initials in a circle. Scales with Dynamic Type.
struct AvatarView: View {

    let name: String
    var size: Font.TextStyle = .body

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size, design: .rounded, weight: .semibold))
            .foregroundStyle(.tint)
            .padding(10)
            .frame(minWidth: 44, minHeight: 44)
            .background(.tint.quaternary, in: .circle)
            .accessibilityLabel(name)
    }
}

// MARK: - Previews

#Preview("AppStyle") {
    NavigationStack {
        List {
            Section("Status") {
                ForEach(StatusRole.allCases, id: \.self) { role in
                    StatusLabel(String(describing: role).capitalized, role: role)
                }
            }
            Section("Rows") {
                Label { Text("Notifications") } icon: { SymbolTile(symbol: .notifications, color: .red) }
                Label { Text("Appearance") } icon: { SymbolTile(symbol: .light, color: .blue) }
                LabeledContent("Tenant") { AvatarView(name: "Amara Okonkwo") }
            }
            Section("Buttons") {
                Button("Glass prominent") {}.buttonStyle(.glassProminent)
                Button("Glass") {}.buttonStyle(.glass)
                Button("Bordered prominent") {}.buttonStyle(.borderedProminent)
            }
            Section {
                VStack(alignment: .leading) {
                    Text("Rent collected").font(.headline)
                    Text("96%").font(.largeTitle.bold())
                }
                .appCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.groupedBackground)
            }
        }
        .navigationTitle("AppStyle")
    }
}
