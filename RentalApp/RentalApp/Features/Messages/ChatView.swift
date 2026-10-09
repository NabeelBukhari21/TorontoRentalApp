//
//  ChatView.swift
//  RentalApp (RentOS)
//
//  Messages — The thread. Glass chat header with live status,
//  animated bubbles, typing indicator, and a floating composer.
//  Works pushed (iPhone) or embedded in the iPad split layout.
//

import SwiftUI

struct ChatView: View {

    let conversationID: String
    let isEmbedded: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container
    @State private var viewModel: ChatViewModel
    @FocusState private var composerFocused: Bool

    init(conversationID: String, isEmbedded: Bool = false, container: AppContainer = .shared) {
        self.conversationID = conversationID
        self.isEmbedded = isEmbedded
        _viewModel = State(initialValue: ChatViewModel(
            conversationID: conversationID,
            repository: container.messages
        ))
    }

    private var conversation: Conversation? { viewModel.conversation }
    private var messages: [ChatMessage] { viewModel.messages }
    private var isTyping: Bool { viewModel.isTyping }

    var body: some View {
        ZStack {
            if !isEmbedded {
                DSAmbientBackground()
            }

            if let conversation {
                VStack(spacing: 0) {
                    chatHeader(conversation)

                    messageList(conversation)

                    composer
                }
            } else {
                DSEmptyState(
                    icon: DS.Icons.messages,
                    title: "Conversation not found",
                    message: "This thread may have been removed."
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        // Scoped reload rather than appending the decoded row.
        //
        // `ChatMessage.id` is a locally generated UUID rather than the
        // database row id, so an appended live message and the same message
        // refetched later would not deduplicate — the thread would show it
        // twice. Reloading one conversation is cheap, and the topic's 40ms
        // coalesce window keeps it feeling immediate. Giving ChatMessage a
        // server-derived id is the change that unlocks true append.
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .messages) {
                await viewModel.refresh()
            }
        }
    }

    // MARK: Header

    private func chatHeader(_ conversation: Conversation) -> some View {
        HStack(spacing: DS.Spacing.md) {
            if !isEmbedded {
                DSIconButton(icon: "chevron.left", diameter: 36) {
                    dismiss()
                }
                .accessibilityLabel("Back")
            }

            DSAvatar(
                name: conversation.name,
                size: .medium,
                status: conversation.isOnline ? .success : nil
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(conversation.name)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                Group {
                    if isTyping {
                        HStack(spacing: 3) {
                            Text("typing")
                            TimelineView(.animation(minimumInterval: 0.4)) { context in
                                let dots = Int(context.date.timeIntervalSinceReferenceDate / 0.4) % 4
                                Text(String(repeating: ".", count: dots))
                                    .frame(width: 12, alignment: .leading)
                            }
                        }
                        .foregroundStyle(DS.Colors.brand)
                    } else {
                        Text(conversation.isOnline ? "Online · \(conversation.context)" : conversation.context)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .animation(DS.Motion.gentle, value: isTyping)
            }

            Spacer()

            DSIconButton(icon: "phone.fill", diameter: 36) {}
            DSIconButton(icon: DS.Icons.more, diameter: 36) {}
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Colors.outline).frame(height: 0.5)
        }
    }

    // MARK: Message List

    private func messageList(_ conversation: Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        VStack(spacing: DS.Spacing.md) {
                            if let separator = message.showsDateSeparator {
                                ChatDateSeparator(text: separator)
                            }

                            ChatBubble(message: message, senderName: conversation.name)
                                .dsEntrance(index: min(index, 8))
                        }
                        .id(message.id)
                    }

                    if isTyping {
                        TypingIndicatorBubble(senderName: conversation.name)
                            .id("typing-indicator")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("thread-bottom")
                }
                .padding(DS.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                withAnimation(DS.Motion.smooth) {
                    proxy.scrollTo("thread-bottom", anchor: .bottom)
                }
            }
            .onChange(of: isTyping) { _, typing in
                if typing {
                    withAnimation(DS.Motion.smooth) {
                        proxy.scrollTo("thread-bottom", anchor: .bottom)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo("thread-bottom", anchor: .bottom)
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        @Bindable var viewModel = viewModel

        return HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            // Attach menu.
            Menu {
                Button {
                    Task { await viewModel.sendAttachment(.photo(paletteIndex: Int.random(in: 0..<6))) }
                } label: {
                    Label("Photo", systemImage: "photo.fill")
                }

                Button {
                    Task { await viewModel.sendAttachment(.document(name: "Document.pdf", size: "240 KB")) }
                } label: {
                    Label("Document", systemImage: "doc.fill")
                }
            } label: {
                Image(systemName: DS.Icons.add)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.brand)
                    .frame(width: 38, height: 38)
                    .background(DS.Colors.brand.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Add attachment")

            // Input.
            HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                TextField("Message…", text: $viewModel.draft, axis: .vertical)
                    .font(.system(size: 14.5))
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm + 2)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        composerFocused ? DS.Colors.brand.opacity(0.5) : DS.Colors.outline,
                        lineWidth: 1
                    )
            )
            .animation(DS.Motion.gentle, value: composerFocused)

            // Send.
            if !viewModel.canSend {
                DSIconButton(icon: "mic.fill", diameter: 38) {}
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.onGold)
                        .frame(width: 38, height: 38)
                        .background(
                            DS.Gradients.champagne,
                            in: Circle()
                        )
                        .dsShadow(DS.Shadows.glow(DS.Colors.brand, intensity: 0.4))
                }
                .buttonStyle(DSPressStyle(scale: 0.85))
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Send")
            }
        }
        .animation(DS.Motion.bouncy, value: viewModel.canSend)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.Colors.outline).frame(height: 0.5)
        }
    }
}

// MARK: - Previews

#Preview("Chat") {
    NavigationStack {
        ChatView(conversationID: "sarah-chen")
    }
    .environment(AppRouter())
}
