//
//  AIAssistantView.swift
//  RentalApp (Purrperty)
//
//  AI Assistant — The operations copilot. Analyzing state, a briefing
//  that types itself, questions you ask and its answers, recommended
//  actions, insights, portfolio health, quick actions, and a live
//  activity log.
//

import SwiftUI

struct AIAssistantView: View {

    @Environment(AppRouter.self) private var router
    @State private var viewModel: AIAssistantViewModel
    @State private var draft = ""
    @FocusState private var isTyping: Bool
    /// A question brought from elsewhere, asked once on arrival.
    private let question: String?

    init(question: String? = nil, container: AppContainer = .shared) {
        self.question = question
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
                        conversation
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
        .safeAreaInset(edge: .bottom) {
            if viewModel.phase == .ready { composer }
        }
        .task {
            await viewModel.start()
            if let question { viewModel.ask(question) }
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: Conversation

    /// What's been asked here, each answer under its question.
    @ViewBuilder
    private var conversation: some View {
        if !viewModel.turns.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(viewModel.turns) { turn in
                    CopilotTurnView(turn: turn) { viewModel.retry(turn) }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    /// The question box, with starters while nothing has been asked.
    private var composer: some View {
        VStack(spacing: DS.Spacing.sm) {
            if viewModel.turns.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(AIAssistantViewModel.suggestions, id: \.self) { suggestion in
                            Button(suggestion) { send(suggestion) }
                                .font(DS.Typography.brand(.footnote, weight: .semibold))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .padding(.horizontal, DS.Spacing.md)
                                .frame(minHeight: 36)
                                .background(DS.Colors.surfaceRaised, in: Capsule())
                                .buttonStyle(DSPressStyle(scale: 0.93))
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                }
            }
            HStack(spacing: DS.Spacing.sm) {
                TextField("Ask about rent, repairs, units or leases", text: $draft, axis: .vertical)
                    .font(DS.Typography.brand(.body))
                    .lineLimit(1...4)
                    .focused($isTyping)
                    .submitLabel(.send)
                    .onSubmit { send(draft) }
                Button("Ask", systemImage: "arrow.up") { send(draft) }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DS.Colors.textOnBrand)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(DS.Colors.brand))
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isAsking)
                    .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.leading, DS.Spacing.lg).padding(.trailing, 6).padding(.vertical, 6)
            .frame(minHeight: 50)
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).strokeBorder(DS.Colors.brand.opacity(0.25), lineWidth: 1))
            .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(.bar)
    }

    private func send(_ text: String) {
        viewModel.ask(text)
        draft = ""
        isTyping = false
    }

    // MARK: Briefing

    private var briefingPanel: some View {
        AIHeroPanel {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.md) {
                    PurrMascot(mood: viewModel.isWorking ? .assistantThinking : .assistantAnswer, size: 72)

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
                        PurrMascot(mood: .allCaughtUp, size: 64)
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
            AISectionLabel(text: "Quick actions")

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
                    PurrMascot(mood: .assistantThinking, size: 48, isInteractive: false)

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
