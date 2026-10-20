//
//  AIAssistantView.swift
//  RentalApp (Purrperty)
//
//  AI Assistant — The operations copilot. Analyzing state, a briefing
//  that types itself, recommended actions, insights, portfolio health,
//  quick actions, and a live activity log.
//

import SwiftUI

struct AIAssistantView: View {

    @Environment(AppRouter.self) private var router
    @State private var viewModel: AIAssistantViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: AIAssistantViewModel(
            copilot: container.copilot,
            notifications: container.notifications
        ))
    }

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {
                    switch viewModel.phase {
                    case .analyzing:
                        AILoadingState()
                            .padding(.top, DS.Spacing.lg)

                    case .briefing:
                        briefingPanel

                    case .ready:
                        briefingPanel
                        readyContent

                    case .failed(let error):
                        DSErrorView(error: error) { await viewModel.retry() }
                    }
                }
                .padding(DS.Spacing.lg)
                .animation(DS.Motion.smooth, value: viewModel.phase)
            }
        }
        .navigationTitle("Copilot")
        .navigationSubtitle("Your operations copilot")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: Briefing

    private var briefingPanel: some View {
        AIHeroPanel {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.md) {
                    AIOrb(size: 52, isWorking: viewModel.isWorking)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DAILY BRIEFING")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .kerning(1.2)
                            .foregroundStyle(DS.Colors.textOnBrand)

                        Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.Colors.textOnBrand)
                    }

                    Spacer()

                    if viewModel.phase == .briefing {
                        DSStatusDot(kind: .warning, pulses: true, size: 8)
                    }
                }

                // Typed briefing with cursor.
                HStack(alignment: .bottom, spacing: 1) {
                    Text(viewModel.typedBriefing)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(DS.Colors.textOnBrand)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if viewModel.phase == .briefing {
                        BriefingCursor()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .dsEntrance(index: 0)
    }

    // MARK: Ready Content

    @ViewBuilder
    private var readyContent: some View {
        // Recommended actions.
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AISectionLabel(text: "Recommended actions")

            if viewModel.actions.isEmpty {
                DSCard(style: .raised) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(DS.Colors.success)
                        Text("All caught up — nothing needs your attention.")
                            .font(DS.Typography.footnote)
                            .foregroundStyle(DS.Colors.textSecondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(Array(viewModel.actions.enumerated()), id: \.element.id) { index, action in
                    AIActionCard(
                        action: action,
                        onAccept: { viewModel.accept(action) },
                        onDismiss: { viewModel.dismiss(action) }
                    )
                    .dsEntrance(index: index)
                }
            }
        }
        .animation(DS.Motion.smooth, value: viewModel.actions.map(\.id))

        // Quick actions.
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AISectionLabel(text: "Ask the copilot")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(viewModel.quickActions) { quickAction in
                        Button {
                            viewModel.run(quickAction)
                        } label: {
                            HStack(spacing: DS.Spacing.xs + 2) {
                                Image(systemName: quickAction.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(quickAction.title)
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(DS.Colors.brand)
                            .padding(.horizontal, DS.Spacing.md + 2)
                            .padding(.vertical, DS.Spacing.sm + 2)
                            .background(DS.Colors.surfaceRaised, in: Capsule())
                            .overlay(
                                Capsule().strokeBorder(DS.Colors.brand.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(DSPressStyle(scale: 0.93))
                        .disabled(viewModel.isWorking)
                    }
                }
                .padding(.horizontal, 1)
            }

            if viewModel.isWorking {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DS.Colors.brand)

                    Text("Copilot is working on it…")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .dsEntrance(index: 1)

        // Portfolio health.
        AIHealthCard(score: viewModel.healthScore, factors: viewModel.healthFactors)
            .dsEntrance(index: 2)

        // Insights.
        AIInsightPanel(
            title: "Maintenance Insights",
            icon: DS.Icons.maintenance,
            rows: viewModel.maintenanceInsights
        )
        .dsEntrance(index: 3)

        AIInsightPanel(
            title: "Lease Insights",
            icon: DS.Icons.lease,
            rows: viewModel.leaseInsights
        )
        .dsEntrance(index: 4)

        // Recent activity.
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    AISectionLabel(text: "Recent AI activity")
                    Spacer()
                    DSStatusDot(kind: .success, pulses: true, size: 7)
                }

                VStack(spacing: DS.Spacing.md) {
                    ForEach(viewModel.activity) { entry in
                        AIActivityRow(entry: entry)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .dsEntrance(index: 5)
        .animation(DS.Motion.smooth, value: viewModel.activity.map(\.id))
    }
}

// MARK: - Cursor

/// Blinking champagne cursor for the typewriter briefing.
private struct BriefingCursor: View {

    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(DS.Colors.textOnBrand)
            .frame(width: 2.5, height: 16)
            .opacity(visible ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - Previews

#Preview("AI Assistant") {
    RootNavigationView()
}
