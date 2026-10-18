//
//  ContentView.swift
//  RentalApp (Purrperty)
//
//  App entry — hosts the root navigation coordinator.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.container) private var container

    var body: some View {
        RootNavigation(container: container)
    }
}

#Preview {
    ContentView()
}
