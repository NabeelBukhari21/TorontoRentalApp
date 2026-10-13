//
//  PaywallFlowView.swift
//  RentalApp (Purrperty)
//
//  Paywall — The three trial screens. Fun on the outside (Purr, motion,
//  haptics), plain on the inside: price, period, trial length and
//  auto-renewal are always stated, Restore/Terms/Privacy always work,
//  and the close button is never hidden or disguised (App Review §3.1.2).
//

import SwiftUI

struct PaywallFlowView: View {

    @State private var viewModel: PaywallViewModel
    /// `true` when the user ends up subscribed or in a trial.
    let onFinished: (_ subscribed: Bool) -> Void

    init(
        container: AppContainer,
        profile: OnboardingProfile,
        source: String,
        onFinished: @escaping (_ subscribed: Bool) -> Void
    ) {
        self.onFinished = onFinished
        _viewModel = State(initialValue: PaywallViewModel(
            entitlements: container.entitlements,
            featureFlags: container.featureFlags,
            analytics: container.analytics,
            profile: profile,
            source: source
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                Group {
                    switch viewModel.step {
                    case .intro:    PaywallIntroStep(viewModel: viewModel)
                    case .timeline: PaywallTimelineStep(viewModel: viewModel)
                    case .plans:    PaywallPlansStep(viewModel: viewModel)
                    }
                }
                .id(viewModel.step)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: viewModel.movesForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: viewModel.movesForward ? .leading : .trailing).combined(with: .opacity)
                    )
                )
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $viewModel.showsAllPlans) {
            PaywallAllPlansSheet(viewModel: viewModel)
                .presentationDetents([.large])
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            if viewModel.step != .intro {
                AuthBackButton { viewModel.goBack() }
                    .transition(.opacity)
            }
            Spacer()
            if viewModel.isDismissible {
                Button {
                    viewModel.dismissed()
                    onFinished(false)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(DS.Colors.surface, in: Circle())
                }
                .buttonStyle(DSPressStyle(scale: 0.9))
                .accessibilityLabel("Close, continue with the free plan")
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.sm)
        .animation(DS.Motion.smooth, value: viewModel.step)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: DS.Spacing.md) {
            if let error = viewModel.errorMessage {
                AuthFormError(message: error)
            }

            switch viewModel.step {
            case .intro, .timeline:
                DSButton(title: "Continue", variant: .primary, size: .large, isFullWidth: true) {
                    viewModel.advance()
                }
                Text("No charge today")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)

            case .plans:
                DSButton(
                    title: "Start my \(viewModel.trialDays)-day free trial",
                    variant: .primary, size: .large, isFullWidth: true,
                    isLoading: viewModel.isPurchasing
                ) {
                    Task {
                        if await viewModel.startTrial() { onFinished(true) }
                    }
                }
                .disabled(viewModel.selectedProduct == nil)

                if let product = viewModel.selectedProduct {
                    Text("\(viewModel.trialDays) days free, then \(product.displayPrice) per \(product.period). Renews automatically until you cancel. Cancel anytime in Settings at least 24 hours before the trial ends and you won't be charged.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PaywallLegalLinks(viewModel: viewModel, onRestored: { onFinished(true) })
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .frame(maxWidth: 560)
        .animation(DS.Motion.gentle, value: viewModel.errorMessage)
    }
}

// MARK: - Step 1: Intro

private struct PaywallIntroStep: View {

    let viewModel: PaywallViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(DS.Gradients.hero)
                    .frame(width: 160, height: 160)
                    .opacity(0.16)
                // 125pt keeps the sunglasses pose crisp (MascotPose.nativePixels).
                MascotView(mood: .cool, size: 125)
            }
            .dsEntrance(index: 0)

            VStack(spacing: DS.Spacing.sm) {
                Text("Try Purrperty \(viewModel.name(of: viewModel.featuredTier)) free for \(viewModel.trialDays) days")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Everything you asked for, and more.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .dsEntrance(index: 1)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(Array(viewModel.outcomes.enumerated()), id: \.offset) { index, outcome in
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DS.Colors.accentMintInk)
                        Text(outcome)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .dsEntrance(index: index + 2)
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
    }
}

// MARK: - Step 2: Timeline

private struct PaywallTimelineStep: View {

    @Bindable var viewModel: PaywallViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            HStack(alignment: .bottom) {
                Text("How your free trial works")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer(minLength: 0)
                MascotFaceView(face: .wink, size: 56)
            }
            .dsEntrance(index: 0)

            VStack(alignment: .leading, spacing: 0) {
                milestone(
                    icon: "lock.open.fill", tint: DS.Colors.brand, iconColor: DS.Colors.textOnBrand,
                    title: "Today", detail: "Full Premium access. No charge.",
                    isLast: false
                )
                milestone(
                    icon: "bell.fill", tint: DS.Colors.accentSunny,
                    title: "Day \(viewModel.reminderDay)",
                    detail: viewModel.remindsBeforeTrialEnds
                        ? "We remind you the trial is ending."
                        : "Reminder off. The trial still ends on day \(viewModel.trialDays).",
                    isLast: false
                )
                milestone(
                    icon: "star.fill", tint: DS.Colors.accentMint,
                    title: "Day \(viewModel.trialDays)",
                    detail: "Your trial ends. You're billed only if you keep Premium.",
                    isLast: true
                )
            }
            .dsEntrance(index: 1)

            Toggle(isOn: $viewModel.remindsBeforeTrialEnds) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me before it ends")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("A notification on day \(viewModel.reminderDay).")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .tint(DS.Colors.brand)
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .sensoryFeedback(.selection, trigger: viewModel.remindsBeforeTrialEnds)
            .dsEntrance(index: 2)
        }
    }

    private func milestone(
        icon: String,
        tint: Color,
        iconColor: Color = DS.Colors.textOnAccent,
        title: String,
        detail: String,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(tint, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(DS.Colors.outline)
                        .frame(width: 3, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(detail)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, DS.Spacing.sm)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step 3: Plans

private struct PaywallPlansStep: View {

    @Bindable var viewModel: PaywallViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            Text("Choose your plan")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(DS.Colors.textPrimary)
                .dsEntrance(index: 0)

            if viewModel.isLoadingProducts {
                ProgressView().frame(maxWidth: .infinity, minHeight: 160)
            } else {
                HStack(spacing: DS.Spacing.md) {
                    if let yearly = viewModel.yearly {
                        planCard(yearly, badge: viewModel.savingsPercent(for: viewModel.featuredTier).map { "Save \($0)%" })
                    }
                    if let monthly = viewModel.monthly {
                        planCard(monthly, badge: nil)
                    }
                }
                .dsEntrance(index: 1)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("\(viewModel.name(of: viewModel.featuredTier)) includes").dsOverline()
                ForEach(viewModel.featuredTier.entitlements.sorted { $0.title < $1.title }, id: \.self) { entitlement in
                    Label(entitlement.title, systemImage: "checkmark")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .labelStyle(PaywallCheckLabelStyle())
                }
            }
            .dsEntrance(index: 2)

            Button("View all plans") { viewModel.showsAllPlans = true }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.Colors.brandInk)
                .frame(maxWidth: .infinity)
                .dsEntrance(index: 3)
        }
    }

    private func planCard(_ product: SubscriptionProduct, badge: String?) -> some View {
        let isSelected = viewModel.selectedPeriod == product.billingPeriod

        return Button {
            withAnimation(DS.Motion.bouncy) { viewModel.selectedPeriod = product.billingPeriod }
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(product.billingPeriod == .year ? "Yearly" : "Monthly")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.textSecondary)

                Text(product.displayPrice)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("per \(product.period)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)

                // Price anchoring: the same price, broken down small.
                Text("≈ \(product.formatted(product.pricePerWeek)) a week")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? DS.Colors.brandInk : DS.Colors.textSecondary)
                    .padding(.top, DS.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(isSelected ? DS.Colors.brand.opacity(0.08) : DS.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(isSelected ? DS.Colors.brand : DS.Colors.outline, lineWidth: isSelected ? 2.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(DS.Colors.textOnAccent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.accentSunny, in: Capsule())
                        .offset(x: -DS.Spacing.sm, y: -DS.Spacing.md)
                }
            }
        }
        .buttonStyle(DSPressStyle(scale: 0.97))
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel("\(product.billingPeriod == .year ? "Yearly" : "Monthly"), \(product.displayPrice) per \(product.period)\(badge.map { ", \($0)" } ?? "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PaywallCheckLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            configuration.icon
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(DS.Colors.accentMintInk)
            configuration.title
        }
    }
}

// MARK: - Legal

private struct PaywallLegalLinks: View {

    let viewModel: PaywallViewModel
    let onRestored: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            Button("Restore purchases") {
                Task { if await viewModel.restore() { onRestored() } }
            }
            Link("Terms", destination: LegalDocument.termsOfService.url())
            Link("Privacy", destination: LegalDocument.privacyPolicy.url())
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DS.Colors.textSecondary)
    }
}

// MARK: - All Plans

/// Every tier with every benefit — people like to read before paying.
private struct PaywallAllPlansSheet: View {

    @Bindable var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    private let tiers: [SubscriptionTier] = [.free, .starter, .professional]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    ForEach(tiers, id: \.self) { tier in
                        tierCard(tier)
                    }
                }
                .padding(DS.Spacing.xl)
            }
            .background(DS.Colors.background)
            .navigationTitle("All plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func tierCard(_ tier: SubscriptionTier) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(viewModel.name(of: tier))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                if tier == viewModel.featuredTier {
                    Text("Recommended")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Colors.brandInk)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.brand.opacity(0.14), in: Capsule())
                }
            }

            if tier == .free {
                Text("Free forever")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
            } else {
                ForEach([SubscriptionProduct.BillingPeriod.year, .month], id: \.self) { period in
                    if let product = viewModel.product(tier, period) {
                        Text("\(product.displayPrice) per \(product.period)")
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
            }

            Label(tier.propertyLimit.map { "Up to \($0) properties" } ?? "Unlimited properties", systemImage: "checkmark")
                .labelStyle(PaywallCheckLabelStyle())
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Colors.textPrimary)

            ForEach(tier.entitlements.filter { $0 != .unlimitedProperties }.sorted { $0.title < $1.title }, id: \.self) { entitlement in
                Label(entitlement.title, systemImage: "checkmark")
                    .labelStyle(PaywallCheckLabelStyle())
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
            }

            if tier != .free {
                // The base screen sells one tier at a time; choosing here
                // makes this tier the one its Yearly/Monthly cards offer.
                DSButton(
                    title: viewModel.featuredTier == tier ? "Selected" : "Choose \(viewModel.name(of: tier))",
                    variant: viewModel.featuredTier == tier ? .soft : .primary,
                    size: .medium,
                    isFullWidth: true
                ) {
                    viewModel.featuredTier = tier
                    dismiss()
                }
                .disabled(viewModel.featuredTier == tier)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(tier == viewModel.featuredTier ? DS.Colors.brand : DS.Colors.outline, lineWidth: tier == viewModel.featuredTier ? 2 : 1)
        )
    }
}
