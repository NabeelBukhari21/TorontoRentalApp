//
//  PropertyPopup.swift
//  RentalApp (Purrperty)
//
//  Dashboard — A home's numbers at a glance, popped up from its pin. Tap
//  it to go inside.
//

import SwiftUI

struct PropertyPopup: View {
    let property: Property
    let accent: DSAccent
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ClayToken(symbol: property.kind.icon, accent: accent, size: 48)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(property.name).font(DS.Typography.brand(.title3, weight: .bold)).lineLimit(1)
                        Text(property.address).font(DS.Typography.brand(.footnote)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 36)
                }
                HStack(spacing: 8) {
                    fact("\(property.occupiedCount)/\(property.unitCount)", "rented", .gold)
                    fact("$\(property.monthlyRevenue.formatted(.number.precision(.fractionLength(1))))K", "a month", .mint)
                    fact("\(property.openRequests)", property.urgentRequests > 0 ? "\(property.urgentRequests) urgent" : "repairs", property.urgentRequests > 0 ? .cherry : .sky)
                }
                HStack(spacing: 4) {
                    Text("Open \(property.name)").lineLimit(1)
                    Image(systemName: "chevron.forward").font(.footnote.weight(.bold))
                }
                .font(DS.Typography.brand(.subheadline, weight: .semibold))
                .foregroundStyle(DS.Colors.brandInk)
            }
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(16)
            .homeGlass(radius: 28, tint: 0.7)
        }
        .buttonStyle(SquishStyle(scale: 0.97))
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(width: 44, height: 44)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(property.name). \(property.occupiedCount) of \(property.unitCount) rented. \(property.openRequests) repairs open.")
        .accessibilityHint("Opens the property")
        .accessibilityAction(named: "Close", onClose)
    }

    private func fact(_ value: String, _ label: String, _ accent: DSAccent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(DS.Typography.brandFixed(20)).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(DS.Typography.brand(.caption, weight: .semibold)).foregroundStyle(accent.ink).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(accent.tint))
    }
}
