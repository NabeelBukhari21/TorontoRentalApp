//
//  VendorPortalView.swift
//  RentalApp (Purrperty)
//
//  Vendor Portal — The app a contractor signs in to: their jobs and their
//  thread with the organization that sends them work. Nothing else from
//  the management app is reachable.
//

import SwiftUI

struct VendorPortalView: View {

    @State private var viewModel: VendorPortalViewModel

    @Environment(SessionViewModel.self) private var sessionModel
    @Environment(\.container) private var container

    init(session: AuthSession, container: AppContainer) {
        _viewModel = State(initialValue: VendorPortalViewModel(
            session: session,
            portal: container.vendorPortal,
            maintenance: container.maintenance,
            sync: container.sync
        ))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.groupedBackground)
            case .notLinked:
                NavigationStack {
                    ContentUnavailableView {
                        Label("No Jobs Yet", systemImage: AppSymbol.vendor.rawValue)
                    } description: {
                        Text("Your account isn't linked to a property manager yet. Ask them to add \(viewModel.session.email) as a vendor in Purrperty, and the jobs they send you will appear here.")
                    }
                    .navigationTitle("Purrperty")
                    .toolbar { accountMenu }
                }
            case .failed(let message):
                NavigationStack {
                    ContentUnavailableView {
                        Label("Couldn't Load Your Jobs", symbol: .caution)
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { Task { await viewModel.load() } }
                    }
                    .toolbar { accountMenu }
                }
            case .ready:
                tabs
            }
        }
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .maintenanceRequests) { await viewModel.load() }
        }
    }

    // MARK: Tabs

    private var tabs: some View {
        TabView {
            Tab("Jobs", systemImage: AppSymbol.vendor.rawValue) {
                NavigationStack {
                    VendorJobsView(viewModel: viewModel)
                        .toolbar { accountMenu }
                }
            }
            .badge(viewModel.newJobs.count)

            Tab("Messages", systemImage: AppSymbol.messages.rawValue) {
                NavigationStack {
                    messages
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    @ViewBuilder
    private var messages: some View {
        if let account = viewModel.account, let conversationID = account.conversationID {
            ChatView(
                conversationID: conversationID,
                perspective: .counterpart(otherName: account.client.name, context: "Property manager"),
                container: container
            )
        } else if let client = viewModel.account?.client {
            ContentUnavailableView {
                Label("No Messages Yet", systemImage: AppSymbol.messages.rawValue)
            } description: {
                Text("\(client.name) hasn't started a conversation with you in Purrperty yet. You can email \(client.email).")
            } actions: {
                if let url = URL(string: "mailto:\(client.email)") {
                    Link("Email \(client.name)", destination: url)
                }
            }
            .navigationTitle("Messages")
        }
    }

    // MARK: Account

    @ToolbarContentBuilder
    private var accountMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Account", systemImage: AppSymbol.person.rawValue) {
                Section(viewModel.account.map { "\($0.contactName) · \($0.company)" } ?? viewModel.session.email) {
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await sessionModel.signOut() }
                    }
                }
            }
        }
    }
}
