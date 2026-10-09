//
//  NotificationsView.swift
//  RentalApp (RentOS)
//
//  Notifications — Grouped center (Today / Yesterday / Earlier) with
//  unread indicators, drag-to-dismiss, and mark-all-read.
//

import SwiftUI

struct NotificationsView: View {

    @Environment(\.container) private var container
    @Environment(AppRouter.self) private var router
    @State private var viewModel: NotificationsViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: NotificationsViewModel(repository: container.notifications))
    }

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.xl) {
                    if viewModel.isLoading {
                        DSListSkeleton(rows: 5)
                    } else if let error = viewModel.error {
                        DSErrorView(error: error) { await viewModel.retry() }
                    } else if viewModel.isEmpty {
                        DSEmptyState(
                            icon: DS.Icons.notifications,
                            title: "All clear",
                            message: "No notifications — you're completely caught up."
                        )
                        .padding(.top, DS.Spacing.huge)
                    } else {
                        ForEach(NotificationGroup.allCases, id: \.self) { group in
                            let items = viewModel.notifications(in: group)
                            if !items.isEmpty {
                                section(group: group, items: items)
                            }
                        }
                    }
                }
                .padding(DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.huge)
                .animation(DS.Motion.smooth, value: viewModel.notifications.map(\.id))
            }
            .refreshable { await viewModel.refresh() }
        }
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .notifications) {
                await viewModel.refresh()
            }
        }
        .dsHeader(
            title: "Notifications",
            subtitle: viewModel.unreadCount > 0 ? "\(viewModel.unreadCount) unread" : "All caught up",
            showsBack: true,
            trailingActions: [
                DSHeaderAction(icon: "checkmark.circle") {
                    Task { await viewModel.markAllRead() }
                }
            ]
        )
    }

    // MARK: Section

    private func section(group: NotificationGroup, items: [AppNotification]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(group.rawValue).dsOverline()

                Spacer()

                let unread = items.filter(\.isUnread).count
                if unread > 0 {
                    Text("\(unread) new")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Colors.brand)
                        .contentTransition(.numericText())
                }
            }

            VStack(spacing: DS.Spacing.sm) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, notification in
                    NotificationRow(
                        notification: notification,
                        onTap: { open(notification) },
                        onDismiss: { Task { await viewModel.dismiss(notification.id) } },
                        onAction: { actionID in
                            Task { await viewModel.perform(actionID, on: notification) }
                        },
                        onMuteSubject: { Task { await viewModel.muteSubject(of: notification) } },
                        onMuteCategory: { Task { await viewModel.muteCategory(of: notification) } }
                    )
                    .dsEntrance(index: index)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
                }
            }
        }
    }

    /// Marks read, then navigates to whatever the notification is about.
    ///
    /// The deep link is handed to the router rather than resolved here — the
    /// router owns tab selection and stack construction, and duplicating a
    /// subset of that is how a notification lands on the right screen in the
    /// wrong tab.
    private func open(_ notification: AppNotification) {
        Task { await viewModel.markRead(notification.id) }

        if let url = notification.deepLinkURL {
            router.open(url)
        } else if let route = notification.route {
            router.push(route)
        }
    }
}

// MARK: - Row (drag to dismiss)

private struct NotificationRow: View {

    let notification: AppNotification
    let onTap: () -> Void
    let onDismiss: () -> Void
    /// Inline actions the server attached to this row. The same identifiers
    /// are registered with iOS, so a lock-screen tap and an in-app tap run
    /// the same code.
    var onAction: ((String) -> Void)? = nil
    var onMuteSubject: (() -> Void)? = nil
    var onMuteCategory: (() -> Void)? = nil

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            // Reveal layer behind the card.
            if dragOffset < -10 {
                HStack {
                    Spacer()
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(DS.Colors.danger, in: Circle())
                        .scaleEffect(min(1, -dragOffset / 80))
                }
                .padding(.trailing, DS.Spacing.lg)
            }

            card
                .contextMenu {
                    if notification.subjectID != nil, let onMuteSubject {
                        Button {
                            onMuteSubject()
                        } label: {
                            Label("Mute this thread", systemImage: "bell.slash")
                        }
                    }
                    if let onMuteCategory {
                        Button {
                            onMuteCategory()
                        } label: {
                            Label("Mute \(notification.category.label.lowercased())",
                                  systemImage: "bell.slash.fill")
                        }
                    }
                    Divider()
                    Button(role: .destructive, action: onDismiss) {
                        Label("Dismiss", systemImage: "trash")
                    }
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            // Only allow leftward pull, with rubber-banding.
                            let translation = value.translation.width
                            dragOffset = translation < 0
                                ? translation
                                : translation * 0.12
                        }
                        .onEnded { value in
                            if value.translation.width < -90 {
                                withAnimation(DS.Motion.smooth) {
                                    dragOffset = -500
                                }
                                onDismiss()
                            } else {
                                withAnimation(DS.Motion.bouncy) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
        }
    }

    private var card: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: notification.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(notification.kind.color)
                        .frame(width: 38, height: 38)
                        .background(notification.kind.tint)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(
                            notification.isUnread
                                ? DS.Typography.headline
                                : DS.Typography.subheadline
                        )
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    Text(notification.message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Server-supplied actions. Absent for informational
                    // notifications, which is why this is conditional rather
                    // than a fixed row of buttons.
                    if !notification.actions.isEmpty, let onAction {
                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(notification.actions) { action in
                                Button {
                                    onAction(action.id)
                                } label: {
                                    Text(action.title)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            action.isDestructive
                                                ? DS.Colors.danger : DS.Colors.brand
                                        )
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.vertical, DS.Spacing.xs + 2)
                                        .background(
                                            (action.isDestructive
                                                ? DS.Colors.danger : DS.Colors.brand
                                            ).opacity(0.12),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(DSPressStyle(scale: 0.94))
                            }
                        }
                        .padding(.top, DS.Spacing.xs + 2)
                    }
                }

                Spacer(minLength: DS.Spacing.sm)

                VStack(alignment: .trailing, spacing: DS.Spacing.sm) {
                    Text(notification.time)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            notification.isUnread ? DS.Colors.brand : DS.Colors.textTertiary
                        )

                    if notification.isUnread {
                        Circle()
                            .fill(DS.Gradients.brand)
                            .frame(width: 9, height: 9)
                            .dsShadow(DS.Shadows.glow(DS.Colors.brand, intensity: 0.5))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(DS.Spacing.md + 2)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(
                        notification.isUnread
                            ? AnyShapeStyle(DS.Colors.brand.opacity(0.4))
                            : AnyShapeStyle(DS.Gradients.glassHighlight),
                        lineWidth: 1
                    )
            )
            .dsShadow(DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle())
    }
}

// MARK: - Previews

#Preview("Notifications") {
    NavigationStack {
        NotificationsView()
    }
    .environment(AppRouter())
}
