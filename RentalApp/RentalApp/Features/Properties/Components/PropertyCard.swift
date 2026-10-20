//
//  PropertyCard.swift
//  RentalApp (Purrperty)
//
//  Properties — Property card with a gradient "photo" hero
//  (procedural skyline placeholder), occupancy status, and stats.
//  Also home to the shared hero image + map preview placeholders.
//

import SwiftUI

// MARK: - Hero "Photo" Placeholder

/// Procedural property image: layered gradient + window grid + glow.
/// Swaps for real photos later (`AsyncImage` drops straight in).
struct PropertyHeroImage: View {

    let property: Property
    var height: CGFloat = 148
    /// The type chip in the corner. Off where the hero carries its own
    /// title block, which the chip would sit under.
    var showsKind = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PropertyPalettes.gradient(property.paletteIndex)

            // Window grid texture.
            Canvas { context, size in
                let cell: CGFloat = 16
                let inset: CGFloat = 4
                var y: CGFloat = 6
                var row = 0
                while y < size.height {
                    var x: CGFloat = 8
                    var column = 0
                    while x < size.width {
                        // Deterministic sparse "lit windows" — champagne gold.
                        let lit = (row * 7 + column * 13) % 9 == 0
                        let rect = CGRect(x: x, y: y, width: cell - inset, height: cell - inset)
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 2),
                            with: .color(
                                lit
                                    ? DS.Colors.onFixedColor.opacity(0.85)
                                    : DS.Colors.onFixedColor.opacity(0.22)
                            )
                        )
                        x += cell
                        column += 1
                    }
                    y += cell
                    row += 1
                }
            }

            // Depth vignette.
            LinearGradient(
                colors: [.clear, DS.Colors.mediaBackground.opacity(0.25)],
                startPoint: .center,
                endPoint: .bottom
            )

            if showsKind {
                PropertyKindChip(kind: property.kind)
                    .padding(DS.Spacing.md)
            }
        }
        .frame(height: height)
        .clipped()
    }
}

// MARK: - Kind Chip

struct PropertyKindChip: View {

    let kind: PropertyKind

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: kind.icon)
                .font(.system(size: 10, weight: .bold))
            Text(kind.rawValue)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(.horizontal, DS.Spacing.sm + 2)
        .padding(.vertical, DS.Spacing.xs + 1)
        .background(DS.Colors.surfaceRaised, in: Capsule())
        .overlay(Capsule().strokeBorder(DS.Colors.outline, lineWidth: 1))
    }
}

// MARK: - Occupancy Badge

struct PropertyOccupancyBadge: View {

    let property: Property

    var body: some View {
        DSBadge(
            text: property.isFull
                ? "Fully occupied"
                : "\(property.vacantCount) vacant",
            kind: property.isFull ? .success : .warning,
            icon: property.isFull ? "checkmark.circle.fill" : "door.left.hand.open"
        )
    }
}

// MARK: - Property Card

struct PropertyCard: View {

    let property: Property
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                PropertyHeroImage(property: property)

                // Info body.
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(property.name)
                                .font(DS.Typography.title3)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)

                            Text("\(property.neighborhood) · \(property.address)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: DS.Spacing.sm)

                        PropertyOccupancyBadge(property: property)
                    }

                    // Occupancy bar.
                    DSProgressBar(
                        value: property.occupancyRate,
                        gradient: property.isFull ? DS.Gradients.success : DS.Gradients.warm,
                        height: 6
                    )

                    // Stats row. Labels drop before anything wraps: a narrow
                    // card with an urgent count shows icons and values only.
                    HStack(spacing: DS.Spacing.lg) {
                        ViewThatFits(in: .horizontal) {
                            stats(labelled: true)
                            stats(labelled: false)
                        }

                        Spacer(minLength: 0)

                        Group {
                            if property.urgentRequests > 0 {
                                DSStatusLabel(text: "\(property.urgentRequests) urgent", kind: .danger, pulses: true)
                            } else if property.openRequests > 0 {
                                DSStatusLabel(text: "\(property.openRequests) open", kind: .info)
                            }
                        }
                        .fixedSize()

                        Image(systemName: DS.Icons.chevronRight)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
                .padding(DS.Spacing.lg)
                .background(DS.Colors.surfaceRaised)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .strokeBorder(DS.Gradients.cardHairline, lineWidth: 1)
            )
            .dsShadow(DS.Shadows.card)
        }
        .buttonStyle(DSPressStyle())
    }

    private func stats(labelled: Bool) -> some View {
        HStack(spacing: labelled ? DS.Spacing.lg : DS.Spacing.md) {
            stat(icon: DS.Icons.unit, value: "\(property.unitCount)", label: labelled ? "units" : nil)
            stat(icon: DS.Icons.occupancy, value: "\(Int(property.occupancyRate * 100))%", label: labelled ? "occupied" : nil)
            stat(icon: DS.Icons.payment, value: "$\(String(format: "%.1f", property.monthlyRevenue))K", label: "/mo")
        }
    }

    private func stat(icon: String, value: String, label: String?) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Colors.brand)

            Text(value)
                .font(DS.Typography.caption.monospacedDigit())
                .foregroundStyle(DS.Colors.textPrimary)

            if let label {
                Text(label)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }
}

// MARK: - Map Preview Placeholder

/// Stylized map card: street grid, glowing pin, "Open in Maps" chip.
/// MapKit slots in here later without layout changes.
struct PropertyMapPreview: View {

    let property: Property
    var height: CGFloat = 150

    @State private var pinDropped = false

    var body: some View {
        ZStack {
            // Map base.
            LinearGradient(
                colors: [DS.Colors.surfaceSecondary, DS.Colors.surface],
                startPoint: .top,
                endPoint: .bottom
            )

            // Street grid.
            Canvas { context, size in
                var path = Path()
                let spacing: CGFloat = 26

                var x: CGFloat = 8
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + 14, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 4
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y + 6))
                    y += spacing
                }

                context.stroke(path, with: .color(DS.Colors.brand.opacity(0.14)), lineWidth: 1)

                // "Main street" accents.
                var main = Path()
                main.move(to: CGPoint(x: 0, y: size.height * 0.62))
                main.addLine(to: CGPoint(x: size.width, y: size.height * 0.55))
                main.move(to: CGPoint(x: size.width * 0.32, y: 0))
                main.addLine(to: CGPoint(x: size.width * 0.38, y: size.height))
                context.stroke(main, with: .color(DS.Colors.brand.opacity(0.3)), lineWidth: 3)
            }

            // Pin with pulse.
            ZStack {
                Circle()
                    .fill(DS.Colors.brand.opacity(0.2))
                    .frame(width: pinDropped ? 54 : 12, height: pinDropped ? 54 : 12)
                    .opacity(pinDropped ? 0 : 1)

                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(DS.Colors.textOnBrand, DS.Colors.brand)
                    .dsShadow(DS.Shadows.glow(DS.Colors.brand, intensity: 0.5))
                    .offset(y: pinDropped ? 0 : -26)
                    .scaleEffect(pinDropped ? 1 : 0.6)
            }

            // Footer chip.
            VStack {
                Spacer()
                HStack {
                    Text(property.address)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Open in Maps")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(DS.Colors.brand)
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surfaceRaised)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(DS.Colors.outline, lineWidth: 1)
        )
        .onAppear {
            withAnimation(DS.Motion.bouncy.delay(0.3)) {
                pinDropped = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Property Card") {
    ZStack {
        DSAmbientBackground()

        VStack(spacing: DS.Spacing.lg) {
            PropertyCard(property: PropertyMockData.properties[0]) {}
            PropertyMapPreview(property: PropertyMockData.properties[0])
        }
        .padding(DS.Spacing.xl)
    }
}
