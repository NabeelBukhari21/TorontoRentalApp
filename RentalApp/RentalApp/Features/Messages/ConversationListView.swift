//
//  ConversationListView.swift
//  RentalApp (Purrperty)
//
//  Messages — Conversation list. On iPhone rows push the chat;
//  on iPad (regular width) it becomes a Slack-style split layout
//  with the thread open beside the list.
//

import SwiftUI

struct ConversationListView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.container) private var container
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var viewModel: ConversationListViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: ConversationListViewModel(
            repository: container.messages,
            notifications: container.notifications
        ))
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitLayout
            } else {
                compactLayout
            }
        }
    }

    // MARK: Compact (iPhone)

    private var compactLayout: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                listContent { conversation in
                    viewModel.open(conversation)
                    router.push(.conversation(conversationID: conversation.id))
                }
                .padding(DS.Spacing.lg)
            }
        }
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .conversations) {
                await viewModel.refresh()
            }
        }
        .navigationTitle("Messages")
        .navigationSubtitle(viewModel.totalUnread > 0 ? "\(viewModel.totalUnread) unread" : "All caught up")
    }

    // MARK: Split (iPad)

    private var splitLayout: some View {
        ZStack {
            DSAmbientBackground()

            HStack(spacing: 0) {
                // List column.
                ScrollView(showsIndicators: false) {
                    listContent { conversation in
                        viewModel.open(conversation)
                        withAnimation(DS.Motion.smooth) {
                            viewModel.selectedConversationID = conversation.id
                        }
                    }
                    .padding(DS.Spacing.lg)
                }
                .frame(width: 380)

                Rectangle()
                    .fill(DS.Colors.outline)
                    .frame(width: 0.5)

                // Thread pane.
                if let selectedID = viewModel.selectedConversationID {
                    ChatView(conversationID: selectedID, isEmbedded: true)
                        .id(selectedID)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    emptyPane
                }
            }
        }
        .navigationTitle("Messages")
        .navigationSubtitle(viewModel.totalUnread > 0 ? "\(viewModel.totalUnread) unread" : "All caught up")
    }

    private var emptyPane: some View {
        VStack {
            Spacer()
            DSEmptyState(
                icon: DS.Icons.messages,
                title: "Pick a conversation",
                message: "Select a thread from the list to start messaging."
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Shared List Content

    private func listContent(onOpen: @escaping (Conversation) -> Void) -> some View {
        VStack(spacing: DS.Spacing.md) {
            DSSearchBar(text: $viewModel.searchText, placeholder: "Search conversations…")
                .dsEntrance(index: 0)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    DSChip(title: "All", isSelected: viewModel.roleFilter == nil && !viewModel.unreadOnly) {
                        viewModel.roleFilter = nil
                        viewModel.unreadOnly = false
                    }
                    DSChip(title: "Tenants", icon: DS.Icons.tenant, isSelected: viewModel.roleFilter == .tenant) {
                        viewModel.roleFilter = viewModel.roleFilter == .tenant ? nil : .tenant
                    }
                    DSChip(title: "Vendors", icon: DS.Icons.vendor, isSelected: viewModel.roleFilter == .vendor) {
                        viewModel.roleFilter = viewModel.roleFilter == .vendor ? nil : .vendor
                    }
                    DSChip(title: "Unread", icon: "envelope.badge.fill", isSelected: viewModel.unreadOnly) {
                        viewModel.unreadOnly.toggle()
                    }
                }
                .padding(.horizontal, 1)
            }
            .dsEntrance(index: 1)

            if viewModel.isLoading {
                DSListSkeleton(rows: 6)
            } else if let error = viewModel.error {
                DSErrorView(error: error) { await viewModel.retry() }
            } else if viewModel.isEmpty {
                DSEmptyState(
                    icon: DS.Icons.messages,
                    title: "No conversations",
                    message: "Nothing matches — adjust your search or filters."
                )
                .padding(.top, DS.Spacing.xxl)
            } else {
                LazyVStack(spacing: DS.Spacing.sm) {
                    ForEach(Array(viewModel.filteredConversations.enumerated()), id: \.element.id) { index, conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: viewModel.selectedConversationID == conversation.id && sizeClass == .regular
                        ) {
                            onOpen(conversation)
                        }
                        .dsEntrance(index: min(2 + index, 12))
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .task { await viewModel.loadMoreIfNeeded(currentItem: conversation) }
                    }
                }
                .animation(DS.Motion.smooth, value: viewModel.filteredConversations.map(\.id))
            }
        }
    }
}
