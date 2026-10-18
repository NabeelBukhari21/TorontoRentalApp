//
//  ActionBar.swift
//  RentalApp (Purrperty)
//
//  AppStyle — The bottom action bar used by setup flows, sign-in and
//  forms: a `safeAreaBar` holding one `.glassProminent` button and,
//  optionally, a plain secondary button beneath it.
//

import SwiftUI


extension View {
    /// A screen's one prominent action (plus any secondary one), in a bar
    /// along the bottom edge. Content scrolls beneath it with the system
    /// scroll edge effect.
    func primaryActionBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        safeAreaBar(edge: .bottom) {
            VStack(spacing: 12) {
                content()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: 540)
        }
    }
}

/// The prominent, full-width Liquid Glass button for a screen's main action.
struct PrimaryActionButton: View {

    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView() }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(isLoading)
    }
}
