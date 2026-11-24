//
//  AddressSuggestions.swift
//  RentalApp (Purrperty)
//
//  Components — What appears under a street field: the dropdown of
//  matching addresses, then whether the address checked out.
//

import MapKit
import SwiftUI

/// The dropdown.
struct AddressSuggestionList: View {

    let search: AddressSearch
    let onPick: (ResolvedAddress) -> Void

    @Environment(\.feedback) private var feedback

    var body: some View {
        if !search.suggestions.isEmpty {
            VStack(spacing: 0) {
                ForEach(search.suggestions) { suggestion in
                    Button {
                        TapAwayKeyboard.dismiss()
                        Task {
                            if let address = await search.resolve(suggestion) {
                                feedback?.play(.tick)
                                onPick(address)
                            }
                        }
                    } label: {
                        row(suggestion)
                    }
                    .buttonStyle(SquishStyle(scale: 0.98))
                    if suggestion.id != search.suggestions.last?.id {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(DS.Colors.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).strokeBorder(DS.Colors.outline))
            .shadow(color: DS.Colors.groundShadow, radius: 12, y: 8)
            .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Matching addresses")
        }
    }

    private func row(_ suggestion: AddressSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(DS.Colors.brandInk)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(suggestion.title)
                    .font(DS.Typography.brand(.callout, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(suggestion.subtitle)
                    .font(DS.Typography.brand(.footnote, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.left")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.Colors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .contentShape(.rect)
    }
}

/// The answer: verified on a small map, a correction, or a caution.
struct AddressStatusView: View {

    let search: AddressSearch
    let onPick: (ResolvedAddress) -> Void

    @Environment(\.feedback) private var feedback

    var body: some View {
        Group {
            switch search.status {
            case .idle, .unavailable:
                EmptyView()
            case .checking:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking the address…")
                }
                .font(DS.Typography.brand(.subheadline))
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            case .verified(let address):
                verified(address)
            case .didYouMean(let address):
                didYouMean(address)
            case .notFound:
                Label("We couldn’t find that address. Check the number and street, or continue to keep it as typed.", symbol: .caution)
                    .font(DS.Typography.brand(.footnote))
                    .foregroundStyle(DSAccent.gold.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(DS.Motion.bouncy, value: search.status)
    }

    private func verified(_ address: ResolvedAddress) -> some View {
        let place = CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude)
        return Map(
            initialPosition: .camera(MapCamera(centerCoordinate: place, distance: 420)),
            interactionModes: []
        ) {
            Marker(address.street, systemImage: "pawprint.fill", coordinate: place)
                .tint(DS.Colors.brand)
        }
        .mapStyle(.hybrid(pointsOfInterest: .excludingAll))
        .id(address)
        .frame(height: 132)
        .clipShape(.rect(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(alignment: .topLeading) {
            Label("Address verified", systemImage: "checkmark.seal.fill")
                .font(DS.Typography.brand(.footnote, weight: .semibold))
                .foregroundStyle(DSAccent.mint.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(DS.Colors.surfaceRaised))
                .padding(10)
        }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Address verified: \(address.street), \(address.city)")
    }

    private func didYouMean(_ address: ResolvedAddress) -> some View {
        Button {
            search.accept(address)
            feedback?.play(.tick)
            onPick(address)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse").font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Did you mean this?")
                        .font(DS.Typography.brand(.footnote, weight: .regular))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Text("\(address.street), \(address.city) \(address.postalCode)")
                        .font(DS.Typography.brand(.callout, weight: .semibold))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Text("Use it")
                    .font(DS.Typography.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(DS.Colors.brandInk)
            }
            .foregroundStyle(DS.Colors.textPrimary)
            .stagePanel()
        }
        .buttonStyle(SquishStyle(scale: 0.97))
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }
}
