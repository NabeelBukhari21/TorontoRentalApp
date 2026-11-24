//
//  SettingsPrefViews.swift
//  RentalApp (Purrperty)
//
//  Settings — Billing, Notifications, Appearance, AI Preferences,
//  and Integrations pages.
//

import SwiftUI

// MARK: - Billing

struct SettingsBillingPage: View {

    @State private var viewModel: BillingSettingsViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: BillingSettingsViewModel(repository: container.billing))
    }
    @State private var usageRevealed = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Plan card — obsidian signature.
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack {
                    Text("CURRENT PLAN")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .kerning(1.2)
                        .foregroundStyle(DS.Colors.textOnBrand)

                    Spacer()

                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Premium")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(DS.Colors.onHighlight)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(
                        DS.Gradients.highlight,
                        in: Capsule()
                    )
                }

                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(viewModel.planName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Colors.textOnBrand)

                    Spacer()

                    Text(viewModel.planPrice)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DS.Colors.textOnBrand)
                }

                // Usage.
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack {
                        Text("Units used")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.textOnBrand)

                        Spacer()

                        Text("\(viewModel.unitsUsed) / \(viewModel.unitQuota)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DS.Colors.textOnBrand)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.Colors.textOnBrand.opacity(0.25))

                            Capsule()
                                .fill(
                                    DS.Gradients.warm
                                )
                                .frame(
                                    width: proxy.size.width
                                        * (usageRevealed ? Double(viewModel.unitsUsed) / Double(viewModel.unitQuota) : 0)
                                )
                        }
                    }
                    .frame(height: 7)

                    Text("AI features, unlimited team members, priority support included.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Colors.textOnBrand)
                }
            }
            .padding(DS.Spacing.xl)
        .dsHeroSurface()
            .dsEntrance(index: 0)
            .onAppear {
                withAnimation(DS.Motion.entrance.delay(0.25)) {
                    usageRevealed = true
                }
            }

            HStack(spacing: DS.Spacing.md) {
                DSButton(title: "Change Plan", variant: .secondary, isFullWidth: true) {}
                DSButton(title: "Payment Method", variant: .soft, isFullWidth: true) {}
            }
            .dsEntrance(index: 1)

            SettingsSectionCard(title: "Invoices") {
                ForEach(Array(viewModel.invoices.enumerated()), id: \.element.id) { index, invoice in
                    HStack(spacing: DS.Spacing.md) {
                        SettingsIconTile(icon: "doc.text.fill", tint: DS.Colors.success)

                        Text(invoice.period)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.textPrimary)

                        Spacer()

                        Text(invoice.amount)
                            .font(DS.Typography.footnote.monospacedDigit())
                            .foregroundStyle(DS.Colors.textSecondary)

                        DSBadge(text: invoice.status, kind: .success)

                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(DS.Spacing.md + 2)

                    if index < viewModel.invoices.count - 1 {
                        SettingsRowDivider()
                    }
                }
            }
            .dsEntrance(index: 2)
        }
    }
}

// MARK: - Notifications

struct SettingsNotificationsPage: View {

    @State private var viewModel: PreferencesSettingsViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: PreferencesSettingsViewModel(repository: container.preferences))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: DS.Spacing.lg) {
            SettingsSectionCard(title: "Push alerts") {
                SettingsToggleRow(
                    icon: DS.Icons.maintenance, title: "Urgent maintenance",
                    subtitle: "Immediate alert for urgent tickets",
                    tint: DS.Colors.danger, isOn: $viewModel.notifyUrgentMaintenance
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: DS.Icons.payment, title: "Payments",
                    subtitle: "Rent received & overdue alerts",
                    tint: DS.Colors.success, isOn: $viewModel.notifyPayments
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: DS.Icons.messages, title: "Messages",
                    tint: DS.Colors.info, isOn: $viewModel.notifyMessages
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: DS.Icons.lease, title: "Lease events",
                    subtitle: "Renewals, signatures, expirations",
                    isOn: $viewModel.notifyLeaseEvents
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: DS.Icons.ai, title: "AI insights",
                    subtitle: "Copilot recommendations",
                    isOn: $viewModel.notifyAIInsights
                )
            }
            .dsEntrance(index: 0)

            SettingsSectionCard(title: "Email") {
                SettingsToggleRow(
                    icon: "envelope.fill", title: "Weekly digest",
                    subtitle: "Monday morning summary",
                    isOn: $viewModel.emailWeeklyDigest
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: DS.Icons.reports, title: "Monthly report",
                    subtitle: "Full portfolio PDF",
                    isOn: $viewModel.emailMonthlyReport
                )
            }
            .dsEntrance(index: 1)

            SettingsSectionCard(title: "Quiet hours") {
                SettingsToggleRow(
                    icon: "moon.fill", title: "Quiet hours",
                    subtitle: "10 PM – 8 AM · urgent alerts still deliver",
                    tint: DS.Colors.accentGoldInk, isOn: $viewModel.quietHoursEnabled
                )
            }
            .dsEntrance(index: 2)
        }
    }
}

// MARK: - Appearance

struct SettingsAppearancePage: View {

    @State private var viewModel: PreferencesSettingsViewModel
    #if DEBUG
    @State private var showsPurrGallery = false
    #endif

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: PreferencesSettingsViewModel(repository: container.preferences))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: DS.Spacing.lg) {
            // Theme picker with live preview tiles.
            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Theme").dsOverline()

                    HStack(spacing: DS.Spacing.md) {
                        ForEach(AppTheme.allCases) { theme in
                            themeTile(theme, isSelected: viewModel.theme == theme) {
                                withAnimation(DS.Motion.smooth) {
                                    viewModel.theme = theme
                                }
                            }
                        }
                    }

                    Text("Applies across the whole app instantly.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 0)

            purrLook
                .dsEntrance(index: 1)

            SettingsSectionCard(title: "Sound & haptics") {
                SettingsToggleRow(
                    icon: "speaker.wave.2.fill", title: "Sound effects",
                    subtitle: "Follow the Ring/Silent switch",
                    tint: DS.Colors.accentGoldInk, isOn: $viewModel.soundEffectsEnabled
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: "iphone.radiowaves.left.and.right", title: "Haptics",
                    subtitle: "Taps you can feel",
                    tint: DS.Colors.accentBlushInk, isOn: $viewModel.hapticsEnabled
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: "arrow.up.and.down", title: "Scrolling haptics",
                    subtitle: "Ticks as you scroll, on top of Haptics",
                    tint: DS.Colors.accentSkyInk, isOn: $viewModel.scrollHapticsEnabled
                )
                .disabled(!viewModel.hapticsEnabled)
                .opacity(viewModel.hapticsEnabled ? 1 : 0.5)
            }
            .dsEntrance(index: 2)

            SettingsSectionCard(title: "Home") {
                SettingsToggleRow(
                    icon: "cloud.sun.fill", title: "Toronto weather",
                    subtitle: "In the sky on Home. From Open-Meteo",
                    tint: DS.Colors.accentSkyInk, isOn: $viewModel.showsWeather
                )
            }
            .dsEntrance(index: 2)

            SettingsSectionCard(title: "Display") {
                SettingsToggleRow(
                    icon: "circle.hexagongrid.fill", title: "Reduce glass effects",
                    subtitle: "Simpler surfaces, better battery",
                    tint: DS.Colors.accentSkyInk, isOn: $viewModel.reduceGlassEffects
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: "eye.fill", title: "Show portfolio value on Home",
                    subtitle: "Hide for privacy in public",
                    isOn: $viewModel.showPortfolioValueOnHome
                )
            }
            .dsEntrance(index: 2)

            #if DEBUG
            Button("All of Purr's moods") { showsPurrGallery = true }
                .font(.footnote.weight(.semibold))
                .sheet(isPresented: $showsPurrGallery) { PurrGallery() }
            #endif
        }
    }

    // MARK: Purr's Look

    /// Four looks of the same cat, each a live preview. Picking one
    /// changes Purr everywhere at once.
    private var purrLook: some View {
        DSCard(style: .raised) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Purr's look").dsOverline()

                HStack(spacing: DS.Spacing.sm) {
                    ForEach(PurrStyle.allCases) { style in
                        purrTile(style, isSelected: viewModel.purrStyle == style) {
                            withAnimation(DS.Motion.smooth) { viewModel.purrStyle = style }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func purrTile(_ style: PurrStyle, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                PurrMascot(mood: .appearance, size: 64, isInteractive: false)
                    .environment(\.purrStyle, style)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.surface, in: .rect(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? DS.Colors.brand : DS.Colors.outline, lineWidth: isSelected ? 2 : 1)
                    )
                Text(style.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? DS.Colors.brand : DS.Colors.textSecondary)
            }
        }
        .buttonStyle(DSPressStyle())
        .accessibilityLabel("\(style.title) look")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func themeTile(_ theme: AppTheme, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                // Mini mock screen.
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(previewBackground(theme))

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewAccent(theme))
                            .frame(width: 26, height: 5)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewCard(theme))
                            .frame(width: 44, height: 16)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewCard(theme))
                            .frame(width: 44, height: 16)
                    }
                }
                .frame(height: 74)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isSelected ? DS.Colors.brand : DS.Colors.outline,
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                HStack(spacing: 3) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 9, weight: .semibold))
                    Text(theme.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(isSelected ? DS.Colors.brand : DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(DSPressStyle())
        .animation(DS.Motion.bouncy, value: isSelected)
    }

    private func previewBackground(_ theme: AppTheme) -> LinearGradient {
        switch theme {
        case .light:
            LinearGradient(colors: [DS.Colors.ThemeSwatch.lightBackground, DS.Colors.ThemeSwatch.lightSurface], startPoint: .top, endPoint: .bottom)
        case .dark:
            LinearGradient(colors: [DS.Colors.ThemeSwatch.darkBackground, DS.Colors.ThemeSwatch.darkSurface], startPoint: .top, endPoint: .bottom)
        case .system:
            LinearGradient(colors: [DS.Colors.ThemeSwatch.lightBackground, DS.Colors.ThemeSwatch.darkBackground], startPoint: .leading, endPoint: .trailing)
        }
    }

    /// The accent bar in each preview tile — the brand cherry as it
    /// actually renders in that mode.
    private func previewAccent(_ theme: AppTheme) -> Color {
        switch theme {
        case .light, .system: DS.Colors.ThemeSwatch.lightAccent
        case .dark: DS.Colors.ThemeSwatch.darkAccent
        }
    }

    private func previewCard(_ theme: AppTheme) -> Color {
        switch theme {
        case .light: DS.Colors.ThemeSwatch.lightSurface
        case .dark: DS.Colors.ThemeSwatch.darkSurface
        case .system: DS.Colors.ThemeSwatch.lightAccent.opacity(0.25)
        }
    }
}

// MARK: - AI Preferences

struct SettingsAIPage: View {

    @State private var viewModel: PreferencesSettingsViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: PreferencesSettingsViewModel(repository: container.preferences))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: DS.Spacing.lg) {
            // Copilot identity.
            AIHeroPanel {
                HStack(spacing: DS.Spacing.lg) {
                    PurrMascot(mood: .assistantIdle, size: 72)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Purrperty Intelligence")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.textOnBrand)

                        Text("Choose how much Copilot does for you")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(DS.Colors.textOnBrand)
                    }

                    Spacer()

                    DSBadge(text: "Active", kind: .success)
                }
            }
            .dsEntrance(index: 0)

            SettingsSectionCard(title: "Automation") {
                SettingsToggleRow(
                    icon: DS.Icons.maintenance, title: "Auto-triage requests",
                    subtitle: "Classify urgency & category on arrival",
                    isOn: $viewModel.aiAutoTriage
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: DS.Icons.messages, title: "Draft tenant replies",
                    subtitle: "You always review before sending",
                    isOn: $viewModel.aiDraftReplies
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: "person.badge.shield.checkmark.fill", title: "Vendor matching",
                    subtitle: "Suggest best vendor per ticket",
                    isOn: $viewModel.aiVendorMatching
                )
            }
            .dsEntrance(index: 1)

            SettingsSectionCard(title: "Insights") {
                SettingsToggleRow(
                    icon: DS.Icons.ai, title: "Weekly briefing",
                    subtitle: "Monday portfolio brief",
                    isOn: $viewModel.aiWeeklyBriefing
                )
                SettingsRowDivider()
                SettingsToggleRow(
                    icon: "chart.line.uptrend.xyaxis", title: "Pricing alerts",
                    subtitle: "Flag under/over-market rents",
                    isOn: $viewModel.aiPricingAlerts
                )
            }
            .dsEntrance(index: 2)

            // Proactiveness slider.
            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        Text("Proactiveness").dsOverline()
                        Spacer()
                        Text(proactivenessLabel)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.brand)
                            .contentTransition(.opacity)
                    }

                    Slider(value: $viewModel.aiProactiveness, in: 0...1)
                        .tint(DS.Colors.brand)

                    HStack {
                        Text("Only urgent")
                        Spacer()
                        Text("Highly proactive")
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(DS.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 3)
        }
    }

    private var proactivenessLabel: String {
        switch viewModel.aiProactiveness {
        case ..<0.25: "Minimal"
        case ..<0.5: "Balanced"
        case ..<0.8: "Proactive"
        default: "Copilot mode"
        }
    }
}

// MARK: - Integrations

struct SettingsIntegrationsPage: View {

    @State private var viewModel: IntegrationsSettingsViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: IntegrationsSettingsViewModel(repository: container.integrations))
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            SettingsSectionCard(title: "Planned") {
                ForEach(Array(viewModel.integrations.enumerated()), id: \.element.id) { index, integration in
                    HStack(spacing: DS.Spacing.md) {
                        SettingsIconTile(
                            icon: integration.icon,
                            tint: integration.isConnected ? DS.Colors.success : DS.Colors.textTertiary
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(integration.name)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(DS.Colors.textPrimary)

                            Text(integration.detail)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }

                        Spacer()

                        // No integration can be connected yet, so there's no
                        // button to press: just where each one stands.
                        DSBadge(
                            text: integration.isConnected ? "Connected" : "Coming soon",
                            kind: integration.isConnected ? .success : .neutral
                        )
                    }
                    .padding(DS.Spacing.md + 2)

                    if index < viewModel.integrations.count - 1 {
                        SettingsRowDivider()
                    }
                }
            }
            .dsEntrance(index: 0)

            DSCard(style: .raised) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)

                    Text("Integrations aren't available yet. These are the first ones planned.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dsEntrance(index: 1)
        }
    }
}
