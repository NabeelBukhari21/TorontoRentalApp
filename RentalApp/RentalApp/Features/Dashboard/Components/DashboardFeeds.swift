//
//  DashboardFeeds.swift
//  RentalApp
//
//  Dashboard — AI insights carousel, upcoming tasks, and live activity feed.
//

import SwiftUI

// MARK: - AI Insights Card

struct DashboardAIInsightsCard: View {

    let insights: [AIInsight]
    var onAction: (AIInsight) -> Void = { _ in }

    @State private var selection = 0

    var body: some View {
        DSCard(style: .glass, cornerRadius: DS.Radius.xl) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header.
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: DS.Icons.ai)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Gradients.ai)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("AI Insights").dsOverline()

                    Spacer()

                    // Page dots.
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(insights.indices, id: \.self) { index in
                            Capsule()
                                .fill(
                                    index == selection
                                        ? AnyShapeStyle(DS.Gradients.ai)
                                        : AnyShapeStyle(DS.Colors.outline)
                                )
                                .frame(width: index == selection ? 18 : 6, height: 6)
                        }
                    }
                    .animation(DS.Motion.smooth, value: selection)
                }

                // Swipeable insights.
                TabView(selection: $selection) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                        insightPage(insight)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 158)
            }
        }
    }

    private func insightPage(_ insight: AIInsight) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: insight.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(insight.kind.color)
                    .frame(width: 36, height: 36)
                    .background(insight.kind.tint)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                Text(insight.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }

            Text(insight.message)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            DSButton(title: insight.actionTitle, icon: DS.Icons.ai, variant: .secondary, size: .small) {
                onAction(insight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, DS.Spacing.sm)
    }
}

// MARK: - Upcoming Tasks Card

struct DashboardTasksCard: View {

    let tasks: [UpcomingTask]
    let onToggle: (UpcomingTask) -> Void

    var body: some View {
        DSCard(style: .glass) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("Upcoming Tasks").dsOverline()
                    Spacer()
                    Text("\(tasks.filter { !$0.isDone }.count) open")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .contentTransition(.numericText())
                }

                VStack(spacing: DS.Spacing.sm) {
                    ForEach(tasks) { task in
                        taskRow(task)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func taskRow(_ task: UpcomingTask) -> some View {
        Button {
            onToggle(task)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Animated checkbox.
                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isDone ? Color.clear : DS.Colors.outline,
                            lineWidth: 1.5
                        )
                        .background(
                            Circle().fill(
                                task.isDone
                                    ? AnyShapeStyle(DS.Gradients.success)
                                    : AnyShapeStyle(Color.clear)
                            )
                        )
                        .frame(width: 24, height: 24)

                    if task.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Image(systemName: task.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(task.isUrgent ? DS.Colors.danger : DS.Colors.brand)
                    .frame(width: 28, height: 28)
                    .background(
                        (task.isUrgent ? DS.Colors.danger : DS.Colors.brand).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(task.isDone ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                        .strikethrough(task.isDone, color: DS.Colors.textTertiary)
                        .lineLimit(1)

                    Text(task.due)
                        .font(DS.Typography.caption)
                        .foregroundStyle(task.isUrgent && !task.isDone ? DS.Colors.danger : DS.Colors.textTertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(DSPressStyle())
    }
}

// MARK: - Activity Feed Card

struct DashboardActivityCard: View {

    let items: [ActivityItem]
    let onSeeAll: () -> Void

    var body: some View {
        DSCard(style: .glass) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Text("Recent Activity").dsOverline()

                    DSStatusDot(kind: .success, pulses: true, size: 7)

                    Spacer()

                    Button(action: onSeeAll) {
                        Text("See all")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.brand)
                    }
                    .buttonStyle(DSPressStyle(scale: 0.95))
                }

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        activityRow(item)

                        if index < items.count - 1 {
                            Rectangle()
                                .fill(DS.Colors.outline)
                                .frame(height: 0.5)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func activityRow(_ item: ActivityItem) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(item.kind.color)
                .frame(width: 32, height: 32)
                .background(item.kind.tint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(item.title)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    if item.isNew {
                        Text("NEW")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DS.Gradients.brand, in: Capsule())
                    }
                }

                Text(item.subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(item.time)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}
